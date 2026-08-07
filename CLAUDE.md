# CLAUDE.md — rjlcevans Repository Guide

## Project Overview

This is a **static, framework-free personal website** for Ryan Evans, an optometrist in Murrieta, CA. The site lives at `rjlcevans.com` (GitHub Pages) and contains:

- A family landing page with weather, dad jokes, and a project showcase
- Interactive patient-education tools (vision simulation, acuity testing, eye wellness)
- Canvas-based browser games (Dr. Glass, Contra, Shooter, Iris Drift)

**Stack: 100% vanilla HTML + CSS + JavaScript — no npm, no build step, no frameworks.**

---

## Repository Layout

```
/
├── index.html              # Root landing page (family site + tool links)
├── manifest.json           # Root PWA manifest (Evans Family app)
├── sw.js                   # Service worker — caches family photos & icons
├── 404.html                # GitHub Pages fallback for client-side routes
├── robots.txt / sitemap.xml / CNAME
├── MEMORY.md               # Personal context (do not modify)
│
├── vision-simulator/       # Vision impairment simulator (AMD, glaucoma, cataracts, color blindness)
│   ├── index.html          # ~1,547 lines; Canvas 2D + pixel-filter pipeline
│   ├── manifest.json       # Standalone PWA manifest for this tool
│   └── samples/            # Bundled demo images (garden, night-street, portrait)
│
├── visual-acuity/          # Snellen-style eye chart tester
│   └── index.html          # ~956 lines
│
├── eye-wellness/           # Patient education content tool
│   └── index.html          # ~890 lines
│
├── iris-drift/             # Iris drift / nystagmus visualization
│   └── index.html          # ~2,735 lines
│
├── dr-glass/               # Mario-style platformer game (optometry theme)
│   ├── index.html          # ~6,139 lines — largest file in repo
│   └── assets/             # Game sprites and audio
│
├── contra/                 # Classic Contra-style shooter (Canvas 2D)
│   └── index.html          # ~1,269 lines
│
└── shooter/                # 3D-perspective shooter (Canvas 2D + advanced filters)
    └── index.html
```

---

## Architecture & Conventions

### No Build Tooling
There is **no package.json, no npm, no Webpack/Vite/Next.js**. Every file is self-contained and served as-is by GitHub Pages. Do not introduce a build step without explicit discussion.

### One File Per App
Each app lives entirely in a single `index.html`. Inline `<style>` handles CSS; inline `<script>` handles JS. Keep new work in this pattern unless the user asks for something different.

### External Dependencies
- **Google Fonts** — Fraunches (serif) and Inter Tight (sans-serif), loaded via `<link>`
- **Open-Meteo API** — Free weather API, no key required. Coordinates hardcoded to Murrieta, CA (`lat=33.5539, lon=-117.2139`)
- No other third-party JS libraries

### Canvas & Game Loops
Games use `requestAnimationFrame` loops with the Canvas 2D API. Vision Simulator applies pixel-level image filters in a Canvas pipeline. No WebGL.

### PWA Setup
- Root `sw.js` caches the landing page assets with a cache-first strategy (`evans-v1` cache name)
- `vision-simulator/` has its own `manifest.json` for standalone installability
- When updating cached assets, bump the cache name version string in `sw.js`

### Responsive Design
- CSS `clamp()` for fluid typography
- CSS Grid + Flexbox for layouts
- Mobile-first media queries

### Design Tokens (root site)
| Purpose | Value |
|---------|-------|
| Background | `#ececec` |
| Dark text / nav | `#1f1f1f` |
| Accent amber | `#f5a623` (approx) |

Clinical tools use a darker blue/tan palette for a professional feel.

---

## Development Workflow

### Running Locally
Open any `index.html` directly in a browser — no server required for most features. The weather widget needs a network connection (Open-Meteo). The service worker only activates over HTTPS or `localhost`.

For service worker testing:
```bash
python3 -m http.server 8080   # then open http://localhost:8080
```

### Editing Files
1. Edit the relevant `index.html` (or `sw.js` for caching changes)
2. Test in browser
3. Commit and push to the working branch

### Deployment
GitHub Pages auto-deploys from `main`. Changes pushed to `main` are live at `rjlcevans.com` within seconds. The `CNAME` file must remain at the repo root.

### Git Conventions
- Branch from `main` for new features
- Commit messages are descriptive and imperative: `Add AMD metamorphopsia to vision simulator`
- No squash policy — individual commits are kept

---

## Key Files to Know

| File | What to watch out for |
|------|-----------------------|
| `sw.js` | Cache version string must be bumped when adding new assets to precache list |
| `vision-simulator/index.html` | Canvas filter pipeline is order-sensitive; conditions layer on top of each other |
| `dr-glass/index.html` | Largest file (~6,100 lines); game state, physics, and levels are all inline |
| `index.html` (root) | Dad jokes array, weather widget, family photo carousel — all embedded inline |

---

## Personal Context (from MEMORY.md)

- **Ryan Evans** — optometrist, site owner
- **Jadyn Evans** — wife, also an optometrist
- **Children:** Landon (8) and Cody (6)
- The optometry theme is intentional across all tools and games

---

## What NOT to Do

- **Do not add a build system** (npm, Webpack, Vite) without explicit request
- **Do not split single-file apps into separate JS/CSS files** unless asked
- **Do not add third-party JS libraries** (jQuery, React, etc.) without discussion
- **Do not modify `MEMORY.md`** — it is personal context, not documentation
- **Do not hard-code new coordinates or API keys** — keep the Open-Meteo endpoint as-is
- **Do not remove the `CNAME` file** — it controls the custom domain

---

## Testing & Validation

There is no automated test suite. Validation is manual:
1. Open the modified file in a browser
2. Test the feature you changed plus adjacent interactions
3. Check mobile layout with DevTools responsive mode
4. For vision simulator changes, test all condition types (AMD, Glaucoma, Cataracts, Color Blindness)
