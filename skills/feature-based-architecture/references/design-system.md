# Design system: atomic design and design tokens

Load this when creating or styling a component, or deciding whether a component belongs in
the app or in the design system.

**Depends on the `quantum-design-tokens` skill.** Tokens, their naming, the token build,
theming and dark mode follow that skill; load it whenever a visual value (color, spacing,
radius, font size, shadow) or a theme is involved. This file covers only where components
live and how they consume tokens.

Reference implementation: `@glrodasz/components` (repo `cero-components`) consumed by
`cero-web`. Examples below write `<design-system-package>`; use the project's own package
name.

## Contents

- [Two packages, one hierarchy](#two-packages-one-hierarchy)
- [Where a component goes](#where-a-component-goes)
- [Component anatomy in the design system](#component-anatomy-in-the-design-system)
- [Design tokens](#design-tokens)
- [Styling rules](#styling-rules)
- [Testing](#testing)

## Two packages, one hierarchy

Atomic design is split across two codebases. The design system owns the generic levels;
the app owns the levels that know the domain.

| Atomic level | Lives in | Example | Knows the domain? |
|---|---|---|---|
| Tokens | design system `tokens/*.json` → generated CSS (see `quantum-design-tokens`) | `--components-tokens--card-image--border-radius--default` | No |
| Atoms | design system `atoms/` | `Button`, `Input`, `Card`, `Heading`, `Icon`, `Modal` | No |
| Molecules | design system `molecules/` | `AddButton`, `IconLabel`, `Accordion`, `LoadingError` | No |
| Layout primitives | design system `layout/` | `Spacer`, `Container`, `CenteredContent`, `FullHeightContent` | No |
| Organisms | app `features/<f>/components/` | `Board`, `Column`, `Chronometer`, `DeleteTaskModal` | Yes |
| Templates | app `features/common/components/` | `MainLayout`, `NavigationMenu`, `UserHeader` | App-level only |
| Pages | app `features/<f>/containers/` + `pages/` | `Planning` container rendered by `pages/planning.js` | Yes |

Definitions used by the design system:

- **Atom** — a component made of a single atom with or without HTML tags, or just HTML
  tags.
- **Molecule** — a component made of at least two different atoms.
- **Layout** — a component whose only job is spacing, alignment, or sizing of its
  children.

A component that renders one element with variants (a `Badge`, a `Divider`) is an atom. It
becomes a molecule only when it composes two or more different atoms (`IconLabel` =
`Icon` + `Paragraph`).

A molecule that happens to carry a domain-sounding name (`Task`, `TaskCounter`) is still a
design-system molecule as long as it takes plain props (strings, numbers, callbacks) and
no domain objects or business rules. The moment it needs a `Task` object, a status
constant, or a limit from config, it is an organism and belongs in the app.

## Where a component goes

Ask in order; stop at the first yes.

1. **Does it take domain objects, call data hooks, or encode a business rule?** → app,
   `features/<f>/components/` (or `containers/` if it wires hooks and handlers).
2. **Is it an app-level layout or chrome shared by several features?** → app,
   `features/common/components/`.
3. **Is it generic UI that any product could use?** → design system, as an atom, molecule,
   or layout primitive.

Rules:

- **Do not build atoms or molecules inside the app.** If the app needs a new primitive (a
  `Badge`, a `Tooltip`), add it to the design system, release it, and bump the dependency.
  If the app can't wait for a release, put a temporary copy in
  `features/common/components/<Name>/` with the same API, add a
  `// TODO: replace with <design-system-package> <Name> (<issue link>)` at the top, and
  delete it in the PR that bumps the package.
- **Do not fork a design-system component to tweak it.** Add a prop/option to the
  original, or override a component token.
- **Compose, don't restyle.** App components arrange design-system primitives with layout
  primitives (`Spacer.Vertical`, `Container`). Their own CSS should be layout, not
  look-and-feel.
- Import primitives by name from the package root:
  `import { Card, Paragraph, Spacer } from '<design-system-package>'`. Never deep-import
  package internals.
- Promotion from app to design system follows the same five questions as any promotion in
  `SKILL.md`; additionally strip every domain word from the name and props on the way.

## Component anatomy in the design system

Scaffold new components with the package's generator (`yarn cc`) when available; it copies
`templates/component/`. Each component is a folder:

```text
atoms/Button/
├── Button.js            component + propTypes + defaultProps, default export wrapped with withStyles
├── Button.module.css    styles, component tokens only
├── Button.stories.js    Storybook: title 'Atoms/Button', one story per option
├── Button.test.jsx      snapshot + behavior
├── constants.js         export const options = { types: ['primary', 'secondary', 'tertiary'] }
├── __snapshots__/
└── index.js             export { default, Button } from './Button'; export { options }; export { default as styles }
```

Conventions:

- **Variants are data.** Allowed values live in `constants.js` as `options`; `propTypes`
  use `PropTypes.oneOf(options.types)`; stories iterate over the same list. Never inline
  the variant list in three places.
- **Class names follow prop names.** `withStyles(styles)` injects `getStyles`;
  `getStyles('button', ['type'], { 'is-inline': isInline })` produces
  `.button .type-primary .is-inline`. Modifier classes are `<prop>-<value>`; boolean state
  classes are `is-<state>`.
- **Event handlers are factories** (`createHandlerClick({ onClick })`) in a shared
  `handlers/` folder — the same pattern the app uses in `handlers.js`.
- Export both the wrapped default and the named raw component, so tests and stories can
  use either.

## Design tokens

Tokens follow the `quantum-design-tokens` skill: Global → System → Component levels in
DTCG JSON, a generated CSS file, and UI code that uses component tokens only
(`--components-tokens--<component>--<property>--<variant>--<state>`). Load that skill for
naming, adding a value, the build, theming and dark mode. Don't restate its rules here.

What this architecture adds:

- **The token source lives in the design-system package**, next to the components that
  consume it. The app imports the package's generated CSS once, first, and never edits it.
- **Each design-system component owns its component tokens**
  (`components.json › button`), added in the same change as the component.
- **App-only roles** that the design system will never need (e.g. a bottom-menu height)
  go under the app namespace that `quantum-design-tokens` defines. Use them sparingly;
  anything reusable belongs upstream.
- **Themes stay in the token source**, as system-level overrides. App components never
  branch on the theme.

## Styling rules

- Follow the project's styling technology. In the design system: CSS Modules +
  `withStyles`. In the app: styled-jsx for component-scoped layout, CSS Modules where
  already used. Do not introduce a third approach.
- Every value is a component token (`var(--components-tokens--…)`). Inline `style={{}}`
  is only acceptable for values computed at runtime (a progress width); never for static
  colors or spacing.
- Spacing between primitives comes from layout primitives (`Spacer`) or spacing tokens,
  not ad-hoc margins.
- Use `classnames` for conditional classes in the app (add it as a direct dependency if
  you use it; don't rely on a transitive install).
- `styles/` in the app holds globals and token overrides only — no component styles.
- Stylelint: recommended config + idiomatic property order. Make sure the lint glob covers
  every style extension the project uses (`.css` and `.scss`).

## Testing

- Design system: co-located `Component.test.jsx` with snapshot + behavior; every option in
  `constants.js` has a story.
- App: mock the design-system package so tests stay about the app's composition:

```js
jest.mock('<design-system-package>', () => {
  const { dummyRender } = require('../../../utils/testUtils/dummyRender')
  return {
    Spacer: { Vertical: dummyRender('Spacer.Vertical') },
    AddButton: dummyRender('AddButton'),
  }
})
```

- Transpile the package in the app's test runner if it ships untranspiled source
  (`transformIgnorePatterns: ['node_modules/(?!<design-system-package>)']`).
