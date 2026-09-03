#!/usr/bin/env python3
"""Mechanical checks for every <skill>/SKILL.md under a skills root.

Usage:
  lint_skills.py [--root DIR] [--skill NAME ...] [--json]

Default root: the directory that contains this skill (i.e. ~/dotfiles/skills when run
from the symlinked copy, because the path is resolved first).

Rules are tagged by severity:
  error  — the skill is invalid per the Anthropic / agentskills.io spec
  warn   — a SHOULD from the best-practices digest that can be checked mechanically
  style  — a house-style convention from references/house-style.md
  info   — cross-skill observations (naming mix, description style mix)

Judgment calls (conciseness, defaults-not-menus, terminology) are NOT checked here;
the audit skill does those by reading. Exit code 1 when any error is found.

Stdlib only.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

# --- limits from the digest ---------------------------------------------------------------
NAME_MAX = 64                 # Anthropic frontmatter rule
DESCRIPTION_MAX = 1024        # Anthropic frontmatter rule
DESCRIPTION_MIN_USEFUL = 60   # shorter than this reads like "Helps with documents"
BODY_MAX_LINES = 500          # Anthropic + agentskills.io hard guidance
BODY_WARN_LINES = 350         # "split when approaching the limit"
BODY_MAX_TOKENS_EST = 5000    # agentskills.io token budget; estimated as words * 1.3
TOKENS_PER_WORD = 1.3
REFERENCE_TOC_LINES = 100     # reference files longer than this need a Contents list
PROSE_MAX_COLUMNS = 100       # house style wraps at ~90; flag only clearly over
FOLDED_DESCRIPTION_MIN = 100  # house style: use `>` block once the description is this long

NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
RESERVED_WORDS = ("anthropic", "claude")
XML_TAG_RE = re.compile(r"<[a-zA-Z/][^>]*>")
FIRST_SECOND_PERSON_RE = re.compile(r"\b(I can|I will|I'll|you can use|you can)\b", re.I)
TRIGGER_RE = re.compile(r"\b(use (this )?when(ever)?|when the user|whenever the user|triggers? on|activates? (for|when))\b", re.I)
WINDOWS_PATH_RE = re.compile(r"(?<![\w\\])(?:[A-Za-z]:\\|(?:scripts|references|assets|docs)\\\w)")
TIME_SENSITIVE_RE = re.compile(
    r"\b(before|after|until|as of|since|prior to)\s+"
    r"((jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+)?(19|20)\d{2}\b",
    re.I,
)
TODO_RE = re.compile(r"^\s*(?:[-*>]\s*|<!--\s*)?(TODO|TBD|FIXME|XXX)\b")
MD_LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s#]+)(?:#[^)]*)?\)")
BARE_REF_RE = re.compile(r"`((?:scripts|references|assets)/[^`\s]+)`")
STEP_HEADING_RE = re.compile(r"^##\s+Step\s+\d+\s*[—–-]", re.M)
PHASE_HEADING_RE = re.compile(r"^##\s+Phase\s+\d+\s*[—–-]", re.M)
VERB_FIRST_NAMES = ("sync-", "run-", "build-", "check-", "make-", "create-", "generate-", "update-", "fix-", "review-", "audit-")

# Keys Claude Code / the spec understand. Anything else is probably a typo.
KNOWN_FRONTMATTER_KEYS = {
    "name", "description", "disable-model-invocation", "user-invocable", "allowed-tools",
    "model", "context", "agent", "argument-hint", "hooks", "paths", "version",
    "compatibility", "metadata", "license",
}


@dataclass
class Finding:
    skill: str
    severity: str  # error | warn | style | info
    rule: str
    message: str
    file: str = "SKILL.md"
    line: int | None = None


# --- tiny YAML subset parser --------------------------------------------------------------
def parse_frontmatter(text: str) -> tuple[dict | None, str, int, list[str]]:
    """Return (fields, body, body_start_line, parse_errors).

    Handles `key: value`, quoted scalars, `>`/`|` block scalars (with optional chomping
    indicator), and simple `- item` lists. Enough for skill frontmatter; anything else is
    reported as a parse error rather than guessed.
    """
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None, text, 1, ["no frontmatter block (file must start with `---`)"]
    end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if end is None:
        return None, text, 1, ["frontmatter opened with `---` but never closed"]

    fields: dict[str, object] = {}
    raw_style: dict[str, str] = {}
    errors: list[str] = []
    i = 1
    while i < end:
        line = lines[i]
        if not line.strip() or line.lstrip().startswith("#"):
            i += 1
            continue
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if not m:
            errors.append(f"line {i + 1}: cannot parse `{line.strip()}`")
            i += 1
            continue
        key, rest = m.group(1), m.group(2)
        if re.fullmatch(r"[>|][+-]?", rest):
            block: list[str] = []
            i += 1
            while i < end and (not lines[i].strip() or lines[i].startswith((" ", "\t"))):
                block.append(lines[i].strip())
                i += 1
            joiner = " " if rest.startswith(">") else "\n"
            fields[key] = joiner.join(part for part in block if part).strip()
            raw_style[key] = "folded" if rest.startswith(">") else "literal"
            continue
        if rest == "":
            items: list[str] = []
            i += 1
            while i < end and re.match(r"^\s+-\s+", lines[i]):
                items.append(re.sub(r"^\s+-\s+", "", lines[i]).strip())
                i += 1
            fields[key] = items
            raw_style[key] = "list"
            continue
        if len(rest) >= 2 and rest[0] == rest[-1] and rest[0] in "\"'":
            rest = rest[1:-1]
        fields[key] = rest
        raw_style[key] = "plain"
        i += 1
    fields["__style__"] = raw_style
    body = "\n".join(lines[end + 1:])
    return fields, body, end + 2, errors


# --- per-skill checks ----------------------------------------------------------------------
def strip_code_blocks(body: str) -> list[tuple[int, str]]:
    """Body lines with fenced code removed, keeping original line numbers (1-based within body)."""
    out: list[tuple[int, str]] = []
    in_fence = False
    for idx, line in enumerate(body.split("\n"), start=1):
        if line.strip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            out.append((idx, line))
    return out


def lint_skill(skill_dir: Path) -> list[Finding]:
    name = skill_dir.name
    skill_md = skill_dir / "SKILL.md"
    findings: list[Finding] = []
    add = lambda sev, rule, msg, **kw: findings.append(Finding(name, sev, rule, msg, **kw))  # noqa: E731

    if not skill_md.exists():
        add("error", "FM001", "SKILL.md is missing")
        return findings
    text = skill_md.read_text()
    fields, body, body_start, parse_errors = parse_frontmatter(text)
    for err in parse_errors:
        add("error", "FM001", f"frontmatter: {err}")
    if fields is None:
        return findings
    style = fields.pop("__style__", {})

    # name
    fm_name = fields.get("name")
    if not isinstance(fm_name, str) or not fm_name:
        add("error", "FM002", "`name` is missing")
    else:
        if len(fm_name) > NAME_MAX:
            add("error", "FM003", f"`name` is {len(fm_name)} chars (max {NAME_MAX})")
        if not NAME_RE.match(fm_name):
            add("error", "FM003", f"`name` `{fm_name}` must be lowercase letters, digits and single hyphens")
        if any(word in fm_name for word in RESERVED_WORDS):
            add("error", "FM004", f"`name` contains a reserved word ({', '.join(RESERVED_WORDS)})")
        if fm_name != name:
            add("error", "FM005", f"`name` `{fm_name}` does not match directory `{name}`")
        if XML_TAG_RE.search(fm_name):
            add("error", "FM008", "`name` contains XML tags")

    # description
    desc = fields.get("description")
    if not isinstance(desc, str) or not desc.strip():
        add("error", "FM006", "`description` is missing or empty")
    else:
        if len(desc) > DESCRIPTION_MAX:
            add("error", "FM007", f"`description` is {len(desc)} chars (max {DESCRIPTION_MAX})")
        if XML_TAG_RE.search(desc):
            add("error", "FM008", "`description` contains XML tags")
        if FIRST_SECOND_PERSON_RE.search(desc):
            add("warn", "FM009", "`description` uses first/second person; write it in third person")
        if not TRIGGER_RE.search(desc):
            add("warn", "FM010", "`description` has no 'Use when …' trigger clause — say when to use it, not only what it does")
        if len(desc) < DESCRIPTION_MIN_USEFUL:
            add("warn", "FM011", f"`description` is only {len(desc)} chars — likely too vague for discovery")
        if len(desc) >= FOLDED_DESCRIPTION_MIN and style.get("description") == "plain":
            add("style", "FM013", "long `description` on one line — house style uses the folded block (`description: >`)")
        if re.match(r"^\s*this skill", desc, re.I):
            add("style", "HS004", "`description` opens with 'This skill …' — house style opens with an imperative verb")
        elif not re.search(r"\buse (this )?when(ever)?\b", desc, re.I):
            add("style", "HS005", "`description` lacks the literal 'Use when …' clause used across the collection")

    for key in fields:
        if key not in KNOWN_FRONTMATTER_KEYS:
            add("warn", "FM012", f"unknown frontmatter key `{key}`")
    extra = sorted(set(fields) - {"name", "description", "disable-model-invocation"})
    if extra:
        add("style", "HS006", f"house style keeps frontmatter to name/description(/disable-model-invocation); found {', '.join(extra)}")

    # body size
    body_lines = body.split("\n")
    n_lines = len(body_lines)
    n_words = len(body.split())
    est_tokens = int(n_words * TOKENS_PER_WORD)
    if n_lines > BODY_MAX_LINES:
        add("error", "BD001", f"body is {n_lines} lines (max {BODY_MAX_LINES}); split into references/")
    elif n_lines > BODY_WARN_LINES:
        add("warn", "BD002", f"body is {n_lines} lines — approaching the {BODY_MAX_LINES}-line limit")
    if est_tokens > BODY_MAX_TOKENS_EST:
        add("warn", "BD002", f"body is ~{est_tokens} tokens (budget ~{BODY_MAX_TOKENS_EST})")

    prose = strip_code_blocks(body)
    if not any(re.match(r"^#\s+\S", line) for _, line in prose):
        add("warn", "BD003", "body has no `# Title` heading")

    long_lines: list[int] = []
    for idx, line in prose:
        ln = body_start + idx - 1
        if len(line) > PROSE_MAX_COLUMNS and not re.search(r"https?://|\|", line):
            long_lines.append(ln)
        if WINDOWS_PATH_RE.search(line):
            add("warn", "BD004", "Windows-style path — use forward slashes", line=ln)
        if TIME_SENSITIVE_RE.search(line):
            add("warn", "BD005", "time-sensitive phrasing — move to an 'Old patterns' section", line=ln)
        if TODO_RE.search(line):
            add("warn", "BD010", f"leftover marker: {TODO_RE.search(line).group(0)}", line=ln)
    if long_lines:
        sample = ", ".join(map(str, long_lines[:6])) + (", …" if len(long_lines) > 6 else "")
        add("style", "HS003", f"{len(long_lines)} prose lines exceed {PROSE_MAX_COLUMNS} columns (house style wraps ~90): lines {sample}", line=long_lines[0])

    # references: exist, one level deep, TOC on long ones
    referenced: set[str] = set()
    for _, line in prose:
        for m in MD_LINK_RE.finditer(line):
            target = m.group(1)
            if not re.match(r"^[a-z]+://|^mailto:", target):
                referenced.add(target)
        for m in BARE_REF_RE.finditer(line):
            referenced.add(m.group(1))
    for target in sorted(referenced):
        if "<" in target:  # placeholder such as references/<slug>.md, not a real path
            continue
        path = (skill_dir / target).resolve()
        if not path.exists():
            # Relative paths climbing out of the skill (../other-skill/...) are checked too.
            add("warn", "BD006", f"referenced file `{target}` does not exist")
            continue
        if path.suffix == ".md" and path.is_relative_to(skill_dir.resolve()):
            ref_text = path.read_text()
            ref_lines = ref_text.count("\n") + 1
            if ref_lines > REFERENCE_TOC_LINES and not re.search(r"^##\s+(contents|table of contents)\b", ref_text, re.I | re.M):
                add("warn", "BD008", f"`{target}` is {ref_lines} lines with no `## Contents` list", file=target)
            nested = [
                m.group(1) for _, l in strip_code_blocks(ref_text) for m in MD_LINK_RE.finditer(l)
                if m.group(1).endswith(".md") and not re.match(r"^[a-z]+://", m.group(1))
                and (path.parent / m.group(1)).exists()
            ]
            if nested:
                add("warn", "BD007", f"`{target}` links onward to {', '.join(nested)} — keep references one level deep from SKILL.md", file=target)

    # orphan bundled files
    for sub in ("scripts", "references", "assets"):
        d = skill_dir / sub
        if d.is_dir():
            for f in sorted(p for p in d.rglob("*") if p.is_file() and not p.name.startswith(".")):
                rel = f.relative_to(skill_dir).as_posix()
                parent = f.parent.relative_to(skill_dir).as_posix() + "/"
                if rel not in referenced and f.name not in body and parent not in body:
                    add("info", "BD009", f"bundled file `{rel}` is never mentioned in SKILL.md")

    # house-style structure
    if STEP_HEADING_RE.search(body) and not PHASE_HEADING_RE.search(body):
        add("style", "HS002", "H2 headings use 'Step N —'; house style uses 'Phase N —'")
    if not re.search(r"^##\s+(verif|report|phase\s+\d+\s*[—–-]\s*verif)", body, re.I | re.M):
        add("style", "HS001", "no `## Verify` / `## Report` section — every skill ends by checking and reporting its work")
    if not re.search(r"^##\s+notes\s*&\s*edge cases", body, re.I | re.M):
        add("style", "HS007", "no `## Notes & edge cases` section")

    return findings


# --- cross-skill checks -------------------------------------------------------------------
def lint_collection(skill_dirs: list[Path]) -> list[Finding]:
    findings: list[Finding] = []
    names: dict[str, list[str]] = {}
    verb_first: list[str] = []
    folded: list[str] = []
    plain: list[str] = []
    for d in skill_dirs:
        skill_md = d / "SKILL.md"
        if not skill_md.exists():
            continue
        fields, _, _, _ = parse_frontmatter(skill_md.read_text())
        if not fields:
            continue
        style = fields.get("__style__", {})
        n = fields.get("name")
        if isinstance(n, str):
            names.setdefault(n, []).append(d.name)
            if n.startswith(VERB_FIRST_NAMES):
                verb_first.append(n)
        if "description" in style:
            (folded if style["description"] == "folded" else plain).append(d.name)
    for n, dirs in names.items():
        if len(dirs) > 1:
            findings.append(Finding("*", "error", "XS003", f"duplicate skill name `{n}` in {', '.join(dirs)}"))
    if verb_first and len(verb_first) < len(names):
        findings.append(Finding("*", "info", "XS001", f"naming mix: verb-first {verb_first} vs noun-phrase for the rest — pick one pattern"))
    if folded and plain:
        findings.append(Finding("*", "info", "XS002", f"description style mix: folded block in {len(folded)} skills, single line in {plain}"))
    return findings


# --- output ---------------------------------------------------------------------------------
SEVERITY_ORDER = {"error": 0, "warn": 1, "style": 2, "info": 3}


def render_markdown(findings: list[Finding], skill_dirs: list[Path]) -> str:
    out = [f"# Skills lint — {len(skill_dirs)} skills, {len(findings)} findings", ""]
    counts = {s: sum(1 for f in findings if f.severity == s) for s in SEVERITY_ORDER}
    out.append(" · ".join(f"{k}: {v}" for k, v in counts.items()))
    out.append("")
    by_skill: dict[str, list[Finding]] = {}
    for f in findings:
        by_skill.setdefault(f.skill, []).append(f)
    for d in skill_dirs:
        items = sorted(by_skill.get(d.name, []), key=lambda f: (SEVERITY_ORDER[f.severity], f.rule, f.line or 0))
        out.append(f"## {d.name}" + ("" if items else " — clean"))
        for f in items:
            loc = f"{f.file}:{f.line}" if f.line else f.file
            out.append(f"- **{f.severity}** `{f.rule}` {f.message} _({loc})_")
        out.append("")
    if "*" in by_skill:
        out.append("## Across the collection")
        for f in sorted(by_skill["*"], key=lambda f: (SEVERITY_ORDER[f.severity], f.rule)):
            out.append(f"- **{f.severity}** `{f.rule}` {f.message}")
        out.append("")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2], help="skills root (default: parent of this skill)")
    ap.add_argument("--skill", action="append", default=[], help="only lint this skill (repeatable)")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of markdown")
    args = ap.parse_args(argv[1:])

    root = args.root.resolve()
    skill_dirs = sorted(p.parent for p in root.glob("*/SKILL.md"))
    if args.skill:
        missing = set(args.skill) - {d.name for d in skill_dirs}
        if missing:
            print(f"no such skill(s) under {root}: {', '.join(sorted(missing))}", file=sys.stderr)
            return 2
        skill_dirs = [d for d in skill_dirs if d.name in args.skill]
    if not skill_dirs:
        print(f"no */SKILL.md found under {root}", file=sys.stderr)
        return 2

    findings: list[Finding] = []
    for d in skill_dirs:
        findings.extend(lint_skill(d))
    if not args.skill:
        findings.extend(lint_collection(skill_dirs))

    if args.json:
        print(json.dumps([asdict(f) for f in findings], indent=2))
    else:
        print(render_markdown(findings, skill_dirs))
    return 1 if any(f.severity == "error" for f in findings) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
