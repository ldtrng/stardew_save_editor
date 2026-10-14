"""Composes Google Play screenshots (1080x1920) and feature graphics (1024x500)
from raw app screenshots in store/screenshots/raw/<lang>_<n>.png.

Usage: python compose.py <fusion_pixel_font_dir>
Needs Pillow. All artwork is drawn here (original pixel art, no game assets)."""
import json, os, random, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FPF = sys.argv[1] if len(sys.argv) > 1 else ''
RAW = os.path.join(ROOT, 'store', 'screenshots', 'raw')
OUT = os.path.join(ROOT, 'store', 'screenshots')
LISTINGS = json.load(open(os.path.join(ROOT, 'store', 'listings.json')))

# app language code -> Play locale
LOCALES = {'en': 'en-US', 'vi': 'vi', 'pt': 'pt-BR', 'es': 'es-ES', 'de': 'de-DE', 'fr': 'fr-FR', 'ru': 'ru-RU',
           'ja': 'ja-JP', 'ko': 'ko-KR', 'zh': 'zh-CN', 'it': 'it-IT', 'tr': 'tr-TR', 'hu': 'hu-HU'}

OUTLINE = (74, 44, 23)
WOOD = (184, 118, 58)
WOOD_DARK = (126, 75, 34)
CREAM = (255, 244, 214)
SKY = [(127, 196, 228), (148, 208, 236), (171, 220, 242)]
GRASS = (107, 175, 74)
GRASS_DARK = (63, 125, 42)
SOIL = (122, 78, 44)
SOIL_DARK = (92, 58, 30)
WHEAT = (233, 184, 74)


def font(lang, size):
    if lang == 'vi':
        return ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/Tiny5.ttf'), size)
    if lang == 'ja':
        return ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/DotGothic16.ttf'), size)
    if lang in ('ko', 'zh'):
        name = {'ko': 'ko', 'zh': 'zh_hans'}[lang]
        return ImageFont.truetype(os.path.join(FPF, f'fusion-pixel-12px-proportional-{name}.ttf'), size)
    f = ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/PixelifySans.ttf'), size)
    try:
        f.set_variation_by_name('Bold')
    except Exception:
        pass
    return f


def pixel_scene(w, h, scale, seed=7, house=True):
    """Draws a small farm scene at (w/scale, h/scale) and upscales it crisply."""
    rnd = random.Random(seed)
    sw, sh = w // scale, h // scale
    im = Image.new('RGB', (sw, sh), SKY[0])
    d = ImageDraw.Draw(im)
    band = sh * 55 // 100
    for i, c in enumerate(SKY):
        d.rectangle([0, i * band // 3, sw, (i + 1) * band // 3], fill=c)
    # sun
    d.rectangle([sw - 22, 6, sw - 12, 16], fill=WHEAT)
    d.rectangle([sw - 24, 8, sw - 10, 14], fill=WHEAT)
    # clouds
    for _ in range(4):
        cx, cy = rnd.randint(0, sw - 20), rnd.randint(4, band // 2)
        d.rectangle([cx, cy, cx + 14, cy + 3], fill=(250, 250, 245))
        d.rectangle([cx + 3, cy - 2, cx + 10, cy], fill=(250, 250, 245))
    # hills
    for x in range(sw):
        y = band - 6 + int(4 * __import__('math').sin(x / 9.0))
        d.line([x, y, x, band], fill=GRASS_DARK)
    d.rectangle([0, band, sw, sh], fill=GRASS)
    # field rows
    top = band + (sh - band) // 3
    for r in range(top, sh, 4):
        d.rectangle([0, r, sw, r + 1], fill=SOIL)
        d.rectangle([0, r + 2, sw, r + 2], fill=SOIL_DARK)
        for x in range(2 + (r % 3), sw, 6):
            d.rectangle([x, r - 1, x + 1, r], fill=GRASS_DARK)
            if rnd.random() < 0.25:
                d.point([x, r - 2], fill=WHEAT)
    # fence
    fy = top - 3
    d.rectangle([0, fy, sw, fy], fill=WOOD)
    for x in range(1, sw, 5):
        d.rectangle([x, fy - 2, x, fy + 1], fill=WOOD_DARK)
    if house:
        hx, hy = 10, band - 14
        d.rectangle([hx, hy + 6, hx + 22, hy + 16], fill=(214, 168, 112))
        d.polygon([(hx - 2, hy + 7), (hx + 11, hy - 1), (hx + 24, hy + 7)], fill=(170, 64, 50))
        d.rectangle([hx + 9, hy + 10, hx + 13, hy + 16], fill=WOOD_DARK)
        d.rectangle([hx + 3, hy + 9, hx + 6, hy + 12], fill=SKY[2])
        d.rectangle([hx + 16, hy + 9, hx + 19, hy + 12], fill=SKY[2])
    return im.resize((w, h), Image.NEAREST)


def wrap(draw, text, fnt, max_w):
    words = text.split(' ')
    if len(words) == 1 or any('　' <= ch <= '鿿' or '가' <= ch <= '힯' for ch in text):
        # CJK: wrap by characters
        lines, cur = [], ''
        for ch in text:
            if draw.textlength(cur + ch, font=fnt) > max_w and cur:
                lines.append(cur)
                cur = ch
            else:
                cur += ch
        return lines + ([cur] if cur else [])
    lines, cur = [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if draw.textlength(t, font=fnt) > max_w and cur:
            lines.append(cur)
            cur = w
        else:
            cur = t
    return lines + ([cur] if cur else [])


def is_cjk(text):
    return any('　' <= ch <= '鿿' or '가' <= ch <= '힯' for ch in text)


def balanced(draw, text, fnt, max_w):
    """Wraps into as few lines as fit, keeping the lines similar in width."""
    lines = wrap(draw, text, fnt, max_w)
    if len(lines) != 2:
        return lines
    if is_cjk(text) and ' ' not in text:
        cuts = range(1, len(text))
        split = lambda i: (text[:i], text[i:])
    else:
        words = text.split(' ')
        cuts = range(1, len(words))
        split = lambda i: (' '.join(words[:i]), ' '.join(words[i:]))
    # Never start a line with closing punctuation.
    cuts = [i for i in cuts if split(i)[1][:1] not in '，。、・！？：；）」』,.!?:;)'] or list(cuts)
    cut = min(cuts, key=lambda i: max(draw.textlength(x, font=fnt) for x in split(i)))
    a, b = split(cut)
    if max(draw.textlength(a, font=fnt), draw.textlength(b, font=fnt)) <= max_w:
        return [a, b]
    return lines


def fit(draw, lang, text, sizes, max_w, max_lines, max_h=None):
    """Largest font size whose wrapped text fits the box."""
    for size in sizes:
        fnt = font(lang, size)
        lines = balanced(draw, text, fnt, max_w)
        if len(lines) <= max_lines and (max_h is None or len(lines) * int(size * 1.2) <= max_h):
            return fnt, lines
    return fnt, lines[:max_lines]


def outlined(draw, xy, text, fnt, fill, outline, width):
    x, y = xy
    for dx in range(-width, width + 1, max(1, width // 2)):
        for dy in range(-width, width + 1, max(1, width // 2)):
            draw.text((x + dx, y + dy), text, font=fnt, fill=outline)
    draw.text((x, y), text, font=fnt, fill=fill)


def framed(shot, w):
    """Scales a raw screenshot to width w and adds a chunky pixel frame."""
    h = shot.height * w // shot.width
    img = shot.resize((w, h), Image.LANCZOS)
    b = 14
    frame = Image.new('RGB', (w + 2 * b, h + 2 * b), OUTLINE)
    inner = Image.new('RGB', (w + b, h + b), WOOD_DARK)
    frame.paste(inner, (b // 2, b // 2))
    frame.paste(img, (b, b))
    return frame


def screenshot(lang, n, caption):
    W, H = 1080, 1920
    bg = pixel_scene(W, H, 8, seed=n)
    d = ImageDraw.Draw(bg)
    # caption plank
    fnt, lines = fit(d, lang, caption, range(76, 55, -4), 900, 2)
    lh = int(fnt.size * 1.25)
    ph = 70 + lh * len(lines)
    d.rectangle([40, 60, W - 40, 60 + ph], fill=OUTLINE)
    d.rectangle([52, 72, W - 52, 48 + ph], fill=WOOD)
    d.rectangle([52, 72, W - 52, 80], fill=(208, 146, 82))
    y = 60 + (ph - lh * len(lines)) // 2
    for ln in lines:
        tw = d.textlength(ln, font=fnt)
        outlined(d, ((W - tw) // 2, y), ln, fnt, CREAM, OUTLINE, 4)
        y += lh
    shot = Image.open(os.path.join(RAW, f'{lang}_{n}.png')).convert('RGB')
    fr = framed(shot, 860)
    top = 60 + ph + 50
    # drop shadow
    sh = Image.new('RGB', fr.size, (40, 26, 14))
    bg.paste(sh, ((W - fr.width) // 2 + 16, top + 16))
    bg.paste(fr, ((W - fr.width) // 2, top))
    return bg


def feature_graphic(lang, headline):
    W, H = 1024, 500
    bg = pixel_scene(W, H, 4, seed=3, house=True)
    d = ImageDraw.Draw(bg)
    # phones on the right
    for i, (n, x, y) in enumerate([(2, 735, 70), (1, 600, 40)]):
        p = os.path.join(RAW, f'{lang}_{n}.png')
        if not os.path.exists(p):
            continue
        fr = framed(Image.open(p).convert('RGB'), 190)
        fr = fr.crop((0, 0, fr.width, min(fr.height, H - y + 40)))
        bg.paste(Image.new('RGB', fr.size, (40, 26, 14)), (x + 10, y + 10))
        bg.paste(fr, (x, y))
    # icon + headline panel
    icon = Image.open(os.path.join(ROOT, 'store', 'icon_512.png')).convert('RGB').resize((112, 112), Image.NEAREST)
    d.rectangle([28, 40, 570, 290], fill=OUTLINE)
    d.rectangle([38, 50, 560, 280], fill=WOOD)
    bg.paste(icon, (56, 68))
    fnt, lines = fit(d, lang, headline, range(52, 29, -2), 350, 3, max_h=150)
    lh = int(fnt.size * 1.2)
    y = 66 + (150 - lh * len(lines)) // 2
    for ln in lines:
        outlined(d, (186, y), ln, fnt, CREAM, OUTLINE, 3)
        y += lh
    title = LISTINGS[LOCALES[lang]]['title']
    sub, _ = fit(d, lang, title, range(28, 15, -1), 480, 1)
    outlined(d, (60, 236), title, sub, WHEAT, OUTLINE, 2)
    return bg


def main():
    for lang, loc in LOCALES.items():
        listing = LISTINGS.get(loc)
        if not listing:
            continue
        out = os.path.join(OUT, loc)
        os.makedirs(out, exist_ok=True)
        made = 0
        for n in range(1, 9):
            if not os.path.exists(os.path.join(RAW, f'{lang}_{n}.png')):
                continue
            screenshot(lang, n, listing['captions'][n - 1]).save(os.path.join(out, f'{n}.png'))
            made += 1
        feature_graphic(lang, listing['feature_graphic']).save(os.path.join(out, 'feature_graphic.png'))
        print(loc, made, 'screenshots + feature graphic')


if __name__ == '__main__':
    main()
