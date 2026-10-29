# Quantum Design token spec

The source format, the per-level rules, the full token vocabulary and the theming model.
Read the section you need. The seed files in `assets/tokens/` already follow every rule
here.

## Contents

1. Source format: slim W3C DTCG
2. Level rules
3. Global vocabulary
4. System vocabulary and default mapping
5. Component vocabulary
6. Theming and re-theming
7. Audit checks
8. Layout grids

---

## 1. Source format: slim W3C DTCG

A **token** is an object with `$type` and `$value`, plus an optional `$description`. Any
other object is a **group**. Nothing else is allowed: no `$extensions` and no design-tool
metadata.

```json
{
  "Spacing": {
    "md": { "$type": "number", "$value": "{global.Sizing.24}" }
  }
}
```

| `$type` | Value form | Examples |
|---|---|---|
| `color` | `#RRGGBB`, or `#RRGGBBAA` when alpha < 1 | `"#D6FF33"`, `"#0A60FF26"` (`26` = 15% alpha, the system's standard translucency) |
| `number` | Unitless number. The build adds units per platform. | `24`, `700`, `1.22` |
| `string` | Emitted verbatim | `"'Inter', system-ui, sans-serif"`, `"clamp(3rem, 20vw, 5rem)"`, `"58%"`, `"0.08em"` |

Never put units inside a `number` (`"24px"` is wrong). If a value needs a unit the scale
doesn't model (`em`, `%`, `rem`, `clamp()`), make it a `string`.

**References** use DTCG curly-brace syntax with a level prefix, followed by the **exact JSON
keys** of the target, separated by dots:

```
{global.Colors.Schemas.Metal chartreuse.Gunmetal.600}
{system.Colors.Complementary.principal}
{system.Border radius.sm}
{system.Typography.font-size.Body.sm}
{components.button.background-color.primary.default}
```

- The prefixes are `global`, `system`, and `components` (plural).
- Lookup is exact and is case- and space-sensitive. `Font-family` ≠ `font-family`, and
  `Border radius` ≠ `Border-radius`. Copy keys character for character.
- The reference must be the **entire** value. There is no composition (`"{a} {b}"`) and no
  math.
- Never use `.`, `{` or `}` inside a key, because they break path splitting.

## 2. Level rules

| Token in | Must | Allowed raw value | Flagged |
|---|---|---|---|
| Global | Hold raw values | Always | Any reference |
| System (light) | Reference a global token | Non-color + `$description` | Raw color; raw non-color without `$description` |
| System (dark) | Override an **existing** light key, referencing a global token | Raw hex only when no global shade exists (prefer adding the shade to global) | Key absent from light; broken reference |
| Component | Reference a system token | Non-color + `$description` | Raw color; raw non-color without `$description`; reference to a global (level skip) |

**The escape hatch** for raw non-color values covers cases where no honest ancestor exists:

```json
"height": {
  "$type": "number",
  "$value": 72,
  "$description": "Fixed chrome height, tuned to the bar contents rather than taken from the sizing scale."
}
```

Legitimate uses: fluid `clamp()` type, `em` tracking, unitless line-height, percentages;
stroke and outline widths (there is no border-width scale); tap-target floors and off-scale
chrome dimensions; readable-measure caps. Never use it to avoid adding a token that belongs
on a scale.

## 3. Global vocabulary

**Colors**

| Group | Palettes | Steps |
|---|---|---|
| `Colors.Custom.Principal palette`, `Colors.Custom.Complementary palette` | Brand-owned slots, grey placeholders until a project fills them | `100`–`600`, `opacity` |
| `Colors.Schemas.<Schema>.<Palette>` | Ten two-palette schemas (below) | `100` (lightest) – `600` (darkest), `opacity` (15% alpha) |
| `Colors.Support.Shark` | Neutral | `0` (white), `100`–`600`, `700`–`950` (dark-theme surface ramp: 700 lightest → 950 darkest), `opacity-light` (white 15%), `opacity-dark` (black 15%) |
| `Colors.Support.Shamrock` / `Supernova` / `Geraldine` | Success (green), warning (yellow/gold), danger (red) | `100`–`600` |

| Schema | Palette A | Palette B |
|---|---|---|
| Frozen ribbon | Blue Ribbon | Frozen |
| Mint blue | Prussian blue | Mint |
| Flash cerulean | Cerulean | Flash white |
| Metal chartreuse | Gunmetal | Chartreuse |
| Mauve neon | Neon blue | Mauve |
| Violet chiffon | Violet | Lemon chiffon |
| Violet bittersweet | Bittersweet | Dark violet |
| Sweet chiffon | Bittersweet | Lemon chiffon |
| Antique amaranth | Amaranth purple | Antique white |
| Flax sepia | Sepia | Flax |

Sweet chiffon reuses palettes from Violet bittersweet and Violet chiffon with identical
values. Each schema still holds its own copy, so a reference names the schema it themes
from.

**Dimensions** (keyed by value)

- `Sizing`: 0, 2, 4, 8, 12, 16, 24, 32, 48, 64, 80, 96, 116, 148, 180, 240, 1140 (container)
- `Border radius`: 0, 2, 4, 6, 8, 12, 16, 24, 32, 48, 100

**Typography**

- `Typography.Font-family`: complete stacks keyed by family — Inter, Montserrat, DM-Sans,
  JetBrains Mono, Work Sans, Manrope, Poppins, Space Grotesk, Syne, Libre Baskerville,
  Space Mono, Roboto, Lato, Oswald, Raleway, Futura. Name a new family exactly as Google
  Fonts does, so the Figma kit and the web font resolve to the same face. The kit
  recommends at most two families, one for headings and one for body, and ideally one.
- `Typography.Font-weight`, keyed by value: 100 (Light), 300 (Regular), 400 (Medium),
  600 (Semibold), 700 (Bold), 900 (Black).
- `Typography.Base`: type-scale seeds, 8–21.
- `Typography.Scale`: `High contrast` 1.41, `Medium contrast` 1.22, `Low contrast` 1.12.
- `Typography.Steps`: 25 computed sizes keyed by value, used for **both** font sizes and
  line heights: `13 16 17 19 20 22 24 27 29 30 34 35 36 38 44 46 48 54 56 59 66 68 80 82 98`

Scale formula: `size(n) = round(Base × Scale^n)`. Headings: Base 20 × 1.22 → 20, 24, 30,
36, 44, 54, 66, 80. Body: Base 13 × 1.22 → 13, 16, 19, 24, 29, 35. Pick the scale by
surface: High contrast for large screens, Medium for content-heavy interfaces, Low for
dashboards and mobile apps.

Line-height formula: the smallest size gets +4, and each step up adds 2 more (+4, +6,
+8, …). Headings 20/24, 24/30, 30/38 … 80/98 and Body 13/17 … 24/34 follow it. Body `xl`
(29/48) and `xxl` (35/59) in the seed don't follow it (the rule gives 29/41 and 35/49).
No `Typography.Styles` entry uses them.

## 4. System vocabulary and default mapping

**Colors.** Copy key casing exactly: `Colors.Typography` keys are capitalized, except
`disabled`.

| Group | Keys | Role |
|---|---|---|
| `Primary` | principal, subtle, off, high | Brand primary |
| `Complementary` | principal, subtle, off, high, deep | Accent. `deep` = accent for fine detail (thin lines, small marks) that must stay visible on light surfaces |
| `Neutral` | principal, subtle, off, high | Greys |
| `Info` / `Success` / `Warning` / `Danger` | high, low | `high` = strong (text, icon, border); `low` = tinted background |
| `Backgrounds` | principal, secondary, tertiary, subtle, neutral, contrast, atmosphere | Page, raised surfaces, inverted surface (`contrast`), decorative backdrop (`atmosphere`) |
| `Foregrounds` | principal, secondary, tertiary, neutral, contrast, disabled | Text and icons; `neutral` = muted; `contrast` = on an inverted surface |
| `Typography` | Heading, Paragraph, Highlight, Alternative, Contrast, Link, disabled | Text roles |
| `Borders` | strong, neutral, disabled, alternative, focus | Strokes and focus rings |
| `Transparency` | primary, complementary, light, dark, shadow | Translucent washes and scrims; `shadow` = the tint every elevation uses |
| `Fixed` | on-accent, on-dark (+ project-specific) | **Theme-invariant** colors, defined identically in both theme files |

The four-step ramp: `principal` default role color · `subtle` softer variant, used for
hover · `off` near-background tint · `high` maximum emphasis, used for pressed states.

**Dimensions**

| Group | Keys → px |
|---|---|
| `Sizing` | xxs 12, xs 16, sm 24, md 32, ml 48, lg 64, xl 96, xxl 148, container 1140 |
| `Spacing` | none 0, xxs 4, xs 8, sm 12, md 24, ml 32, lm 48, lg 64, xl 80, xxl 116, xxxl 180 |
| `Border radius` | flat 2, xs 4, sm 8, md 12, lm 16, lg 24, xl 32, xxl 48, full 100 |

`ml` is the step after `md`, and `lm` is the step after `ml`. Both are deliberate.

**Elevations** — `Elevations.<intensity>` with `offset-x`, `offset-y`, `blur-radius`,
`spread-radius` (px), named by intensity:

| Intensity | offset-x / offset-y / blur / spread (px) |
|---|---|
| soft | 0 / 8 / 12 / −8 |
| medium | 0 / 8 / 24 / −4 |
| high | 0 / 12 / 32 / 0 |
| extreme | 0 / 12 / 48 / 0 |

All intensities share `Colors.Transparency.shadow` (Gunmetal at 15% in light, black at
15% in dark). The kit shows the shadows but doesn't publish their values. These values
were fitted to the kit's rendering and land on the Sizing scale. To give a component a
shadow, add one component token per part pointing at an intensity (e.g.
`card-image.shadow.elevation.*` → `{system.Elevations.medium.*}`), then compose them:

```css
box-shadow: var(--components-tokens--card-image--shadow--elevation--offset-x)
            var(--components-tokens--card-image--shadow--elevation--offset-y)
            var(--components-tokens--card-image--shadow--elevation--blur-radius)
            var(--components-tokens--card-image--shadow--elevation--spread-radius)
            var(--components-tokens--card-image--shadow-color--elevation);
```

Keep the `-radius` suffixes. The build adds `px` only to paths containing a length word,
and a bare `blur` would come out unitless.

**Typography**

| Group | Keys → value |
|---|---|
| `Typography.Font-family` | Headings, Body, Alternative text (labels, buttons, inputs), Code |
| `Typography.Font-weight` | Weak 300, Moderate 400, Medium 600, Strong 700, Strongest 900 |
| `Typography.font-size.Headings` | Base, Scale, xxs 20, xs 24, sm 30, md 36, lg 44, xl 54, xxl 66, huge 80 |
| `Typography.font-size.Body` | Base, Scale, xs 13, sm 16, md 19, lg 24, xl 29, xxl 35 |
| `Typography.Line-height.Headings` | xxs 24, xs 30, sm 38, md 46, lg 56, xl 68, xxl 82, huge 98 |
| `Typography.Line-height.Body` | xs 17, sm 22, md 27, lg 34, xl 48, xxl 59 |

`font-size` is lowercase and `Line-height` is capitalized. That inconsistency is real, so
copy it exactly.

**Default semantic mapping (light theme)**

| System token | → Global reference |
|---|---|
| Primary principal / subtle / off / high | Metal chartreuse.Gunmetal 600 / 500 / 100 / 600 |
| Complementary principal / subtle / off / high / deep | Metal chartreuse.Chartreuse 400 / 500 / 100 / 600 / 500 |
| Neutral principal / subtle / off / high | Support.Shark 500 / 400 / 100 / 600 |
| Info high / low | Metal chartreuse.Gunmetal 600 / 100 |
| Success, Warning, Danger high / low | Shamrock, Supernova, Geraldine 400 / 100 |
| Backgrounds principal / secondary / tertiary / subtle / neutral / contrast / atmosphere | Shark.0 / Gunmetal.100 / Shark.100 / Shark.200 / Shark.100 / Gunmetal.600 / Flax sepia.Sepia.200 |
| Foregrounds principal / secondary / tertiary / neutral / contrast / disabled | Gunmetal.600 / Gunmetal.500 / Shark.600 / Shark.400 / Gunmetal.100 / Shark.200 |
| Typography Heading / Paragraph / Highlight / Alternative / Contrast / Link / disabled | Gunmetal.600 / Shark.500 / Gunmetal.500 / Chartreuse.400 / Gunmetal.100 / Gunmetal.500 / Shark.200 |
| Borders strong / neutral / disabled / alternative / focus | Gunmetal.500 / Shark.200 / Shark.100 / Chartreuse.400 / Frozen ribbon.Blue Ribbon.500 |
| Transparency primary / complementary / light / dark / shadow | Gunmetal.opacity / Chartreuse.opacity / Shark.opacity-light / Shark.opacity-dark / Gunmetal.opacity |
| Fixed on-accent / on-dark | Shark.950 / Shark.0 |
| Font-family Headings / Body / Alternative text / Code | DM-Sans / Inter / Inter / JetBrains Mono |

The Figma kit defines every key above except `Complementary.deep`,
`Backgrounds.atmosphere`, `Borders.focus`, `Transparency.shadow` and `Fixed`. Those are
additions the code needs (focus rings, fine detail, shadows, theme-invariant colors), so
keep them when syncing with a newer kit.

The default dark overrides move surfaces to the Shark 700–950 ramp
(`Backgrounds.principal` → Shark.950, `Backgrounds.contrast` → Shark.0), invert
foregrounds and text to Shark 0–300, use Shark 600–800 for borders, move the accent and
focus to Chartreuse.400, and darken `Transparency.shadow` to Shark.opacity-dark. Feedback
colors use the 300 step (high) and 600 step (low) of their support palette.

## 5. Component vocabulary

**Path grammar:** `{component}.{property}.{variant|size}.{state}`. Drop any segment that
doesn't apply. The kit calls the first three segments Object (component), Base
(category) and Modifier (variant). Figma Variables separate the same segments with `/`
(`button/background-color/primary/default`), and each segment becomes one nested JSON
group.

```
button.background-color.primary.hover
button.spacing.large.vertical
button.typography.small.font-size
input-field.border-color.error
card-image.text-color.contrast.title
```

| Segment | Vocabulary |
|---|---|
| component | kebab-case, named after the kit's catalog (below) |
| property | `background-color`, `text-color`, `border-color`, `outline-color`, `icon-color`, `fill-color`, `shadow-color`, `divider-color`, `spacing`, `sizing`, `border-radius`, `shadow` (children: `offset-x`, `offset-y`, `blur-radius`, `spread-radius`), `typography` (children: `font-family`, `font-weight`, `font-size`, `line-height`) |
| variant | `primary`, `secondary`, `tertiary`, `ghost-light`, `ghost-dark` (`ghost` when only one exists); surface styles `flat`, `elevation`, `edge`, `colorful`, `contrast`; feedback `discovery`, `info`, `success`, `warning`, `error`, `neutral` |
| size | `large`, `small` (add `medium` only when a third size exists) |
| state | `default`, `hover`, `active`, `focus`, `disabled`, `error` |
| spacing leaf | `horizontal`, `vertical`, `gap`, or a named gap (`button-gap`, `icon-gap`) |

Keep one vocabulary: `active`, not `actived` (the kit's Figma labels use both). A
misspelled key becomes a misspelled public variable name.

**Component catalog.** The kit follows atomic design, with tokens as quarks. Reuse these
names before inventing new ones:

| Tier | Components |
|---|---|
| Atoms | `icon-button`, `number-button`, `check-button`, typography styles, `logo`, `tag`, `badge`, `status`, `icon` (Phosphor Icons) |
| Molecules | `button`, `dropdown`, `breadcrumb`, `pagination`, `calendar`, `input-field`, `text-area`, `checkbox`, `switch`, `radio-button`, `progress-bar`, `avatar`, `avatar-group`, `tooltip`, `alert`, `icon-box`, `entry-title`, `menu-avatar`, `accordion`, `header` |
| Organisms | `button-group`, `float-tab`, `full-tab`, `select`, `card-input`, `card-image`, `card-icon`, `card-text` |
| Templates | `menu`, `nav-label`, `nav-bar`, `footer`, `sidebar`, `sidebar-item`, `dialog`, `data-table` |

A new component belongs one tier above the parts it combines: an atom is built from
quarks only, and a molecule, organism or template combines at least two different pieces
from the tier below.

**Shared typography ramp** — `Typography.Styles.<Style>.<Size>`, each with `Font-family`,
`Font-weight`, `Font-size`, `Line-height`:

| Style | Sizes | Family | Weight | Size / line-height (px) |
|---|---|---|---|---|
| Display | Large, Small | Headings | Strong | Headings.huge 80/98 · Headings.xxl 66/82 |
| Heading | Large, Small | Headings | Strong | Headings.xl 54/68 · Headings.lg 44/56 |
| Title | Large, Small | Headings | Strong | Headings.md 36/46 · Headings.sm 30/38 |
| Subtitle | Large, Small | Body | Strong | Headings.xs 24/30 · Headings.xxs 20/24 |
| Paragraph | Large, Small, Extra small | Body | `Font-weight regular` → Moderate, `Font-weight bold` → Strong | Body.md 19/27 · Body.sm 16/22 · Body.xs 13/17 |
| Label | Large, Small | Alternative text | Medium | Body.sm 16/22 · Body.xs 13/17 |
| Text button | Large, Small | Alternative text | Medium | Body.sm on Line-height Body.md 16/27 · Body.xs on Body.sm 13/22 |
| Input text | Large, Small | Alternative text | Moderate | Body.md 19/27 · Body.sm 16/22 |

`Typography.Colors` holds Headings, Paragraph, Label and Link.

**App namespace.** Page-level roles that belong to no reusable component live under one
app namespace. The seed calls it `Site`: `colors.*` (background, surface,
surface-secondary, text, text-muted, border, accent, accent-text, on-accent),
`typography.font-family.*` (headings, body, code), `focus-ring.*`, `Page-layout.*`. Add
page sections as `Site.<Section>.<property>`.

```json
{
  "button": {
    "background-color": {
      "primary": {
        "default":  { "$type": "color", "$value": "{system.Colors.Complementary.principal}" },
        "active":   { "$type": "color", "$value": "{system.Colors.Complementary.high}" },
        "disabled": { "$type": "color", "$value": "{system.Colors.Complementary.off}" }
      }
    },
    "sizing": {
      "small": {
        "min-height": {
          "$type": "number",
          "$value": 36,
          "$description": "Tap-target floor for the small button; falls between Sizing md (32) and ml (48)."
        }
      }
    }
  }
}
```

## 6. Theming and re-theming

- **Light is the base.** `system-light.json` defines every system token.
- **Dark overrides colors only.** `system-dark.json` holds only `Colors.*` tokens, every key
  already exists in light, and values reference global tokens.
- **Components are theme-independent.** They alias system tokens and switch automatically.
  Never create `button.dark.*` or per-theme component tokens.
- **Theme-invariant colors are explicit.** A color that must not change (dark text on a
  yellow accent) goes in `Colors.Fixed` with the **same value in both files**. Never rely
  on a token being undefined.
- **Fallback scope.** The bundled build emits light colors under
  `:root, [data-theme="light"]` and dark overrides under `[data-theme="dark"]`, so a color
  missing from the dark file inherits its light value. A generator that emits light colors
  only under `[data-theme="light"]` needs a complete dark file.
- **Selection order:** persisted user choice → OS preference → light, applied on the root
  before first paint.

**Re-theming** repoints system color references at another schema; component tokens stay
untouched:

```json
"Primary": {
  "principal": { "$type": "color", "$value": "{global.Colors.Schemas.Mint blue.Prussian blue.600}" },
  "subtle":    { "$type": "color", "$value": "{global.Colors.Schemas.Mint blue.Prussian blue.500}" },
  "off":       { "$type": "color", "$value": "{global.Colors.Schemas.Mint blue.Prussian blue.100}" },
  "high":      { "$type": "color", "$value": "{global.Colors.Schemas.Mint blue.Prussian blue.600}" }
}
```

A brand palette that doesn't exist yet goes into global first, as `100`–`600` plus
`opacity`. Fill `Colors.Custom.Principal palette` (repoint `Primary`,
`Backgrounds.contrast`, `Borders.strong`) and `Colors.Custom.Complementary palette`
(repoint `Complementary`), or add `Colors.Custom.<Brand>`. A further theme, such as
high-contrast, is one more override file (`system-<theme>.json`) with the same rules and
its own scope.

**Type scale change:** pick `Base` and `Scale`, compute `round(Base × Scale^n)`, add any
missing values to `global › Typography.Steps`, then repoint `system ›
Typography.font-size.*` and `Line-height.*`. Line heights run about 1.2–1.3× the size for
headings and 1.3–1.7× for body.

## 7. Audit checks

What `scripts/quantum-tokens.mjs audit` reports:

| Check | Severity | Detects |
|---|---|---|
| `format` | error | Non-slim DTCG (`$extensions`, unknown `$` keys), bad `$type`, units in a `number`, malformed hex, `.{}` in keys, non-color tokens in the dark file |
| `broken-reference` | error | A reference target that doesn't exist (light space, and dark space for dark overrides); a dark override with no light counterpart; cycles |
| `missing-token` | error | UI code referencing a token name that no JSON file defines |
| `bad-usage` | warning | UI code referencing `system-tokens` or `global-tokens` directly |
| `raw-value` | warning | A raw color in system or component tokens; a raw non-color without `$description`; a level skip or same-level chain; a reference inside global |
| `hardcoded` | warning | Literal colors in UI code, and literal lengths/weights/families on spacing, radius, `box-shadow` and type properties |
| `duplicate` | info | System or component tokens of one type with identical resolved values |
| `unused` | info | Globals no system token references; system tokens no component token references; component tokens no UI code uses |
| `dark-coverage` | info | Light system colors with no dark override |

## 8. Layout grids

The kit's page grids. They aren't seeded as tokens. When a project adopts one, add its
values under the app namespace (`Site.Page-layout.*`): reference `Sizing.container`
(1140) and Spacing steps where they match, and use raw numbers with a `$description`
for off-scale widths (1320, 716, 312).

| Grid | Viewport | Columns | Gutter | Margin | Container |
|---|---|---|---|---|---|
| Fixed XL | ≥ 1440 | 12 | 16 | auto (centered) | 1320 |
| Fixed LG | ≥ 1200 | 12 | 16 | auto (centered) | 1140 |
| Fixed MD | ≥ 992 | 8 | 12 | auto (centered) | 716 |
| Fixed SM | mobile | 4 | 8 | 24 at 360 wide | 312 |
| Fluid container | any | 12 | 16 | 32 | stretch |
| Fluid side menu | dashboards | menu 20–25% · content 75–80% | 48 | 32 | stretch |

Fixed SM is labeled "8 columns / gutter 12" in the kit, but its drawing has 4 columns and
8px gutters, which is what fits 312px. Use the drawing.
