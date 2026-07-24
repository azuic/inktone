# Deployment plan — Inktone

## Overview

Inktone is a static frontend plus one Vercel serverless function (no npm
dependencies, no build step), which keeps the deployment story minimal:
GitHub for source of truth, Vercel for hosting, CDN, and the function runtime.

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
- With `ELEVENLABS_API_KEY` set and AI chip on: GENERATE calls
  `/api/generate-sound`, plays real audio, trimmed to the sketch duration
- With AI chip off, or key missing/invalid: GENERATE still works via local
  synth, LCD shows the fallback message when a call was attempted and failed
- Pads play/loop/pitch/delete correctly
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
