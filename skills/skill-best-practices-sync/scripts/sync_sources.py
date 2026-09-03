#!/usr/bin/env python3
"""Fetch the upstream skill-authoring best-practice docs and compare them to the local copies.

Usage:
  sync_sources.py check            # fetch, compare hashes, report; exit 1 if anything changed
  sync_sources.py diff [slug]      # show a unified diff of local vs live (no writes)
  sync_sources.py update [slug]    # write changed sources + manifest, print the diff of each change

Sources are declared in ../references/sources.json. Local copies live in
../references/sources/<slug>.md. The manifest stores a sha256 of the normalized
text and the fetch timestamp, so "up to date" means "content unchanged", not
"fetched recently" — none of the upstream pages expose a version or date.

Stdlib only. Network access required.
"""

from __future__ import annotations

import difflib
import hashlib
import json
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
MANIFEST = SKILL_DIR / "references" / "sources.json"
SOURCES_DIR = SKILL_DIR / "references" / "sources"

# Docs sites occasionally block default urllib UAs; a browser-ish UA is accepted everywhere tested.
USER_AGENT = "Mozilla/5.0 (compatible; skill-best-practices-sync/1.0)"
# Generous timeout: the markdown endpoints are fast, but the HTML page ships a large bundle.
TIMEOUT_SECONDS = 30


class _HtmlToText(HTMLParser):
    """Minimal HTML -> markdown-ish text. Keeps headings, paragraphs, lists, code; drops chrome."""

    SKIP = {"script", "style", "nav", "header", "footer", "aside", "svg", "button", "noscript"}
    BLOCK = {"p", "div", "section", "article", "li", "ul", "ol", "pre", "blockquote", "tr", "table"}

    def __init__(self, root_tag: str | None) -> None:
        super().__init__(convert_charrefs=True)
        self.out: list[str] = []
        self._root_tag = root_tag  # "article" or "main": only text inside it is kept
        self._skip_depth = 0
        self._in_pre = False
        self._in_root = root_tag is None
        self._list_depth = 0

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self._skip_depth += 1
            return
        if self._skip_depth:
            return
        if tag == self._root_tag:
            self._in_root = True
        if not self._in_root:
            return
        if re.fullmatch(r"h[1-6]", tag):
            self.out.append("\n\n" + "#" * int(tag[1]) + " ")
        elif tag == "pre":
            self._in_pre = True
            self.out.append("\n\n```\n")
        elif tag in ("ul", "ol"):
            self._list_depth += 1
            self.out.append("\n")
        elif tag == "li":
            self.out.append("\n" + "  " * (self._list_depth - 1) + "- ")
        elif tag == "br":
            self.out.append("\n")
        elif tag in self.BLOCK:
            self.out.append("\n\n")
        elif tag == "code" and not self._in_pre:
            self.out.append("`")

    def handle_endtag(self, tag):
        if tag in self.SKIP:
            self._skip_depth = max(0, self._skip_depth - 1)
            return
        if self._skip_depth:
            return
        if not self._in_root:
            return
        if tag == self._root_tag:
            self._in_root = False
        elif tag == "pre":
            self._in_pre = False
            self.out.append("\n```\n")
        elif tag in ("ul", "ol"):
            self._list_depth = max(0, self._list_depth - 1)
        elif tag == "code" and not self._in_pre:
            self.out.append("`")
        elif tag in self.BLOCK or re.fullmatch(r"h[1-6]", tag):
            self.out.append("\n")

    def handle_data(self, data):
        if self._skip_depth:
            return
        # Ignore everything outside the content root (nav, cookie banners, footers).
        if not self._in_root:
            return
        self.out.append(data if self._in_pre else re.sub(r"\s+", " ", data))

    def text(self) -> str:
        return "".join(self.out)


def normalize(text: str) -> str:
    """Whitespace-only normalization so hashes don't churn on formatting noise."""
    lines = [line.rstrip() for line in text.replace("\r\n", "\n").split("\n")]
    out: list[str] = []
    blank_run = 0
    for line in lines:
        blank_run = blank_run + 1 if not line else 0
        if blank_run <= 2:
            out.append(line)
    return "\n".join(out).strip() + "\n"


def fetch(source: dict) -> str:
    req = urllib.request.Request(
        source["fetch_url"],
        headers={"User-Agent": USER_AGENT, "Accept": "text/markdown, text/html;q=0.9, */*;q=0.1"},
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
        body = resp.read().decode("utf-8", errors="replace")
        content_type = resp.headers.get("Content-Type", "")
    if source["format"] == "html" or "text/html" in content_type:
        # Docs sites wrap the page body in <article>; fall back to <main>, then the whole document.
        root_tag = next((t for t in ("article", "main") if f"<{t}" in body), None)
        parser = _HtmlToText(root_tag)
        parser.feed(body)
        body = parser.text()
    return normalize(body)


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text())


def save_manifest(manifest: dict) -> None:
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


def local_path(source: dict) -> Path:
    return SOURCES_DIR / f"{source['slug']}.md"


def local_text(source: dict) -> str | None:
    path = local_path(source)
    return path.read_text() if path.exists() else None


def unified_diff(old: str, new: str, slug: str) -> str:
    return "".join(
        difflib.unified_diff(
            old.splitlines(keepends=True),
            new.splitlines(keepends=True),
            fromfile=f"{slug} (local)",
            tofile=f"{slug} (live)",
            n=2,
        )
    )


def status_for(source: dict, live: str) -> str:
    local = local_text(source)
    if local is None:
        return "new"
    return "unchanged" if sha256(local) == sha256(live) else "changed"


def cmd_check(sources: list[dict]) -> int:
    changed = 0
    print(f"{'status':<10} {'slug':<32} {'last fetched':<21} url")
    for source in sources:
        try:
            live = fetch(source)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            print(f"{'FETCH-ERR':<10} {source['slug']:<32} {str(source.get('fetched_at') or '-'):<21} {source['url']}  ({exc})")
            continue
        status = status_for(source, live)
        if status != "unchanged":
            changed += 1
        print(f"{status.upper():<10} {source['slug']:<32} {str(source.get('fetched_at') or '-'):<21} {source['url']}")
    print()
    print("All local copies are up to date." if not changed else f"{changed} source(s) differ from the live page. Run `update` to refresh them.")
    return 1 if changed else 0


def cmd_diff(sources: list[dict]) -> int:
    for source in sources:
        live = fetch(source)
        local = local_text(source)
        if local is None:
            print(f"### {source['slug']}: no local copy yet ({len(live.splitlines())} live lines)\n")
        elif sha256(local) == sha256(live):
            print(f"### {source['slug']}: unchanged\n")
        else:
            print(f"### {source['slug']}: changed\n")
            print(unified_diff(local, live, source["slug"]))
    return 0


def cmd_update(manifest: dict, sources: list[dict]) -> int:
    SOURCES_DIR.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    updated: list[str] = []
    for source in sources:
        try:
            live = fetch(source)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            print(f"### {source['slug']}: FETCH FAILED — keeping local copy ({exc})\n")
            continue
        status = status_for(source, live)
        if status == "unchanged":
            source["fetched_at"] = now
            print(f"### {source['slug']}: unchanged\n")
            continue
        local = local_text(source)
        if local is not None:
            print(f"### {source['slug']}: changed — diff follows\n")
            print(unified_diff(local, live, source["slug"]))
        else:
            print(f"### {source['slug']}: new — {len(live.splitlines())} lines written\n")
        local_path(source).write_text(live)
        source["sha256"] = sha256(live)
        source["fetched_at"] = now
        updated.append(source["slug"])
    save_manifest(manifest)
    print("Updated:", ", ".join(updated) if updated else "nothing (all sources unchanged)")
    if updated:
        print("Next: fold the diffs above into references/best-practices.md so the digest matches the sources.")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[1] not in {"check", "diff", "update"}:
        print(__doc__)
        return 2
    manifest = load_manifest()
    sources = manifest["sources"]
    if len(argv) > 2:
        wanted = set(argv[2:])
        sources = [s for s in sources if s["slug"] in wanted]
        unknown = wanted - {s["slug"] for s in sources}
        if unknown:
            print(f"Unknown slug(s): {', '.join(sorted(unknown))}. Known: {', '.join(s['slug'] for s in manifest['sources'])}")
            return 2
    if argv[1] == "check":
        return cmd_check(sources)
    if argv[1] == "diff":
        return cmd_diff(sources)
    return cmd_update(manifest, sources)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
