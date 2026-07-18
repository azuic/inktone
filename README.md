# Inktone — S-4 Sketch Sampler

Sketch a sound. Draw on the paper with one of four inks and Inktone translates the
sketch — its color, position, length, speed, and jaggedness — into a synthesized
sound on a six-pad sampler. Pitch it, loop it, play a beat.

**The drawing is the prompt**: every sketch compiles to a line like
`fluttering jagged, gritty metallic impact, bright airy character, 0.8s` — the
string a production build would send to a text-to-sound-effects API. This build
renders it locally with the Web Audio API, so there is no backend and no keys.

## Mapping

- **Ink → timbre**: black = sub drone · red = metallic impact · blue = resonant
  tone · ochre = grainy texture (most-drawn color wins)
- **Height on paper** → pitch (80–880 Hz) · **drawn length** → duration
  (0.25–1.6 s) · **speed** → flutter rate · **jaggedness** → grit/detune

## Run locally

It's a static site with no build step:

```sh
npx serve .
```

Keys `1`–`6` trigger pads.

## Docs

- [Product doc](docs/PRODUCT.md)
- [Deployment plan](docs/DEPLOYMENT.md)

## Stack

Vanilla HTML/CSS/JS, Web Audio API, IBM Plex Mono. Deployed on Vercel.
