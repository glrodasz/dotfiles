#!/usr/bin/env python3
"""Inventory a pull-request-sized Git diff for semantic split planning.

The script is intentionally read-only. It compares a source ref with its merge
base, classifies changed files, and maps best-effort CODEOWNERS matches from the
base branch. It never modifies the repository.
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import shutil
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple


class AnalysisError(RuntimeError):
    """Raised when repository analysis cannot continue safely."""


def run_command(
    args: Sequence[str],
    cwd: Path,
    *,
    check: bool = True,
    text: bool = True,
) -> subprocess.CompletedProcess[Any]:
    result = subprocess.run(
        list(args),
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=text,
        check=False,
    )
    if check and result.returncode != 0:
        stderr = result.stderr.strip() if text else result.stderr.decode("utf-8", "replace").strip()
        raise AnalysisError(f"Command failed ({' '.join(args)}): {stderr}")
    return result


def git(repo: Path, *args: str, check: bool = True, text: bool = True) -> subprocess.CompletedProcess[Any]:
    return run_command(("git", *args), repo, check=check, text=text)


def git_text(repo: Path, *args: str, check: bool = True) -> str:
    return git(repo, *args, check=check, text=True).stdout.strip()


def resolve_repo(path: str) -> Path:
    candidate = Path(path).expanduser().resolve()
    result = run_command(
        ("git", "rev-parse", "--show-toplevel"),
        candidate,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        raise AnalysisError(f"Not a Git repository: {candidate}")
    return Path(result.stdout.strip()).resolve()


def ref_exists(repo: Path, ref: str) -> bool:
    result = git(repo, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}", check=False)
    return result.returncode == 0


def resolve_named_ref(repo: Path, name: str, remote: str, prefer_remote: bool) -> Optional[str]:
    if not name:
        return None

    looks_qualified = (
        name.startswith("refs/")
        or name.startswith(f"{remote}/")
        or "/" in name
        or re.fullmatch(r"[0-9a-fA-F]{7,40}", name) is not None
    )

    if looks_qualified:
        candidates = [name]
    elif prefer_remote:
        candidates = [f"{remote}/{name}", name]
    else:
        candidates = [name, f"{remote}/{name}"]

    for candidate in candidates:
        if ref_exists(repo, candidate):
            return candidate
    return None


def discover_current_pr(repo: Path) -> Optional[Dict[str, Any]]:
    if shutil.which("gh") is None:
        return None

    result = run_command(
        (
            "gh",
            "pr",
            "view",
            "--json",
            "number,url,title,baseRefName,headRefName,isDraft",
        ),
        repo,
        check=False,
        text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None

    try:
        value = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def resolve_base(
    repo: Path,
    explicit_base: Optional[str],
    remote: str,
    current_pr: Optional[Dict[str, Any]],
) -> Tuple[str, str]:
    if explicit_base:
        resolved = resolve_named_ref(repo, explicit_base, remote, prefer_remote=False)
        if resolved:
            return resolved, "explicit"
        raise AnalysisError(f"Base ref does not exist locally: {explicit_base}")

    if current_pr and current_pr.get("baseRefName"):
        resolved = resolve_named_ref(
            repo,
            str(current_pr["baseRefName"]),
            remote,
            prefer_remote=True,
        )
        if resolved:
            return resolved, "current GitHub PR"

    remote_head = git_text(
        repo,
        "symbolic-ref",
        "--quiet",
        "--short",
        f"refs/remotes/{remote}/HEAD",
        check=False,
    )
    if remote_head and ref_exists(repo, remote_head):
        return remote_head, "remote default"

    for candidate in (f"{remote}/main", f"{remote}/master", "main", "master"):
        if ref_exists(repo, candidate):
            return candidate, "conventional default"

    raise AnalysisError("Could not infer the base ref. Pass --base <ref>.")


def resolve_head(repo: Path, head: str) -> Tuple[str, str]:
    if not ref_exists(repo, head):
        raise AnalysisError(f"Head ref does not exist: {head}")
    sha = git_text(repo, "rev-parse", f"{head}^{{commit}}")
    if head == "HEAD":
        branch = git_text(repo, "symbolic-ref", "--quiet", "--short", "HEAD", check=False)
        return sha, branch or "HEAD (detached)"
    return sha, head


def decode_path(raw: bytes) -> str:
    return raw.decode("utf-8", "surrogateescape")


def parse_numstat_z(data: bytes) -> List[Dict[str, Any]]:
    parts = data.split(b"\0")
    output: List[Dict[str, Any]] = []
    index = 0

    while index < len(parts):
        record = parts[index]
        if not record:
            index += 1
            continue

        fields = record.split(b"\t", 2)
        if len(fields) != 3:
            raise AnalysisError("Unexpected git --numstat -z output")

        additions_raw, deletions_raw, path_raw = fields
        old_path: Optional[str] = None

        if path_raw:
            path = decode_path(path_raw)
            index += 1
        else:
            if index + 2 >= len(parts):
                raise AnalysisError("Truncated rename entry in git --numstat -z output")
            old_path = decode_path(parts[index + 1])
            path = decode_path(parts[index + 2])
            index += 3

        binary = additions_raw == b"-" or deletions_raw == b"-"
        additions = None if binary else int(additions_raw)
        deletions = None if binary else int(deletions_raw)
        output.append(
            {
                "path": path,
                "old_path": old_path,
                "additions": additions,
                "deletions": deletions,
                "binary": binary,
            }
        )

    return output


def parse_name_status_z(data: bytes) -> Dict[str, Dict[str, Optional[str]]]:
    parts = data.split(b"\0")
    output: Dict[str, Dict[str, Optional[str]]] = {}
    index = 0

    while index < len(parts):
        if not parts[index]:
            index += 1
            continue

        status = decode_path(parts[index])
        index += 1
        kind = status[:1]

        if kind in {"R", "C"}:
            if index + 1 >= len(parts):
                raise AnalysisError("Truncated rename entry in git --name-status -z output")
            old_path = decode_path(parts[index])
            path = decode_path(parts[index + 1])
            index += 2
        else:
            if index >= len(parts):
                raise AnalysisError("Truncated path entry in git --name-status -z output")
            old_path = None
            path = decode_path(parts[index])
            index += 1

        output[path] = {"status": status, "old_path": old_path}

    return output


LOCKFILE_NAMES = {
    "bun.lock",
    "bun.lockb",
    "cargo.lock",
    "composer.lock",
    "gemfile.lock",
    "go.sum",
    "package-lock.json",
    "packages.lock.json",
    "pipfile.lock",
    "pnpm-lock.yaml",
    "poetry.lock",
    "pubspec.lock",
    "uv.lock",
    "yarn.lock",
}

VENDOR_DIRS = {"node_modules", "third_party", "third-party", "vendor", "vendors"}
GENERATED_DIRS = {".next", "coverage", "dist", "generated", "gen"}
DOC_DIRS = {"doc", "docs", "documentation"}
MIGRATION_DIRS = {"migration", "migrations"}
TEST_DIRS = {"__tests__", "spec", "specs", "test", "tests"}
CONFIG_NAMES = {
    ".babelrc",
    ".dockerignore",
    ".editorconfig",
    ".env.example",
    ".eslintignore",
    ".eslintrc",
    ".gitattributes",
    ".gitignore",
    ".npmrc",
    ".prettierignore",
    ".prettierrc",
    "dockerfile",
    "makefile",
    "tsconfig.json",
}


def classify_file(path: str, binary: bool) -> str:
    if binary:
        return "binary"

    normalized = path.replace("\\", "/")
    lower = normalized.lower()
    parts = [part for part in lower.split("/") if part]
    name = parts[-1] if parts else lower

    if name in LOCKFILE_NAMES or name.endswith((".lock", ".lock.json")):
        return "lockfile"
    if any(part in VENDOR_DIRS for part in parts):
        return "vendored"
    if any(part in GENERATED_DIRS for part in parts):
        return "generated"
    if (
        ".generated." in name
        or ".gen." in name
        or name.endswith((".g.dart", ".pb.go", ".pb.ts", ".snap"))
        or name.startswith("generated_")
    ):
        return "generated"
    if any(part in MIGRATION_DIRS for part in parts):
        return "migration"
    if (
        any(part in TEST_DIRS for part in parts)
        or re.search(r"(^|[._-])(spec|test)([._-]|$)", name) is not None
    ):
        return "test"
    if any(part in DOC_DIRS for part in parts) or name.endswith((".md", ".mdx", ".rst", ".adoc")):
        return "documentation"
    if (
        name in CONFIG_NAMES
        or name.startswith((".github", ".gitlab"))
        or name.endswith((".config.js", ".config.cjs", ".config.mjs", ".config.ts"))
        or name.endswith((".toml", ".yaml", ".yml"))
    ):
        return "configuration"
    return "source"


def is_reviewable_category(category: str) -> bool:
    return category in {"source", "test", "configuration", "migration", "documentation"}


def translate_codeowners_glob(pattern: str) -> str:
    output: List[str] = []
    index = 0

    while index < len(pattern):
        char = pattern[index]
        if char == "*":
            if index + 1 < len(pattern) and pattern[index + 1] == "*":
                while index + 1 < len(pattern) and pattern[index + 1] == "*":
                    index += 1
                if index + 1 < len(pattern) and pattern[index + 1] == "/":
                    output.append("(?:.*/)?")
                    index += 1
                else:
                    output.append(".*")
            else:
                output.append("[^/]*")
        elif char == "?":
            output.append("[^/]")
        else:
            output.append(re.escape(char))
        index += 1

    return "".join(output)


def compile_codeowners_pattern(pattern: str) -> re.Pattern[str]:
    anchored = pattern.startswith("/")
    clean = pattern[1:] if anchored else pattern
    directory_pattern = clean.endswith("/")
    clean = clean.rstrip("/")

    if not clean:
        return re.compile(r"a^")

    contains_slash = "/" in clean
    prefix = "^" if anchored or contains_slash else r"(?:^|.*/)"
    body = translate_codeowners_glob(clean)
    last_component = clean.rsplit("/", 1)[-1]
    exact_last_component = "*" not in last_component and "?" not in last_component
    allows_descendants = directory_pattern or exact_last_component or clean.endswith("/**")
    suffix = r"(?:/.*)?$" if allows_descendants else "$"
    return re.compile(prefix + body + suffix)


def parse_codeowners(content: str) -> Tuple[List[Dict[str, Any]], List[str]]:
    rules: List[Dict[str, Any]] = []
    warnings: List[str] = []

    for line_number, raw_line in enumerate(content.splitlines(), start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        try:
            tokens = shlex.split(raw_line, comments=True, posix=True)
        except ValueError as exc:
            warnings.append(f"CODEOWNERS line {line_number} could not be parsed: {exc}")
            continue

        if not tokens:
            continue

        pattern = tokens[0]
        owners = tokens[1:]
        valid = True
        reason: Optional[str] = None

        if pattern.startswith("!"):
            valid = False
            reason = "negation is not valid CODEOWNERS syntax"
        elif "[" in pattern or "]" in pattern:
            valid = False
            reason = "character ranges are not valid CODEOWNERS syntax"

        regex: Optional[re.Pattern[str]] = None
        if valid:
            try:
                regex = compile_codeowners_pattern(pattern)
            except re.error as exc:
                valid = False
                reason = f"pattern could not be compiled: {exc}"

        if not valid and reason:
            warnings.append(f"CODEOWNERS line {line_number} skipped: {reason}")

        rules.append(
            {
                "line": line_number,
                "pattern": pattern,
                "owners": owners,
                "valid": valid,
                "reason": reason,
                "_regex": regex,
            }
        )

    return rules, warnings


def find_codeowners(repo: Path, base_ref: str) -> Tuple[Optional[str], Optional[str]]:
    for candidate in (".github/CODEOWNERS", "CODEOWNERS", "docs/CODEOWNERS"):
        result = git(repo, "show", f"{base_ref}:{candidate}", check=False, text=True)
        if result.returncode == 0:
            return candidate, result.stdout
    return None, None


def match_codeowners(path: str, rules: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    matched_rule: Optional[Dict[str, Any]] = None
    normalized = path.replace("\\", "/").lstrip("./")

    for rule in rules:
        regex = rule.get("_regex")
        if rule.get("valid") and regex is not None and regex.match(normalized):
            matched_rule = rule

    if matched_rule is None:
        return {
            "matched": False,
            "owners": [],
            "pattern": None,
            "line": None,
        }

    return {
        "matched": True,
        "owners": list(matched_rule["owners"]),
        "pattern": matched_rule["pattern"],
        "line": matched_rule["line"],
    }


def ownership_label(ownership: Dict[str, Any]) -> str:
    owners = ownership.get("owners") or []
    if owners:
        return " ".join(str(owner) for owner in owners)
    if ownership.get("matched"):
        return "(explicitly unowned)"
    return "(unmatched)"


def top_level_area(path: str) -> str:
    normalized = path.replace("\\", "/").lstrip("/")
    return normalized.split("/", 1)[0] if normalized else "(root)"


def summarize_groups(files: Sequence[Dict[str, Any]], key_fn: Any) -> List[Dict[str, Any]]:
    groups: Dict[str, Dict[str, int]] = defaultdict(
        lambda: {
            "files": 0,
            "reviewable_lines": 0,
            "auxiliary_lines": 0,
            "binary_files": 0,
        }
    )

    for item in files:
        key = str(key_fn(item))
        group = groups[key]
        group["files"] += 1
        if item["binary"]:
            group["binary_files"] += 1
        elif item["reviewable"]:
            group["reviewable_lines"] += item["changed_lines"]
        else:
            group["auxiliary_lines"] += item["changed_lines"]

    return [
        {"name": name, **values}
        for name, values in sorted(
            groups.items(),
            key=lambda entry: (
                -entry[1]["reviewable_lines"],
                -entry[1]["auxiliary_lines"],
                entry[0],
            ),
        )
    ]


def gh_capabilities(repo: Path) -> Dict[str, Any]:
    if shutil.which("gh") is None:
        return {"available": False, "version": None, "stack_available": False}

    version_result = run_command(("gh", "--version"), repo, check=False, text=True)
    version = version_result.stdout.splitlines()[0] if version_result.returncode == 0 else None
    stack_result = run_command(("gh", "stack", "--help"), repo, check=False, text=True)
    return {
        "available": True,
        "version": version,
        "stack_available": stack_result.returncode == 0,
    }


def analyze(args: argparse.Namespace) -> Dict[str, Any]:
    repo = resolve_repo(args.repo)
    current_pr = discover_current_pr(repo)
    base_ref, base_resolution = resolve_base(repo, args.base, args.remote, current_pr)
    head_sha, source_ref = resolve_head(repo, args.head)
    base_sha = git_text(repo, "rev-parse", f"{base_ref}^{{commit}}")
    merge_base = git_text(repo, "merge-base", base_ref, head_sha)

    status_text = git_text(repo, "status", "--porcelain=v1", "--untracked-files=normal", check=True)
    dirty = bool(status_text)

    numstat_data = git(
        repo,
        "diff",
        "--numstat",
        "-z",
        "--find-renames",
        merge_base,
        head_sha,
        text=False,
    ).stdout
    status_data = git(
        repo,
        "diff",
        "--name-status",
        "-z",
        "--find-renames",
        merge_base,
        head_sha,
        text=False,
    ).stdout

    numstat = parse_numstat_z(numstat_data)
    status_by_path = parse_name_status_z(status_data)

    codeowners_path, codeowners_content = find_codeowners(repo, base_ref)
    if codeowners_content is not None:
        codeowners_rules, codeowners_warnings = parse_codeowners(codeowners_content)
    else:
        codeowners_rules, codeowners_warnings = [], []

    files: List[Dict[str, Any]] = []
    for raw in numstat:
        status_entry = status_by_path.get(raw["path"], {})
        old_path = raw["old_path"] or status_entry.get("old_path")
        category = classify_file(raw["path"], raw["binary"])
        reviewable = is_reviewable_category(category)
        changed_lines = 0
        if not raw["binary"]:
            changed_lines = int(raw["additions"] or 0) + int(raw["deletions"] or 0)
        ownership = match_codeowners(raw["path"], codeowners_rules)

        files.append(
            {
                "status": status_entry.get("status", "?"),
                "path": raw["path"],
                "old_path": old_path,
                "additions": raw["additions"],
                "deletions": raw["deletions"],
                "changed_lines": changed_lines,
                "binary": raw["binary"],
                "category": category,
                "reviewable": reviewable,
                "area": top_level_area(raw["path"]),
                "ownership": ownership,
            }
        )

    files.sort(key=lambda item: item["path"])

    total_additions = sum(int(item["additions"] or 0) for item in files if not item["binary"])
    total_deletions = sum(int(item["deletions"] or 0) for item in files if not item["binary"])
    reviewable_lines = sum(item["changed_lines"] for item in files if item["reviewable"])
    auxiliary_lines = sum(
        item["changed_lines"] for item in files if not item["reviewable"] and not item["binary"]
    )
    binary_files = sum(1 for item in files if item["binary"])

    commit_lines = git_text(
        repo,
        "log",
        "--reverse",
        "--format=%H%x09%s",
        f"{merge_base}..{head_sha}",
        check=True,
    )
    commits = []
    for line in commit_lines.splitlines():
        if not line:
            continue
        sha, _, subject = line.partition("\t")
        commits.append({"sha": sha, "subject": subject})

    warnings = list(codeowners_warnings)
    if dirty:
        warnings.append("Working tree is dirty; uncommitted and untracked changes are excluded.")
    if codeowners_path is None:
        warnings.append("No CODEOWNERS file was found on the resolved base ref.")
    if not files:
        warnings.append("No committed diff was found between merge-base and head.")
    if reviewable_lines > 2000:
        warnings.append("The change exceeds the skill's 2,000 reviewable-line maximum for one PR.")
    elif reviewable_lines > 1000:
        warnings.append("The change exceeds the 1,000 reviewable-line target for one PR.")

    public_rules = [
        {
            "line": rule["line"],
            "pattern": rule["pattern"],
            "owners": rule["owners"],
            "valid": rule["valid"],
            "reason": rule["reason"],
        }
        for rule in codeowners_rules
    ]

    return {
        "repository": str(repo),
        "source": {
            "requested_ref": args.head,
            "display_ref": source_ref,
            "sha": head_sha,
        },
        "base": {
            "ref": base_ref,
            "sha": base_sha,
            "merge_base_sha": merge_base,
            "resolution": base_resolution,
        },
        "current_pr": current_pr,
        "working_tree": {
            "dirty": dirty,
            "porcelain": status_text.splitlines(),
            "uncommitted_changes_included": False,
        },
        "summary": {
            "commits": len(commits),
            "files": len(files),
            "additions": total_additions,
            "deletions": total_deletions,
            "total_numeric_lines": total_additions + total_deletions,
            "reviewable_lines": reviewable_lines,
            "auxiliary_lines": auxiliary_lines,
            "binary_files": binary_files,
        },
        "codeowners": {
            "path": codeowners_path,
            "read_from_ref": base_ref if codeowners_path else None,
            "rules": public_rules,
            "matching_is_best_effort": True,
        },
        "ownership_summary": summarize_groups(files, lambda item: ownership_label(item["ownership"])),
        "area_summary": summarize_groups(files, lambda item: item["area"]),
        "files": files,
        "commits": commits,
        "github_cli": gh_capabilities(repo),
        "warnings": warnings,
    }


def markdown_table(headers: Sequence[str], rows: Iterable[Sequence[Any]]) -> str:
    header = "| " + " | ".join(headers) + " |"
    divider = "|" + "|".join("---" for _ in headers) + "|"
    body = ["| " + " | ".join(str(value).replace("|", "\\|") for value in row) + " |" for row in rows]
    return "\n".join([header, divider, *body])


def render_markdown(report: Dict[str, Any]) -> str:
    summary = report["summary"]
    base = report["base"]
    source = report["source"]
    codeowners = report["codeowners"]
    current_pr = report.get("current_pr")

    lines = [
        "# Pull request inventory",
        "",
        f"- Repository: `{report['repository']}`",
        f"- Base: `{base['ref']}` at `{base['sha'][:12]}` ({base['resolution']})",
        f"- Merge base: `{base['merge_base_sha'][:12]}`",
        f"- Source: `{source['display_ref']}` at `{source['sha'][:12]}`",
        f"- Working tree: `{'dirty' if report['working_tree']['dirty'] else 'clean'}`",
        f"- CODEOWNERS: `{codeowners['path'] or 'none'}`",
    ]
    if current_pr:
        lines.append(f"- Current PR: #{current_pr.get('number')} {current_pr.get('url', '')}")

    lines.extend(
        [
            "",
            "## Totals",
            "",
            markdown_table(
                ("Metric", "Value"),
                (
                    ("Commits", summary["commits"]),
                    ("Files", summary["files"]),
                    ("Additions", summary["additions"]),
                    ("Deletions", summary["deletions"]),
                    ("Reviewable lines", summary["reviewable_lines"]),
                    ("Auxiliary lines", summary["auxiliary_lines"]),
                    ("Binary files", summary["binary_files"]),
                ),
            ),
            "",
            "## Ownership summary",
            "",
            markdown_table(
                ("Owners", "Files", "Reviewable", "Auxiliary", "Binary"),
                (
                    (
                        item["name"],
                        item["files"],
                        item["reviewable_lines"],
                        item["auxiliary_lines"],
                        item["binary_files"],
                    )
                    for item in report["ownership_summary"]
                ),
            ),
            "",
            "## Area summary",
            "",
            markdown_table(
                ("Area", "Files", "Reviewable", "Auxiliary", "Binary"),
                (
                    (
                        item["name"],
                        item["files"],
                        item["reviewable_lines"],
                        item["auxiliary_lines"],
                        item["binary_files"],
                    )
                    for item in report["area_summary"]
                ),
            ),
            "",
            "## Files",
            "",
            markdown_table(
                ("Status", "Path", "Owners", "Category", "+", "-", "Lines"),
                (
                    (
                        item["status"],
                        item["path"],
                        ownership_label(item["ownership"]),
                        item["category"],
                        "-" if item["binary"] else item["additions"],
                        "-" if item["binary"] else item["deletions"],
                        "binary" if item["binary"] else item["changed_lines"],
                    )
                    for item in report["files"]
                ),
            ),
            "",
            "## Commits",
            "",
        ]
    )

    if report["commits"]:
        lines.extend(f"- `{item['sha'][:12]}` {item['subject']}" for item in report["commits"])
    else:
        lines.append("- None")

    lines.extend(["", "## Warnings", ""])
    if report["warnings"]:
        lines.extend(f"- {warning}" for warning in report["warnings"])
    else:
        lines.append("- None")

    lines.extend(
        [
            "",
            "> CODEOWNERS matching is best-effort. Verify complex or invalid patterns against the hosting platform before publishing PRs.",
        ]
    )
    return "\n".join(lines) + "\n"


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Read-only inventory of a large PR or branch diff for stacked-PR planning."
    )
    parser.add_argument("--repo", default=".", help="Path inside the Git repository (default: .)")
    parser.add_argument("--base", help="Base ref. Inferred from the current PR or remote default when omitted.")
    parser.add_argument("--head", default="HEAD", help="Source ref to analyze (default: HEAD)")
    parser.add_argument("--remote", default="origin", help="Remote used for base inference (default: origin)")
    parser.add_argument(
        "--format",
        choices=("json", "markdown"),
        default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument("--output", help="Write output to this file instead of stdout")
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    try:
        report = analyze(args)
    except AnalysisError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if args.format == "json":
        rendered = json.dumps(report, indent=2, sort_keys=False, ensure_ascii=False) + "\n"
    else:
        rendered = render_markdown(report)

    if args.output:
        output_path = Path(args.output).expanduser()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered, encoding="utf-8")
    else:
        sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
