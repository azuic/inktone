# Deployment plan — Inktone

## Overview

Inktone is a dependency-free static site (three files, no build step), which makes
the deployment story deliberately minimal: GitHub for source of truth, Vercel for
hosting and CDN.

## Targets

| Stage      | Where                          | Trigger                         |
|------------|--------------------------------|---------------------------------|
| Local dev  | `npx serve .` or any static server | manual                      |
| Preview    | Vercel preview deployment      | every push to a non-main branch / PR |
| Production | Vercel production deployment   | push to `main`                  |

## Steps

### 1. Repository

- [x] `git init`, initial commit with app + docs
- [x] GitHub repo created and `main` pushed: https://github.com/azuic/inktone

### 2. Vercel project

- [x] Vercel project `inktone` created; production deployment live at
      https://inktone-lemon.vercel.app (framework: none / static — Vercel serves
      `index.html` from the root; no build command, no output dir, no env vars)
- [x] GitHub repo linked to the Vercel project — pushes auto-deploy: PRs get
      preview URLs, `main` goes to production

### 3. Verification checklist (per deploy)

- Page loads over HTTPS, fonts (IBM Plex Mono via Google Fonts) render
- Drawing works with mouse and touch (pointer events, `touch-action: none`)
- GENERATE produces sound after a user gesture (AudioContext resume path)
- Pads play/loop/pitch/delete correctly
- Layout correct at 390px (phone) and desktop widths

### 4. Rollback

Vercel keeps every deployment immutable — roll back via dashboard
("Promote to Production" on a previous deployment) or `vercel rollback`.

## Configuration

- No environment variables in v1 (all client-side).
- No `vercel.json`/`vercel.ts` needed; static auto-detection is sufficient.
- Future: when the real SFX API is integrated, add `SFX_API_KEY` via
  `vercel env add` and a serverless `/api/generate` function — key stays
  server-side, never shipped to the client.

## Custom domain (optional, later)

Add via Vercel dashboard → Domains; Vercel provisions TLS automatically.
