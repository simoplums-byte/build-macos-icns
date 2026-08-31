---
name: build-macos-icns
description: Convert SVG or PNG artwork into compact macOS .icns and matching 1024×1024 PNG application icons using the common 32, 128, 512, and 1024 pixel layers, including square-source, transparency, compilation, reverse-unpack checks, and clean final-output delivery. Use when Codex needs to create, rebuild, inspect, or diagnose a macOS ICNS from SVG or PNG source artwork while delivering final ICNS and PNG files.
---

# Build macOS ICNS

Create a verified `.icns` from SVG or PNG artwork on macOS.

## Workflow

1. Confirm the host is macOS and that `sips` and `iconutil` are available.
2. Inspect the source before conversion:
   - Require SVG or PNG input.
   - Require a square canvas; do not stretch non-square artwork.
   - Prefer at least 1024×1024 source artwork. Allow the script to upscale smaller square inputs automatically, while warning that upscaling cannot restore detail.
   - For SVG, reject external `<image href="...">` or `<image xlink:href="...">` references unless they are embedded `data:` URLs. Ask the user to flatten or inline them. Be aware that `sips` SVG support varies by macOS release; if rendering fails, request a 1024×1024 transparent PNG export.
   - Preserve real transparency outside the icon shape; do not simulate it with a white canvas.
   - Apply the macOS safe area: center the normalized artwork on a transparent 1024×1024 canvas with an 81 px inset on every side (862×862 content area). This matches the supplied reference icon's visible footprint in the Dock.
3. In Codex, load the bundled workspace dependencies and use its Pillow-enabled Python path as `ICNS_PYTHON`. Then run the converter with system approval on the first attempt because sandboxed `iconutil` can incorrectly report `Invalid Iconset`:

   ```bash
   ICNS_PYTHON=PATH_TO_BUNDLED_PYTHON scripts/build_icns.sh INPUT_FILE [OUTPUT.icns]
   ```

   For project work, always pass an explicit output path following the layout below. If the output argument is omitted, write `<input-basename>-final.icns` beside the input.
4. Review the converter's checks. Do not claim success if Alpha, dimensions, `iconutil`, or reverse unpack validation fails.
5. Treat `hasAlpha: yes` only as evidence that an Alpha channel exists. Also require genuinely transparent pixels outside rounded artwork. Heed the script's opaque-corner warning and visually inspect the four corners.
6. Visually inspect 32×32, 128×128, and 1024×1024 when appearance matters. Pay special attention to thin strokes and dense detail at small sizes.
7. Enforce the output requirements below, then return the absolute output path and summarize any visual limitations.

## Output requirements

- Use exactly one project-root output directory: `<project-root>/icns-output/`.
- Create one lowercase, hyphenated case subdirectory per conversion: `<project-root>/icns-output/<case-name>/`.
- Write the final files as `<project-root>/icns-output/<case-name>/<case-name>-final.icns` and `<project-root>/icns-output/<case-name>/<case-name>-final.png`.
- Deliver exactly two final usable files: matching `.icns` and 1024×1024 `.png` files, each named descriptively and ending in `-final`.
- Keep normalized PNG files, generated iconsets, reverse-unpack directories, test ICNS candidates, and validation artifacts in temporary storage only.
- Remove temporary artifacts created by the current task after validation succeeds.
- Do not create additional root-level `*-icns-output` directories. Do not delete or overwrite unrelated files that existed before the task.
- Confirm the case subdirectory contains no task-created files other than the final `.icns` and `.png` before reporting completion.

## Script behavior

The script creates only four common physical sizes in a temporary iconset:

```text
icon_16x16@2x.png
icon_128x128.png
icon_256x256@2x.png
icon_512x512@2x.png
```

These filenames represent 32, 128, 512, and 1024 physical pixels. The script normalizes the source, applies the 81 px macOS safe area with the bundled Pillow helper, copies that validated 1024×1024 master PNG to the final output, compiles the temporary layers with `iconutil`, reverse-unpacks the result, verifies them, and then removes all temporary artifacts. Return the matching final `.icns` and `.png` files.

## Troubleshooting

- Use the `.icns` extension, never `.icons`.
- Do not use `qlmanage` for SVG conversion; it can introduce a white background.
- If SVG conversion displays a red cross or missing artwork, inline external images or flatten the SVG to paths first.
- If the input is non-square, pad the canvas transparently in an image editor or regenerate the source; never force-resize it.
- If the script warns that all corners are opaque, the output will be a square even when the PNG technically has an Alpha channel. Add a transparent rounded-rectangle or squircle mask before converting.
- If Finder or Dock shows an old icon after replacement, reinstall the app or restart Finder/Dock to refresh macOS caches.
