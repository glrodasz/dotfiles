# Stack adapters

Per-stack code for detection, page rendering, and the language toggle. Everything here
imports from the core module (`core-module.md`) and never re-implements its logic.

## Contents

- Detection at the edge (Vercel, Netlify, Cloudflare)
- Detection on an SSR server
- Detection in a blocking boot script (static hosts)
- Rendering the page locale: SSR, React Router SPA, Astro (static)
- Language toggle: React, Astro

## Detection at the edge

Preferred whenever the host runs middleware (Vercel Middleware, Netlify Edge Functions,
Cloudflare). The redirect happens before any HTML is sent.

```ts
// middleware.ts (Vercel, framework-less)
import { LOCALE_COOKIE, parseAcceptLanguage, readCookie, resolveLocaleRedirect } from './src/i18n/locale';

export default function middleware(request: Request) {
  const url = new URL(request.url);
  const target = resolveLocaleRedirect({
    pathname: url.pathname,
    savedLocale: readCookie(request.headers.get('cookie'), LOCALE_COOKIE),
    languages: parseAcceptLanguage(request.headers.get('accept-language')),
  });
  if (!target) return;

  return new Response(null, {
    status: 307,
    headers: {
      Location: new URL(target + url.search, url).href,
      'Cache-Control': 'private, no-store',
      Vary: 'Cookie, Accept-Language',
    },
  });
}

export const config = {
  matcher: ['/((?!api/|assets/|.*\\.).*)'], // skip APIs, build assets, anything with a file extension
};
```

On Netlify, put the same body in `netlify/edge-functions/locale.ts` with
`export const config = { path: '/*', excludedPath: ['/api/*', '/_astro/*'] }`.

## Detection on an SSR server

When the app renders on its own server (Express/Hono/Fastify handlers, or a framework's
server middleware), run the same `resolveLocaleRedirect` call in the first middleware,
before routing and rendering. Return the identical 307 with
`Cache-Control: private, no-store` and `Vary: Cookie, Accept-Language`. Keep the exemption
for APIs and static assets in the middleware mount path, not in a second regex.

If the framework ships its own i18n routing (e.g. Next.js, Nuxt, SvelteKit), configure it
to match the core: default locale unprefixed, no automatic detection redirect of its own
(or one that follows the same precedence), and the same `locale` cookie. Never run two
detectors.

## Detection in a blocking boot script

Fallback for a purely static host. Bundle it to an IIFE (esbuild) and load it as a
blocking `<script>` in `<head>`, right after the theme boot script.

```ts
// src/scripts/localeBoot.ts
import { LOCALE_COOKIE, readCookie, resolveLocaleRedirect } from '../i18n/locale';

const root = document.documentElement;
try {
  const target = resolveLocaleRedirect({
    pathname: location.pathname,
    savedLocale: readCookie(document.cookie, LOCALE_COOKIE),
    languages: navigator.languages?.length ? navigator.languages : [navigator.language],
  });
  if (target) {
    root.setAttribute('data-locale-pending', '');
    setTimeout(() => root.removeAttribute('data-locale-pending'), 300); // never strand a blank page
    location.replace(target + location.search + location.hash);
  }
} catch {
  root.removeAttribute('data-locale-pending');
}
```

```css
html[data-locale-pending] body { opacity: 0; }
```

Serve the script unhashed with `Cache-Control: max-age=0, must-revalidate`. If you inline
it instead and the site has a CSP with script hashes, update the hash.

## Rendering the page locale

### SSR

Compute `pageLocale(url.pathname)` once per request and pass it to the render. Emit
`<html lang>`, canonical, `alternateLinks()` and `og:locale` in the server-rendered head,
so crawlers see them without JS. Hydrate the client with the same locale (a serialized
prop, or re-derive it from `location.pathname`); never let the client detect again.

### React Router SPA

One route tree serves every locale:

```tsx
<Route path="/:lang?" element={<LocaleLayout />}>
  <Route index element={<Home />} />
  <Route path="about" element={<About />} />
  <Route path="*" element={<NotFound />} />
</Route>
```

```tsx
export const LocaleLayout: React.FC = () => {
  const { lang } = useParams<{ lang?: string }>();
  const { pathname } = useLocation();
  const { i18n } = useTranslation();
  const locale = lang === undefined ? DEFAULT_LOCALE : localePrefix(`/${lang}`);

  useEffect(() => {
    if (!locale) return;
    i18n.changeLanguage(locale);
    document.documentElement.lang = locale;
    document.querySelector('meta[property="og:locale"]')?.setAttribute('content', OG_LOCALES[locale]);
  }, [locale, i18n]);

  if (!locale) return <NotFound />; // `/xyz` and `/en/...` are 404s, not locales

  return (
    <>
      {/* React 19 hoists these into <head> */}
      <link rel="canonical" href={new URL(pathname, SITE_URL).href} />
      {alternateLinks(pathname, SITE_URL).map((link) => (
        <link key={link.hreflang} rel="alternate" hrefLang={link.hreflang} href={link.href} />
      ))}
      <Outlet />
    </>
  );
};
```

Initialize i18next with `lng: pageLocale(location.pathname)` and
`fallbackLng: DEFAULT_LOCALE`. Skip the browser language detector: the URL already decided
the language, and the detector adds a second persisted store (`i18nextLng`) that can
disagree with the cookie.

### Astro (static)

Set `i18n: { locales: LOCALES, defaultLocale: DEFAULT_LOCALE, routing: { prefixDefaultLocale: false } }`
so Astro's helpers agree with the core. Mirror pages under `src/pages/es/`. In the layout,
compute `pageLocale(Astro.url.pathname)` once and pass it down. `BaseHead` emits
`<html lang>`, canonical, `alternateLinks()`, `og:locale`, and the RSS link for that
locale. On Netlify, serve locale 404s via `_redirects`: `/es/*  /es/404/  404`.

## Language toggle

### React (design-system component)

```tsx
// src/components/molecules/LanguageToggle/LanguageToggle.tsx
export interface LanguageToggleProps {
  alternates?: Alternates;
  className?: string;
}

export const LanguageToggle: React.FC<LanguageToggleProps> = ({ alternates, className }) => {
  const { pathname } = useLocation();
  const { i18n } = useTranslation();
  const target = LOCALES.find((locale) => locale !== pageLocale(pathname)) ?? DEFAULT_LOCALE;
  const tTarget = i18n.getFixedT(target);

  return (
    <Link
      to={switchLocalePath(pathname, target, alternates)}
      className={['language-toggle', className].filter(Boolean).join(' ')}
      hrefLang={target}
      lang={target}
      aria-label={tTarget('nav.switchLanguage')}
      onClick={() => persistLocale(target)}
    >
      <Globe size={14} aria-hidden />
      {LANGUAGE_NAMES[target]}
    </Link>
  );
};
```

Style it with tokens that alias the same design tokens as the theme toggle, so the two
read as one cluster. If the project has Storybook (or similar), add a story covering both
locales.

### Astro

```astro
---
import { LANGUAGE_NAMES, LOCALES, pageLocale, switchLocalePath, type Alternates } from '../i18n/locale';
import { getMessages } from '../i18n';
interface Props { alternates?: Alternates }
const target = LOCALES.find((l) => l !== pageLocale(Astro.url.pathname))!;
const href = switchLocalePath(Astro.url.pathname, target, Astro.props.alternates);
---
<a href={href} class="language-toggle" hreflang={target} lang={target}
   data-switch-locale={target} aria-label={getMessages(target).navigation.switchLanguage}>
  <LanguageIcon /> {LANGUAGE_NAMES[target]}
</a>

<script>
  import { isLocale } from '../i18n/locale';
  import { persistLocale } from '../i18n/persistLocale';
  // Delegated, so the "Read in …" banner links persist too: give them data-switch-locale.
  document.addEventListener('click', (event) => {
    const link = (event.target as Element).closest<HTMLAnchorElement>('a[data-switch-locale]');
    const locale = link?.dataset.switchLocale;
    if (isLocale(locale)) persistLocale(locale);
  });
</script>
```
