---
name: prod-page-audit
description: >
  Run a production readiness audit on a web page or site and fix the gaps it finds —
  covering SEO, favicon, Open Graph / social previews, and mobile optimization.
  Use whenever the user asks for a production check, launch checklist, SEO or OG audit,
  mobile readiness check, mentions going live, or asks about favicon, meta tags,
  social previews, or viewport issues.
---

# Production Page Check

Audit + auto-fix workflow for web pages before they go to production.

| Area | What's checked | Auto-fix? |
|---|---|---|
| SEO | Title, description, semantic HTML, canonical, robots | Fix meta; flag structural issues |
| Favicon | Presence, sizes, formats, manifest | Generate if missing |
| Open Graph | og: tags, Twitter Card, image dimensions | Generate OG image if missing |
| Mobile | Viewport, font sizes, input zoom, touch targets | Fix in-place where possible |

## Step 0 — Understand the target

1. **Input type**: file path / project directory → read source directly; URL → fetch or ask for the HTML.
2. **Page type**: landing, blog post, product, portfolio — determines what the OG image and favicon should look like.
3. **Brand context**: colors, logo, name — pull from CSS variables, `<meta>`, or ask.

If ambiguous, ask one focused question before proceeding.

## Step 1 — SEO

**Check**:
- `<title>`: exists, 50–60 chars, descriptive and unique
- `<meta name="description">`: exists, 120–160 chars, action-oriented
- `<link rel="canonical">` present; `<meta name="robots">` not accidentally `noindex`
- Single `<h1>`, logical heading nesting
- Images have meaningful `alt`; links have descriptive text (not "click here")
- Landmarks: `<header>`, `<main>`, `<footer>`, `<nav>`, `<article>`/`<section>` where appropriate
- `<html lang="...">` set
- JSON-LD structured data if applicable (article, product, local business)

**Fix**: add/rewrite title, description, canonical, and `lang` inline. Add missing `alt` with descriptive placeholders marked `<!-- TODO: update alt -->`. Flag structural issues (heading hierarchy, missing `<main>`) with a TODO comment and suggested fix — don't restructure HTML blindly.

## Step 2 — Favicon

**Check**: `<link rel="icon">` exists; sizes 16/32 (ICO or PNG), 180 (apple-touch-icon), 192 + 512 (PWA manifest); `<link rel="manifest">` if PWA icons expected; SVG favicon for modern browsers.

**Fix if missing**:
1. Extract brand identity: primary color from CSS custom properties or dominant styles; initials from `<title>` / `og:site_name`; any existing logo SVG.
2. Generate an SVG favicon — brand initial(s) on a rounded rect in the primary color.
3. Save as `favicon.svg`; convert to PNG/ICO with sharp, Jimp, or Pillow if available, otherwise note conversion is a build-time step.
4. Inject the standard `<head>` links: SVG icon, 32×32 PNG, apple-touch-icon, manifest.
5. Generate `site.webmanifest` if missing (name, short_name, 192/512 icons, theme/background color, `display: standalone`).

## Step 3 — Open Graph & social previews

**Check**: `og:title`, `og:description`, `og:image` (absolute URL, 1200×630), `og:url` (canonical), `og:type`, `og:site_name`; Twitter Card tags (`twitter:card`, `twitter:title`, `twitter:description`, `twitter:image`).

**Fix if missing**: derive basic OG tags from existing meta content. If `og:image` is missing or placeholder, generate one:
1. Pick the source by page type: article → hero image; product → product image; landing/portfolio → generate a branded card.
2. Generate at 1200×630 with ~60px safe-zone padding: brand background, logo, title (max 2 lines), subtitle, site name/URL in a corner. Use sharp + resvg, Pillow, or an HTML template screenshot at build time — whatever the project supports.
3. Save under `/public/og/` and inject `og:image` (+ width/height) and `twitter:card: summary_large_image`.

## Step 4 — Mobile

**Check**:
- `<meta name="viewport" content="width=device-width, initial-scale=1">` — and **no** `user-scalable=no` / `maximum-scale=1` (accessibility violation)
- All `<input>`/`<select>`/`<textarea>` have `font-size` ≥ 16px — iOS Safari zooms on focus below that; the most common overlooked issue
- No fixed widths wider than the viewport; images `max-width: 100%`; no horizontal scroll at 375px
- `@media` coverage: ≤640px and ≤1024px if the layout is complex
- Touch targets ≥ 44×44px with ≥ 8px gaps
- Typography: base ≥ 16px, line-height ≥ 1.5, nothing below 12px
- Performance (flag, don't fix): image `width`/`height` attributes (CLS), `loading="lazy"` below the fold, `defer`/`async` on scripts

**Fix**: add/correct the viewport meta; add `input, select, textarea { font-size: max(16px, 1rem); }` if missing; add missing `max-width: 100%` on images; flag touch-target issues with specific selectors and suggested fixes.

## Step 5 — Report

```
## Production Readiness Report — [Page Title]

SEO          [score /10] — ✅/⚠️/❌ per item, one line each
Favicon      [PASS / GENERATED / FAIL]
Open Graph   [PASS / GENERATED / FAIL]
Mobile       [score /10]

### Changes made
- [files modified or created]

### Still needs human attention
- [items requiring manual decision or content]
```

## Notes & edge cases

- **Framework-specific**: Next.js → `metadata` exports in `app/layout.tsx`; Nuxt → `useHead()` / `useSeoMeta()`. Fix via the framework-idiomatic pattern, not raw HTML.
- **Dynamic OG images**: if the project uses `@vercel/og` or similar, audit the template instead of replacing it.
- **i18n**: multiple languages → recommend `hreflang` alternates.
- **Dark mode**: suggest an SVG favicon with a `prefers-color-scheme` media query inside the SVG.
- **`robots.txt` / `sitemap.xml`**: mention if missing, but don't generate unless asked.
