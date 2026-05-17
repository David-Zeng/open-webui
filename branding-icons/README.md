# Branding Icons Replacement Process

## Purpose
Replace all company branding assets (favicons, logos, splash screens) in Open WebUI with a new company identity. Single source → 13 output files.

## File Inventory

### Source Locations (both must be updated)

| # | File | `static/static/` | `backend/open_webui/static/` | Dimensions | Format |
|---|------|:---:|:---:|---|---|
| 1 | `favicon.svg` | ✅ | ✅ | Any | SVG |
| 2 | `favicon.png` | ✅ | ✅ | 32×32 | PNG |
| 3 | `favicon-96x96.png` | ✅ | ✅ | 96×96 | PNG |
| 4 | `favicon-dark.png` | ✅ | ✅ | 32×32 | PNG |
| 5 | `favicon.ico` | ✅ | ✅ | 16+32 multi | ICO |
| 6 | `apple-touch-icon.png` | ✅ | ✅ | 180×180 | PNG |
| 7 | `logo.png` | ✅ | ✅ | ~200px height | PNG |
| 8 | `splash.png` | ✅ | — | ~800px height | PNG |
| 9 | `splash-dark.png` | ✅ | — | ~800px height | PNG |
| 10 | `web-app-manifest-192x192.png` | ✅ | — | 192×192 | PNG |
| 11 | `web-app-manifest-512x512.png` | ✅ | — | 512×512 | PNG |
| 12 | `user.png` | ✅ | — | 128×128 | PNG |
| 13 | `swagger-ui/favicon.png` | — | ✅ | 32×32 | PNG |

### Where They're Referenced

```
src/app.html                    — Lines 5, 9, 16, 19, 23, 76, 153
static/static/site.webmanifest  — PWA icons (192×192, 512×512)
```

## Minimal Input Required

**Single file:** `company-logo.svg` (vector logo in SVG format)

That's it. Everything else is auto-generated.

## Output Generation Pipeline

```
Input: company-logo.svg
│
├─ 1. favicon.svg .................... Copy + optimize SVG
├─ 2. favicon.png .................... Rasterize @ 32×32
├─ 3. favicon-96x96.png .............. Rasterize @ 96×96
├─ 4. favicon-dark.png ............... Invert white → 32×32
├─ 5. favicon.ico .................... Convert PNG → ICO (multi-res)
├─ 6. apple-touch-icon.png ........... Logo on rounded rect @ 180×180
├─ 7. logo.png ....................... Full logo @ 200px height (transparent)
├─ 8. splash.png ..................... Logo centered on #ffffff bg
├─ 9. splash-dark.png ................ Logo centered on #000000 bg
├─10. web-app-manifest-192x192.png ... Logo on bg @ 192×192
├─11. web-app-manifest-512x512.png ... Logo on bg @ 512×512
├─12. user.png ....................... Default avatar placeholder
└─13. swagger-ui/favicon.png ......... Same as favicon.png
```

## Deploy Process

```bash
# 1. Generate all files into .sisyphus/branding-icons/output/
# 2. Review output
# 3. Copy to both locations:
cp output/*.svg output/*.png output/*.ico static/static/
cp output/*.svg output/*.png output/*.ico backend/open_webui/static/
cp output/swagger-ui/favicon.png backend/open_webui/static/swagger-ui/
```

## Notes
- `favicon-dark.png` is used by browsers that prefer dark theme; invert the logo colors
- `apple-touch-icon.png` needs background padding (Apple's HIG)
- `favicon.ico` requires ImageMagick: `convert favicon.png favicon.ico`
- Splash screens: logo centered, matching the light/dark theme background
- The `site.webmanifest` references `/static/` paths — no changes needed if filenames stay same
