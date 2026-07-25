'use strict';

const INKS = [
  { key: 'black', hex: '#1c1d20', word: 'deep sub drone', tag: 'SUB' },
  { key: 'red', hex: '#a83f38', word: 'metallic impact', tag: 'IMPACT' },
  { key: 'blue', hex: '#33549c', word: 'resonant tone', tag: 'TONE' },
  { key: 'ochre', hex: '#95782e', word: 'grainy texture', tag: 'TEXTR' },
];

const PAPER_H = 272;
const SLOTS = 6;

const $ = (id) => document.getElementById(id);
const device = $('device');
const canvas = $('paper');
const ctx = canvas.getContext('2d');

const state = {
  ink: 'black',
  generating: false,
  aiMode: true,                  // true: try ElevenLabs Music API, fall back to local synth
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
  ctx.fillStyle = '#f4f5f7';
  ctx.fillRect(0, 0, w, PAPER_H);
  ctx.fillStyle = '#c4c8cf';
  for (let x = 14; x < w; x += 18)
    for (let y = 14; y < PAPER_H; y += 18)
      ctx.fillRect(x, y, 1.5, 1.5);
}

function drawStroke(s) {
  ctx.strokeStyle = INKS.find((i) => i.key === s.color).hex;
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  s.pts.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
  ctx.stroke();
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
  ctx.strokeStyle = INKS.find((i) => i.key === cur.color).hex;
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(l.x, l.y);
  ctx.lineTo(p.x, p.y);
  ctx.stroke();
});
function penUp() {
  if (!cur) return;
  if (cur.pts.length > 1) strokes.push(cur);
  cur = null;
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

function thumb() {
  const t = document.createElement('canvas');
  t.width = 120;
  t.height = Math.round((120 * PAPER_H) / canvas.getBoundingClientRect().width);
  t.getContext('2d').drawImage(canvas, 0, 0, t.width, t.height);
  return t.toDataURL('image/jpeg', 0.7);
}

/* ---- audio engine ---- */

let _ac = null;
let _nb = null;

function ac() {
  if (!_ac) _ac = new (window.AudioContext || window.webkitAudioContext)();
  if (_ac.state === 'suspended') _ac.resume();
  return _ac;
}

function noiseBuf() {
  if (_nb) return _nb;
  const a = ac();
  const b = a.createBuffer(1, a.sampleRate * 2, a.sampleRate);
  const d = b.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  _nb = b;
  return b;
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
  const fr = f.freq * semi;
  const dur = f.dur;
  const out = a.createGain();
  out.gain.value = 0.7;
  out.connect(a.destination);

  if (f.color === 'red') {
    // filtered noise burst + pitch-drop thump
    const n = a.createBufferSource();
    n.buffer = noiseBuf();
    const bp = a.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.value = fr * 2;
    bp.Q.value = 8 - f.jag * 5;
    const g = a.createGain();
    g.gain.setValueAtTime(1, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur * 0.6);
    n.connect(bp).connect(g).connect(out);
    n.start(t);
    n.stop(t + dur);
    const o = a.createOscillator();
    o.frequency.setValueAtTime(fr * 2, t);
    o.frequency.exponentialRampToValueAtTime(Math.max(30, fr * 0.4), t + 0.12);
    const og = a.createGain();
    og.gain.setValueAtTime(0.9, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.25);
    o.connect(og).connect(out);
    o.start(t);
    o.stop(t + 0.3);
  } else if (f.color === 'blue') {
    // detuned triangle pad with vibrato
    const g = a.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.5, t + 0.05);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    const lp = a.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = fr * 4;
    lp.connect(g).connect(out);
    for (const det of [-1, 1]) {
      const o = a.createOscillator();
      o.type = 'triangle';
      o.frequency.value = fr;
      o.detune.value = det * (6 + f.jag * 25);
      const l = a.createOscillator();
      l.frequency.value = f.rate;
      const lg = a.createGain();
      lg.gain.value = 4 + f.jag * 10;
      l.connect(lg).connect(o.detune);
      l.start(t);
      l.stop(t + dur);
      o.connect(lp);
      o.start(t);
      o.stop(t + dur);
    }
  } else if (f.color === 'ochre') {
    // band-passed noise with wobbling filter
    const n = a.createBufferSource();
    n.buffer = noiseBuf();
    n.loop = true;
    const bp = a.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.value = fr * 3;
    bp.Q.value = 2 + f.jag * 6;
    const l = a.createOscillator();
    l.frequency.value = f.rate;
    const lg = a.createGain();
    lg.gain.value = fr * 1.5;
    l.connect(lg).connect(bp.frequency);
    l.start(t);
    l.stop(t + dur);
    const g = a.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.45, t + 0.04);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    n.connect(bp).connect(g).connect(out);
    n.start(t);
    n.stop(t + dur);
  } else {
    // black: deep sub drone, dual detuned sines
    const o = a.createOscillator();
    o.frequency.value = Math.max(35, fr * 0.5);
    const o2 = a.createOscillator();
    o2.frequency.value = Math.max(35, fr * 0.5) * 1.005;
    const g = a.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.8, t + 0.02);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur * 1.4);
    o.connect(g);
    o2.connect(g);
    g.connect(out);
    o.start(t);
    o.stop(t + dur * 1.5);
    o2.start(t);
    o2.stop(t + dur * 1.5);
  }

  scheduleFlash(i, t, Math.min(600, dur * 1000));
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
  const th = thumb();
  state.generating = true;
  $('genBtn').classList.add('waiting');
  $('genBtn').textContent = 'WAIT';
  setLcd('reading sketch');
  await wait(300);

  let buffer = null;
  if (state.aiMode) {
    setLcd('> sending prompt to sfx model');
    try {
      buffer = await fetchAiBuffer(prompt, f.dur);
      setLcd('> rendering audio');
      await wait(150);
    } catch (err) {
      console.warn('AI generation failed, falling back to local synth:', err);
      setLcd('AI unavailable — local synth');
      await wait(500);
    }
  } else {
    setLcd('> rendering audio');
    await wait(700);
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

$('aiBtn').addEventListener('click', () => {
  state.aiMode = !state.aiMode;
  render();
});

// keyboard: 1–6 trigger pads
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
  $('aiBtn').classList.toggle('on', state.aiMode);

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
