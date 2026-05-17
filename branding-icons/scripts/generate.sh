#!/bin/bash
set -euo pipefail
# =============================================================================
# Branding Icons Generator
# =============================================================================
# Takes a single company SVG logo and generates all required branding assets
# for Open WebUI: favicons, touch icons, splash screens, PWA manifests.
#
# Usage:
#   ./generate.sh path/to/company-logo.svg
#
# Output: .sisyphus/branding-icons/output/
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/output"

# Clean and recreate output
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# --- Input Validation ---

if [ $# -lt 1 ]; then
    echo "Usage: $0 <logo.svg>" >&2
    echo "  Provide your company SVG logo file." >&2
    exit 1
fi

LOGO_SVG="$1"

if [ ! -f "$LOGO_SVG" ]; then
    echo "Error: SVG file not found: $LOGO_SVG" >&2
    exit 1
fi

# Determine SVG size from viewBox (default 256x256 if not found)
# Uses POSIX-compatible approach — no -P flag
VIEWBOX=$(grep -o 'viewBox="[^"]*"' "$LOGO_SVG" 2>/dev/null | sed 's/viewBox="//;s/"//' || true)
VIEWBOX=${VIEWBOX:-"0 0 256 256"}
SVG_WIDTH=$(echo "$VIEWBOX" | awk '{print $3}')
SVG_HEIGHT=$(echo "$VIEWBOX" | awk '{print $4}')
SVG_WIDTH=${SVG_WIDTH:-256}
SVG_HEIGHT=${SVG_HEIGHT:-256}

echo "🔍 Logo SVG detected: ${SVG_WIDTH}x${SVG_HEIGHT}"

# --- Dependency Checks ---

MISSING=()

# ImageMagick — non-optional
if command -v magick >/dev/null 2>&1; then
    # ImageMagick v7+ unified CLI
    __CONVERT="magick"
    __IDENTIFY="magick identify"
elif command -v convert >/dev/null 2>&1; then
    __CONVERT="convert"
    __IDENTIFY="identify"
else
    MISSING+=("ImageMagick (convert/magick)")
fi

# Verify identify is usable
if [ -n "${__IDENTIFY:-}" ]; then
    if ! $__IDENTIFY -version >/dev/null 2>&1; then
        MISSING+=("ImageMagick identify (not functional)")
    fi
fi

# Determine best SVG rasterizer
if command -v inkscape >/dev/null 2>&1; then
    __RASTERIZE="inkscape_rasterize"
    __RASTERIZE_FIT="inkscape_rasterize_fit"
elif command -v rsvg-convert >/dev/null 2>&1; then
    __RASTERIZE="rsvg_rasterize"
    __RASTERIZE_FIT="rsvg_rasterize_fit"
else
    MISSING+=("inkscape or librsvg (rsvg-convert)")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "❌ Missing required tools:"
    for dep in "${MISSING[@]}"; do
        echo "   - $dep"
    done
    echo ""
    echo "Install options:"
    echo ""
    echo "  macOS:"
    echo "    brew install inkscape imagemagick librsvg"
    echo ""
    echo "  Ubuntu/Debian:"
    echo "    sudo apt install inkscape imagemagick librsvg2-bin"
    echo ""
    echo "  Fedora:"
    echo "    sudo dnf install inkscape ImageMagick librsvg2-tools"
    exit 1
fi

# --- Rasterize Functions ---

# Square rasterize (forces WxH square — for favicons, PWA icons)
inkscape_rasterize() {
    local input="$1" output="$2" size="$3"
    inkscape "$input" --export-type=png --export-filename="$output" \
        --export-width="$size" --export-height="$size" 2>/dev/null
}

rsvg_rasterize() {
    local input="$1" output="$2" size="$3"
    rsvg-convert -w "$size" -h "$size" "$input" -o "$output"
}

# Aspect-ratio-preserving rasterize (height only, width auto-scales)
inkscape_rasterize_fit() {
    local input="$1" output="$2" height="$3"
    inkscape "$input" --export-type=png --export-filename="$output" \
        --export-height="$height" 2>/dev/null
}

rsvg_rasterize_fit() {
    local input="$1" output="$2" height="$3"
    rsvg-convert -h "$height" "$input" -o "$output"
}

# --- Generate Favicons ---

echo ""
echo "🎨 Generating favicons..."

# Copy SVG favicon as-is
cp "$LOGO_SVG" "$OUTPUT_DIR/favicon.svg"
echo "  ✓ favicon.svg"

# favicon.png (32x32)
$__RASTERIZE "$LOGO_SVG" "$OUTPUT_DIR/favicon.png" 32
echo "  ✓ favicon.png (32×32)"

# favicon-96x96.png
$__RASTERIZE "$LOGO_SVG" "$OUTPUT_DIR/favicon-96x96.png" 96
echo "  ✓ favicon-96x96.png (96×96)"

# favicon-dark.png (inverted for dark browser themes)
$__RASTERIZE "$LOGO_SVG" "$OUTPUT_DIR/temp_dark.png" 32
$__CONVERT "$OUTPUT_DIR/temp_dark.png" -negate "$OUTPUT_DIR/favicon-dark.png"
rm -f "$OUTPUT_DIR/temp_dark.png"
echo "  ✓ favicon-dark.png (32×32, inverted)"

# favicon.ico (multi-resolution ICO)
$__CONVERT "$OUTPUT_DIR/favicon.png" -define icon:auto-resize=16,32,48,64 \
    "$OUTPUT_DIR/favicon.ico"
echo "  ✓ favicon.ico"

# --- Apple Touch Icon (180x180, iOS applies its own corner rounding) ---

echo ""
echo "🍎 Generating Apple touch icon..."

$__RASTERIZE "$LOGO_SVG" "$OUTPUT_DIR/temp_touch.png" 180

# Create 180x180 canvas, draw logo centered with padding
LOGO_SIZE=100
PADDING=$(( (180 - LOGO_SIZE) / 2 ))
$__CONVERT -size 180x180 xc:white \
    \( "$OUTPUT_DIR/temp_touch.png" -resize ${LOGO_SIZE}x${LOGO_SIZE} \) \
    -geometry +${PADDING}+${PADDING} -composite \
    "$OUTPUT_DIR/apple-touch-icon.png"
rm -f "$OUTPUT_DIR/temp_touch.png"
echo "  ✓ apple-touch-icon.png (180×180)"

# --- Logo (preserves aspect ratio, height-constrained) ---

echo ""
echo "🖼️  Generating logo..."

LOGO_HEIGHT=200
$__RASTERIZE_FIT "$LOGO_SVG" "$OUTPUT_DIR/temp_logo.png" "$LOGO_HEIGHT"
WIDTH=$($__IDENTIFY -format '%w' "$OUTPUT_DIR/temp_logo.png")

if [ -z "$WIDTH" ] || [ "$WIDTH" -eq 0 ]; then
    echo "Error: Could not determine logo dimensions from rasterized output." >&2
    exit 1
fi

# Use pure bash integer math (no bc dependency needed — ImageMagick handles sub-pixel)
$__CONVERT "$OUTPUT_DIR/temp_logo.png" -resize "${WIDTH}x${LOGO_HEIGHT}" "$OUTPUT_DIR/logo.png"
rm -f "$OUTPUT_DIR/temp_logo.png"
echo "  ✓ logo.png (${WIDTH}x${LOGO_HEIGHT}, aspect ratio preserved)"

# --- Splash Screens ---

echo ""
echo "🌅 Generating splash screens..."

LOGO_FOR_SPLASH="${LOGO_FOR_SPLASH:-$OUTPUT_DIR/logo.png}"

SPLASH_W=800
SPLASH_H=800

# Light splash
SPLASH_LOGO_SIZE=256
$__CONVERT -size ${SPLASH_W}x${SPLASH_H} xc:'#ffffff' \
    \( "$LOGO_FOR_SPLASH" -resize ${SPLASH_LOGO_SIZE}x${SPLASH_LOGO_SIZE} \) \
    -gravity center -composite \
    "$OUTPUT_DIR/splash.png"
echo "  ✓ splash.png (800×800, light)"

# Dark splash
$__CONVERT -size ${SPLASH_W}x${SPLASH_H} xc:'#000000' \
    \( "$LOGO_FOR_SPLASH" -resize ${SPLASH_LOGO_SIZE}x${SPLASH_LOGO_SIZE} \) \
    -gravity center -composite \
    "$OUTPUT_DIR/splash-dark.png"
echo "  ✓ splash-dark.png (800×800, dark)"

# --- PWA Manifest Icons ---

echo ""
echo "📱 Generating PWA icons..."

# web-app-manifest-192x192.png
$__RASTERIZE "$LOGO_SVG" "$OUTPUT_DIR/temp_pwa192.png" 128
$__CONVERT -size 192x192 xc:white \
    \( "$OUTPUT_DIR/temp_pwa192.png" -resize 128x128 \) \
    -gravity center -composite \
    "$OUTPUT_DIR/web-app-manifest-192x192.png"
rm -f "$OUTPUT_DIR/temp_pwa192.png"
echo "  ✓ web-app-manifest-192x192.png"

# web-app-manifest-512x512.png
$__RASTERIZE "$LOGO_SVG" "$OUTPUT_DIR/temp_pwa512.png" 384
$__CONVERT -size 512x512 xc:white \
    \( "$OUTPUT_DIR/temp_pwa512.png" -resize 384x384 \) \
    -gravity center -composite \
    "$OUTPUT_DIR/web-app-manifest-512x512.png"
rm -f "$OUTPUT_DIR/temp_pwa512.png"
echo "  ✓ web-app-manifest-512x512.png"

# --- User Avatar ---

echo ""
echo "👤 Generating default user avatar..."

$__RASTERIZE "$LOGO_SVG" "$OUTPUT_DIR/temp_user.png" 80
$__CONVERT -size 128x128 xc:'#e5e7eb' \
    \( "$OUTPUT_DIR/temp_user.png" -resize 80x80 \) \
    -gravity center -composite \
    "$OUTPUT_DIR/user.png"
rm -f "$OUTPUT_DIR/temp_user.png"
echo "  ✓ user.png (128×128)"

# --- Swagger UI Favicon ---

mkdir -p "$OUTPUT_DIR/swagger-ui"
cp "$OUTPUT_DIR/favicon.png" "$OUTPUT_DIR/swagger-ui/favicon.png"
echo "  ✓ swagger-ui/favicon.png"

# --- Summary ---

echo ""
echo "======================================"
echo "  ✅ All branding assets generated!"
echo "======================================"
echo ""
echo "Output: $OUTPUT_DIR"
echo ""

echo "Files created:"
for ext in png svg ico; do
    ls -lh "$OUTPUT_DIR/"*."$ext" 2>/dev/null || true
done
ls -lh "$OUTPUT_DIR/"swagger-ui/*.png 2>/dev/null || true

echo ""
echo "Next steps:"
echo "  1. Review the generated files in $OUTPUT_DIR"
echo "  2. Copy to project locations:"
echo ""
echo "     cp $OUTPUT_DIR/*.svg $OUTPUT_DIR/*.png $OUTPUT_DIR/*.ico static/static/"
echo "     cp $OUTPUT_DIR/*.svg $OUTPUT_DIR/*.png $OUTPUT_DIR/*.ico backend/open_webui/static/"
echo "     cp $OUTPUT_DIR/swagger-ui/favicon.png backend/open_webui/static/swagger-ui/"
echo ""
echo "  3. Rebuild the project"
