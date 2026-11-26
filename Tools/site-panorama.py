"""Usage: python3 Tools/site-panorama.py [cards, default 11]  (needs Pillow)

One wide picture behind every card of the store page, so each card runs into the next: a chain of
linked 7s along the band under the headlines, its nodes on the cards and on the gaps between them, and
big digits sitting on the gaps, half in one card and half in the next."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os, sys

N = int(sys.argv[1]) if len(sys.argv) > 1 else 11
S = 2                       # pixels per CSS pixel
CARD, GAP = 260 * S, 14 * S
UNIT = CARD + GAP
H = round(260 * 17.5 / 9) * S
W = N * UNIT
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'site', 'gallery')

def rounded(size, weight=b'Heavy'):
    f = ImageFont.truetype('/System/Library/Fonts/SFNSRounded.ttf', size); f.set_variation_by_name(weight); return f

def gradient(stops):
    im = Image.new('RGB', (W, H)); d = ImageDraw.Draw(im)
    for x in range(W):
        t = x / (W - 1) * (len(stops) - 1)
        a, b = stops[int(t)], stops[min(int(t) + 1, len(stops) - 1)]
        f = t - int(t)
        d.line([(x, 0), (x, H)], fill=tuple(int(a[i] + (b[i] - a[i]) * f) for i in range(3)))
    return im.convert('RGBA')

def draw(theme):
    light = theme == 'light'
    stops = ([(217, 232, 255), (228, 220, 255), (255, 220, 234), (255, 230, 207), (223, 244, 226), (214, 239, 255), (226, 220, 255)]
             if light else [(17, 34, 63), (31, 26, 61), (53, 23, 43), (48, 34, 15), (16, 41, 28), (12, 38, 56), (31, 26, 61)])
    im = gradient(stops)

    # Big digits on the gaps, half in each card; the 7 of the icon among them.
    big = rounded(620)
    layer = Image.new('RGBA', im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    digits = '4719358621'
    for k in range(N - 1):
        x = (k + 1) * UNIT - GAP / 2
        d.text((x, H - 120), digits[k % len(digits)], font=big, anchor='ms',
               fill=(20, 30, 60, 22) if light else (255, 255, 255, 26))
    im.alpha_composite(layer)

    # The chain: a wave along the band under the headlines, through a node on every card and on every
    # gap, its links solid and dashed in turn, as the hints draw strong and weak links.
    band = 118 * S
    points = []
    for k in range(2 * N + 1):
        x = k * UNIT / 2 - GAP / 2 if k % 2 == 0 else (k // 2) * UNIT + CARD / 2
        y = band + math.sin(k * 1.1) * 12 * S
        points.append((x, y))
    line = (10, 102, 216, 190) if light else (90, 167, 255, 200)
    layer = Image.new('RGBA', im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    for k in range(len(points) - 1):
        (x1, y1), (x2, y2) = points[k], points[k + 1]
        samples = [(x1 + (x2 - x1) * t / 40, y1 + (y2 - y1) * (3 * (t / 40) ** 2 - 2 * (t / 40) ** 3)) for t in range(41)]
        if k % 2 == 0:
            d.line(samples, fill=line, width=5 * S // 2 * 2, joint='curve')
        else:
            for t in range(0, 40, 6):
                d.line(samples[t:t + 4], fill=line, width=4 * S // 2 * 2)
    im.alpha_composite(layer)

    shadow = Image.new('RGBA', im.size, (0, 0, 0, 0)); sd = ImageDraw.Draw(shadow)
    nodes = Image.new('RGBA', im.size, (0, 0, 0, 0)); nd = ImageDraw.Draw(nodes)
    small = rounded(26 * S, b'Bold')
    for k, (x, y) in enumerate(points):
        r = (17 if k % 2 == 0 else 14) * S
        color = (47, 158, 85) if (k // 1) % 2 == 0 else (47, 123, 240)
        sd.ellipse((x - r, y - r + 4 * S, x + r, y + r + 4 * S), fill=(0, 20, 60, 70))
        nd.ellipse((x - r, y - r, x + r, y + r), fill=color + (255,))
        nd.ellipse((x - r, y - r, x + r, y + r), outline=(255, 255, 255, 230), width=2 * S)
        nd.text((x, y + 1), '7', font=rounded(int(r * 1.15), b'Bold'), fill=(255, 255, 255), anchor='mm')
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(5 * S)))
    im.alpha_composite(nodes)
    return im.convert('RGB')

for theme in ('light', 'dark'):
    im = draw(theme)
    im.save(f'{OUT}/panorama-{theme}.jpg', quality=82, optimize=True)
    print(theme, im.size)
