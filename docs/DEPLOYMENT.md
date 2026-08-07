# Deployment plan — Tink-on

## Overview

Tink-on is a static frontend (with Tone.js vendored in-repo for the fallback
synth) plus one Vercel serverless function, with no build step, which keeps
the deployment story minimal: GitHub for source of truth, Vercel for hosting,
CDN, and the function runtime.

> The app was renamed from "Inktone" to "Tink-on" in-product only. The GitHub
> repo (`azuic/inktone`) and Vercel project/domain (`inktone-lemon.vercel.app`)
> were intentionally left unchanged to avoid breaking the live URL.

## Targets

| Stage      | Where                          | Trigger                         |
|------------|--------------------------------|---------------------------------|
| Local dev  | `npx serve .` (frontend only) or `vercel dev` (frontend + `/api`) | manual |
| Preview    | Vercel preview deployment      | every push to a non-main branch / PR |
| Production | Vercel production deployment   | push to `main`                  |

## Steps

### 1. Repository

- [x] `git init`, initial commit with app + docs
- [x] GitHub repo created and `main` pushed: https://github.com/azuic/inktone

### 2. Vercel project

- [x] Vercel project `inktone` created; production deployment live at
      https://inktone-lemon.vercel.app (framework: none / static — Vercel serves
      `index.html` from the root and auto-detects `api/*.js` as serverless
      functions; no build command, no output dir)
- [x] GitHub repo linked to the Vercel project — pushes auto-deploy: PRs get
      preview URLs, `main` goes to production

### 3. ElevenLabs Sound Effects API integration

- [x] `api/generate-sound.js` added — Node serverless function, proxies to
      `POST https://api.elevenlabs.io/v1/sound-generation`, reads
      `ELEVENLABS_API_KEY` from `process.env` (server-side only)
- [ ] **Add `ELEVENLABS_API_KEY` in the Vercel dashboard** — Project `inktone`
      → Settings → Environment Variables → add for **Production** and
      **Preview** (get a key at https://elevenlabs.io/app/settings/api-keys;
      music generation requires a paid ElevenLabs plan)
- [ ] Redeploy after adding the key — Vercel snapshots env vars per
      deployment, so a deployment made before the key was added won't see it.
      Any new push (or "Redeploy" in the dashboard) picks it up.
- [x] Fails safe without the key: the AI toggle is on by default, but a
      missing/invalid key or any upstream error makes `generate()` fall back
      to the local synth automatically (see `docs/PRODUCT.md`)

### 4. Verification checklist (per deploy)

- Page loads over HTTPS, fonts (IBM Plex Mono via Google Fonts) render
- Drawing works with mouse and touch (pointer events, `touch-action: none`)
- GENERATE produces sound after a user gesture (AudioContext resume path)
- With `ELEVENLABS_API_KEY` set: GENERATE calls `/api/generate-sound` and
  plays real audio, trimmed to the sketch duration
- With the key missing/invalid or the call failing: GENERATE still produces a
  playable pad via the Tone.js fallback synth, and the LCD shows
  `sfx model unavailable — synth`
- `vendor/tone.js` loads (global `Tone` defined); all four fallback voices
  are audible; the transport schedules its metronome on the shared clock
- Pads play/pitch/delete correctly (eight pads, keys 1–8)
- Transport: PLAY sweeps a playhead across the 16-tick bar and ticks a
  metronome on each quarter beat; STOP halts cleanly with no stray highlight
- Ink swatches, UNDO/CLR, and the prompt row are all visible (regression
  check — a flexbox shrink bug hid the whole ink row once)
- Overlapping strokes of two different inks show a visibly different third
  color where they cross (multiply blend), not just one drawn over the other
- A generated pad shows a square magnetic-board thumbnail: a coarse grid of
  small rounded-square units that pixelate the drawn sketch, very faint units
  for unsketched cells, black/gray shades per ink color (single color = black)
- Surfaces are cold gray (canvas, tick bar, pad tiles) — no cream/yellow
- Left pane is a square sketch canvas + prompt; right pane stacks the 4×2
  square pads, pitch/DEL control, and one-line transport. Both panes fill the
  same height and neither scrolls (desktop and landscape phone)
- Mobile portrait shows the "ROTATE TO LANDSCAPE" hint, not the device;
  mobile landscape and desktop both show the two-pane device directly
- Each pane (sketch, pads) scrolls independently if its content is taller
  than the device
- Device panel scrolls internally (not clipped) when content exceeds one screen
- Layout correct at 390px (phone) and desktop widths

### 5. Rollback

Vercel keeps every deployment immutable — roll back via dashboard
("Promote to Production" on a previous deployment) or `vercel rollback`.

## Configuration

- **Environment variable**: `ELEVENLABS_API_KEY` (Production + Preview) — the
  only server-side secret. Never referenced from client code; only read inside
  `api/generate-sound.js`.
- No `vercel.json`/`vercel.ts` needed; static + `api/` auto-detection is
  sufficient for this project's needs.
- No SDK dependency — `api/generate-sound.js` uses the platform's global
  `fetch`, so no `package.json`/`npm install` step is introduced.

## Custom domain (optional, later)

Add via Vercel dashboard → Domains; Vercel provisions TLS automatically.
