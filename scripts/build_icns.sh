#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") INPUT.svg|INPUT.png [OUTPUT.icns]" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage

input=$1
[[ -f "$input" ]] || { echo "Error: input file not found: $input" >&2; exit 1; }
command -v sips >/dev/null || { echo "Error: sips is required (macOS only)." >&2; exit 1; }
command -v iconutil >/dev/null || { echo "Error: iconutil is required (macOS only)." >&2; exit 1; }
python_bin=${ICNS_PYTHON:-python3}
command -v "$python_bin" >/dev/null || { echo "Error: Python is required to apply the macOS icon safe area." >&2; exit 1; }
"$python_bin" -c 'from PIL import Image' >/dev/null 2>&1 || {
  echo "Error: the selected Python needs Pillow. Set ICNS_PYTHON to a Python runtime with Pillow." >&2
  exit 1
}

script_dir=$(cd "$(dirname "$0")" && pwd)
input_abs=$(cd "$(dirname "$input")" && pwd)/$(basename "$input")
stem=$(basename "$input_abs")
stem=${stem%.*}
output=${2:-"$(dirname "$input_abs")/$stem-final.icns"}
output_dir=$(dirname "$output")
mkdir -p "$output_dir"
output_abs=$(cd "$output_dir" && pwd)/$(basename "$output")
[[ "$output_abs" == *.icns ]] || { echo "Error: output must use the .icns extension." >&2; exit 1; }

ext=${input_abs##*.}
ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
[[ "$ext" == svg || "$ext" == png ]] || { echo "Error: input must be SVG or PNG." >&2; exit 1; }

if [[ "$ext" == svg ]] && grep -Eiq "<image[^>]+(xlink:)?href=['\"]" "$input_abs"; then
  if ! grep -Eiq "<image[^>]+(xlink:)?href=['\"]data:" "$input_abs"; then
    echo "Error: SVG contains an external <image href>. Inline or flatten the referenced artwork first." >&2
    exit 1
  fi
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/build-macos-icns.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT
base_png="$work_dir/base.png"
iconset="$work_dir/icon.iconset"
verifyset="$work_dir/verify.iconset"
compiled="$work_dir/output.icns"
final_png="$work_dir/output.png"
mkdir -p "$iconset"

if [[ "$ext" == svg ]]; then
  if ! sips -s format png "$input_abs" --out "$base_png" >/dev/null; then
    echo "Error: sips could not render this SVG. Flatten/inline its artwork or export a transparent PNG and retry." >&2
    exit 1
  fi
else
  cp "$input_abs" "$base_png"
fi

read -r width height alpha < <(
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$base_png" |
    awk '/pixelWidth:/ {w=$2} /pixelHeight:/ {h=$2} /hasAlpha:/ {a=$2} END {print w, h, a}'
)
[[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || { echo "Error: could not read source dimensions." >&2; exit 1; }
[[ "$width" -eq "$height" ]] || { echo "Error: source must be square; got ${width}x${height}. Pad it transparently instead of stretching it." >&2; exit 1; }
[[ "$alpha" == yes ]] || { echo "Error: source PNG does not contain an Alpha channel." >&2; exit 1; }

if [[ "$width" -lt 1024 ]]; then
  echo "Warning: upscaling ${width}x${height} source to 1024x1024; this cannot add detail." >&2
fi
sips -z 1024 1024 "$base_png" --out "$work_dir/source-1024.png" >/dev/null
"$python_bin" "$script_dir/inset_icon.py" "$work_dir/source-1024.png" "$work_dir/inset-1024.png"
base_png="$work_dir/inset-1024.png"

if command -v python3 >/dev/null && [[ -f "$script_dir/check_png_corners.py" ]]; then
  if ! python3 "$script_dir/check_png_corners.py" "$base_png"; then
    echo "Warning: all four corner pixels are opaque. The ICNS will remain square; add genuinely transparent rounded corners if a rounded icon is required." >&2
  fi
else
  echo "Warning: could not inspect corner pixels; visually confirm that rounded-corner artwork is genuinely transparent outside its shape." >&2
fi

names=(
  icon_16x16@2x.png
  icon_128x128.png
  icon_256x256@2x.png
  icon_512x512@2x.png
)
sizes=(32 128 512 1024)

for i in "${!names[@]}"; do
  sips -z "${sizes[$i]}" "${sizes[$i]}" "$base_png" --out "$iconset/${names[$i]}" >/dev/null
done

iconutil -c icns "$iconset" -o "$compiled"
iconutil -c iconset "$compiled" -o "$verifyset"

for i in "${!names[@]}"; do
  file="$verifyset/${names[$i]}"
  [[ -f "$file" ]] || { echo "Error: reverse validation is missing ${names[$i]}." >&2; exit 1; }
  read -r actual_w actual_h actual_a < <(
    sips -g pixelWidth -g pixelHeight -g hasAlpha "$file" |
      awk '/pixelWidth:/ {w=$2} /pixelHeight:/ {h=$2} /hasAlpha:/ {a=$2} END {print w, h, a}'
  )
  [[ "$actual_w" -eq "${sizes[$i]}" && "$actual_h" -eq "${sizes[$i]}" ]] || {
    echo "Error: ${names[$i]} has unexpected dimensions ${actual_w}x${actual_h}." >&2
    exit 1
  }
  [[ "$actual_a" == yes ]] || { echo "Error: ${names[$i]} lost its Alpha channel." >&2; exit 1; }
done

cp "$base_png" "$final_png"
mv -f "$compiled" "$output_abs"
png_output="${output_abs%.icns}.png"
mv -f "$final_png" "$png_output"
echo "Created and verified: $output_abs"
echo "Created master PNG: $png_output"
