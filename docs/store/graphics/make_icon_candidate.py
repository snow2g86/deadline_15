#!/usr/bin/env python3
"""앱 아이콘 후보(심플, 대표 이미지와 같은 결): 등각 격자 + 파란 이동칸 + 빨간 성문 줄 + 큰 '15'. 코드로만 그림.
사용: python3 make_icon_candidate.py -> icon_candidate_1024.png (1024x1024, 모서리는 스토어가 자름)"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "../../../godot/assets/fonts/NotoSansKR-VariableFont_wght.ttf")
S = 1024
img = Image.new("RGB", (S, S), (10, 14, 28))
d = ImageDraw.Draw(img, "RGBA")
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=(int(12 + 22 * t), int(16 + 18 * t), int(36 + 50 * t)))

tw, th = 128, 64
ox, oy = S // 2, 70


def iso(cx, cy):
    return (ox + (cx - cy) * tw // 2, oy + (cx + cy) * th // 2)


def tile(cx, cy):
    x, y = iso(cx, cy)
    return [(x, y), (x + tw // 2, y + th // 2), (x, y + th), (x - tw // 2, y + th // 2)]


N = 6
for cy in range(N):
    for cx in range(N):
        s = 40 + ((cx + cy) % 2) * 8
        col = (s, s + 8, s + 26, 255)
        edge = (95, 120, 180, 170)
        if cy == N - 1:
            col, edge = (210, 50, 45, 230), (255, 175, 140, 255)
        elif (cx, cy) in [(1, 2), (2, 2), (3, 2), (2, 3), (3, 3), (2, 1)]:
            col, edge = (60, 140, 250, 190), (150, 215, 255, 255)
        d.polygon(tile(cx, cy), fill=col, outline=edge)

glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).polygon(tile(2, N - 1), fill=(255, 90, 60, 255))
img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(26)))
d = ImageDraw.Draw(img, "RGBA")

f = ImageFont.truetype(FONT, 360)
try:
    f.set_variation_by_axes([900])
except Exception:
    pass
txt = "15"
bb = d.textbbox((0, 0), txt, font=f)
tx, ty = (S - (bb[2] - bb[0])) // 2 - bb[0], 520 - bb[1]
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).text((tx, ty), txt, font=f, fill=255)
glow2 = Image.new("RGBA", (S, S), (0, 0, 0, 0))
glow2.paste(Image.new("RGBA", (S, S), (255, 80, 50, 255)), (0, 0), mask.filter(ImageFilter.MaxFilter(9)))
img = Image.alpha_composite(img, glow2.filter(ImageFilter.GaussianBlur(28)))
outl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
outl.paste(Image.new("RGBA", (S, S), (8, 10, 24, 255)), (0, 0), mask.filter(ImageFilter.MaxFilter(15)))
img = Image.alpha_composite(img, outl)
y0, y1 = mask.getbbox()[1], mask.getbbox()[3]
grad = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(grad)
for y in range(y0, y1 + 1):
    t = (y - y0) / max(1, y1 - y0)
    gd.line([(0, y), (S, y)], fill=(255, int(235 - 150 * t), int(120 - 80 * t), 255))
fillimg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
fillimg.paste(grad, (0, 0), mask)
img = Image.alpha_composite(img, fillimg)


# ── 꾸미기: 빛기둥 / 불씨 / 금빛 테두리 / 비네트
import random, math
random.seed(7)
def blur_over(layer, r, k=1.0):
    global img
    b = layer.filter(ImageFilter.GaussianBlur(r))
    if k != 1.0:
        b.putalpha(b.split()[3].point(lambda v: min(255, int(v * k))))
    img = Image.alpha_composite(img, b)

# 빨간 줄 위로 솟는 빛기둥
beam = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bd = ImageDraw.Draw(beam)
for cx in range(N):
    x, y = iso(cx, N - 1)
    y += th // 2
    for j in range(40):
        a = int(210 * (1 - j / 40) ** 1.4)
        bd.line([(x, y - j * 5), (x, y - (j + 1) * 5)], fill=(255, 120, 70, a), width=int(26 * (1 - j / 70)))
blur_over(beam, 8, 1.8)

# 파란 영역 발광
bl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bld = ImageDraw.Draw(bl)
for c in [(1, 2), (2, 2), (3, 2), (2, 3), (3, 3), (2, 1)]:
    bld.polygon(tile(*c), fill=(80, 160, 255, 255))
blur_over(bl, 22, 0.55)

# 방사 빛(숫자 뒤)
rg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(rg).ellipse([160, 470, 864, 860], fill=(255, 100, 50, 90))
blur_over(rg, 70)

# 불씨
sp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(sp)
for _ in range(70):
    x, y = random.randint(40, S - 40), random.randint(40, S - 40)
    r = random.choice([2, 3, 3, 5, 7])
    col = random.choice([(255, 200, 120), (255, 130, 80), (190, 225, 255), (255, 245, 210)])
    sd.ellipse([x - r, y - r, x + r, y + r], fill=col + (random.randint(130, 255),))
blur_over(sp, 2.5, 1.5)
img = Image.alpha_composite(img, sp)

# 금빛 이중 테두리
fr = Image.new("RGBA", (S, S), (0, 0, 0, 0))
fd = ImageDraw.Draw(fr)
fd.rounded_rectangle([34, 34, S - 34, S - 34], radius=120, outline=(255, 214, 120, 255), width=10)
fd.rounded_rectangle([54, 54, S - 54, S - 54], radius=102, outline=(255, 150, 70, 200), width=4)
blur_over(fr, 7, 1.4)
img = Image.alpha_composite(img, fr)
# 모서리 장식(마름모)
dec = Image.new("RGBA", (S, S), (0, 0, 0, 0))
dd = ImageDraw.Draw(dec)
for cx_, cy_ in [(S // 2, 34), (S // 2, S - 34), (34, S // 2), (S - 34, S // 2)]:
    r = 22
    dd.polygon([(cx_, cy_ - r), (cx_ + r, cy_), (cx_, cy_ + r), (cx_ - r, cy_)], fill=(255, 226, 150, 255), outline=(120, 60, 20, 255))
blur_over(dec, 6, 1.2)
img = Image.alpha_composite(img, dec)

# 비네트
vg = Image.new("L", (S, S), 0)
ImageDraw.Draw(vg).ellipse([-120, -120, S + 120, S + 120], fill=255)
vg = vg.filter(ImageFilter.GaussianBlur(120))
img = Image.composite(img, Image.blend(img, Image.new("RGBA", (S, S), (0, 0, 0, 255)), 0.28), vg)

out = os.path.join(HERE, "icon_candidate_1024.png")
img.convert("RGB").save(out)
img.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(HERE, "icon_candidate_512.png"))
print("saved", out)
