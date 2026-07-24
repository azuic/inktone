// Serverless function: proxies sketch prompts to the ElevenLabs Sound Effects API.
// Keeps ELEVENLABS_API_KEY server-side only — never shipped to the client.
//
// This endpoint natively supports 0.5-30s clips, which covers a sampler hit's
// 250-1600ms range almost exactly (only sketches under 0.5s need clamping),
// unlike the Music API's 3s floor.

const MIN_DURATION_SEC = 0.5;
const MAX_DURATION_SEC = 30;
const MAX_PROMPT_LEN = 2000;

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method not allowed' });
    return;
  }

  const apiKey = process.env.ELEVENLABS_API_KEY;
  if (!apiKey) {
    res.status(500).json({ error: 'ELEVENLABS_API_KEY is not configured' });
    return;
  }

  let body = req.body;
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body);
    } catch {
      res.status(400).json({ error: 'invalid JSON body' });
      return;
    }
  }

  const prompt = typeof body?.prompt === 'string' ? body.prompt.trim().slice(0, MAX_PROMPT_LEN) : '';
  if (!prompt) {
    res.status(400).json({ error: 'prompt is required' });
    return;
  }

  const rawDur = typeof body?.durationSec === 'number' ? body.durationSec : null;
  const durationSeconds = rawDur == null ? null : Math.min(MAX_DURATION_SEC, Math.max(MIN_DURATION_SEC, rawDur));

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 45000);

  let upstream;
  try {
    upstream = await fetch('https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128', {
      method: 'POST',
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        text: prompt,
        duration_seconds: durationSeconds,
        model_id: 'eleven_text_to_sound_v2',
      }),
      signal: controller.signal,
    });
  } catch (err) {
    clearTimeout(timeout);
    res.status(502).json({ error: 'upstream request failed', detail: String(err) });
    return;
  }
  clearTimeout(timeout);

  if (!upstream.ok) {
    const text = await upstream.text().catch(() => '');
    res.status(upstream.status).json({ error: 'elevenlabs error', detail: text.slice(0, 500) });
    return;
  }

  const buf = Buffer.from(await upstream.arrayBuffer());
  res.setHeader('Content-Type', 'audio/mpeg');
  res.setHeader('Cache-Control', 'no-store');
  res.status(200).send(buf);
};
