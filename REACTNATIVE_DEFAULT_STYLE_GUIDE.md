# ReactNative Default Style Guide

## Description

Use this style guide as the default architecture and file-organization guide for React Native and Expo apps unless a project-specific guide overrides it.

## Exports and imports

- Do not use barrel files (`index.ts`, `index.tsx`, or aggregate re-export files) unless the framework explicitly requires them.
- Do not use default exports unless the framework explicitly requires them, such as Expo Router route modules in `app/`.
- Keep one public export per file. If a screen needs exported constants, metadata, fixtures, or helpers, move each public export into its own file.
- Prefer direct imports from the file that owns the export instead of importing through folders.

## Routing and screens

- Keep `app/` files limited to route/screen shells and framework-required `_layout` files only.
- Route/screen shells should contain framework-required route wiring and delegate rendering to a screen module.
- Create screen implementations outside `app/`, in a `screens/` folder.
- Route shell example: `app/(tabs)/profile.tsx` imports and renders `ProfileScreen` from `screens/profile/ProfileScreen.tsx`.
- If the framework requires a default export for a route shell, limit the default export to that shell file.

## Component, hook, and logic placement

- If a component is reusable, put it in `core/components/`.
- If a hook is reusable, put it in `core/hooks/`.
- If non-UI logic is reusable, put it in `core/logic/`.
- If a component is custom to one screen, put it next to that screen in its local `components/` folder.
- If a hook is custom to one screen, put it next to that screen in its local `hooks/` folder.
- If logic is custom to one screen, put it next to that screen in its local `logic/` folder.
- Do not promote components, hooks, or logic to `core/` until they are genuinely reused or intentionally part of the shared app foundation.

## Atomic component tiers

Organize components by atomic design tier:

```text
core/components/
  atoms/
  molecules/
  organisms/
core/hooks/
core/logic/

screens/<screen-name>/
  <ScreenName>Screen.tsx
  components/
    atoms/
    molecules/
    organisms/
  hooks/
  logic/
```

- Atoms: smallest UI building blocks, such as text labels, icon buttons, badges, and spacers.
- Molecules: small composed UI groups, such as list rows, form fields, and setting items.
- Organisms: larger sections made from atoms and molecules, such as profile headers, settings sections, and screen hero panels.

## Naming

- Name screens `<FeatureName>Screen.tsx`.
- Name components by what they render, not by where they appear.
- Keep folder names feature-oriented for screens and tier-oriented for component libraries.
