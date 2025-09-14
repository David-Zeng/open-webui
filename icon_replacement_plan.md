
# Icon Replacement Plan for Open WebUI

This document outlines the identified icon definitions within the Open WebUI project and provides a detailed, step-by-step plan for their replacement.

## 1. Identified Icon Definitions

### 1.1. PWA and Web Page Icons

These icons are primarily defined in `src/app.html` and located in the `static/` and `static/favicon/` directories.

* **`src/app.html` references:**
  * `/static/favicon.png`
  * `/static/favicon-96x96.png`
  * `/static/favicon.svg`
  * `/static/favicon.ico`
  * `/static/apple-touch-icon.png`
  * `/manifest.json` (which is `static/manifest.json`)

* **`static/favicon/` directory contents:**
  * `apple-touch-icon.png`
  * `favicon-96x96.png`
  * `favicon.ico`
  * `favicon.svg`
  * `web-app-manifest-192x192.png`
  * `web-app-manifest-512x512.png`

* **`static/manifest.json`:**
  * This file is currently empty. The presence of `web-app-manifest-192x192.png` and `web-app-manifest-512x512.png` in `static/favicon/` suggests these are intended for a manifest file, which may need to be populated or updated.

### 1.2. Model Icons

The search in `.svelte` files revealed that `favicon.png` is frequently used as a placeholder or default profile image for models. It appears that `profile_image_url` is a common property for models, defaulting to `favicon.png` if not explicitly set.

### 1.3. Other General Icons

* `doge.png` is used in some chat components.
* `user.png` is present in the `static/` directory, likely a default user profile image.
* `image-placeholder.png` is also in `static/`.

## 2. Detailed Plan for Icon Replacement

### Phase 1: PWA and Web Page Icons

1. **Prepare New Icons:**
    * Create or obtain your new PWA and web page icons in various sizes and formats (PNG, SVG, ICO) as listed above.
    * Ensure the new icons are named identically to the existing ones to minimize code changes.

2. **Update `src/app.html`:**
    * Navigate to `src/app.html`.
    * Locate the `<link>` tags referencing the favicon and apple-touch-icon files.
    * Verify that the `href` attributes point to the correct paths for your new icons. If you maintained the same filenames and directory structure, no changes might be needed here, but it's crucial to confirm.

3. **Replace files in `static/favicon/` directory:**
    * Go to the `static/favicon/` directory.
    * Replace the existing `apple-touch-icon.png`, `favicon-96x96.png`, `favicon.ico`, `favicon.svg`, `web-app-manifest-192x192.png`, and `web-app-manifest-512x512.png` files with your new icon files.
    * Ensure the new files have the exact same names and are of the appropriate dimensions (e.g., 192x192 for `web-app-manifest-192x192.png`).

4. **Update `static/manifest.json` (if of the appropriate dimensions (e.g., 192x192 for `web-app-manifest-192x192.png`).

---

icon list:

* static/static/apple-touch-icon.png: done
* static/static/favicon-dark.png
* static/static/logo.png
