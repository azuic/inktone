"""Compose review layouts from unmodified Simulator exports.

Text and brand shapes remain separate SVG elements; the app screen is one image.
"""
from pathlib import Path
from base64 import b64encode
from html import escape

ROOT = Path(__file__).resolve().parent
SHOTS = ROOT.parent / "screenshots"
INK = "#1c1d20"
MUTED = "#676b72"
PAPER = "#eceef0"
COLORS = ["#2fa7cf", "#f5c400", "#f26731", "#e94b9e"]


def text(x, y, value, size=24, weight=400, color=INK, spacing=0):
    return f'<text x="{x}" y="{y}" font-family="Menlo, monospace" font-size="{size}" font-weight="{weight}" fill="{color}" letter-spacing="{spacing}">{escape(value)}</text>'


def artboard(name, width, height, source, source_width, source_height, phone):
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
             f'<title>{name}</title>', f'<rect width="{width}" height="{height}" fill="{PAPER}"/>']
    margin = 82 if phone else 106
    parts += [f'<rect x="{margin}" y="40" width="22" height="22" fill="{INK}"/>', text(margin+43, 62, 'TINK-ON', 31, 700, spacing=4)]
    for i, color in enumerate(COLORS):
        parts.append(f'<circle cx="{width-margin-130+i*43}" cy="51" r="12" fill="{color}"/>')
    if phone:
        parts.append(text(margin, 150, 'Sketch a sound. Play a beat.', 74, 700, spacing=-3))
        image_width, image_x, image_y = 2136, 243, 202
    else:
        parts += [text(margin, 195, 'Sketch a sound.', 99, 700, spacing=-4),
                  text(margin, 308, 'Play a beat.', 99, 700, spacing=-4)]
        image_width, image_x, image_y = 1704, 180, 405
    image_height = image_width * source_height / source_width
    parts.append(f'<rect x="{image_x-2}" y="{image_y-2}" width="{image_width+4}" height="{image_height+4:.4f}" rx="18" fill="#c5c9ce"/>')
    parts.append(f'<defs><clipPath id="screen"><rect x="{image_x}" y="{image_y}" width="{image_width}" height="{image_height:.4f}" rx="16"/></clipPath></defs>')
    payload = b64encode(source.read_bytes()).decode()
    parts.append(f'<image id="actual-app-screenshot" x="{image_x}" y="{image_y}" width="{image_width}" height="{image_height:.4f}" preserveAspectRatio="xMidYMid meet" clip-path="url(#screen)" xlink:href="data:image/jpeg;base64,{payload}"/>')
    parts.append('</svg>')
    (ROOT / f'{name}.svg').write_text('\n'.join(parts))


artboard('01-iphone-landscape', 2622, 1206, SHOTS / '03-iphone-17-pro-instrument.jpg', 2622, 1206, True)
artboard('02-ipad-portrait', 2064, 2752, SHOTS / '02-ipad-13-portrait.jpg', 2064, 2752, False)
