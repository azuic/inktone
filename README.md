# Tink-on — S-4 Sketch Sampler

Sketch a sound. Draw on the paper with one of four risograph inks and Tink-on
translates the sketch — its color, position, length, speed, and jaggedness —
into a synthesized sound on a four-pad sampler. Pitch it, place it on a
16-step sequencer, play a beat.

Tink-on is a landscape-shaped instrument, played sideways: on a phone, rotate
to landscape to use it — a sketch-and-controls pane sits beside the pad grid
and step sequencer.

**The drawing is the prompt**: every sketch compiles to a line like
`fluttering jagged, gritty metallic impact, bright airy character, 0.8s`, sent
to the [ElevenLabs Sound Effects API](https://elevenlabs.io/docs/api-reference/text-to-sound-effects)
via a small serverless function that keeps the API key server-side. If that
call is unavailable or fails, Tink-on falls back instantly to a local
[Tone.js](https://tonejs.github.io) synth — no backend, no keys, no network.

## Mapping

- **Ink → timbre** (vibrant riso inks): blue = resonant tone · yellow = grainy
  texture · orange = metallic impact · pink = deep sub drone (most-drawn color
  wins). Overlapping strokes multiply-blend into a third riso color, same as
  overlapping ink passes (blue × yellow → green, orange × pink → red).
- **Height on paper** → pitch (80–880 Hz) · **drawn length** → duration
  (0.25–1.6 s) · **speed** → flutter rate · **jaggedness** → grit/detune
- Each generated pad gets a single geometric shape filled with a black
  halftone (dots large in the center, small at the edges), centered on the
  pad's gray ground — seeded from that sketch's own features (not a photo).

## Run locally

Frontend only — the AI call 404s without the serverless function, so every
pad uses the local Tone.js synth:

```sh
npx serve .
```

Frontend + `/api/generate-sound` (requires the [Vercel CLI](https://vercel.com/docs/cli)
and a linked project):

```sh
npm i -g vercel
vercel link
cp .env.example .env.local   # fill in ELEVENLABS_API_KEY
vercel dev
```

Keys `1`–`4` trigger pads. GENERATE always calls the ElevenLabs Sound Effects
API and falls back to the Tone.js synth on any failure. The **SEQ** section is
a shared 16-step clock (40–240 BPM) — toggle steps per pad and hit PLAY to
place pads on exact beats relative to each other.

## Docs

- [Product doc](docs/PRODUCT.md)
- [Deployment plan](docs/DEPLOYMENT.md)

## Stack

Vanilla HTML/CSS/JS, Web Audio API, [Tone.js](https://tonejs.github.io)
(vendored at `vendor/tone.js` for the fallback synth), IBM Plex Mono, and one
Vercel serverless function (`api/generate-sound.js`, no dependencies) calling
the ElevenLabs Sound Effects API. No build step. Deployed on Vercel.
