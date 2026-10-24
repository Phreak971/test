"""Generates Overworld's original app icons (default + alternates).

Usage: python3 -I tool/gen_icons.py   (run from app/)
Outputs:
  assets/icons/<id>.png                         in-app previews (256 px)
  android/app/src/main/res/mipmap-*/ic_launcher[_<id>].png
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png  (default icon only)
  ios/Runner/Assets.xcassets/AppIcon-<id>.appiconset  alternate icons for iOS
"""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFilter

S = 1024

ICONS = {
    # id: (bg top, bg bottom, glyph, accent, style)
    'default': ((0x14, 0x2A, 0x6B), (0x05, 0x0A, 0x1F), (255, 255, 255), (0x3D, 0x9B, 0xFF), 'pin'),
    'neon': ((0x0A, 0x0E, 0x1C), (0x05, 0x07, 0x0F), (0xFC, 0xEE, 0x0A), (0x19, 0xE3, 0xFF), 'neon'),
    'frontier': ((0xE6, 0xD3, 0xAD), (0xC2, 0xA4, 0x72), (0x3A, 0x26, 0x14), (0xB0, 0x28, 0x1E), 'compass'),
    'blocky': ((0x8C, 0xC8, 0x5A), (0x5E, 0x9A, 0x36), (0xFF, 0xFF, 0xFF), (0x7A, 0x52, 0x30), 'block'),
    'terminal': ((0x0B, 0x22, 0x10), (0x03, 0x0B, 0x05), (0x6C, 0xFF, 0x9A), (0x6C, 0xFF, 0x9A), 'crt'),
    'racer': ((0x1A, 0x10, 0x4A), (0x05, 0x08, 0x19), (0xFF, 0xE5, 0x3B), (0xFF, 0x3C, 0xAC), 'chevron'),
}


def gradient(top, bottom):
    img = Image.new('RGB', (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def map_lines(img, color, alpha=60, width=10):
    """Faint street grid that reads as 'map' at small sizes."""
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = color + (alpha,)
    d.line([(0, 300), (1024, 420)], fill=c, width=width * 2)
    d.line([(0, 760), (1024, 640)], fill=c, width=width)
    d.line([(330, 0), (420, 1024)], fill=c, width=width)
    d.line([(760, 0), (700, 1024)], fill=c, width=width * 2)
    img.paste(layer, (0, 0), layer)


def pin_path(cx, cy, r):
    """Teardrop pin polygon pointing down."""
    pts = []
    for i in range(0, 361, 4):
        a = math.radians(i)
        if 200 <= i <= 340:
            continue
        pts.append((cx + r * math.cos(a), cy - r * math.sin(a)))
    pts.insert(len(pts) // 2, (cx, cy + r * 1.75))
    # Rebuild as: arc over top from 340° to 200° going through 90°, then tip.
    arc = [(cx + r * math.cos(math.radians(a)), cy - r * math.sin(math.radians(a))) for a in range(-20, 201, 4)]
    return arc + [(cx, cy + r * 1.75)]


def glow(img, draw_fn, color, radius=40):
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer), color + (255,))
    blurred = layer.filter(ImageFilter.GaussianBlur(radius))
    img.paste(blurred, (0, 0), blurred)
    img.paste(layer, (0, 0), layer)


def make(id_, spec):
    top, bottom, glyph, accent, style = spec
    img = gradient(top, bottom).convert('RGBA')
    map_lines(img, glyph, alpha=40 if style != 'compass' else 70)
    d = ImageDraw.Draw(img)
    cx, cy, r = 512, 440, 230

    if style == 'pin':
        glow(img, lambda dd, c: dd.polygon(pin_path(cx, cy, r), fill=accent + (255,)), accent, 60)
        d = ImageDraw.Draw(img)
        d.polygon(pin_path(cx, cy, r), fill=glyph + (255,))
        # Pixel globe in the pin head.
        for gx in range(-3, 4):
            for gy in range(-3, 4):
                if gx * gx + gy * gy <= 10:
                    x0, y0 = cx + gx * 34 - 15, cy + gy * 34 - 15
                    d.rectangle([x0, y0, x0 + 28, y0 + 28], fill=accent + (255,) if (gx + gy) % 2 == 0 else (0x14, 0x2A, 0x6B, 255))
    elif style == 'neon':
        def outline(dd, c):
            dd.line(pin_path(cx, cy, r) + [pin_path(cx, cy, r)[0]], fill=c, width=36, joint='curve')
        glow(img, outline, accent, 50)
        d = ImageDraw.Draw(img)
        d.ellipse([cx - 70, cy - 70, cx + 70, cy + 70], fill=glyph + (255,))
    elif style == 'compass':
        d.ellipse([cx - 300, 512 - 300, cx + 300, 512 + 300], outline=glyph + (255,), width=18)
        for a, length in [(90, 280), (270, 280), (0, 280), (180, 280), (45, 160), (135, 160), (225, 160), (315, 160)]:
            rad = math.radians(a)
            tip = (cx + length * math.cos(rad), 512 - length * math.sin(rad))
            side1 = (cx + 40 * math.cos(rad + math.pi / 2), 512 - 40 * math.sin(rad + math.pi / 2))
            side2 = (cx + 40 * math.cos(rad - math.pi / 2), 512 - 40 * math.sin(rad - math.pi / 2))
            d.polygon([tip, side1, (cx, 512), side2], fill=(accent if a == 90 else glyph) + (255,))
    elif style == 'block':
        # Pixel-art map pin built from chunky voxels.
        rows = [
            '..XXXXX..',
            '.XXXXXXX.',
            'XXXX.XXXX',
            'XXX...XXX',
            'XXXX.XXXX',
            '.XXXXXXX.',
            '..XXXXX..',
            '...XXX...',
            '....X....',
        ]
        px = 78
        ox, oy = 512 - px * 9 // 2, 150
        for ry, row in enumerate(rows):
            for rx, ch in enumerate(row):
                if ch != 'X':
                    continue
                x0, y0 = ox + rx * px, oy + ry * px
                d.rectangle([x0 + 8, y0 + 8, x0 + px + 8, y0 + px + 8], fill=(0, 0, 0, 70))
                d.rectangle([x0, y0, x0 + px - 4, y0 + px - 4], fill=glyph + (255,))
                d.rectangle([x0, y0 + px - 18, x0 + px - 4, y0 + px - 4], fill=(0xD9, 0xD9, 0xD9, 255))
    elif style == 'crt':
        for y in range(0, S, 12):
            d.line([(0, y), (S, y)], fill=(0, 0, 0, 90), width=4)
        def shape(dd, c):
            dd.line(pin_path(cx, cy, r) + [pin_path(cx, cy, r)[0]], fill=c, width=30)
            dd.ellipse([cx - 60, cy - 60, cx + 60, cy + 60], outline=c, width=24)
        glow(img, shape, accent, 30)
    elif style == 'chevron':
        for i, off in enumerate([0, 120, 240]):
            d.line([(140 + off, 900), (60 + off, 1024)], fill=accent + (120,), width=20)
        def chev(dd, c):
            dd.polygon([(512, 180), (800, 760), (512, 620), (224, 760)], fill=c)
        glow(img, chev, accent, 50)
        d = ImageDraw.Draw(img)
        d.polygon([(512, 180), (800, 760), (512, 620), (224, 760)], fill=glyph + (255,))
    return img.convert('RGB')


def main():
    os.makedirs('assets/icons', exist_ok=True)
    mip = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    for id_, spec in ICONS.items():
        img = make(id_, spec)
        img.resize((256, 256), Image.LANCZOS).save(f'assets/icons/{id_}.png')
        name = 'ic_launcher' if id_ == 'default' else f'ic_launcher_{id_}'
        for folder, px in mip.items():
            out = f'android/app/src/main/res/mipmap-{folder}'
            os.makedirs(out, exist_ok=True)
            img.resize((px, px), Image.LANCZOS).save(f'{out}/{name}.png')
            # Adaptive icon background layer (108dp; launchers mask the outer third).
            img.resize((px * 108 // 48, px * 108 // 48), Image.LANCZOS).save(f'{out}/{name}_background.png')
        os.makedirs('android/app/src/main/res/mipmap-anydpi-v26', exist_ok=True)
        with open(f'android/app/src/main/res/mipmap-anydpi-v26/{name}.xml', 'w') as fh:
            fh.write('<?xml version="1.0" encoding="utf-8"?>\n'
                     '<!-- Generated by tool/gen_icons.py -->\n'
                     '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                     f'    <background android:drawable="@mipmap/{name}_background"/>\n'
                     '    <foreground android:drawable="@android:color/transparent"/>\n'
                     '</adaptive-icon>\n')
        if id_ != 'default':
            # Alternate icon as its own single-size asset catalog set; listed in
            # ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES in the Xcode project.
            set_dir = f'ios/Runner/Assets.xcassets/AppIcon-{id_}.appiconset'
            os.makedirs(set_dir, exist_ok=True)
            img.save(f'{set_dir}/icon-1024.png')
            json.dump({
                'images': [{'filename': 'icon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
                'info': {'author': 'xcode', 'version': 1},
            }, open(f'{set_dir}/Contents.json', 'w'), indent=2)
        else:
            set_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
            contents = json.load(open(f'{set_dir}/Contents.json'))
            for entry in contents['images']:
                fn = entry.get('filename')
                if not fn:
                    continue
                size = float(entry['size'].split('x')[0]) * int(entry['scale'].rstrip('x'))
                img.resize((int(size), int(size)), Image.LANCZOS).save(f'{set_dir}/{fn}')
            img.save('assets/icons/master_1024.png')
    print('icons generated:', ', '.join(ICONS))


if __name__ == '__main__':
    main()
