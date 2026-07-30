'use strict';

// Vibrant risograph ink colors (Blue / Yellow / Orange / Fluorescent Pink),
// the four classic Riso spot inks. Strokes are drawn with a multiply blend
// (see drawStroke), so overlapping inks mix into a third color the way
// overlapping riso passes do on paper: blue×yellow→green, orange×pink→red.
const INKS = [
  { key: 'blue', hex: '#2FA8DE', word: 'resonant tone', tag: 'TONE' },
  { key: 'yellow', hex: '#F4C20D', word: 'grainy texture', tag: 'TEXTR' },
  { key: 'orange', hex: '#F15A2B', word: 'metallic impact', tag: 'IMPACT' },
  { key: 'pink', hex: '#F0509E', word: 'deep sub drone', tag: 'SUB' },
];

const PAPER_HEX = '#f4f5f7'; // sketch canvas ground: cold gray
const PAPER_GRID_HEX = '#c4c8cf';
const THUMB_BG_HEX = '#e5e7ea'; // pad thumbnail ground: cold gray
const STROKE_WIDTH = 12;
const STROKE_ALPHA = 0.92;

const PAPER_H = 224;
const SLOTS = 4;

const $ = (id) => document.getElementById(id);
const device = $('device');
const canvas = $('paper');
const ctx = canvas.getContext('2d');

const state = {
  ink: 'blue',
  generating: false,
  pads: Array(SLOTS).fill(null), // {params, prompt, thumb, color, pitch, buffer}
  sel: -1,
};

let strokes = [];
let cur = null;

/* ---- paper ---- */

function sizeCanvas() {
  const dpr = devicePixelRatio || 1;
  const w = canvas.getBoundingClientRect().width;
  canvas.width = w * dpr;
  canvas.height = PAPER_H * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  redraw();
}

function drawGrid() {
  const w = canvas.width / (devicePixelRatio || 1);
  ctx.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 1;
  ctx.fillStyle = PAPER_HEX;
  ctx.fillRect(0, 0, w, PAPER_H);
  ctx.fillStyle = PAPER_GRID_HEX;
  for (let x = 14; x < w; x += 18)
    for (let y = 14; y < PAPER_H; y += 18)
      ctx.fillRect(x, y, 1.5, 1.5);
}

// Multiply blend + <1 alpha approximates how riso ink lays down: solid over
// paper, but a visibly different third color where two inks overlap.
function drawStroke(s) {
  ctx.globalCompositeOperation = 'multiply';
  ctx.globalAlpha = STROKE_ALPHA;
  ctx.strokeStyle = INKS.find((i) => i.key === s.color).hex;
  ctx.lineWidth = STROKE_WIDTH;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  s.pts.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
  ctx.stroke();
  ctx.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 1;
}

function redraw() {
  drawGrid();
  for (const s of strokes) drawStroke(s);
}

function pos(e) {
  const r = canvas.getBoundingClientRect();
  return { x: e.clientX - r.left, y: e.clientY - r.top, t: performance.now() };
}

canvas.addEventListener('pointerdown', (e) => {
  canvas.setPointerCapture(e.pointerId);
  cur = { color: state.ink, pts: [pos(e)] };
  renderPaperEmpty();
});
canvas.addEventListener('pointermove', (e) => {
  if (!cur) return;
  const p = pos(e);
  const pts = cur.pts;
  const l = pts[pts.length - 1];
  if (Math.hypot(p.x - l.x, p.y - l.y) < 2) return;
  pts.push(p);
  ctx.globalCompositeOperation = 'multiply';
  ctx.globalAlpha = STROKE_ALPHA;
  ctx.strokeStyle = INKS.find((i) => i.key === cur.color).hex;
  ctx.lineWidth = STROKE_WIDTH;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(l.x, l.y);
  ctx.lineTo(p.x, p.y);
  ctx.stroke();
  ctx.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 1;
});
function penUp() {
  if (!cur) return;
  if (cur.pts.length > 1) strokes.push(cur);
  cur = null;
  // The live preview draws overlapping short multiply-blended segments as
  // the pointer moves, which self-darkens near-adjacent round caps well
  // beyond one clean pass. Redraw from the stroke history so the finished
  // stroke composites as a single multiply pass, same as after undo/clear.
  redraw();
  renderPaperEmpty();
}
canvas.addEventListener('pointerup', penUp);
canvas.addEventListener('pointercancel', penUp);

/* ---- sketch analysis ---- */

function analyze() {
  let len = 0, n = 0, ySum = 0, speedSum = 0, jag = 0, jn = 0;
  const colorLen = {};
  for (const s of strokes) {
    let sl = 0;
    const P = s.pts;
    for (let i = 1; i < P.length; i++) {
      const d = Math.hypot(P[i].x - P[i - 1].x, P[i].y - P[i - 1].y);
      sl += d;
      ySum += P[i].y;
      n++;
      const dt = Math.max(1, P[i].t - P[i - 1].t);
      speedSum += d / dt;
      if (i > 1) {
        const a1 = Math.atan2(P[i - 1].y - P[i - 2].y, P[i - 1].x - P[i - 2].x);
        const a2 = Math.atan2(P[i].y - P[i - 1].y, P[i].x - P[i - 1].x);
        let da = Math.abs(a2 - a1);
        if (da > Math.PI) da = 2 * Math.PI - da;
        jag += da;
        jn++;
      }
    }
    len += sl;
    colorLen[s.color] = (colorLen[s.color] || 0) + sl;
  }
  const dom = Object.keys(colorLen).sort((a, b) => colorLen[b] - colorLen[a])[0];
  const yNorm = 1 - ySum / Math.max(1, n) / PAPER_H;
  const speed = speedSum / Math.max(1, n);
  const jagN = Math.min(1, jag / Math.max(1, jn) / 0.9);
  return {
    color: dom,
    freq: 80 + Math.pow(yNorm, 1.6) * 800,
    dur: Math.min(1.6, 0.25 + len / 900),
    jag: jagN,
    rate: Math.min(12, 1 + speed * 8),
    speed,
    yNorm,
  };
}

function promptFor(f) {
  const ink = INKS.find((i) => i.key === f.color);
  const sp = f.speed > 1.1 ? 'fluttering' : f.speed < 0.35 ? 'slow-moving' : 'steady';
  const jg = f.jag > 0.5 ? 'jagged, gritty' : 'smooth, rounded';
  const hi = f.yNorm > 0.6 ? 'bright, airy' : f.yNorm < 0.35 ? 'dark, weighty' : 'warm';
  return `${sp} ${jg} ${ink.word}, ${hi} character, ${f.dur.toFixed(1)}s`;
}

/* ---- pad art ----
 * Each generated pad shows a single bold riso shape (drawn from a small
 * library modelled on classic riso geometry — circle, star, sunburst,
 * flower, rings, crescent, etc.) in the sketch's dominant ink color, on a
 * cold-gray ground. The shape is given a dotted grain texture by punching
 * a jittered field of tiny holes through it, so the gray shows through as
 * riso-print speckle. Everything is seeded from the sketch's own features,
 * so one sketch always regenerates the same motif and different sketches
 * read as distinct.
 */

function mulberry32(seed) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Each shape draws centered at (cx,cy) within radius r, using the context's
// current fill/stroke style (the ink color). rot is a base rotation.
function shCircle(g, cx, cy, r) {
  g.beginPath();
  g.arc(cx, cy, r, 0, Math.PI * 2);
  g.fill();
}
function shTriangle(g, cx, cy, r, rot) {
  g.beginPath();
  for (let i = 0; i < 3; i++) {
    const a = rot - Math.PI / 2 + (i / 3) * Math.PI * 2;
    const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r;
    i ? g.lineTo(x, y) : g.moveTo(x, y);
  }
  g.closePath();
  g.fill();
}
function shPolygon(sides) {
  return (g, cx, cy, r, rot) => {
    g.beginPath();
    for (let i = 0; i < sides; i++) {
      const a = rot + (i / sides) * Math.PI * 2;
      const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r;
      i ? g.lineTo(x, y) : g.moveTo(x, y);
    }
    g.closePath();
    g.fill();
  };
}
function shStar(points, innerRatio) {
  return (g, cx, cy, r, rot) => {
    g.beginPath();
    for (let i = 0; i < points * 2; i++) {
      const a = rot + (i / (points * 2)) * Math.PI * 2;
      const rr = i % 2 ? r * innerRatio : r;
      const x = cx + Math.cos(a) * rr, y = cy + Math.sin(a) * rr;
      i ? g.lineTo(x, y) : g.moveTo(x, y);
    }
    g.closePath();
    g.fill();
  };
}
function shTarget(g, cx, cy, r) {
  const rings = 3;
  g.lineWidth = r / (rings * 2 + 0.5);
  for (let i = rings; i >= 1; i--) {
    g.beginPath();
    g.arc(cx, cy, (r * i) / rings - g.lineWidth * 0.5, 0, Math.PI * 2);
    g.stroke();
  }
  g.beginPath();
  g.arc(cx, cy, g.lineWidth * 0.9, 0, Math.PI * 2);
  g.fill();
}
function shFlower(g, cx, cy, r, rot) {
  const petals = 6;
  const pr = r * 0.42;
  for (let i = 0; i < petals; i++) {
    const a = rot + (i / petals) * Math.PI * 2;
    g.beginPath();
    g.arc(cx + Math.cos(a) * r * 0.55, cy + Math.sin(a) * r * 0.55, pr, 0, Math.PI * 2);
    g.fill();
  }
  g.beginPath();
  g.arc(cx, cy, r * 0.34, 0, Math.PI * 2);
  g.fill();
}
function shSun(g, cx, cy, r, rot) {
  shStar(12, 0.62)(g, cx, cy, r, rot);
  g.beginPath();
  g.arc(cx, cy, r * 0.5, 0, Math.PI * 2);
  g.fill();
}
function shCrescent(g, cx, cy, r, rot) {
  g.beginPath();
  g.arc(cx, cy, r, 0, Math.PI * 2);
  g.fill();
  const prev = g.globalCompositeOperation;
  g.globalCompositeOperation = 'destination-out';
  g.beginPath();
  g.arc(cx + Math.cos(rot) * r * 0.55, cy + Math.sin(rot) * r * 0.55, r * 0.86, 0, Math.PI * 2);
  g.fill();
  g.globalCompositeOperation = prev;
}
function shArcs(g, cx, cy, r, rot) {
  const rings = 3;
  g.lineWidth = r / (rings * 2 + 1);
  g.lineCap = 'round';
  for (let i = rings; i >= 1; i--) {
    g.beginPath();
    g.arc(cx, cy + r * 0.35, (r * i) / rings, rot + Math.PI, rot + Math.PI * 2);
    g.stroke();
  }
}
function shSquares(g, cx, cy, r) {
  const rings = 3;
  g.lineWidth = r / (rings * 2);
  for (let i = rings; i >= 1; i--) {
    const s = (r * i) / rings;
    g.strokeRect(cx - s, cy - s, s * 2, s * 2);
  }
}
function shAsterisk(g, cx, cy, r, rot) {
  const arms = 6;
  g.lineWidth = r * 0.26;
  g.lineCap = 'round';
  for (let i = 0; i < arms; i++) {
    const a = rot + (i / arms) * Math.PI;
    g.beginPath();
    g.moveTo(cx - Math.cos(a) * r, cy - Math.sin(a) * r);
    g.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r);
    g.stroke();
  }
}
function shSemicircle(g, cx, cy, r, rot) {
  g.beginPath();
  g.moveTo(cx, cy);
  g.arc(cx, cy, r, rot, rot + Math.PI);
  g.closePath();
  g.fill();
}
function shPieSplit(g, cx, cy, r, rot) {
  for (const off of [0, Math.PI]) {
    g.beginPath();
    g.moveTo(cx, cy);
    g.arc(cx, cy, r, rot + off, rot + off + Math.PI / 2);
    g.closePath();
    g.fill();
  }
}
function shSquiggle(g, cx, cy, r, rot) {
  g.lineWidth = r * 0.3;
  g.lineCap = 'round';
  g.lineJoin = 'round';
  g.beginPath();
  const w = r * 1.7;
  for (let i = 0; i <= 40; i++) {
    const t = i / 40;
    const x = cx - w / 2 + t * w;
    const y = cy + Math.sin(rot + t * Math.PI * 3) * r * 0.55;
    i ? g.lineTo(x, y) : g.moveTo(x, y);
  }
  g.stroke();
}

const THUMB_SHAPES = [
  shCircle, shTriangle, shPolygon(6), shPolygon(8),
  shStar(5, 0.45), shStar(8, 0.5), shTarget, shFlower, shSun,
  shCrescent, shArcs, shSquares, shAsterisk, shSemicircle, shPieSplit, shSquiggle,
];

function makeThumb(f) {
  const size = 240;
  const t = document.createElement('canvas');
  t.width = size;
  t.height = size;
  const g = t.getContext('2d');

  const seed = Math.floor(f.jag * 9973) ^ Math.floor(f.dur * 7919) ^ Math.floor(f.freq * 31) ^ Math.floor(f.rate * 6151);
  const rng = mulberry32(seed);
  const color = INKS.find((i) => i.key === f.color).hex;

  // Draw the shape on its own layer so the grain can punch holes only where
  // the ink is, letting the gray ground show through as speckle.
  const layer = document.createElement('canvas');
  layer.width = layer.height = size;
  const sg = layer.getContext('2d');
  sg.fillStyle = sg.strokeStyle = color;
  sg.lineJoin = 'round';
  const shape = THUMB_SHAPES[Math.floor(rng() * THUMB_SHAPES.length)];
  shape(sg, size / 2, size / 2, size * 0.36, rng() * Math.PI * 2);

  // Dotted grain: punch a jittered field of tiny holes through the ink.
  sg.globalCompositeOperation = 'destination-out';
  const stepPx = 4.4;
  for (let y = 0; y < size; y += stepPx) {
    for (let x = 0; x < size; x += stepPx) {
      if (rng() > 0.5) continue;
      const jx = x + (rng() - 0.5) * stepPx;
      const jy = y + (rng() - 0.5) * stepPx;
      sg.beginPath();
      sg.arc(jx, jy, 1.2 + rng() * 0.9, 0, Math.PI * 2);
      sg.fill();
    }
  }
  sg.globalCompositeOperation = 'source-over';

  g.fillStyle = THUMB_BG_HEX;
  g.fillRect(0, 0, size, size);
  g.drawImage(layer, 0, 0);

  return t.toDataURL('image/png');
}

/* ---- audio engine ---- */

let _ac = null;

function ac() {
  if (!_ac) _ac = new (window.AudioContext || window.webkitAudioContext)();
  if (_ac.state === 'suspended') _ac.resume();
  return _ac;
}

/* ---- Tone.js fallback synth ----
 * When the ElevenLabs call fails, a pad is voiced locally by Tone.js. Tone is
 * pointed at the app's own AudioContext (Tone.setContext), so its clock is the
 * same one the step sequencer schedules against — a hit scheduled at
 * AudioContext time `t` lines up whether it plays back an AI buffer or a Tone
 * voice. Each of the four ink families maps to a Tone voice.
 */
let _toneReady = false;
let _toneOut = null;

function ensureTone() {
  if (_toneReady) return;
  Tone.setContext(ac());
  _toneOut = new Tone.Gain(0.7).toDestination();
  _toneReady = true;
}

// Tone nodes aren't garbage-collected the way bare Web Audio nodes are, so
// free each voice's nodes once it has finished sounding.
function disposeLater(nodes, endTime) {
  const ms = Math.max(0, endTime - ac().currentTime) * 1000 + 400;
  setTimeout(() => { for (const n of nodes) { try { n.dispose(); } catch (e) {} } }, ms);
}

function playSynth(f, fr, dur, t) {
  ensureTone();
  const out = _toneOut;

  if (f.color === 'orange') {
    // metallic impact: pitch-drop membrane thump + band-passed noise burst
    const membrane = new Tone.MembraneSynth({
      pitchDecay: 0.05, octaves: 5,
      envelope: { attack: 0.001, decay: 0.3, sustain: 0, release: 0.1 },
    }).connect(out);
    membrane.triggerAttackRelease(Math.max(40, fr * 0.6), dur * 0.6, t);
    const bp = new Tone.Filter({ type: 'bandpass', frequency: fr * 2, Q: 8 - f.jag * 5 }).connect(out);
    const noise = new Tone.NoiseSynth({
      noise: { type: 'white' },
      envelope: { attack: 0.001, decay: dur * 0.5, sustain: 0 },
    }).connect(bp);
    noise.triggerAttackRelease(dur * 0.5, t);
    disposeLater([membrane, noise, bp], t + dur + 0.3);
  } else if (f.color === 'blue') {
    // resonant tone: detuned triangle pad through vibrato + a lowpass
    const lp = new Tone.Filter({ type: 'lowpass', frequency: fr * 4 }).connect(out);
    const vib = new Tone.Vibrato({ frequency: f.rate, depth: 0.1 + f.jag * 0.25 }).connect(lp);
    const synth = new Tone.Synth({
      oscillator: { type: 'fattriangle', count: 2, spread: 6 + f.jag * 25 },
      envelope: { attack: 0.05, decay: 0.2, sustain: 0.6, release: dur * 0.6 },
    }).connect(vib);
    synth.triggerAttackRelease(fr, dur, t);
    disposeLater([synth, vib, lp], t + dur + 0.6);
  } else if (f.color === 'yellow') {
    // grainy texture: pink noise through a wobbling band-pass auto-filter
    const env = new Tone.AmplitudeEnvelope({ attack: 0.04, decay: 0.1, sustain: 0.75, release: 0.12 }).connect(out);
    const auto = new Tone.AutoFilter({
      frequency: f.rate, depth: 1, baseFrequency: fr * 2, octaves: 2,
      filter: { type: 'bandpass', Q: 2 + f.jag * 6 },
    }).connect(env).start(t);
    const noise = new Tone.Noise('pink').connect(auto);
    noise.start(t);
    noise.stop(t + dur + 0.05);
    env.triggerAttackRelease(dur, t);
    disposeLater([noise, auto, env], t + dur + 0.3);
  } else {
    // pink: deep sub drone, detuned sines, long decay (boosted — a low sub
    // reads much quieter than the other voices at matched levels)
    const synth = new Tone.Synth({
      volume: 10,
      oscillator: { type: 'fatsine', count: 2, spread: 8 },
      envelope: { attack: 0.02, decay: dur * 1.2, sustain: 0.15, release: 0.3 },
    }).connect(out);
    synth.triggerAttackRelease(Math.max(35, fr * 0.5), dur, t);
    disposeLater([synth], t + dur + 0.5);
  }
}

// `when` (AudioContext time) lets callers schedule a hit precisely ahead of
// now — the step sequencer needs this for sample-accurate timing; manual
// pad taps just omit it and play immediately.
function play(i, when) {
  const pad = state.pads[i];
  if (!pad) return;
  const a = ac();
  const t = when != null ? when : a.currentTime;
  const semi = Math.pow(2, pad.pitch / 12);

  if (pad.buffer) {
    // AI-generated audio: play the (already trimmed) buffer at the pitched rate.
    const src = a.createBufferSource();
    src.buffer = pad.buffer;
    src.playbackRate.value = semi;
    const out = a.createGain();
    out.gain.value = 0.9;
    src.connect(out).connect(a.destination);
    src.start(t);
    scheduleFlash(i, t, Math.min(600, (pad.buffer.duration * 1000) / semi));
    return;
  }

  const f = pad.params;
  playSynth(f, f.freq * semi, f.dur, t);
  scheduleFlash(i, t, Math.min(600, f.dur * 1000));
}

// Schedules the pad's invert-flash to fire when the audio actually starts
// (t may be in the future for sequencer hits) rather than at call time.
function scheduleFlash(i, t, ms) {
  const delayMs = Math.max(0, (t - ac().currentTime) * 1000);
  setTimeout(() => flashPad(i, ms), delayMs);
}

function flashPad(i, ms) {
  const entry = padEls[i];
  const el = entry.root;
  el.classList.remove('playing');
  void el.offsetWidth; // restart the animation
  el.classList.add('playing');
  clearTimeout(entry.flashTimer);
  entry.flashTimer = setTimeout(() => el.classList.remove('playing'), ms);
}

/* ---- generate flow ---- */

function setLcd(text) {
  $('lcdText').textContent = text;
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Requests a clip from the ElevenLabs Sound Effects API (via our
// /api/generate-sound proxy, which holds the key server-side), targeting the
// sketch's exact duration — the API accepts 0.5-30s, so only sketches under
// 0.5s need the returned audio trimmed down afterward.
async function fetchAiBuffer(prompt, targetDurSec) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 45000);
  try {
    const resp = await fetch('/api/generate-sound', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt, durationSec: targetDurSec }),
      signal: controller.signal,
    });
    if (!resp.ok) throw new Error(`generation failed: ${resp.status}`);
    const arrBuf = await resp.arrayBuffer();
    const decoded = await ac().decodeAudioData(arrBuf);
    return targetDurSec < decoded.duration ? trimBuffer(decoded, targetDurSec) : decoded;
  } finally {
    clearTimeout(timer);
  }
}

function trimBuffer(buffer, targetDurSec) {
  const a = ac();
  const targetLen = Math.max(1, Math.min(buffer.length, Math.round(targetDurSec * buffer.sampleRate)));
  const out = a.createBuffer(buffer.numberOfChannels, targetLen, buffer.sampleRate);
  const fadeLen = Math.min(targetLen, Math.round(0.03 * buffer.sampleRate)); // 30ms fade-out
  for (let ch = 0; ch < buffer.numberOfChannels; ch++) {
    const src = buffer.getChannelData(ch);
    const dst = out.getChannelData(ch);
    for (let i = 0; i < targetLen; i++) {
      const fadeMul = i > targetLen - fadeLen ? (targetLen - i) / fadeLen : 1;
      dst[i] = src[i] * fadeMul;
    }
  }
  return out;
}

async function generate() {
  if (state.generating) return;
  if (!strokes.length) {
    setLcd('nothing sketched — draw first');
    return;
  }
  ac(); // resume audio inside the user gesture
  const f = analyze();
  const prompt = promptFor(f);
  const th = makeThumb(f);
  state.generating = true;
  $('genBtn').classList.add('waiting');
  $('genBtn').textContent = 'WAIT';
  setLcd('reading sketch');
  await wait(300);

  // Always try the ElevenLabs Sound Effects API; on any failure fall back to
  // the local Tone.js synth so a pad always ends up with a playable sound.
  let buffer = null;
  setLcd('> sending prompt to sfx model');
  try {
    buffer = await fetchAiBuffer(prompt, f.dur);
    setLcd('> rendering audio');
    await wait(150);
  } catch (err) {
    console.warn('AI generation failed, falling back to Tone.js synth:', err);
    setLcd('sfx model unavailable — synth');
    await wait(500);
  }

  let slot = state.pads.indexOf(null);
  if (slot < 0) slot = state.sel >= 0 ? state.sel : 0;
  state.pads[slot] = { params: f, prompt, thumb: th, color: f.color, pitch: 0, buffer };
  state.generating = false;
  state.sel = slot;
  $('genBtn').classList.remove('waiting');
  $('genBtn').textContent = 'GENERATE';
  setLcd(prompt);
  device.classList.remove('flash');
  void device.offsetWidth;
  device.classList.add('flash');
  setTimeout(() => device.classList.remove('flash'), 350);
  strokes = [];
  redraw();
  render();
  play(slot);
}

/* ---- pads ---- */

function tapPad(i) {
  const pad = state.pads[i];
  state.sel = i;
  render();
  if (pad) play(i);
}

/* ---- controls ---- */

function setPitchVal(v) {
  const p = state.pads[state.sel];
  if (!p) return;
  p.pitch = Math.max(-12, Math.min(12, Math.round(v)));
  render();
}

const fader = $('fader');
let faderDown = false;

function faderVal(e) {
  const r = fader.getBoundingClientRect();
  return ((e.clientX - r.left) / r.width) * 24 - 12;
}
fader.addEventListener('pointerdown', (e) => {
  fader.setPointerCapture(e.pointerId);
  faderDown = true;
  setPitchVal(faderVal(e));
});
fader.addEventListener('pointermove', (e) => {
  if (faderDown) setPitchVal(faderVal(e));
});
fader.addEventListener('pointerup', () => (faderDown = false));
fader.addEventListener('pointercancel', () => (faderDown = false));

$('delBtn').addEventListener('click', () => {
  const i = state.sel;
  if (i < 0 || !state.pads[i]) return;
  state.pads[i] = null;
  setLcd('slot cleared');
  render();
});

$('undoBtn').addEventListener('click', () => {
  strokes.pop();
  redraw();
  renderPaperEmpty();
});

$('clrBtn').addEventListener('click', () => {
  strokes = [];
  redraw();
  renderPaperEmpty();
});

$('genBtn').addEventListener('click', generate);

// keyboard: 1–4 trigger pads
document.addEventListener('keydown', (e) => {
  const k = parseInt(e.key, 10);
  if (k >= 1 && k <= SLOTS && !e.metaKey && !e.ctrlKey) tapPad(k - 1);
});

/* ---- sequencer ----
 * A shared clock (not each pad looping on its own timer) is what lets a
 * pad be placed on a specific beat relative to another. STEPS is a single
 * 16-step bar of 16th notes at `bpm`; scheduling uses the standard Web
 * Audio lookahead pattern (poll frequently, schedule audio a bit ahead of
 * now) so timing stays sample-accurate instead of drifting like setInterval.
 */

const SEQ_STEPS = 16;
const SEQ_LOOKAHEAD_MS = 25;
const SEQ_SCHEDULE_AHEAD_SEC = 0.1;

const seq = {
  bpm: 120,
  playing: false,
  pattern: Array.from({ length: SLOTS }, () => Array(SEQ_STEPS).fill(false)),
  currentStep: 0,
  nextStepTime: 0,
  timer: null,
};
let seqHighlighted = -1;

function secondsPerStep() {
  return 60 / seq.bpm / 4; // 16th notes
}

function seqScheduleStep(step, time) {
  for (let i = 0; i < SLOTS; i++) {
    if (seq.pattern[i][step]) play(i, time);
  }
  const delayMs = Math.max(0, (time - ac().currentTime) * 1000);
  setTimeout(() => seqHighlightStep(step), delayMs);
}

function seqTick() {
  const a = ac();
  while (seq.nextStepTime < a.currentTime + SEQ_SCHEDULE_AHEAD_SEC) {
    seqScheduleStep(seq.currentStep, seq.nextStepTime);
    seq.nextStepTime += secondsPerStep();
    seq.currentStep = (seq.currentStep + 1) % SEQ_STEPS;
  }
  seq.timer = setTimeout(seqTick, SEQ_LOOKAHEAD_MS);
}

function seqHighlightStep(step) {
  // Guards against a highlight scheduled just before STOP firing after
  // stopSeq() already cleared the playhead (its 100ms lookahead delay can
  // outlive the click that stopped playback).
  if (!seq.playing) return;
  if (seqHighlighted >= 0) {
    for (const row of seqRowEls) row.cells[seqHighlighted].classList.remove('current');
  }
  for (const row of seqRowEls) row.cells[step].classList.add('current');
  seqHighlighted = step;
}

function seqClearHighlight() {
  if (seqHighlighted >= 0) {
    for (const row of seqRowEls) row.cells[seqHighlighted].classList.remove('current');
  }
  seqHighlighted = -1;
}

function startSeq() {
  if (seq.playing) return;
  ac(); // resume audio inside the user gesture
  seq.playing = true;
  seq.currentStep = 0;
  seq.nextStepTime = ac().currentTime + 0.05;
  seqTick();
  render();
}

function stopSeq() {
  seq.playing = false;
  clearTimeout(seq.timer);
  seq.timer = null;
  seqClearHighlight();
  render();
}

function setBpm(v) {
  seq.bpm = Math.max(40, Math.min(240, v));
  $('bpmValue').textContent = seq.bpm;
}

$('bpmDown').addEventListener('click', () => setBpm(seq.bpm - 5));
$('bpmUp').addEventListener('click', () => setBpm(seq.bpm + 5));
$('playBtn').addEventListener('click', () => (seq.playing ? stopSeq() : startSeq()));

/* ---- rendering ---- */

const padEls = [];

function buildPads() {
  const grid = $('padGrid');
  for (let i = 0; i < SLOTS; i++) {
    const root = document.createElement('div');
    root.className = 'pad';
    root.innerHTML =
      '<img class="pad-thumb" alt="" draggable="false">' +
      '<div class="pad-blank">EMPTY</div>' +
      '<div class="pad-strip">' +
      '<div class="pad-led"></div>' +
      `<div class="pad-label">P${i + 1}</div>` +
      '<div class="pad-tag">—</div>' +
      '</div>';
    root.addEventListener('click', () => tapPad(i));
    grid.appendChild(root);
    padEls.push({
      root,
      img: root.querySelector('.pad-thumb'),
      led: root.querySelector('.pad-led'),
      tag: root.querySelector('.pad-tag'),
    });
  }
}

function buildInks() {
  const row = $('inkSwatches');
  for (const ink of INKS) {
    const el = document.createElement('div');
    el.className = 'ink-swatch';
    el.style.background = ink.hex;
    el.addEventListener('click', () => {
      state.ink = ink.key;
      render();
    });
    row.appendChild(el);
    ink.el = el;
  }
}

const seqRowEls = [];

function buildSeq() {
  const grid = $('seqGrid');
  for (let i = 0; i < SLOTS; i++) {
    const row = document.createElement('div');
    row.className = 'seq-row';
    const label = document.createElement('div');
    label.className = 'seq-row-label';
    label.textContent = `P${i + 1}`;
    row.appendChild(label);

    const steps = document.createElement('div');
    steps.className = 'seq-steps';
    const cells = [];
    for (let s = 0; s < SEQ_STEPS; s++) {
      const cell = document.createElement('div');
      cell.className = 'step' + (Math.floor(s / 4) % 2 ? ' step-alt' : '');
      cell.addEventListener('click', () => {
        seq.pattern[i][s] = !seq.pattern[i][s];
        cell.classList.toggle('on', seq.pattern[i][s]);
      });
      steps.appendChild(cell);
      cells.push(cell);
    }
    row.appendChild(steps);
    grid.appendChild(row);
    seqRowEls.push({ cells });
  }
}

function renderPaperEmpty() {
  $('paperEmpty').classList.toggle('hidden', strokes.length > 0 || !!cur);
}

function render() {
  for (const ink of INKS) ink.el.classList.toggle('selected', ink.key === state.ink);
  $('inkHint').textContent = INKS.find((i) => i.key === state.ink).word.toUpperCase();

  for (let i = 0; i < SLOTS; i++) {
    const p = state.pads[i];
    const el = padEls[i];
    const ink = p ? INKS.find((k) => k.key === p.color) : null;
    el.root.classList.toggle('filled', !!p);
    el.root.classList.toggle('selected', i === state.sel);
    if (p && el.img.src !== p.thumb) el.img.src = p.thumb;
    el.led.style.background = p ? ink.hex : 'transparent';
    el.led.style.borderColor = p ? ink.hex : '#a3a7ae';
    el.tag.textContent = p
      ? ink.tag + (p.pitch ? ` ${p.pitch > 0 ? '+' : ''}${p.pitch}` : '')
      : '—';
  }

  const selPad = state.pads[state.sel];
  $('selName').textContent = selPad ? `P${state.sel + 1}` : 'NO PAD';
  $('pitchLabel').textContent = selPad ? (selPad.pitch > 0 ? '+' : '') + selPad.pitch : '—';
  $('faderKnob').style.left = (((selPad ? selPad.pitch : 0) + 12) / 24) * 100 + '%';

  $('playBtn').classList.toggle('on', seq.playing);
  $('playBtn').textContent = seq.playing ? 'STOP' : 'PLAY';

  renderPaperEmpty();
}

/* ---- boot ---- */

buildInks();
buildPads();
buildSeq();
setLcd('draw, then press GENERATE');
setBpm(seq.bpm);
sizeCanvas();
render();
addEventListener('resize', sizeCanvas);
