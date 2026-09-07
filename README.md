# Build macOS ICNS

A Codex skill for converting square SVG or PNG artwork into a verified macOS `.icns` icon and a matching 1024×1024 PNG.

It uses macOS `sips` and `iconutil`, applies an 81 px Dock-safe inset, produces the common 32, 128, 512 and 1024 pixel layers, and reverse-validates the compiled ICNS.

## Install

Copy this repository directory into your local Codex skills directory:

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/simoplums-byte/build-macos-icns.git ~/.codex/skills/build-macos-icns
```

Restart Codex or start a new task after installation.

## Use

Provide a square SVG or PNG with transparency. In Codex, invoke:

```text
Use $build-macos-icns to convert <your-icon.svg> into a validated macOS ICNS file.
```

The final artifacts are written to:

```text
<project-root>/icns-output/<case-name>/<case-name>-final.icns
<project-root>/icns-output/<case-name>/<case-name>-final.png
```

## Requirements

- macOS, including `sips` and `iconutil`
- Python 3 with Pillow

The bundled `scripts/build_icns.sh` can also be run directly:

```bash
ICNS_PYTHON=/path/to/python-with-pillow \
  scripts/build_icns.sh INPUT.svg OUTPUT.icns
```

## License

MIT
