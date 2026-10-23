#!/usr/bin/env python3
"""產生辨識用的測試照片。

這些不是 app 的內容，是拿來驗證 Vision 辨識流程的測試素材，
放在 Tools/fixtures/ 底下，不會被打包進 app。

    python3 Tools/make-fixtures.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent / "fixtures"
OUT.mkdir(parents=True, exist_ok=True)

HEITI = "/System/Library/Fonts/STHeiti Medium.ttc"
SONGTI = "/System/Library/Fonts/Supplemental/Songti.ttc"


def font(size: int, path: str = HEITI) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def receipt() -> Path:
    """加油站的熱感紙簽單：金額 1,024、公升 32.40。"""
    w, h = 760, 1100
    image = Image.new("RGB", (w, h), (247, 246, 240))
    draw = ImageDraw.Draw(image)

    y = 70
    draw.text((w / 2, y), "中油 大直站", font=font(40), fill=(20, 20, 20), anchor="mm")
    y += 60
    draw.text((w / 2, y), "統一編號 12345678", font=font(26, SONGTI), fill=(70, 70, 70), anchor="mm")
    y += 60
    draw.line([(60, y), (w - 60, y)], fill=(150, 150, 150), width=2)
    y += 70

    rows = [
        ("95無鉛汽油", "32.40 公升"),
        ("單價", "31.6 元"),
        ("公升", "32.40"),
        ("金額", "1,024 元"),
    ]
    for label, value in rows:
        draw.text((70, y), label, font=font(42), fill=(20, 20, 20))
        draw.text((w - 70, y), value, font=font(42), fill=(20, 20, 20), anchor="ra")
        y += 78

    y += 20
    draw.line([(60, y), (w - 60, y)], fill=(150, 150, 150), width=2)
    y += 60
    draw.text((70, y), "總計", font=font(48), fill=(20, 20, 20))
    draw.text((w - 70, y), "1,024 元", font=font(48), fill=(190, 30, 30), anchor="ra")

    path = OUT / "receipt.png"
    image.save(path)
    return path


def pump_led() -> Path:
    """加油機的 LED 顯示：白字在深底上，對比刻意壓低、加一點雜訊。"""
    w, h = 900, 700
    image = Image.new("RGB", (w, h), (26, 28, 30))
    draw = ImageDraw.Draw(image)

    rows = [("單價", "31.6"), ("公升", "32.40"), ("金額", "1,024")]
    y = 90
    for label, value in rows:
        draw.text((80, y), label, font=font(54), fill=(120, 128, 132))
        draw.text((w - 80, y), value, font=font(96), fill=(214, 220, 224), anchor="ra")
        y += 180

    # 一點雜訊，模擬現場燈光與玻璃反光
    pixels = image.load()
    for i in range(0, w * h, 7):
        x, y2 = i % w, i // w
        r, g, b = pixels[x, y2]
        delta = (i % 9) - 4
        pixels[x, y2] = (max(0, r + delta), max(0, g + delta), max(0, b + delta))

    path = OUT / "pump-led.png"
    image.save(path)
    return path


if __name__ == "__main__":
    for path in (receipt(), pump_led()):
        print(path)
