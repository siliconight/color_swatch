# Color Swatch

A simple, stable color memory for game creators. Save the colors you like or
dislike, share your library with other creators, and generate (and keep) solid
60/30/10 swatch sets.

**Standalone — no other add-on required.** Four files, no dependencies.

## Install (Windows, one toggle)

1. Delete any old `addons/color_swatch/` in your project, then extract this so
   you get a clean `res://addons/color_swatch/`.
2. Open the project in Godot 4.
3. Project → Project Settings → Plugins → enable **Color Swatch**.
4. The dock appears on the right.

Your old `color_swatch_library.json` still loads — it's upgraded in place the
first time you make a change.

## Use it

- **Add:** pick a color or type a hex, optional name, then hit **Like** or
  **Dislike** — it lands in that list straight away. (Neutral still exists as a
  low-key "meh" bucket you can move colors into.)
- **Sort / fix:** each color has buttons to move it between lists, plus Copy and
  Delete. Click a name to rename it.
- **Share:** *Copy Library* copies a readable, section-grouped block — colors
  listed under LIKED / DISLIKED / NEUTRAL headers, one `#HEX  Name` per line —
  so it's legible when pasted into chat. Another creator hits *Paste & Merge* to
  fold in your colors (duplicates skipped). Legacy JSON and the raw
  `color_swatch_library.json` file still import too.
- **Generate 60/30/10:** builds from your **Liked** colors (never disliked) — a
  calm dominant, a middle secondary, and a punchy accent, each with a
  shadow/base/light family.
  - **Name it + Save** to keep it. Saved palettes persist under *Saved Palettes*,
    each with Copy and Delete.
  - **Copy as Text** copies a labeled version — so a Discord paste still says
    which hex is the dominant base, the accent shadow, etc.

Everything auto-saves to `res://color_swatch_library.json`
(`{ colors, palettes }`).

## Versioning

Packages ship as `color_swatch_vMAJOR.MINOR.PATCH.zip`; the same number is in
`plugin.cfg`. This is **v2.3.0**.

Godot 4.x · GabagoolStudios
