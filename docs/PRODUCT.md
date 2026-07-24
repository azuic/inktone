# Inktone — S-4 Sketch Sampler

## Product overview

Inktone is a sketch-to-sound sampler. The user draws on a small sheet of "paper" with
colored inks; the app reads the sketch — its color, position, length, speed, and
jaggedness — and translates it into a synthesized sound that lands on one of six
sampler pads. Pads can be retriggered, pitched, looped, and layered into a beat.

The core idea: **the drawing is the prompt.** Every sketch is compiled into a
human-readable prompt line (e.g. `fluttering jagged, gritty metallic impact,
bright airy character, 0.8s`) — exactly the string a production integration would
send to a generative sound-effects API. The current build renders that prompt
locally with Web Audio synthesis so the loop is instant and free.

## Sound mapping

### Ink color → timbre family

| Ink   | Hex       | Timbre                                                  |
|-------|-----------|---------------------------------------------------------|
| Black | `#1c1d20` | Deep sub drone — dual detuned sine sub-bass, long decay |
| Red   | `#a83f38` | Metallic impact — band-passed noise burst + pitch-drop thump |
| Blue  | `#33549c` | Resonant tone — detuned triangle pad with LFO vibrato   |
| Ochre | `#95782e` | Grainy texture — band-passed noise with wobbling filter |

If a sketch mixes inks, the color with the greatest total drawn length wins.

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

- **Sketch paper** — pointer-drawn canvas with dot grid, four ink swatches, UNDO and CLR.
- **Generate** — analyzes the sketch, shows staged status on the LCD
  (`reading sketch` → `sending prompt to sfx model` → `rendering audio`), fills the
  next empty pad with the sound, its prompt, and a thumbnail of the sketch, then
  plays it with an e-ink refresh flash.
- **Six pads (P1–P6)** — tap to play; each shows the sketch thumbnail, an ink LED,
  and a family tag (SUB / IMPACT / TONE / TEXTR) plus pitch offset.
- **Pad controls** — pitch fader (±12 semitones), LOOP toggle (retriggers at the
  sound's duration), DEL to clear a slot.
- **Aesthetic** — e-ink instrument panel: IBM Plex Mono, `#eceef0` chassis,
  hairline `rgba(28,29,32,.22)` borders, invert-flash animations, blinking LCD cursor.

## Architecture

Static frontend, zero npm dependencies, zero build step, plus one serverless
function:

- `index.html` — layout (device panel, paper, prompt LCD, pad grid, control strip)
- `styles.css` — design tokens and e-ink styling; responsive (full-screen phone-shaped
  panel on mobile, centered device on desktop)
- `app.js` — stroke capture, feature analysis, prompt compiler, AI-fetch +
  trim, Web Audio synth engine (fallback), pad/loop/pitch state
- `api/generate-sound.js` — Vercel Node serverless function; proxies prompts
  to ElevenLabs, keeps `ELEVENLABS_API_KEY` server-side. Plain `fetch`, no SDK,
  no `package.json` — stays zero-build.

With AI mode on and a key configured, audio comes from ElevenLabs; otherwise
(or on any failure) it's synthesized client-side via the Web Audio API, and no
data leaves the browser at all.

## AI sound generation (ElevenLabs Music API)

The prompt line is sent to a real generative model: `POST /api/generate-sound`
(`api/generate-sound.js`) proxies it to ElevenLabs' Music API
(`POST /v1/music`, `model_id: music_v2`, `force_instrumental: true`), holding
`ELEVENLABS_API_KEY` server-side — the key is never shipped to the client.

- ElevenLabs' `music.compose` has a 3,000ms floor, above a sampler hit's
  0.25–1.6s range, so the function always requests the 3s minimum. The client
  decodes the response and trims it to the sketch's target duration with a
  30ms fade-out (`trimBuffer` in `app.js`), so it still plays like a short hit
  rather than a music clip.
- The **AI** chip in the ink row toggles generation on/off. On (default): tap
  GENERATE and Inktone requests real audio; on failure (no key configured,
  rate limit, network error, timeout) it logs a warning and falls back to the
  local synth automatically, with the LCD noting the fallback. Off: skips the
  network call entirely and always uses the instant, free local synth.
- Generated audio plays through an `AudioBufferSourceSource` with
  `playbackRate` driven by the pitch fader (same ±12 semitone range as the
  synth path), and loops the same way — `setInterval` retriggering `play()`
  at the pad's duration.

This is a paid ElevenLabs feature and each AI generation is a billed request;
the local synth remains the free, always-available fallback and is what powers
the app when `ELEVENLABS_API_KEY` isn't set.

## Non-goals (v1)

- Sequencer / step recording (loop toggle covers rhythmic use)
- Saving kits between sessions
- Multi-touch simultaneous pad playing
