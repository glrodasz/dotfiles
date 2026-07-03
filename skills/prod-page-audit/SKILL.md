---
name: prod-page-audit
description: >
  Run a comprehensive production readiness audit on a web page or site. Use this skill whenever
  the user wants to verify a page is ready to ship, asks for a "production check", "launch checklist",
  "SEO audit", "OG audit", "mobile readiness check", or mentions going live with a site or landing page.
  Also trigger when the user says things like "is this page ready?", "check my site before launch",
  or asks about favicon, Open Graph, meta tags, mobile viewport, or semantic HTML issues.
  This skill covers: SEO, favicon, Open Graph / social previews, and mobile optimization — and it
  fixes any gaps it finds, not just reports them.
---

# Production Page Check

A systematic audit + auto-fix workflow for web pages before they go to production.

## Scope

| Area | What's checked | Auto-fix? |
|---|---|---|
| SEO | Title, description, semantic HTML, canonical, robots | Fix meta; flag structural issues |
| Favicon | Presence, sizes, formats, manifest | Generate if missing |
| Open Graph | og: tags, Twitter Card, image dimensions | Generate OG image if missing |
| Mobile | Viewport, font sizes, input zoom prevention, touch targets | Fix in-place where possible |

---

## Step 0 — Understand the target

Before starting, identify:
1. **Input type**: Is the user pointing at a file path, a URL, or a project directory?
   - File/directory → read source directly
   - URL → use fetch or ask user to provide the HTML
2. **Page type**: Landing page, blog post, article, product page, portfolio, etc.
   - This determines what the OG image and favicon should look like
3. **Brand context**: Colors, logo, name — pull from existing CSS variables, `<meta>`, or ask

If ambiguous, ask one focused question before proceeding.

---

## Step 1 — SEO Audit

### Check
- `<title>` exists, is 50–60 characters, descriptive and unique
- `<meta name="description">` exists, is 120–160 characters, action-oriented
- `<link rel="canonical">` present
- `<meta name="robots">` not accidentally set to `noindex`
- Heading hierarchy: single `<h1>`, logical `h2`/`h3` nesting
- Images have meaningful `alt` attributes (not empty, not "image")
- Links have descriptive text (not "click here")
- Semantic HTML landmarks: `<header>`, `<main>`, `<footer>`, `<nav>`, `<article>`/`<section>` where appropriate
- `<html lang="...">` is set
- Structured data (`<script type="application/ld+json">`) if applicable (article, product, local business)

### Fix
- Add or rewrite `<title>` and `<meta name="description">` inline
- Add `<link rel="canonical">` pointing to the page's canonical URL
- Add `<html lang="en">` (or correct locale)
- Flag structural issues (wrong heading hierarchy, missing `<main>`) with a TODO comment and suggested fix — don't restructure HTML blindly
- Add missing `alt` attributes with descriptive placeholder text marked `<!-- TODO: update alt -->`

### Output
Report each item as ✅ PASS, ⚠️ WARN, or ❌ FAIL with a one-line explanation.

---

## Step 2 — Favicon Audit

### Check
- `<link rel="icon" href="...">` exists
- Sizes present: 16×16, 32×32 (ICO or PNG), 180×180 (apple-touch-icon), 192×192 + 512×512 (PWA manifest)
- `<link rel="manifest" href="/site.webmanifest">` exists if PWA icons are expected
- SVG favicon for modern browsers (`<link rel="icon" type="image/svg+xml">`)

### Fix if missing
Generate a favicon programmatically:

1. **Extract brand identity** from the page:
   - Primary color from CSS custom properties (`--color-primary`, `--brand-*`) or dominant color in existing styles
   - Site name or abbreviation from `<title>` or `<meta property="og:site_name">`
   - Any existing logo SVG in the codebase

2. **Generate SVG favicon** using the brand initial(s) on a colored background:
   ```svg
   <!-- Example output -->
   <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
     <rect width="32" height="32" rx="6" fill="#YOUR_BRAND_COLOR"/>
     <text x="16" y="22" font-family="system-ui,sans-serif" font-size="18"
           font-weight="700" fill="white" text-anchor="middle">A</text>
   </svg>
   ```

3. **Save** as `favicon.svg` and `favicon.ico` (use sharp, Jimp, or Python Pillow if available; otherwise write the SVG and note that PNG/ICO conversion should be done at build time)

4. **Inject** the following into `<head>`:
   ```html
   <link rel="icon" type="image/svg+xml" href="/favicon.svg">
   <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
   <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
   <link rel="manifest" href="/site.webmanifest">
   ```

5. **Generate `site.webmanifest`** if missing:
   ```json
   {
     "name": "Site Name",
     "short_name": "Short",
     "icons": [
       { "src": "/favicon-192x192.png", "sizes": "192x192", "type": "image/png" },
       { "src": "/favicon-512x512.png", "sizes": "512x512", "type": "image/png" }
     ],
     "theme_color": "#YOUR_BRAND_COLOR",
     "background_color": "#ffffff",
     "display": "standalone"
   }
   ```

---

## Step 3 — Open Graph & Social Preview Audit

### Check
- `<meta property="og:title">` — matches `<title>` or is a refined version
- `<meta property="og:description">` — matches meta description or is a tailored version
- `<meta property="og:image">` — absolute URL, ideally 1200×630px
- `<meta property="og:url">` — canonical URL
- `<meta property="og:type">` — `website`, `article`, `product`, etc.
- `<meta property="og:site_name">` — brand name
- Twitter Card tags: `twitter:card`, `twitter:title`, `twitter:description`, `twitter:image`

### Fix if missing

**Add basic OG tags** from existing meta content.

**Generate OG image** if `og:image` is missing or placeholder:

1. **Determine page type and available assets**:
   - Blog/article → use the post's hero image if present; otherwise generate a text-based card
   - Product page → use the product image
   - Landing page → generate a branded card
   - Portfolio → generate with project name and tagline

2. **Generate OG image** as an HTML/SVG composition saved to `/public/og/`:
   ```
   Dimensions: 1200 × 630px
   Safe zone: 60px padding on all sides
   Structure:
   - Background: brand primary color or gradient
   - Logo/icon: top-left or centered
   - Title: large, bold, max 2 lines
   - Subtitle/description: smaller, max 2 lines
   - Site name or URL: bottom-right corner
   ```
   
   Use a Node script with `sharp` + `@resvg/resvg-js`, or a Python script with `Pillow`, or generate an HTML file and note that it can be screenshot at 1200×630 with Puppeteer/Playwright at build time.

3. **Inject**:
   ```html
   <meta property="og:image" content="https://yourdomain.com/og/page-name.png">
   <meta property="og:image:width" content="1200">
   <meta property="og:image:height" content="630">
   <meta name="twitter:card" content="summary_large_image">
   ```

---

## Step 4 — Mobile Optimization Audit

### Check

#### Viewport
- `<meta name="viewport" content="width=device-width, initial-scale=1">` exists
- `user-scalable=no` or `maximum-scale=1` are **not** present (accessibility violation)

#### Input zoom prevention (iOS Safari)
- All `<input>`, `<select>`, `<textarea>` have `font-size` ≥ 16px in CSS
- iOS zooms in when font-size < 16px on focus — this is the most common overlooked issue

#### Responsive layout
- No fixed pixel widths wider than the viewport on key containers
- Images use `max-width: 100%` or are in responsive containers
- No horizontal scroll on 375px viewport (iPhone SE baseline)
- `@media` queries cover at least: ≤ 640px (mobile), ≤ 1024px (tablet) if layout is complex

#### Touch targets
- Interactive elements (buttons, links, inputs) have a minimum touch target of 44×44px (Apple HIG) / 48×48dp (Material)
- No tap targets that are too close together (< 8px gap)

#### Typography
- Base font-size is at least 16px
- Line-height is at least 1.5 for body text
- No text smaller than 12px

#### Performance hints (flag, don't fix)
- Images have `width` and `height` attributes to prevent layout shift (CLS)
- `loading="lazy"` on below-fold images
- No render-blocking scripts without `defer` or `async`

### Fix
- Add or correct `<meta name="viewport">` 
- Add CSS rule for input font-size if missing:
  ```css
  /* Prevent iOS zoom on input focus */
  input, select, textarea {
    font-size: max(16px, 1rem);
  }
  ```
- Fix any `max-width: 100%` missing on images
- Flag touch target issues with specific selectors and suggested fix

---

## Step 5 — Report & Summary

After all checks and fixes, output a structured summary:

```
## Production Readiness Report — [Page Title]

### SEO          [score /10]
✅ ...
⚠️ ...
❌ ...

### Favicon      [PASS / GENERATED / FAIL]
...

### Open Graph   [PASS / GENERATED / FAIL]
...

### Mobile       [score /10]
...

---
### Changes made
- [list of files modified or created]

### Still needs human attention
- [list of items that require manual decision or content]
```

---

## Notes & Edge Cases

- **Framework-specific**: If the project uses Next.js, check `app/layout.tsx` for `metadata` exports and `<Head>` components. For Nuxt, check `useHead()` / `useSeoMeta()`. Flag framework-idiomatic patterns instead of editing raw HTML.
- **Dynamic OG images**: If the project already uses `@vercel/og` or similar, don't replace it — audit the template instead.
- **i18n**: If multiple languages are detected, flag `<link rel="alternate" hreflang="...">` as a recommended addition.
- **Dark mode favicon**: If the site has a dark/light theme, suggest an SVG favicon with `prefers-color-scheme` media query inside the SVG.
- **`robots.txt` and `sitemap.xml`**: Mention if missing, but don't generate unless asked.
