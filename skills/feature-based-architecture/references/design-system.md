# Design system: atomic design and design tokens

Load this when creating or styling a component, adding a visual value (color, spacing, radius, font size, shadow), theming, or deciding whether a component belongs in the app or in the design system.

Reference implementation: `@glrodasz/components` (repo `cero-components`) consumed by `cero-web`.

## Contents

- [Two packages, one hierarchy](#two-packages-one-hierarchy)
- [Where a component goes](#where-a-component-goes)
- [Component anatomy in the design system](#component-anatomy-in-the-design-system)
- [Design tokens](#design-tokens)
- [Styling rules](#styling-rules)
- [Theming](#theming)
- [Testing](#testing)

## Two packages, one hierarchy

Atomic design is split across two codebases. The design system owns the generic levels; the app owns the levels that know the domain.

| Atomic level | Lives in | Example | Knows the domain? |
|---|---|---|---|
| Tokens | design system `tokens/` → `styles/tokens.css` | `--color-primary`, `--card-border-radius` | No |
| Atoms | design system `atoms/` | `Button`, `Input`, `Card`, `Heading`, `Icon`, `Modal` | No |
| Molecules | design system `molecules/` | `AddButton`, `IconLabel`, `Accordion`, `LoadingError` | No |
| Layout primitives | design system `layout/` | `Spacer`, `Container`, `CenteredContent`, `FullHeightContent` | No |
| Organisms | app `features/<f>/components/` | `Board`, `Column`, `Chronometer`, `DeleteTaskModal` | Yes |
| Templates | app `features/common/components/` | `MainLayout`, `NavigationMenu`, `UserHeader` | App-level only |
| Pages | app `features/<f>/containers/` + `pages/` | `Planning` container rendered by `pages/planning.js` | Yes |

Definitions used by the design system:

- **Atom** — a component made of a single atom with or without HTML tags, or just HTML tags.
- **Molecule** — a component made of at least two different atoms.
- **Layout** — a component whose only job is spacing, alignment, or sizing of its children.

A component that renders one element with variants (a `Badge`, a `Divider`) is an atom. It becomes a molecule only when it composes two or more different atoms (`IconLabel` = `Icon` + `Paragraph`).

A molecule that happens to carry a domain-sounding name (`Task`, `TaskCounter`) is still a design-system molecule as long as it takes plain props (strings, numbers, callbacks) and no domain objects or business rules. The moment it needs a `Task` object, a status constant, or a limit from config, it is an organism and belongs in the app.

## Where a component goes

Ask in order; stop at the first yes.

1. **Does it take domain objects, call data hooks, or encode a business rule?** → app, `features/<f>/components/` (or `containers/` if it wires hooks and handlers).
2. **Is it an app-level layout or chrome shared by several features?** → app, `features/common/components/`.
3. **Is it generic UI that any product could use?** → design system, as an atom, molecule, or layout primitive.

Rules:

- **Do not build atoms or molecules inside the app.** If the app needs a new primitive (a `Badge`, a `Tooltip`), add it to the design system, release it, and bump the dependency. If the app can't wait for a release, put a temporary copy in `features/common/components/<Name>/` with the same API, add a `// TODO: replace with @glrodasz/components <Name> (<issue link>)` at the top, and delete it in the PR that bumps the package.
- **Do not fork a design-system component to tweak it.** Add a prop/option to the original, or override a component token.
- **Compose, don't restyle.** App components arrange design-system primitives with layout primitives (`Spacer.Vertical`, `Container`). Their own CSS should be layout, not look-and-feel.
- Import primitives by name from the package root: `import { Card, Paragraph, Spacer } from '@glrodasz/components'`. Never deep-import package internals.
- Promotion from app to design system follows the same five questions as any promotion in `SKILL.md`; additionally strip every domain word from the name and props on the way.

## Component anatomy in the design system

Scaffold new components with the package's generator (`yarn cc`) when available; it copies `templates/component/`. Each component is a folder:

```text
atoms/Button/
├── Button.js            component + propTypes + defaultProps, default export wrapped with withStyles
├── Button.module.css    styles, tokens only
├── Button.stories.js    Storybook: title 'Atoms/Button', one story per option
├── Button.test.jsx      snapshot + behavior
├── constants.js         export const options = { types: ['primary', 'secondary', 'tertiary'] }
├── __snapshots__/
└── index.js             export { default, Button } from './Button'; export { options }; export { default as styles }
```

Conventions:

- **Variants are data.** Allowed values live in `constants.js` as `options`; `propTypes` use `PropTypes.oneOf(options.types)`; stories iterate over the same list. Never inline the variant list in three places.
- **Class names follow prop names.** `withStyles(styles)` injects `getStyles`; `getStyles('button', ['type'], { 'is-inline': isInline })` produces `.button .type-primary .is-inline`. Modifier classes are `<prop>-<value>`; boolean state classes are `is-<state>`.
- **Event handlers are factories** (`createHandlerClick({ onClick })`) in a shared `handlers/` folder — the same pattern the app uses in `handlers.js`.
- Export both the wrapped default and the named raw component, so tests and stories can use either.

## Design tokens

Tokens are the only source of visual values. They come in layers; each layer only references the one below it.

| Layer | Also called | Defined in | Naming | Examples |
|---|---|---|---|---|
| 1. Choices | global / primitive / palette | `tokens/index.js` → `choices` | `--<category>-<scale>` | `--color-brand-medium-purple`, `--color-amber-600`, `--border-radius-sm`, `--font-size-md`, `--box-shadow-xs`, `--z-index-10` |
| 2. Decisions — semantic | system / alias | `tokens/index.js` → `decisions` | `--color-<role>[-<variant>]`, `--background-color-<role>` | `--color-primary`, `--color-primary-muted`, `--color-font-base`, `--background-color-primary` |
| 3. Decisions — component | component | `tokens/index.js` → `decisions.<component>` | `--<component>-<property>[-<variant>]` | `--button-border-radius-lg`, `--input-height`, `--card-border-radius`, `--stopwatch-color` |

Tokens are authored as JS objects (camelCase) and compiled to CSS custom properties (kebab-case) by `scripts/build-tokens.js` into `styles/tokens.css`. Never hand-edit the generated CSS.

Rules:

- **Components consume layers 2 and 3, not layer 1.** `Button.module.css` uses `var(--color-primary)` and `var(--button-border-radius-lg)`, not `var(--color-brand-medium-purple)`. A raw palette value in a component means a semantic token is missing — add it.
- **Add a component token when a value must be themeable per component** (dark mode wants square cards → `--card-border-radius`). Otherwise reuse a semantic or scale token.
- **Palette naming (layer 1):** brand colors by name under `color.brand` (`--color-brand-medium-purple`); every other hue as a numeric scale 50–900 (`--color-orange-500`). A new hex first goes in as the closest scale step or a new brand entry; then a semantic role points at it (`--color-warning: var(--color-orange-500)`).
- **Variant suffixes:** `-muted`, `-highlight`, `-inverted` for color roles; `-xs … -lg` for sizes; `-desktop` (or another breakpoint name) for responsive overrides.
- **No magic numbers.** A literal `px`, hex, or `rgba()` in component CSS is a missing token. Exceptions: `0`, `100%`, `auto`, `max-content`, and one-off structural values with a comment.
- **App-specific tokens** that the design system will never need (e.g. `--bottom-menu-height`) live in the app's `styles/globals.scss` under `:root`, named like component tokens. Use them sparingly; anything reusable belongs upstream.

## Styling rules

- Follow the project's styling technology. In the design system: CSS Modules + `withStyles`. In the app: styled-jsx for component-scoped layout, CSS Modules where already used. Do not introduce a third approach.
- Every value is a `var(--token)`. Inline `style={{}}` is only acceptable for values computed at runtime (a progress width); never for static colors or spacing.
- Spacing between primitives comes from layout primitives (`Spacer`) or spacing tokens, not ad-hoc margins.
- Use `classnames` for conditional classes in the app (add it as a direct dependency if you use it; don't rely on a transitive install).
- `styles/` in the app holds globals and token overrides only — no component styles.
- Stylelint: recommended config + idiomatic property order. Make sure the lint glob covers every style extension the project uses (`.css` and `.scss`).

## Theming

Theming means re-pointing layer-2 and layer-3 tokens; layer 1 never changes and components never change.

```scss
@mixin dark-color-scheme {
  --color-primary: var(--color-amber-600);
  --background-color-primary: var(--color-cool-gray-900);
  --card-border-radius: var(--border-radius-xs);
}

@media (prefers-color-scheme: dark) {
  :root:not([data-color-scheme='light']) { @include dark-color-scheme; }
}
:root[data-color-scheme='dark'] { @include dark-color-scheme; }
```

- Themes live in the **app** (`styles/globals.scss`), because they are product decisions; the design system ships the default (light) values. Move a theme upstream only if several products need the same one.
- "Square" or "none" values still use the scale (`var(--border-radius-none)`), not a literal `0`.
- System preference applies unless the user chose explicitly; the explicit choice is `html[data-color-scheme]`, persisted by one hook (`useColorScheme`). Keep the persistence logic in one place.
- Override values point at layer-1 tokens (`var(--color-amber-600)`), not at raw hex.
- If a theme needs to change something no token controls, add the token to the design system first.

## Testing

- Design system: co-located `Component.test.jsx` with snapshot + behavior; every option in `constants.js` has a story.
- App: mock the design-system package so tests stay about the app's composition:

```js
jest.mock('@glrodasz/components', () => {
  const { dummyRender } = require('../../../utils/testUtils/dummyRender')
  return {
    Spacer: { Vertical: dummyRender('Spacer.Vertical') },
    AddButton: dummyRender('AddButton'),
  }
})
```

- Transpile the package in the app's test runner if it ships untranspiled source (`transformIgnorePatterns: ['node_modules/(?!@glrodasz/components)']`).
