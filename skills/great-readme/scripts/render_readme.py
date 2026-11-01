#!/usr/bin/env python3
"""Render Markdown files the way GitHub shows them and screenshot both color schemes.

Run from the target repo's root, with --out outside the repo so nothing needs cleaning up:

    python3 render_readme.py README.md docs/ARCHITECTURE.md --out "$TMPDIR/readme-preview"

It writes <name>-light.png and <name>-dark.png per file. <picture> sources follow the
emulated color scheme. If shields.io is unreachable, stand-in badges keep the hero layout
real. Exits 1 and lists every image that failed to load, after still writing the
screenshots so the rest of the page can be reviewed.

This is Python-Markdown with GitHub's stylesheet, not GitHub's parser: lists nested by 2
spaces look flat here but nest correctly on GitHub.

Needs: pip install markdown playwright, then playwright install chromium; and npm, which
fetches github-markdown-css into a temp cache rather than the target repo.
"""

from __future__ import annotations

import argparse
import html
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlparse

# Pinned so every run renders against the same stylesheet.
CSS_PACKAGE = "github-markdown-css"
CSS_VERSION = "5.9.0"

MARKDOWN_EXTENSIONS = ["tables", "fenced_code", "md_in_html"]

# The github-markdown-css README gives GitHub's container as 980px wide with 45px padding.
CONTAINER_WIDTH = 980
CONTAINER_CSS = f"""
.markdown-body {{ box-sizing: border-box; max-width: {CONTAINER_WIDTH}px; margin: 0 auto; padding: 45px; }}
"""
BACKGROUNDS = {"light": "#ffffff", "dark": "#0d1117"}

VIEWPORT_HEIGHT = 800  # Only the starting size: screenshots capture the full page.
SCALE = 2  # Retina output, so small badge text stays readable when reviewing.
BADGE_TIMEOUT_MS = 5_000  # Past this, treat shields.io as unreachable and draw a stand-in.
PAGE_TIMEOUT_MS = 30_000  # A hanging remote image must not block the run; it's reported.

BROKEN_IMAGES_JS = """
[...document.images]
  .filter((img) => !img.complete || img.naturalWidth === 0)
  .map((img) => img.currentSrc || img.getAttribute('src'))
"""


def css_dir() -> Path:
    """Return the folder holding the stylesheets, installing them into a temp cache once."""
    cache = Path(tempfile.gettempdir()) / f"great-readme-{CSS_PACKAGE}-{CSS_VERSION}"
    package = cache / "node_modules" / CSS_PACKAGE
    if (package / "github-markdown-light.css").exists():
        return package
    npm = shutil.which("npm")
    if not npm:
        sys.exit(f"npm not found: it is needed once to fetch {CSS_PACKAGE}@{CSS_VERSION}")
    cache.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [npm, "install", "--prefix", str(cache), "--no-save", "--ignore-scripts",
         "--no-audit", "--no-fund", f"{CSS_PACKAGE}@{CSS_VERSION}"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.exit(f"npm could not fetch {CSS_PACKAGE}@{CSS_VERSION}:\n{result.stderr.strip()}")
    return package


def page_html(source: Path, body: str, theme: str, css: str) -> str:
    # <base> makes the source's relative image paths resolve from a page in a temp folder.
    base = source.parent.resolve().as_uri() + "/"
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<base href="{html.escape(base, quote=True)}">
<style>{css}</style>
<style>body {{ margin: 0; background: {BACKGROUNDS[theme]}; }}{CONTAINER_CSS}</style>
</head>
<body><article class="markdown-body">
{body}
</article></body>
</html>
"""


def stand_in_badge(url: str) -> str:
    label = unquote(Path(urlparse(url).path).stem)[:24] or "badge"
    width = len(label) * 7 + 12
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="20">'
        f'<rect width="{width}" height="20" rx="3" fill="#555"/>'
        f'<text x="6" y="14" fill="#fff" font-family="Verdana, sans-serif" font-size="11">'
        f"{html.escape(label)}</text></svg>"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sources", nargs="+", type=Path, help="Markdown files to render")
    ap.add_argument("--out", type=Path, required=True, help="output directory, outside the repo")
    args = ap.parse_args()

    for source in args.sources:
        if not source.is_file():
            sys.exit(f"{source}: no such file (pass only docs the repo has)")
    stems = [source.stem for source in args.sources]
    duplicates = sorted({stem for stem in stems if stems.count(stem) > 1})
    if duplicates:
        sys.exit(f"Output names would collide for {', '.join(duplicates)}: render those files in separate runs with different --out")

    try:
        import markdown
        from playwright.sync_api import Error as PlaywrightError
        from playwright.sync_api import TimeoutError as PlaywrightTimeout
        from playwright.sync_api import sync_playwright
    except ImportError as err:
        sys.exit(f"Missing {err.name}: pip install markdown playwright, then playwright install chromium")

    package = css_dir()
    args.out.mkdir(parents=True, exist_ok=True)
    broken: list[str] = []
    stand_ins: set[str] = set()

    def route_badge(route) -> None:
        url = route.request.url
        try:
            response = route.fetch(timeout=BADGE_TIMEOUT_MS)
            if response.ok:
                route.fulfill(response=response)
                return
        except PlaywrightError:
            pass
        stand_ins.add(url)
        route.fulfill(content_type="image/svg+xml", body=stand_in_badge(url))

    with sync_playwright() as pw:
        try:
            browser = pw.chromium.launch()
        except PlaywrightError as err:
            sys.exit(f"Could not start Chromium (try: playwright install chromium):\n{err}")
        with tempfile.TemporaryDirectory() as tmp:
            for source in args.sources:
                body = markdown.markdown(source.read_text(encoding="utf-8"), extensions=MARKDOWN_EXTENSIONS)
                for theme in BACKGROUNDS:
                    css = (package / f"github-markdown-{theme}.css").read_text(encoding="utf-8")
                    host = Path(tmp) / f"{source.stem}-{theme}.html"
                    host.write_text(page_html(source, body, theme, css), encoding="utf-8")
                    context = browser.new_context(
                        color_scheme=theme,
                        device_scale_factor=SCALE,
                        viewport={"width": CONTAINER_WIDTH, "height": VIEWPORT_HEIGHT},
                    )
                    page = context.new_page()
                    page.route("https://img.shields.io/**", route_badge)
                    try:
                        page.goto(host.as_uri(), wait_until="load", timeout=PAGE_TIMEOUT_MS)
                    except PlaywrightTimeout:
                        pass  # Whatever never loaded shows up in the broken-image check below.
                    broken += [f"{source} ({theme}): {src}" for src in page.evaluate(BROKEN_IMAGES_JS)]
                    dest = args.out / f"{source.stem}-{theme}.png"
                    page.screenshot(path=str(dest), full_page=True)
                    print(dest)
                    context.close()
        browser.close()

    for url in sorted(stand_ins):
        print(f"Stand-in badge (shields.io unreachable): {url}")
    if broken:
        print("Broken images:", *broken, sep="\n  ", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
