#!/usr/bin/env python3
"""畫出 app 圖示。

跟 app 裡的數字同一套語言：紙、卡片、紅色麥克筆的「95」、藍色底線。
圖示是手畫的，不是套字型——這樣才會跟 app 裡的手寫數字同一家人。

    <bundled python> Tools/make-icon.py
"""
from PIL import Image, ImageDraw, ImageFilter
import math
import os

SIZE = 1024
# 這三個值必須跟 FuelCost/World/Palette.swift 的 token 一模一樣，
# 不然圖示跟 app 會是兩個世界（曾經就是這樣）。
PAPER = (241, 238, 230)   # 0xF1EEE6
CARD = (255, 255, 255)    # 0xFFFFFF
RED = (196, 43, 34)       # 0xC42B22
BLUE = (31, 79, 216)      # 0x1F4FD8

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "FuelCost", "Assets.xcassets",
                       "AppIcon.appiconset")
OUT = os.path.join(OUT_DIR, "icon-1024.png")

# 筆畫粗細是畫布的比例。這是麥克筆的體重：約字高的 0.12。
STROKE = 0.042


def jitter(seed):
    """固定不亂跳的偽隨機，跟 MarkerGlyphs 的抖動同一個精神。"""
    state = seed & 0xFFFFFFFF

    def nxt():
        nonlocal state
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        return state / 0xFFFFFFFF

    return nxt


def curve(points, samples=64):
    """把控制點畫成平滑折線（Catmull-Rom）。"""
    if len(points) < 3:
        return points
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(len(pts) - 3):
        p0, p1, p2, p3 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t +
                       (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 +
                       (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t +
                       (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 +
                       (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(points[-1])
    return out


def stroke(draw, points, width, colour, seed):
    """一筆麥克筆線：抖一點、圓頭、圓轉角。"""
    nxt = jitter(seed)
    amp = width * 0.25
    wobbled = [(x * SIZE + (nxt() - 0.5) * amp * 2,
                y * SIZE + (nxt() - 0.5) * amp * 2) for x, y in points]
    w = max(2, int(round(width * SIZE)))
    draw.line(wobbled, fill=colour, width=w, joint="curve")
    r = w / 2
    for p in (wobbled[0], wobbled[-1]):
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=colour)


# 「9」：一個圈，右邊一撇往下拉。
NINE_LOOP = curve([(0.42, 0.06), (0.72, 0.12), (0.82, 0.32), (0.70, 0.52),
                   (0.42, 0.58), (0.16, 0.48), (0.08, 0.28), (0.20, 0.08),
                   (0.42, 0.06)])
NINE_TAIL = curve([(0.74, 0.50), (0.76, 0.68), (0.68, 0.84), (0.54, 0.96)])

# 「5」：上面一橫、左邊一豎、下面一個肚子。
FIVE_BAR = curve([(0.08, 0.08), (0.36, 0.05), (0.66, 0.07)])
FIVE_STEM = curve([(0.11, 0.07), (0.12, 0.22), (0.11, 0.36)])
FIVE_BOWL = curve([(0.11, 0.36), (0.42, 0.37), (0.66, 0.46), (0.74, 0.64),
                   (0.62, 0.84), (0.36, 0.94), (0.10, 0.88)])

# 每個字自己一欄。欄位之間留白，字才不會黏在一起。
GLYPH_LAYOUT = [
    ([NINE_LOOP, NINE_TAIL], (0.20, 0.28, 0.46, 0.74)),
    ([FIVE_BAR, FIVE_STEM, FIVE_BOWL], (0.54, 0.28, 0.80, 0.74)),
]


def bounds(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return min(xs), min(ys), max(xs), max(ys)


def place(strokes, box):
    """把一組筆畫等比縮放、置中放進 box，回傳新的筆畫。"""
    pts = [p for s in strokes for p in s]
    x0, y0, x1, y1 = bounds(pts)
    bw, bh = max(x1 - x0, 1e-6), max(y1 - y0, 1e-6)
    bx, by, bx1, by1 = box
    scale = min((bx1 - bx) / bw, (by1 - by) / bh)
    ox = bx + ((bx1 - bx) - bw * scale) / 2
    oy = by + ((by1 - by) - bh * scale) / 2
    return [[((p[0] - x0) * scale + ox, (p[1] - y0) * scale + oy) for p in s]
            for s in strokes]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    img = Image.new("RGB", (SIZE, SIZE), PAPER)

    # 卡片：稍微歪一點，像被順手放在櫃台上。
    card_size = int(SIZE * 0.72)
    card = Image.new("RGBA", (card_size, card_size), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    inset = int(card_size * 0.02)
    cd.rounded_rectangle([inset, inset, card_size - inset, card_size - inset],
                         radius=int(card_size * 0.07), fill=CARD + (255,))
    card = card.rotate(-3.5, resample=Image.BICUBIC, expand=True)

    # 影子：柔的，不是硬邊偏移。
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh = Image.new("L", card.size, 0)
    sh.paste(card.split()[3], (0, 0))
    shadow.paste((22, 24, 26, 64), (int(SIZE * 0.14) + 6, int(SIZE * 0.14) + 14), sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(SIZE * 0.018))
    img = Image.alpha_composite(img.convert("RGBA"), shadow).convert("RGB")

    img.paste(card, (int(SIZE * 0.14), int(SIZE * 0.14)), card)
    draw = ImageDraw.Draw(img)

    seed = 11
    for group, box in GLYPH_LAYOUT:
        for points in place(group, box):
            stroke(draw, points, STROKE, RED, seed)
            seed += 7

    # 藍色底線，稍微起伏，像隨手補的一筆。
    underline = curve([(0.22, 0.845), (0.40, 0.858), (0.60, 0.845), (0.78, 0.860)])
    stroke(draw, underline, 0.017, BLUE, 997)

    img.save(OUT, "PNG")
    print(f"寫出 {os.path.relpath(OUT)}  {img.size[0]}x{img.size[1]}  {img.mode}")


if __name__ == "__main__":
    main()
