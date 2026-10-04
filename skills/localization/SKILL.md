---
name: localization
description: >
  Implement or extend localization (i18n) for a static, SSR or client-rendered website, or
  a native app sharing its links, using one canonical pattern — locale-prefixed URLs,
  locale inferred from a saved choice then the browser/OS languages, a language toggle in
  the UI, hreflang/SEO, and typed translated strings. Use whenever the user adds a
  language, translates pages or UI copy, builds or moves a language switcher/toggle,
  touches Accept-Language or navigator.languages detection, locale redirects or edge
  middleware, hreflang/og:locale/html lang, per-language routes, slugs, RSS or sitemaps —
  even if they only say "make this page work in Spanish" or "add an English version".
---

# Localization

One pattern for static sites, SSR apps, client-rendered SPAs and the native apps that
share their links. The **core** (URL scheme, precedence, persistence, toggle behavior)
must behave identically in every app. Only the **adapters** (where detection runs, how
the page renders its locale) change per stack. When an app already localizes, compare it
against the rules below and fix the deviations you touch instead of adding a second
mechanism.

- Core module, copied verbatim into every app: see `references/core-module.md`.
- Edge, SSR and boot-script detection, SPA and static-site rendering, toggle components:
  see `references/stack-adapters.md`.

## Phase 0 — Understand the target

1. **Existing i18n:** grep for an i18n library (`i18next`, `react-intl`, `next-intl`,
   `vue-i18n`, Astro `i18n` config), `[lang]`/`[locale]` route folders, `Accept-Language`
   or `navigator.languages` reads, locale cookies or localStorage keys, a language
   switcher, and hreflang tags. Note what each one controls.
2. **Rendering and host:** static, SSR or client-rendered SPA, and whether the host runs
   middleware. This picks the detection adapter (see *Where detection runs*).
3. **Locales:** the default locale, the other locales, and whether content uses shared or
   per-language slugs.
4. **Sibling apps:** other apps on the same registrable domain (blog subdomain, native app)
   that must share the `locale` cookie and the `/{locale}` link shape.
5. **Deviations** (existing i18n): list every place the app breaks the rules below
   (`?lang=`, 301 redirects, a localStorage-only choice, hand-written prefixes, flags, a
   toggle in the header). Fix the ones you touch, replace the old mechanism instead of
   running two, and carry the rest into the report.

## The model

```
request /about?utm=x
  │
  ├─ path has a locale prefix (/es/…)? ── yes ─► render that locale. Never redirect away.
  ├─ exempt path (API, assets, dev pages, per-language-slug content)? ── yes ─► render as-is
  │
  ├─ saved choice: cookie `locale`                       ─┐
  ├─ else browser/OS: Accept-Language | navigator.languages ├─► target locale
  └─ else DEFAULT_LOCALE                                 ─┘
        │
        └─ target ≠ default ─► 307 / location.replace → /es/about?utm=x
```

## Rules, and why

1. **The URL is the source of truth for what a page renders.** Detection only decides
   where an *unprefixed* first visit lands. A shared `/es/...` link must open in Spanish
   for everyone, and crawlers (no cookie, no Accept-Language) must be able to reach every
   language.
2. **Default locale unprefixed, every other locale under `/{locale}`.** `/about` =
   English, `/es/about` = Spanish. One deploy, one cookie scope, shareable and crawlable
   URLs. No `?lang=` (poorly indexed, lost on copy) and no same-URL content negotiation
   (breaks caching and sharing).
3. **Precedence: URL → saved choice → browser/OS languages → default.** An explicit
   choice always beats inference, and inference beats a guess.
4. **Negotiate in the user's priority order.** Walk the language list (Accept-Language
   sorted by `q`, or `navigator.languages`) and take the first entry whose base language
   you support. `sv, es;q=0.8` → `es`; `en-US, es` → `en`. Looking at only the first
   entry, or at *any* entry, both get real users wrong.
5. **Redirect only unprefixed → prefixed, temporarily, preserving `?query#hash`.** Use 307
   (edge) or `location.replace` (client), never 301: the target depends on who's asking,
   and a cached permanent redirect traps people in the wrong language. Never let a CDN
   cache the redirect.
6. **Persist the choice in one cookie, `locale`.** Edge code can read cookies;
   localStorage is invisible to the edge and scoped to a single origin. Set `Domain` to
   the registrable domain so sibling apps (e.g. site + blog subdomain) share one choice.
7. **Any link that switches language persists the choice on `click`.** Not `mousedown`:
   keyboard activation never fires it.
8. **Never hand-write locale prefixes.** All internal links go through `localizePath()`,
   and the toggle target comes from `switchLocalePath()`. Duplicated regexes in components
   drift apart.
9. **Everything locale-specific derives from `pageLocale(pathname)`:** `<html lang>`,
   `og:locale`, hreflang, feeds, date formats, form payloads, 404 page.

## URL and link arrangement

| Resource | Default (`en`) | Other (`es`) |
|---|---|---|
| Home | `/` | `/es` |
| Page with a shared slug | `/about` | `/es/about` |
| Content with per-language slugs | `/posts/what-is-an-algorithm` | `/es/posts/que-es-un-algoritmo` |
| Feed | `/rss.xml` | `/es/rss.xml` |
| 404 | `/404` | `/es/404` |
| API, assets, dev-only pages | `/api/*`, `/assets/*`, `/tokens` | not localized |
| Cross-app link | `https://blog.example.com/` | `https://blog.example.com/es` |

The default locale is never prefixed (`/en/about` is a 404, not an alias). Pick one
trailing-slash form per app (e.g. `/es` on an SPA, `/es/` on static directory output) and
use it consistently in canonical, hreflang and the toggle. If your host serves `/es/`,
change the root case in `localizePath`.

## Core module

`src/i18n/locale.ts` holds the config (`LOCALES`, `DEFAULT_LOCALE`, `LOCALE_COOKIE`,
`COOKIE_DOMAIN`, `EXEMPT_PATHS`, `LANGUAGE_NAMES`, `OG_LOCALES`) and the pure functions
`isLocale`, `localePrefix`, `pageLocale`, `stripLocale`, `localizePath`,
`switchLocalePath`, `parseAcceptLanguage`, `negotiateLocale`, `resolveLocaleRedirect`,
`readCookie`, `alternateLinks`. `src/i18n/persistLocale.ts` is the browser-only cookie
writer. Copy both from `references/core-module.md` as-is and change only the config block.
Never re-implement any of this logic inside an adapter or component.

## Where detection runs

Detection must finish before first paint, or Spanish visitors see an English flash.

- **Preferred: at the edge or on the server.** Whenever the host runs middleware (Vercel
  Middleware, Netlify Edge Functions, Cloudflare Workers) or the app renders on the server
  (SSR), redirect there with a 307, `Cache-Control: private, no-store` and
  `Vary: Cookie, Accept-Language`, before any HTML is sent.
- **Fallback: blocking boot script.** On a purely static host, a blocking `<script>` in
  `<head>` right after the theme boot script calls `location.replace`, hiding the body
  for at most 300 ms.

Code for both, plus SSR, React Router and Astro rendering: see
`references/stack-adapters.md`.

## Language toggle

**Placement: a preferences cluster `[🌐 Español] [☾ Dark]`**
- On desktop, put it at the right end of the footer bottom bar, language first, then
  theme.
- On mobile, show the same cluster at the bottom of the menu overlay, and keep it in the
  footer too.
- On content with a translation, add one contextual link in the post meta ("Read in
  English"). It's a second entry point, not a second global switcher.
- Keep it out of the header nav. Auto-detection already lands most visitors in the right
  language, so the toggle is a correction tool. Spanish strings also run 20–30% longer,
  and the header needs that room.

**Behavior**
- Make it a real link (`<a href>` or router `<Link>`), not a button. It then works without
  JS, is crawlable, opens in a new tab, and can carry `hreflang`.
- Label it with the target language's endonym: "Español" on English pages, "English" on
  Spanish pages. Users scan for their own language. Never use flags: they stand for
  countries, not languages.
- Set `lang` and `hreflang` to the target, and take `aria-label` from the target locale's
  dictionary ("Cambiar a español" / "Switch to English"). `lang` applies to the label too,
  so the screen reader voices it correctly.
- Compute `href` with `switchLocalePath(pathname, target, alternates)`.
- Call `persistLocale(target)` on `click`.
- With two locales, use a single toggle. With three or more, use a disclosure button that
  lists every locale as links, applying the same rules to each link.

React and Astro components: see `references/stack-adapters.md`.

## Strings and formatting

- **Dictionaries.** Keep one dictionary per locale (and per namespace) with an identical
  shape. The default locale is the type source (`typeof en`, or `satisfies Messages`), so
  a missing key fails the build. Fall back to the default locale at runtime.
- **Whole sentences.** Interpolate complete sentences (`"switchTo": "Cambiar a
  {language}"`). Never concatenate translated fragments: word order differs between
  languages.
- **Locale-specific data.** Course titles, project blurbs and similar content live in
  data files keyed by locale, not inline in components.
- **Dates and numbers.** Format with `Intl.DateTimeFormat(locale, …)` and
  `Intl.NumberFormat(locale, …)`. Never hand-format month names.
- **Side effects.** Everything outside the page carries the locale too: form payloads
  (e.g. the newsletter list per language), emails, OG images (`/og/es/…`), RSS, audio,
  404.
- **Content conventions.** Rules like "IA" in Spanish vs "AI" in English belong in the
  app's `AGENTS.md`, not here.

## Content with per-language slugs

Store entries as `content/posts/{locale}/<slug>.md`. Each entry declares its counterparts
in frontmatter (e.g. `languageVersions: [{ language: es, url: /es/posts/... }]`). Build an
`Alternates` map from that list plus the page itself, and pass the map to both the toggle
and the head:
- **Missing translation.** The toggle goes to the target locale's home, and hreflang lists
  only the versions that exist.
- **Exempt from auto-redirect.** Add these content roots (e.g. `/posts`, `/tags`) to
  `EXEMPT_PATHS`. An English slug has no Spanish twin at `/es/<same-slug>`, so a redirect
  would 404.

## SEO and metadata checklist

- `<html lang>` = `pageLocale(pathname)`.
- Self-referencing canonical. Never canonicalize `/es/x` to `/x`.
- `hreflang` alternates for every existing version plus `x-default`, reciprocal across
  versions (`alternateLinks()`).
- `og:locale`, plus `og:locale:alternate` for the other versions.
- A sitemap with alternates. For shared slugs, use the `@astrojs/sitemap` `i18n` option.
  Per-language slugs need a custom `serialize`.
- One RSS feed per locale with `<language>`, and an autodiscovery link pointing at the
  current locale's feed.
- JSON-LD `inLanguage`.

## Testing

**Unit tests: the shared truth table.** Every app's core must pass this table:

| pathname | cookie | languages | → redirect |
|---|---|---|---|
| `/` | — | `es-ES` | `/es` |
| `/about` | — | `sv, es;q=0.8` | `/es/about` |
| `/` | — | `en-US, es` | none |
| `/` | `es` | `en-US` | `/es` |
| `/` | `en` | `es-ES` | none |
| `/es/about` | `en` | `en` | none (URL wins) |
| `/api/subscribe` | `es` | `es` | none (exempt) |
| `/apis` | — | `es` | `/es/apis` (segment boundary) |
| `/` | `garbage` | `es` | `/es` (invalid cookie ignored) |

Also assert the round trips: `localizePath('/es','en') === '/'`,
`switchLocalePath('/es/about','en') === '/about'`, alternates are honored, and a missing
alternate falls back to the locale home.

**End-to-end tests (Playwright)**
- `test.use({ locale: 'es-ES' })`: `/` lands on `/es`, and `/about?utm_source=x` keeps its
  query.
- With an `en` cookie (`context.addCookies`) and an es-ES browser, the visitor stays on
  `/`.
- With an English browser, `/es/...` is not redirected.
- Keyboard toggle (`focus()` + `Enter`): the cookie is set, the visitor lands on the
  counterpart, and a reload stays there.
- Per locale, check `<html lang>`, `og:locale`, and the hreflang count.

## Adding a locale

1. Append it to `LOCALES`, `LANGUAGE_NAMES` and `OG_LOCALES`.
2. Add its dictionaries. The type check flags any gaps.
3. Add routes. A `/:lang?` route tree (SPA or SSR) needs nothing. File-based static
   routing needs mirrored pages, e.g. `src/pages/{locale}/`.
4. Add its feeds, OG images, 404 page, form side effects and sitemap entries.
5. With three or more locales, turn the toggle into the disclosure button (see Language
   toggle).
6. Extend the truth table.

## Native apps

- **Precedence without a URL:** saved in-app choice → OS preferred languages
  (`Intl.DateTimeFormat().resolvedOptions().locale`, Expo `getLocales()`,
  `Locale.preferredLanguages`, `LocaleList`) through the same `negotiateLocale()` →
  default.
- **Toggle:** prefer the platform's per-app language setting (iOS, Android 13+). If you
  also add an in-app toggle, put it in Settings next to theme.
- **Links:** universal/deep links keep the web's `/es/...` shape, so shared links open in
  the right language everywhere.

## Verify

Before reporting done, copy and tick:

```
- [ ] The core passes the truth table, and there are no hand-written `'/es` strings outside `locale.ts`.
- [ ] The redirect returns 307 (or uses `replace`), keeps the query, never fires on prefixed or exempt paths, and is never cached.
- [ ] The toggle sits in the footer cluster and the mobile menu, is a link with `lang`/`hreflang`, and persists on click.
- [ ] Every page has `<html lang>`, a self canonical, hreflang + `x-default`, and `og:locale`.
- [ ] Strings are typed against the default locale, and dates/numbers go through `Intl`.
- [ ] End-to-end tests cover an es browser, a saved `en` cookie, an explicit `/es`, and the keyboard toggle.
```

## Report

```markdown
## Localization — <app>

**Stack:** <framework · rendering · host>   **Locales:** <default> + <others>

### Changes made
- Core module: <copied | existing, fixed N deviations> · config: <locales, cookie domain, exempt paths>
- Detection: <edge middleware | SSR | boot script>
- Toggle: <components, placement>
- Strings: <dictionaries, namespaces, Intl formatting>
- SEO: <html lang, canonical, hreflang, og:locale, sitemap, RSS>
- Tests: <truth table, end-to-end cases>

### Still needs human attention
- <deviations left, untranslated content, missing per-language slugs, side effects not localized, checks not run>
```
