# Tink-on — S-4 Sketch Sampler

## Product overview

Tink-on is a sketch-to-sound sampler. The user draws on a small sheet of "paper" with
colored inks; the app reads the sketch — its color, position, length, speed, and
jaggedness — and translates it into a synthesized sound that lands on one of four
sampler pads. Pads can be retriggered, pitched, and placed on a shared step
grid to build a beat.

The core idea: **the drawing is the prompt.** Every sketch is compiled into a
human-readable prompt line (e.g. `fluttering jagged, gritty metallic impact,
bright airy character, 0.8s`) sent to the ElevenLabs Sound Effects API. If that
call fails, the prompt's features drive a local Tone.js synth instead, so a
sketch always turns into a playable pad — with or without the network.

## Sound mapping

### Ink color → timbre family

The four inks are the classic vibrant risograph spot colors (Blue, Yellow,
Orange, Fluorescent Pink):

| Ink    | Hex       | Timbre                                                  |
|--------|-----------|---------------------------------------------------------|
| Blue   | `#2FA8DE` | Resonant tone — detuned triangle pad with LFO vibrato   |
| Yellow | `#F4C20D` | Grainy texture — band-passed noise with wobbling filter |
| Orange | `#F15A2B` | Metallic impact — band-passed noise burst + pitch-drop thump |
| Pink   | `#F0509E` | Deep sub drone — dual detuned sine sub-bass, long decay |

If a sketch mixes inks, the color with the greatest total drawn length wins.
Strokes are multiply-blended, so overlapping inks mix like overlapping riso
passes on paper (blue × yellow → green, orange × pink → red).

### Stroke geometry → sound parameters

| Feature            | Measured as                                    | Maps to                                   |
|--------------------|------------------------------------------------|-------------------------------------------|
| Vertical position  | Mean Y of all points (inverted, normalized)    | Pitch, 80–880 Hz (high on paper = higher) |
| Total drawn length | Sum of segment lengths across strokes          | Duration, 0.25–1.6 s                      |
| Drawing speed      | Mean px/ms across segments                     | Vibrato / filter-wobble rate ("fluttering" vs "slow-moving") |
| Jaggedness         | Mean absolute turn angle between segments      | Grit / detune ("jagged, gritty" vs "smooth, rounded") |

### Prompt line

The same features are serialized into the prompt shown on the LCD:

```
{speed word} {jaggedness words} {ink word}, {brightness words} character, {duration}s
```

- speed: `fluttering` (> 1.1 px/ms) · `steady` · `slow-moving` (< 0.35 px/ms)
- jaggedness: `jagged, gritty` (> 0.5) · `smooth, rounded`
- brightness (from vertical position): `bright, airy` (> 0.6) · `warm` · `dark, weighty` (< 0.35)

## Features

- **Sketch paper** — pointer-drawn canvas on a cold-gray ground with a dot
  grid, four riso ink swatches, UNDO and CLR. Strokes are wide
  (12px, round caps) and composited with a `multiply` blend at less than
  full opacity, the way overlapping riso ink passes actually look: two
  crossing strokes mix into a visibly different third color rather than one
  simply drawing over the other. The live in-progress stroke redraws once
  from the clean stroke history on pen-up, so it settles into a single flat
  multiply pass instead of the self-overlapping round caps of the live
  preview darkening further than intended.
- **Generate** — analyzes the sketch, shows staged status on the LCD
  (`reading sketch` → `sending prompt to sfx model` → `rendering audio`), fills the
  next empty pad with the sound, a generated thumbnail, and its prompt, then
  plays it with an e-ink refresh flash.
- **Four pads (P1–P4)** — tap to play; each shows a generative riso-shape
  thumbnail, an ink LED, and a family tag (SUB / IMPACT / TONE / TEXTR) plus
  pitch offset. The thumbnail is a single bold shape drawn from a ~16-shape
  library modelled on classic riso geometry (circle, triangle, polygon, star,
  sunburst, flower, target rings, crescent, arcs, nested squares, asterisk,
  semicircle, pie-split, squiggle) rendered in the sketch's dominant ink color
  on a cold-gray ground. A dotted grain texture
  is punched through the shape (a jittered field of tiny holes, letting the
  gray show through as riso speckle). The shape and grain are seeded from the
  sketch's own features (jaggedness, duration, pitch, flutter rate), so one
  sketch always regenerates the same motif and different sketches read as
  distinct. This replaced an earlier canvas snapshot of the sketch, which
  looked blurry at pad size.
- **Pad controls** — pitch fader (±12 semitones), DEL to clear a slot.
- **Step sequencer (SEQ)** — a shared master clock (40–240 BPM) and a 16-step
  grid (one row per pad) let you place pads on exact beats relative to each
  other, rather than each pad looping independently on its own duration.
  PLAY/STOP starts and stops the clock; a playhead outline sweeps across the
  grid while running. Steps can be toggled whether or not PLAY is running,
  and persist per pad slot even if that slot's sound is later regenerated.
- **Aesthetic** — e-ink instrument panel: IBM Plex Mono, `#eceef0` chassis,
  hairline `rgba(28,29,32,.22)` borders, invert-flash animations, blinking LCD cursor.

## Layout

Tink-on is a landscape-shaped device: a masthead bar over two side-by-side
panes. The left pane holds everything tied to a single sound — paper, ink
row, prompt/GENERATE, and the pad controls (pitch fader, DEL). The right
pane is the pad grid over the step sequencer, and is a flex column: the
sequencer keeps its natural height and the pad grid flexes to fill the rest,
so the right pane never has to scroll regardless of device height. (The
left pane can still scroll on a short screen, since it holds the tall sketch
canvas.)

On a phone held upright (portrait), the two-pane layout doesn't have room to
work, so the device is hidden and a "ROTATE TO LANDSCAPE" hint is shown
instead (gated to narrow viewports via `orientation: portrait` combined with
`max-width: 899px`, so a resized-but-still-wide desktop window isn't mistaken
for a phone). On desktop, or a phone turned sideways, the device shows
directly — centered with rounded-corner chrome above ~900px wide, full-bleed
below it.

## Architecture

Static frontend, one vendored library, zero build step, plus one serverless
function:

- `index.html` — masthead + two-pane layout (sketch + controls pane, pad
  grid / sequencer pane), plus the portrait rotate-hint screen; loads
  `vendor/tone.js` before `app.js`
- `styles.css` — design tokens and riso/e-ink styling; the device is
  landscape-shaped at every breakpoint (full-bleed on narrow/short viewports,
  centered card above ~900px wide), and each pane scrolls internally if its
  content exceeds the device's height
- `app.js` — stroke capture (wide multiply-blended riso strokes), feature
  analysis, prompt compiler, generative riso-shape thumbnails, AI-fetch +
  trim, Tone.js fallback synth, pad/pitch state, step-sequencer clock and
  scheduling
- `vendor/tone.js` — the [Tone.js](https://tonejs.github.io) UMD build,
  committed to the repo rather than pulled from a CDN so the site stays
  self-contained and buildless (exposes the global `Tone`)
- `api/generate-sound.js` — Vercel Node serverless function; proxies prompts
  to the ElevenLabs Sound Effects API, keeps `ELEVENLABS_API_KEY` server-side.
  Plain `fetch`, no SDK, no `package.json` — stays zero-build.

With a key configured, audio comes from ElevenLabs; otherwise (or on any
failure) it's synthesized client-side by Tone.js, and no data leaves the
browser at all.

## AI sound generation (ElevenLabs Sound Effects API)

The prompt line is sent to a real generative model: `POST /api/generate-sound`
(`api/generate-sound.js`) proxies it to ElevenLabs' Sound Effects API
(`POST /v1/sound-generation`, `model_id: eleven_text_to_sound_v2`), holding
`ELEVENLABS_API_KEY` server-side — the key is never shipped to the client.
This endpoint (not the Music API) is the right fit: it's built for one-shot
textures and impacts rather than multi-section songs, and it natively accepts
0.5–30s clips — right in range for a sampler hit (0.25–1.6s) — instead of
Music's 3s floor.

- The function passes the sketch's exact target duration as
  `duration_seconds` (clamped to the API's 0.5s minimum). Only sketches under
  0.5s need the response trimmed afterward — `trimBuffer` in `app.js` cuts it
  down with a 30ms fade-out; everything else plays back close to full length.
- GENERATE always attempts the API (there is no on/off toggle). On failure —
  no key configured, rate limit, network error, timeout — it logs a warning,
  shows `sfx model unavailable — synth` on the LCD, and voices the pad with
  the Tone.js fallback instead.
- AI-generated audio plays through an `AudioBufferSourceNode` with
  `playbackRate` driven by the pitch fader (same ±12 semitone range as the
  synth path). Both AI and synth playback go through the same `play(i, when)`
  path, which accepts an optional AudioContext time so the step sequencer can
  schedule hits precisely ahead of now instead of just "play immediately."

This is a paid ElevenLabs feature and each AI generation is a billed request;
the Tone.js synth is the free, always-available fallback and is what powers
the app when `ELEVENLABS_API_KEY` isn't set.

### Tone.js fallback synth

When the API call fails, the pad is voiced locally by Tone.js. Tone is pointed
at the app's own AudioContext (`Tone.setContext(ac())`) so its clock is the
same one the sequencer schedules against — a hit scheduled at AudioContext
time `t` lines up whether it's an AI buffer or a Tone voice. Each ink family
maps to a Tone voice: **orange** (impact) = `MembraneSynth` pitch-drop thump +
band-passed `NoiseSynth` burst; **blue** (tone) = detuned `fattriangle`
`Synth` through `Vibrato` + a lowpass; **yellow** (texture) = pink `Noise`
through a wobbling `AutoFilter` band-pass; **pink** (sub) = detuned `fatsine`
`Synth` with a long decay (level-boosted, since a low sub reads much quieter
than the other voices). Voice nodes are disposed on a timer after they finish
sounding, since Tone nodes aren't garbage-collected like bare Web Audio nodes.

## Non-goals (v1)

- Saving kits or sequencer patterns between sessions
- Multi-touch simultaneous pad playing
- Patterns longer than one 16-step bar, or per-pad step counts/subdivisions
