// Serverless function: proxies sketch prompts to the ElevenLabs Music API.
// Keeps ELEVENLABS_API_KEY server-side only — never shipped to the client.
//
// ElevenLabs music.compose has a 3,000ms minimum duration, shorter than a
// sampler hit (250-1600ms), so we always request the minimum here and let
// the client trim the returned audio down to the sketch's target length.

const MIN_MUSIC_LENGTH_MS = 3000;
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

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60000);

  let upstream;
  try {
    upstream = await fetch('https://api.elevenlabs.io/v1/music?output_format=auto', {
      method: 'POST',
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        prompt,
        music_length_ms: MIN_MUSIC_LENGTH_MS,
        model_id: 'music_v2',
        force_instrumental: true,
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
