#!/usr/bin/env python3
"""구글 플레이 대표 이미지(1024x500) v2 — 캐릭터 없이 '전술' + 화려한 빛 효과.
등각 격자 맵 + 이동(청)/공격(적) 범위 발광 + 마법진 + 15번째 줄 성문 빛기둥 + 불씨 입자 + 글로우 제목.
사용: python3 make_feature_graphic.py [ko|en|ja|zh-CN|zh-TW|es] -> feature_graphic_fancy_<lang>_1024x500.png
코드로만 그림(외부 이미지·AI 생성 없음). 글꼴은 godot/assets/fonts 의 Noto Sans."""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

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
OUT = os.path.join(HERE, f"feature_graphic_fancy_{LANG}_1024x500.png" if LANG != "ko" else "feature_graphic_fancy_1024x500.png")

W, H, SS = 1024, 500, 2
w, h = W * SS, H * SS
random.seed(15)


def font(sz, wght=800):
    f = ImageFont.truetype(os.path.join(FONTS, FILES[LANG] + "-VariableFont_wght.ttf"), int(sz * SS))
    try:
        f.set_variation_by_axes([wght])
    except Exception:
        pass
    return f


def glow(layer, radius, strength=1.0):
    b = layer.filter(ImageFilter.GaussianBlur(radius * SS))
    if strength != 1.0:
        a = b.split()[3].point(lambda v: min(255, int(v * strength)))
        b.putalpha(a)
    return b


def over(base, layer):
    base.alpha_composite(layer)


# ── 배경: 깊은 남색 + 보랏빛/주황빛 방사
base = Image.new("RGBA", (w, h), (7, 9, 22, 255))
bgd = ImageDraw.Draw(base)
for y in range(h):
    t = y / h
    bgd.line([(0, y), (w, y)], fill=(int(8 + 14 * t), int(10 + 8 * t), int(26 + 30 * t), 255))
rad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
rd = ImageDraw.Draw(rad)
rd.ellipse([w * 0.40, -h * 0.25, w * 1.15, h * 1.15], fill=(110, 60, 200, 120))
rd.ellipse([w * 0.58, h * 0.25, w * 1.05, h * 1.05], fill=(255, 110, 60, 70))
over(base, glow(rad, 90))

# ── 등각 격자
COLS, ROWS = 8, 15
tw, th = 72 * SS, 36 * SS
ox, oy = int(w * 0.79), int(-4 * SS)


def iso(cx, cy):
    return (ox + (cx - cy) * tw // 2, oy + (cx + cy) * th // 2)


def tile(cx, cy):
    x, y = iso(cx, cy)
    return [(x, y), (x + tw // 2, y + th // 2), (x, y + th), (x - tw // 2, y + th // 2)]


grid = Image.new("RGBA", (w, h), (0, 0, 0, 0))
gd = ImageDraw.Draw(grid)
for cy in range(ROWS):
    for cx in range(COLS):
        s = 30 + ((cx + cy) % 2) * 7
        gd.polygon(tile(cx, cy), fill=(s, s + 8, s + 28, 235), outline=(90, 120, 190, 150))
over(base, grid)

move = [(2, 6), (3, 6), (4, 6), (1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (2, 8), (3, 8), (4, 8), (3, 5), (3, 9)]
attack = [(5, 6), (6, 6), (6, 7), (7, 7), (5, 8), (6, 8), (4, 5), (4, 9), (5, 9)]


def tiles_layer(cells, fill, edge):
    L = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(L)
    for c in cells:
        ld.polygon(tile(*c), fill=fill, outline=edge)
    return L


mv = tiles_layer(move, (60, 150, 255, 150), (150, 225, 255, 255))
at = tiles_layer(attack, (255, 70, 50, 150), (255, 190, 140, 255))
over(base, glow(mv, 10, 1.6)); over(base, mv)
over(base, glow(at, 10, 1.6)); over(base, at)

# ── 마법진
cxm, cym = iso(3.0, 7.0)
cym += th // 2
circ = Image.new("RGBA", (w, h), (0, 0, 0, 0))
cd = ImageDraw.Draw(circ)
for rx, col in [(150, (170, 220, 255, 230)), (118, (255, 225, 140, 220)), (86, (170, 220, 255, 200))]:
    ry = rx // 2
    cd.ellipse([cxm - rx * SS, cym - ry * SS, cxm + rx * SS, cym + ry * SS], outline=col, width=2 * SS)
for i in range(12):
    a = i * math.pi / 6
    rx, ry = 134 * SS, 67 * SS
    x, y = cxm + math.cos(a) * rx, cym + math.sin(a) * ry
    cd.ellipse([x - 4 * SS, y - 3 * SS, x + 4 * SS, y + 3 * SS], fill=(255, 235, 170, 255))
for i in range(6):
    a1 = i * math.pi / 3 - math.pi / 2
    a2 = a1 + 2 * math.pi / 3
    rx, ry = 118 * SS, 59 * SS
    cd.line([(cxm + math.cos(a1) * rx, cym + math.sin(a1) * ry), (cxm + math.cos(a2) * rx, cym + math.sin(a2) * ry)], fill=(255, 225, 140, 200), width=2 * SS)
over(base, glow(circ, 6, 1.8)); over(base, circ)

# ── 15번째 줄: 성문 빛기둥
gate = Image.new("RGBA", (w, h), (0, 0, 0, 0))
gtd = ImageDraw.Draw(gate)
for cx in range(COLS):
    gtd.polygon(tile(cx, ROWS - 1), fill=(255, 60, 40, 200), outline=(255, 200, 150, 255))
over(base, glow(gate, 14, 2.0)); over(base, gate)
beam = Image.new("RGBA", (w, h), (0, 0, 0, 0))
bd = ImageDraw.Draw(beam)
for cx in range(COLS):
    x, y = iso(cx, ROWS - 1)
    y += th // 2
    for j in range(60):
        a = int(255 * (1 - j / 60) ** 1.3)
        bd.line([(x, y - j * 3 * SS), (x, y - (j + 1) * 3 * SS)], fill=(255, 110, 70, a), width=int(22 * SS * (1 - j / 90)))
over(base, glow(beam, 7, 2.2)); over(base, glow(beam, 2, 1.2))


# ── 이동 화살표(발광)
def arrow(points, col, wd=5):
    L = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ad = ImageDraw.Draw(L)
    pts = [(x, y + th // 2) for x, y in (iso(*p) for p in points)]
    ad.line(pts, fill=col, width=wd * SS, joint="curve")
    (x1, y1), (x2, y2) = pts[-2], pts[-1]
    a = math.atan2(y2 - y1, x2 - x1)
    Ln = 18 * SS
    ad.polygon([(x2 + math.cos(a) * 5 * SS, y2 + math.sin(a) * 5 * SS),
                (x2 - math.cos(a - 0.5) * Ln, y2 - math.sin(a - 0.5) * Ln),
                (x2 - math.cos(a + 0.5) * Ln, y2 - math.sin(a + 0.5) * Ln)], fill=col)
    over(base, glow(L, 6, 2.2)); over(base, L)


arrow([(1, 7), (2, 6), (3, 6), (4, 6), (5, 6)], (255, 240, 150, 255))
arrow([(2, 8), (3, 9), (4, 8), (5, 8), (6, 8)], (170, 225, 255, 255))

# ── 방어 말(노란 구슬)
orbs = Image.new("RGBA", (w, h), (0, 0, 0, 0))
od = ImageDraw.Draw(orbs)
for c in [(3, 7), (4, 8), (4, 6)]:
    x, y = iso(*c)
    y += th // 2
    r = 11 * SS
    od.ellipse([x - r, y - r, x + r, y + r], fill=(255, 220, 90, 255), outline=(255, 250, 220, 255), width=2 * SS)
over(base, glow(orbs, 9, 2.4)); over(base, orbs)

# ── 불씨 입자
sp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
sd = ImageDraw.Draw(sp)
for _ in range(120):
    x = random.randint(int(w * 0.30), w)
    y = random.randint(0, h)
    r = random.choice([1, 1, 2, 2, 3]) * SS
    col = random.choice([(255, 190, 110), (255, 120, 80), (190, 220, 255), (255, 245, 200)])
    sd.ellipse([x - r, y - r, x + r, y + r], fill=col + (random.randint(120, 255),))
over(base, glow(sp, 2.5, 1.6)); over(base, sp)

# ── 왼쪽 글자 영역을 어둡게
shade = Image.new("L", (w, h), 0)
sh = ImageDraw.Draw(shade)
for x in range(w):
    t = max(0.0, 1.0 - x / (w * 0.50))
    sh.line([(x, 0), (x, h)], fill=int(225 * t ** 0.9))
dark = Image.new("RGBA", (w, h), (6, 8, 20, 255))
base = Image.composite(dark, base, shade)


# ── 글자 (그라데이션 + 외곽선 + 글로우)
def text_gradient(txt, fnt, xy, top, bottom, outline=(8, 10, 26, 255), ow=4, glowcol=None):
    global base
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text(xy, txt, font=fnt, fill=255)
    bbox = mask.getbbox()
    y0, y1 = bbox[1], bbox[3]
    grad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gp = ImageDraw.Draw(grad)
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        gp.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    fill = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fill.paste(grad, (0, 0), mask)
    if glowcol:
        gl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        gl.paste(Image.new("RGBA", (w, h), glowcol), (0, 0), mask.filter(ImageFilter.MaxFilter(5)))
        over(base, glow(gl, 14, 2.2))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (w, h), outline), (0, 0), mask.filter(ImageFilter.MaxFilter(2 * ow + 1)))
    over(base, out); over(base, fill)


tf = font(70, 900)
text_gradient("DEADLINE", tf, (46 * SS, 108 * SS), (255, 255, 255), (170, 195, 255), glowcol=(120, 150, 255, 255))
bw = ImageDraw.Draw(Image.new("L", (10, 10))).textlength("DEADLINE ", font=tf) / SS
text_gradient("15", tf, (int((46 + bw) * SS), 108 * SS), (255, 235, 130), (255, 70, 50), glowcol=(255, 90, 40, 255))

line = Image.new("RGBA", (w, h), (0, 0, 0, 0))
ImageDraw.Draw(line).line([(50 * SS, 230 * SS), (350 * SS, 230 * SS)], fill=(255, 110, 70, 255), width=3 * SS)
over(base, glow(line, 6, 2.0)); over(base, line)
l1, l2, l3 = TEXT[LANG]
text_gradient(l1, font(29, 700), (50 * SS, 252 * SS), (255, 255, 255), (205, 220, 250), ow=3)
text_gradient(l2, font(31, 800), (50 * SS, 297 * SS), (255, 240, 170), (255, 170, 70), ow=3, glowcol=(255, 150, 60, 200))
ImageDraw.Draw(base, "RGBA").text((52 * SS, 372 * SS), l3, font=font(21, 500), fill=(170, 185, 225, 255))

# ── 비네트
vg = Image.new("L", (w, h), 0)
ImageDraw.Draw(vg).ellipse([-w * 0.15, -h * 0.35, w * 1.15, h * 1.35], fill=255)
vg = vg.filter(ImageFilter.GaussianBlur(70 * SS))
black = Image.new("RGBA", (w, h), (0, 0, 0, 255))
base = Image.composite(base, Image.blend(base, black, 0.55), vg)

img = base.convert("RGB").resize((W, H), Image.LANCZOS)
img.save(OUT)
print("saved", OUT, img.size)
