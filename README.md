# Tink-on — S-4 Sketch Sampler

Sketch a sound. Draw on the paper with one of four risograph inks and Tink-on
translates the sketch — its color, position, length, speed, and jaggedness —
into a synthesized sound on a six-pad sampler. Pitch it, place it on a
16-step sequencer, play a beat.

Tink-on is a landscape-shaped instrument, played sideways: on a phone, rotate
to landscape to use it — a dedicated sketch pane sits beside the pads,
controls, and sequencer.

**The drawing is the prompt**: every sketch compiles to a line like
`fluttering jagged, gritty metallic impact, bright airy character, 0.8s`, sent
to the [ElevenLabs Sound Effects API](https://elevenlabs.io/docs/api-reference/text-to-sound-effects)
via a small serverless function that keeps the API key server-side. If AI
generation is off, unavailable, or fails, Tink-on falls back instantly to a
local Web Audio synth — no backend, no keys, no network.

## Mapping

- **Ink → timbre**: black = sub drone · red = metallic impact · blue = resonant
  tone · ochre = grainy texture (most-drawn color wins). Overlapping strokes
  multiply-blend into a third riso-style color, same as overlapping ink passes.
- **Height on paper** → pitch (80–880 Hz) · **drawn length** → duration
  (0.25–1.6 s) · **speed** → flutter rate · **jaggedness** → grit/detune
- Each generated pad gets a small generative riso-shape thumbnail (not a
  photo of the sketch) seeded from that sketch's own features.

## Run locally

Frontend only, no AI (local synth always used):

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

Keys `1`–`6` trigger pads. The **AI** chip toggles ElevenLabs generation on/off.
The **SEQ** section is a shared 16-step clock (40–240 BPM) — toggle steps per
pad and hit PLAY to place pads on exact beats relative to each other.

## Docs

- [Product doc](docs/PRODUCT.md)
- [Deployment plan](docs/DEPLOYMENT.md)

## Stack

Vanilla HTML/CSS/JS, Web Audio API, IBM Plex Mono, one Vercel serverless
function (`api/generate-sound.js`, zero dependencies) calling the ElevenLabs
Sound Effects API. Deployed on Vercel.
