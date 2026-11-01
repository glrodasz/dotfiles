#!/usr/bin/env python3
"""Turn one themeable diagram SVG into GitHub-ready light and dark files.

Author the diagram once with semantic classes (see SKILL.md, "Phase 4 — Draw the diagrams"),
then run:

    python theme_svg.py docs/diagrams/src/architecture.svg --out docs/diagrams

It writes architecture-light.svg and architecture-dark.svg with every color baked in,
because GitHub renders README SVGs as <img>: no CSS variables, no web fonts, and the
page theme only reaches the image through <picture> + prefers-color-scheme.
Optionally pass --png to also write PNG previews (needs Playwright + Chromium).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

FONT_SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif"
FONT_MONO = "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace"

# Claude diagram palette (50 / 100 / 200 / 400 / 600 / 800 / 900 stops).
RAMPS = {
    "purple": ["#EEEDFE", "#CECBF6", "#AFA9EC", "#7F77DD", "#534AB7", "#3C3489", "#26215C"],
    "teal": ["#E1F5EE", "#9FE1CB", "#5DCAA5", "#1D9E75", "#0F6E56", "#085041", "#04342C"],
    "coral": ["#FAECE7", "#F5C4B3", "#F0997B", "#D85A30", "#993C1D", "#712B13", "#4A1B0C"],
    "pink": ["#FBEAF0", "#F4C0D1", "#ED93B1", "#D4537E", "#993556", "#72243E", "#4B1528"],
    "gray": ["#F1EFE8", "#D3D1C7", "#B4B2A9", "#888780", "#5F5E5A", "#444441", "#2C2C2A"],
    "blue": ["#E6F1FB", "#B5D4F4", "#85B7EB", "#378ADD", "#185FA5", "#0C447C", "#042C53"],
    "green": ["#EAF3DE", "#C0DD97", "#97C459", "#639922", "#3B6D11", "#27500A", "#173404"],
    "amber": ["#FAEEDA", "#FAC775", "#EF9F27", "#BA7517", "#854F0B", "#633806", "#412402"],
    "red": ["#FCEBEB", "#F7C1C1", "#F09595", "#E24B4A", "#A32D2D", "#791F1F", "#501313"],
}
S50, S100, S200, S400, S600, S800, S900 = range(7)

THEMES = {
    "light": {"text": "#1F2328", "muted": "#59636E", "line": "#5F5E5A"},
    "dark": {"text": "#F0F6FC", "muted": "#9198A1", "line": "#B4B2A9"},
}


def ramp_rules(name: str, r: list[str], theme: str) -> str:
    light = theme == "light"
    # Containers: the lightest tint in light mode, the deepest shade in dark mode.
    cont_fill, cont_stroke, cont_title, cont_sub = (
        (r[S50], r[S400], r[S800], r[S600]) if light else (r[S900], r[S400], r[S50], r[S200])
    )
    # Nodes: white cards in light mode, 800 fills in dark mode.
    node_fill, node_stroke, node_title, node_sub = (
        ("#FFFFFF", r[S400], r[S800], r[S600]) if light else (r[S800], r[S200], r[S50], r[S100])
    )
    # Standalone tinted nodes (outside any container).
    solo_fill = r[S50] if light else r[S800]
    solo_stroke = r[S600] if light else r[S200]
    edge = r[S400] if light else r[S200]
    return f"""
.ct-{name} > rect {{ fill: {cont_fill}; stroke: {cont_stroke}; }}
.ct-{name} > .th {{ fill: {cont_title}; }}
.ct-{name} > .ts {{ fill: {cont_sub}; }}
.n-{name} > rect {{ fill: {node_fill}; stroke: {node_stroke}; }}
.n-{name} > .th, .n-{name} > .tm {{ fill: {node_title}; }}
.n-{name} > .ts {{ fill: {node_sub}; }}
.s-{name} > rect {{ fill: {solo_fill}; stroke: {solo_stroke}; }}
.s-{name} > .th, .s-{name} > .tm {{ fill: {node_title}; }}
.s-{name} > .ts {{ fill: {node_sub}; }}
.e-{name} {{ stroke: {edge}; }}"""


def stylesheet(theme: str) -> str:
    t = THEMES[theme]
    rules = "".join(ramp_rules(n, r, theme) for n, r in RAMPS.items())
    return f"""<style>
text {{ font-family: {FONT_SANS}; }}
.th {{ font-size: 14px; font-weight: 600; fill: {t['text']}; }}
.tm {{ font-family: {FONT_MONO}; font-size: 13px; font-weight: 500; fill: {t['text']}; }}
.ts {{ font-size: 12px; font-weight: 400; fill: {t['muted']}; }}
rect {{ stroke-width: 1; }}
.dash > rect {{ stroke-dasharray: 5 4; }}
.arr {{ fill: none; stroke: {t['line']}; stroke-width: 1.25; }}
.arr.llm {{ stroke-dasharray: 5 4; }}
.mk {{ fill: none; stroke: {t['line']}; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: round; }}
{rules}
</style>"""


def bake(svg: str, theme: str) -> str:
    svg = re.sub(r"<style>.*?</style>", "", svg, flags=re.S)
    return re.sub(r"(<svg\b[^>]*>)", lambda m: m.group(1) + stylesheet(theme), svg, count=1)


def write_pngs(paths: list[Path]) -> None:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        sys.exit("--png needs Playwright: pip install playwright, then playwright install chromium")

    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        for p in paths:
            bg = "#0d1117" if p.stem.endswith("-dark") else "#ffffff"
            page = browser.new_page(device_scale_factor=2, viewport={"width": 920, "height": 800})
            # Load as <img>, exactly like GitHub does, so the preview shows what readers will see.
            host = p.with_suffix(".preview.html")
            host.write_text(
                f"<body style='margin:0;padding:20px;background:{bg}'>"
                f"<img id='d' src='{p.name}' width='880'></body>",
                encoding="utf-8",
            )
            page.goto(host.resolve().as_uri())
            page.wait_for_load_state("networkidle")
            page.locator("#d").screenshot(path=str(p.with_suffix(".png")))
            host.unlink()
            page.close()
        browser.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sources", nargs="+", type=Path, help="themeable SVG sources")
    ap.add_argument("--out", type=Path, required=True, help="output directory")
    ap.add_argument("--png", action="store_true", help="also write PNG previews")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for src in args.sources:
        raw = src.read_text(encoding="utf-8")
        for theme in THEMES:
            dest = args.out / f"{src.stem}-{theme}.svg"
            dest.write_text(bake(raw, theme), encoding="utf-8")
            written.append(dest)
            print(dest)
    if args.png:
        write_pngs(written)
    return 0


if __name__ == "__main__":
    sys.exit(main())
