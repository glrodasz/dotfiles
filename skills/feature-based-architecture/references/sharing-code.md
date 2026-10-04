# Sharing code between features

Load this when a second feature needs code that lives in the first, or when deciding whether to extract something into `features/common/`, `utils/`, or the design system.

Default to keeping code local. Extraction is a decision, not a reflex.

```text
feature-specific → a second feature needs it → evaluate → promote only if truly generic
```

When a second feature needs something, evaluate before moving it:

1. Does it contain domain-specific terminology?
2. Does it accept domain-specific objects?
3. Does it encode business rules?
4. Would another feature understand it without knowing the original feature?
5. Can it be expressed without importing feature-specific code?

Then choose one outcome:

- **Still domain-specific (yes to 1–3):** leave it in the owning feature. The consumer
  imports it from the owner. A visible dependency between two features is honest; a domain
  helper relocated to `utils/` hides the same dependency.
- **A shared domain concept has emerged:** create a properly named domain feature for it,
  not a generic folder.
- **Shared app-level React code (layouts, dialogs, generic hooks):** promote to
  `features/common/`.
- **Truly generic (yes to 4–5, no to 1–3):** promote to `utils/`, an infrastructure
  folder, or the design-system package. Strip any domain naming as you move it.

**Prefer duplication over a wrong abstraction.** Two similar functions in two features can
evolve independently. One shared function coupled to both forces every future change to
consider both. But do not duplicate the *same* function verbatim in two places inside one
feature (e.g. a hook and a component helper that both persist the color scheme): that is a
missed import, not independence.

Reject this reasoning: "This could theoretically be useful elsewhere, so put it in utils."
Hypothetical reuse is not a reason to extract.
