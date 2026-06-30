# Color Swatch

A simple, stable color memory for game creators. Save the colors you like or
dislike, share your library with other creators, and generate (and keep) solid
60/30/10 swatch sets.

**Standalone — no other add-on required.** Four files, no dependencies.

## Install

1. **Download** the zip and **unzip** it. Inside you'll find a folder named
   `addons`.
2. **Drop that `addons` folder into your Godot project folder** — the folder
   that has your `project.godot` file in it. If your project already has an
   `addons` folder, just merge them (say yes if asked; it won't disturb your
   other add-ons).
3. **Open the project in Godot.**
4. Go to **Project → Project Settings → Plugins** and switch **Color Swatch**
   to **On**.

That's it — the Color Swatch panel appears on the right side of the editor.

Works the same on a brand-new project or one you've already got going. If
you've used Color Swatch before, your saved colors come back on their own.

## Use it

- **Add:** pick a color or type a hex, optional name, then hit **Like** or
  **Dislike** — it lands in that list straight away. (Neutral is a low-key "meh"
  bucket you can move colors into if you want.)
- **Sort / fix:** each color has buttons to move it between lists, plus Copy and
  Delete. Click a name to rename it.
- **Share:** *Copy Library* copies a readable list grouped under LIKED /
  DISLIKED / NEUTRAL, so it's legible when pasted into chat. Another creator
  hits *Paste & Merge* to fold your colors into theirs (duplicates skipped).
- **Generate 60/30/10:** builds from your **Liked** colors — a calm dominant, a
  middle secondary, and a punchy accent, each with a shadow/base/light family.
  - **Name it + Save** to keep it. Saved palettes stick around under *Saved
    Palettes*, each with Copy and Delete.
  - **Copy as Text** copies a labeled version — a Discord paste still says which
    hex is the dominant base, the accent shadow, etc.

Everything saves automatically to a `color_swatch_library.json` file in your
project.

## Versioning

Packages ship as `color_swatch_vX.Y.Z.zip`, matching `plugin.cfg`.
This is **v2.3.1**.

Godot 4.x · GabagoolStudios
