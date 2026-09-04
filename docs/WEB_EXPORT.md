# Web export and deployment

The browser build is the primary target. A finished, working export is committed at
[`web/`](../web/) and can be deployed as a static site with no build step.

---

## What is in `web/`

| File | What it is |
|---|---|
| `index.html` | The page, generated from `web/shell.html` at export time |
| `index.js` | Godot's JavaScript loader |
| `index.wasm` | The engine, compiled to WebAssembly (~39 MB raw, ~10 MB gzipped) |
| `index.pck` | All game content: scripts, scenes, art, audio, data (~2.8 MB) |
| `index.audio.worklet.js`, `index.audio.position.worklet.js` | Audio worklets |
| `index.png`, `index.icon.png`, `index.apple-touch-icon.png` | Icons |
| `shell.html` | The HTML template the export is generated from, kept for reference |
| `.gdignore` | Stops Godot importing its own export output back into the project |

Everything must stay in the same folder and be served together.

---

## Running it locally

WebAssembly cannot be loaded over `file://`. Serve the folder over http:

```bash
python -m http.server 8000 --directory web
```

Then open `http://localhost:8000`.

---

## Rebuilding the export

Needs Godot 4.7.2 and the matching export templates.

```bash
godot --headless --path . --export-release "Web" web/index.html
```

The preset is committed in `export_presets.cfg`. Key settings and why:

| Setting | Value | Reason |
|---|---|---|
| `variant/thread_support` | `false` | Threads require the `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers. Without threads the build runs on any plain static host, including GitHub Pages, which cannot set them. |
| `html/custom_html_shell` | `web/shell.html` | Loading screen, canvas sizing, gesture blocking. |
| `html/canvas_resize_policy` | Adaptive | The canvas follows the window, which matters on phones as the URL bar hides. |
| `include_filter` | `*.json` | Area layouts are JSON, not resources, so they need explicit inclusion. |
| `exclude_filter` | `tools/*, tests/*, docs/*, web/*, *.py, *.md, *.import` | Keeps generators, tests and docs out of the shipped package. |
| `script_export_mode` | Binary tokens | Smaller and faster to parse than source. |

After exporting, delete any `.import` files Godot may leave in `web/`.

---

## The HTML shell

`web/shell.html` handles the things a default shell does not:

- **A loading screen** with a real progress bar driven by `onProgress`, plus the control
  list so a first-time player knows what to press.
- **Canvas sizing.** The canvas is pinned to the viewport with `position: fixed` rather
  than laid out by a flex parent. A parent that measures zero at start-up hands WebGL a
  zero-size framebuffer and the game renders black. The shell also re-syncs the drawing
  buffer on `resize`, `orientationchange` and `visualViewport` resize.
- **Gesture blocking.** Context menu, pinch-zoom and double-tap zoom are suppressed, and
  arrow keys and space are prevented from scrolling the page.
- **Safe areas.** `viewport-fit=cover` plus `env(safe-area-inset-*)`, so the game reaches
  the edges on a notched phone while the touch controls stay clear of the cutout.
- **Real error messages.** If the engine cannot start, or the browser is missing a
  required feature, the page says so instead of showing a black rectangle.

---

## Saves in the browser

Godot maps `user://` to IndexedDB on the web, so saves survive a reload and a browser
restart. `SaveManager` writes only to `user://`, with no absolute paths and no assumptions
about a real filesystem, which is what makes the same code work on both targets.

Caveats worth knowing:

- Saves are per-origin. A game on `example.com` and the same game on `localhost` have
  separate saves.
- Private browsing may discard IndexedDB when the window closes.
- Clearing site data clears saves.

---

## Deploying to GitHub Pages

**Option A — publish the folder from `main`.**

1. Push `main` with `web/` committed.
2. Repository → **Settings → Pages**.
3. Source: **Deploy from a branch**. Branch: `main`, folder: **`/web`**... GitHub only
   offers `/` and `/docs`, so either move the build to `/docs`, or use Option B.

**Option B — GitHub Actions (recommended, and already set up).**

`.github/workflows/export-web.yml` installs Godot and the export templates, exports the
build, verifies `web/index.html` exists, and on `main` publishes it to Pages.

1. Repository → **Settings → Pages** → Source: **GitHub Actions**.
2. Push to `main`.
3. The site appears at `https://<user>.github.io/<repo>/`.

The build uses relative paths, so it works from a subdirectory without changes.

---

## Deploying to Cloudflare Pages

1. Cloudflare dashboard → **Workers & Pages → Create → Pages → Connect to Git**.
2. Pick the repository.
3. Build settings:
   - **Framework preset:** None
   - **Build command:** *(leave empty)*
   - **Build output directory:** `web`
4. Deploy.

Nothing is compiled at deploy time; Cloudflare serves the committed files. It gzips and
Brotli-compresses `.wasm` automatically, which is where the 39 MB becomes roughly 10 MB
over the wire.

To deploy without Git:

```bash
npx wrangler pages deploy web --project-name sidewalk-kings
```

---

## Any other static host

The build is plain files. Netlify, Vercel, S3 + CloudFront, nginx and Apache all work.
Two things to check:

1. **`.wasm` is served as `application/wasm`.** Most hosts do this already. If the game
   fails with a streaming-compile error, this is why.
2. **Compression is enabled** for `.wasm`, `.pck` and `.js`. Without it the first load
   transfers 42 MB instead of about 11 MB.

No `Cross-Origin-Opener-Policy` or `Cross-Origin-Embedder-Policy` headers are needed,
because the build has thread support turned off.

---

## Performance notes

- The renderer is **Compatibility** (OpenGL ES 3.0 / WebGL 2), which is the right choice
  for mobile browsers.
- The design resolution is 480×270, stretched with `canvas_items` and an `expand` aspect,
  so pixel art stays crisp at any window size and wider screens see more of the street
  rather than black bars.
- Audio is imported compressed; the whole soundtrack and every effect fit in the 2.8 MB
  package alongside the art.
- First load is dominated by `index.wasm`. Subsequent loads are cached by the browser.

---

## Verified

The committed build was loaded in a Chromium browser from a local static server and played
through: title screen, New Game, the opening conversation with Dez, movement, and combat.
The area layouts, sprite sheets, audio and save system all work from the packaged build.
