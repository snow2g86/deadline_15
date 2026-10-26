#!/usr/bin/env python3
"""구글 플레이 대표 이미지(1024x500) 심플 버전 — 캐릭터 없이 '전술' 느낌: 등각 격자 맵 + 이동/공격 범위 + 화살표 + 15번째 줄 성문 표시.
사용: python3 make_feature_graphic_simple.py [ko|en|ja|zh-CN|zh-TW|es] -> feature_graphic_simple_<lang>_1024x500.png (ko 는 접미사 없음)
코드로만 그림(외부 이미지·AI 생성 없음). 화려한 버전은 make_feature_graphic.py."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "../../../godot/assets/fonts")
LANG = sys.argv[1] if len(sys.argv) > 1 else "ko"
FILES = {"ko": "NotoSansKR", "en": "NotoSansKR", "es": "NotoSansKR", "ja": "NotoSansJP", "zh-CN": "NotoSansSC", "zh-TW": "NotoSansTC"}
TEXT = {
    "ko": ("맵 끝에서 끝까지 15칸,", "그 끝을 막아라.", "턴제 전술 방어 RPG"),
    "en": ("15 tiles, edge to edge.", "Hold the line.", "Turn-based tactical defense RPG"),
    "ja": ("マップの端から端まで15マス、", "その先を守り抜け。", "ターン制戦術ディフェンスRPG"),
    "zh-CN": ("地图两端相隔15格，", "守住最后一线。", "回合制战术防御RPG"),
    "zh-TW": ("地圖兩端相隔15格，", "守住最後一線。", "回合制戰術防禦RPG"),
    "es": ("15 casillas de lado a lado.", "Defiende la línea.", "RPG de defensa táctico por turnos"),
}
OUT = os.path.join(HERE, "feature_graphic_simple_%s_1024x500.png" % LANG if LANG != "ko" else "feature_graphic_simple_1024x500.png")

W, H, SS = 1024, 500, 2
w, h = W * SS, H * SS
img = Image.new("RGB", (w, h), (10, 14, 26))
d = ImageDraw.Draw(img, "RGBA")
for y in range(h):
    t = y / h
    d.line([(0, y), (w, y)], fill=(int(10 + 20 * t), int(14 + 22 * t), int(26 + 40 * t)))

COLS, ROWS = 8, 15
tw, th = 70 * SS, 35 * SS
ox, oy = int(w * 0.77), int(-6 * SS)


def iso(cx, cy):
    return (ox + (cx - cy) * tw // 2, oy + (cx + cy) * th // 2)


def tile(cx, cy):
    x, y = iso(cx, cy)
    return [(x, y), (x + tw // 2, y + th // 2), (x, y + th), (x - tw // 2, y + th // 2)]


for cy in range(ROWS):
    for cx in range(COLS):
        s = 36 + ((cx + cy) % 2) * 6
        d.polygon(tile(cx, cy), fill=(s, s + 8, s + 22, 255), outline=(70, 90, 130, 160))

move = [(3, 7), (4, 7), (2, 7), (3, 6), (3, 8), (4, 6), (2, 8), (4, 8), (2, 6), (5, 7), (1, 7), (3, 5), (3, 9)]
attack = [(6, 7), (5, 6), (5, 8), (6, 6), (6, 8), (7, 7), (4, 5), (4, 9)]
for c in move:
    d.polygon(tile(*c), fill=(70, 140, 255, 120), outline=(130, 190, 255, 230))
for c in attack:
    d.polygon(tile(*c), fill=(255, 80, 80, 115), outline=(255, 150, 140, 230))
for c in [(3, 7), (5, 7)]:
    x, y = iso(*c)
    r = 9 * SS
    d.ellipse([x - r, y + th // 2 - r, x + r, y + th // 2 + r], fill=(255, 215, 90, 255), outline=(40, 30, 10, 255))


def arrow(points, col=(255, 235, 140, 255), wd=5 * SS):
    pts = [(x, y + th // 2) for x, y in (iso(*p) for p in points)]
    d.line(pts, fill=col, width=wd, joint="curve")
    (x1, y1), (x2, y2) = pts[-2], pts[-1]
    a = math.atan2(y2 - y1, x2 - x1)
    L = 16 * SS
    d.polygon([(x2 + math.cos(a) * 4 * SS, y2 + math.sin(a) * 4 * SS),
               (x2 - math.cos(a - 0.5) * L, y2 - math.sin(a - 0.5) * L),
               (x2 - math.cos(a + 0.5) * L, y2 - math.sin(a + 0.5) * L)], fill=col)


arrow([(1, 7), (2, 6), (3, 6), (4, 6)])
arrow([(2, 8), (3, 9), (4, 8), (5, 8)], col=(150, 205, 255, 255))
for cx in range(COLS):
    d.polygon(tile(cx, ROWS - 1), fill=(200, 40, 40, 150), outline=(255, 120, 100, 255))

fnt_num = ImageFont.truetype(os.path.join(FONTS, FILES[LANG] + "-VariableFont_wght.ttf"), 11 * SS)
for r in (1, 5, 10, 15):
    x, y = iso(COLS, r - 1)
    d.text((x + 6 * SS, y - 6 * SS), str(r), font=fnt_num, fill=(170, 190, 230, 200))

# 왼쪽을 어둡게 가려 글자 영역 확보
shade = Image.new("L", (w, h), 0)
sd = ImageDraw.Draw(shade)
for x in range(w):
    t = max(0.0, 1.0 - x / (w * 0.50))
    sd.line([(x, 0), (x, h)], fill=int(235 * t ** 0.8))
img = Image.composite(Image.new("RGB", (w, h), (8, 11, 22)), img, shade)
d = ImageDraw.Draw(img, "RGBA")


def font(sz, wght=800):
    f = ImageFont.truetype(os.path.join(FONTS, FILES[LANG] + "-VariableFont_wght.ttf"), sz * SS)
    try:
        f.set_variation_by_axes([wght])
    except Exception:
        pass
    return f


t1 = font(64, 900)
d.text((48 * SS, 120 * SS), "DEADLINE", font=t1, fill=(245, 247, 255, 255))
bw = d.textlength("DEADLINE ", font=t1) / SS
d.text(((48 + bw) * SS, 120 * SS), "15", font=t1, fill=(255, 92, 80, 255))
d.line([(52 * SS, 238 * SS), (330 * SS, 238 * SS)], fill=(255, 92, 80, 255), width=3 * SS)
l1, l2, l3 = TEXT[LANG]
d.text((52 * SS, 262 * SS), l1, font=font(30, 700), fill=(225, 232, 250, 255))
d.text((52 * SS, 306 * SS), l2, font=font(30, 700), fill=(255, 205, 120, 255))
d.text((52 * SS, 372 * SS), l3, font=font(22, 500), fill=(160, 175, 210, 255))

img = img.resize((W, H), Image.LANCZOS)
img.save(OUT)
print("saved", OUT, img.size)
