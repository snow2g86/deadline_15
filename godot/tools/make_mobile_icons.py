#!/usr/bin/env python3
"""6a: 모바일 앱 아이콘·시작 화면 그림 — PC 임시 아이콘(godot/icon.png, 지휘관 그림)을 크기별로 (새 그림 아님)

사용: python3 godot/tools/make_mobile_icons.py        → godot/assets/app_icon/*.png

- 바탕은 게임 본문 바탕과 같은 남색 그라디언트(#1e2d4a → #0a0e1a, 바깥 화면 Body 와 같은 색) — 스토어 아이콘은 투명을 받지 않으므로
- 안드로이드: 기본 아이콘 192 (바탕 + 그림), 적응형 전경 432 (투명 + 그림 60% — 런처가 가운데 66%(안전 영역)만 보여 주므로 그 안에 들어가게) ·
  배경 432 (바탕만) · 테마 아이콘(monochrome) 432 (같은 그림의 윤곽 = 알파를 흰색으로, 같은 60%)
- iOS: 1024 (불투명 — App Store 요구, Godot 이 나머지 크기를 이것으로 줄임)
- 시작 화면: iOS 스토리보드 그림 @2x 400 · @3x 600 (투명 + 그림, 바탕은 프리셋의 바탕색 #0a0e1a)
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "icon.png")
OUT = os.path.join(ROOT, "assets", "app_icon")
TOP, BOTTOM = (0x1E, 0x2D, 0x4A), (0x0A, 0x0E, 0x1A)


def backdrop(n):
    """바깥 화면 Body 와 같은 방사형 그라디언트 (가운데 위 20% 가 밝음)"""
    im = Image.new("RGB", (n, n))
    px = im.load()
    cx, cy = n * 0.5, n * 0.2
    rx, ry = n * 1.15 * 0.5 * 1.4, n * 1.05 * 0.5 * 1.4
    for y in range(n):
        for x in range(n):
            d = min(1.0, (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2) ** 0.5)
            px[x, y] = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * d) for i in range(3))
    return im


def figure(n, scale):
    src = Image.open(SRC).convert("RGBA")
    s = int(round(n * scale))
    fig = src.resize((s, s), Image.LANCZOS)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.alpha_composite(fig, ((n - s) // 2, (n - s) // 2))
    return out


def composed(n, scale=1.0):
    bg = backdrop(n).convert("RGBA")
    bg.alpha_composite(figure(n, scale))
    return bg.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    composed(192).save(os.path.join(OUT, "android_192.png"))
    figure(432, 0.6).save(os.path.join(OUT, "android_fg_432.png"))
    fg = figure(432, 0.6)
    mono = Image.new("RGBA", fg.size, (255, 255, 255, 0))
    mono.putalpha(fg.getchannel("A").point(lambda a: 255 if a > 127 else 0))
    mono.save(os.path.join(OUT, "android_mono_432.png"))
    backdrop(432).save(os.path.join(OUT, "android_bg_432.png"))
    composed(1024).save(os.path.join(OUT, "ios_1024.png"))
    figure(400, 1.0).save(os.path.join(OUT, "launch_400.png"))
    figure(600, 1.0).save(os.path.join(OUT, "launch_600.png"))
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".png"):
            im = Image.open(os.path.join(OUT, f))
            print(f, im.size, im.mode)


if __name__ == "__main__":
    main()
