#!/usr/bin/env python3
"""앱 아이콘 엠블럼: 방패에 '15'. 금속 테두리 + 등각 격자 무늬 + 아래 붉은 성문 띠 + 금빛 숫자 + 후광/광선/불씨. 코드로만 그림.

사용
  python3 make_icon_shield.py                       -> icon_shield_1024.png / icon_shield_512.png (확정 시안, 이 폴더)
  python3 godot/tools/make_mobile_icons.py          -> 같은 그림으로 godot 의 모든 앱 아이콘 파일 (아래 레이어)

레이어 (render_layers() 가 1024 기준으로 돌려줌 — 전부 같은 그림 코드에서 나옴, 외부 그림·AI 없음)
  full    전체 합성 1024 RGB 불투명 (= 확정 시안. iOS 1024 · 데스크톱 icon.png · 192 레거시의 원본)
  bg      적응형 배경 — 남색 바탕 + 후광 + 광선 + 불씨 + 비네트 (방패·숫자 없음), RGB
  fg      적응형 전경 — 투명 바탕에 방패 + 숫자 + 작은 그림자만 (금빛 번짐은 전체 합성에만 — 적응형은 방패가 작아져 번짐 자리가 안 맞음), RGBA
  mono    테마 아이콘 — 방패 테두리 띠 + 방패 면(숫자는 뚫음)을 흰색 단색으로, RGBA
  fg_circle  fg 방패 바깥 윤곽(+그림자)이 들어가는 가장 작은 원 (cx, cy, r — 1024 좌표). 적응형 변환(fit_adaptive)이 씀
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "../../../godot/assets/fonts/NotoSansKR-VariableFont_wght.ttf")
S = 1024
CX, TOP, SW, SH = 512, 96, 640, 800


def bez(p0, p1, p2, n=40):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / n for i in range(n + 1)]]


def shield(cx, top, w, h, k=1.0):
    """방패 윤곽: 위는 살짝 오목한 직선, 옆은 곧게 내려오다 아래 꼭짓점으로 모임. k 로 안쪽 축소."""
    hw = w / 2 * k
    t = top + (1 - k) * h * 0.18
    hh = h * k
    pts = []
    pts += bez((cx - hw, t + 40 * k), (cx - hw * 0.5, t - 14 * k), (cx, t + 18 * k), 30)          # 왼 어깨 → 중앙 오목
    pts += bez((cx, t + 18 * k), (cx + hw * 0.5, t - 14 * k), (cx + hw, t + 40 * k), 30)          # 중앙 → 오른 어깨
    pts += [(cx + hw, t + hh * 0.52)]
    pts += bez((cx + hw, t + hh * 0.52), (cx + hw * 0.92, t + hh * 0.84), (cx, t + hh), 50)        # 오른쪽 곡선 → 꼭짓점
    pts += bez((cx, t + hh), (cx - hw * 0.92, t + hh * 0.84), (cx - hw, t + hh * 0.52), 50)        # 꼭짓점 → 왼쪽
    return pts


def mask_of(poly):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    return m


def vgrad(box_top, box_bot, c_top, c_bot):
    g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    for y in range(box_top, box_bot + 1):
        t = (y - box_top) / max(1, box_bot - box_top)
        gd.line([(0, y), (S, y)], fill=tuple(int(c_top[i] + (c_bot[i] - c_top[i]) * t) for i in range(3)) + (255,))
    return g


def paste_masked(base, layer, mask):
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(layer, (0, 0), mask)
    return Image.alpha_composite(base, out)


def blur(layer, r, k=1.0):
    b = layer.filter(ImageFilter.GaussianBlur(r))
    if k != 1.0:
        b.putalpha(b.split()[3].point(lambda v: min(255, int(v * k))))
    return b


def clear():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


OUTER = shield(CX, TOP, SW, SH, 1.0)
RIM_IN = shield(CX, TOP, SW, SH, 0.93)
FIELD = shield(CX, TOP, SW, SH, 0.875)


# ── 배경 조각
def step_backdrop():
    img = Image.new("RGBA", (S, S), (9, 12, 26, 255))
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / S
        d.line([(0, y), (S, y)], fill=(int(10 + 16 * t), int(13 + 10 * t), int(30 + 40 * t), 255))
    return img


def step_halo_rays(img):
    halo = clear()
    ImageDraw.Draw(halo).ellipse([130, 120, 894, 900], fill=(255, 120, 60, 130))
    img = Image.alpha_composite(img, blur(halo, 90))
    rays = clear()
    rd = ImageDraw.Draw(rays)
    for i in range(16):
        a = i * math.pi / 8
        w = 0.07
        rd.polygon([(512, 520), (512 + math.cos(a - w) * 900, 520 + math.sin(a - w) * 900), (512 + math.cos(a + w) * 900, 520 + math.sin(a + w) * 900)],
                   fill=(255, 190, 120, 24))
    return Image.alpha_composite(img, blur(rays, 4))


def step_shadow(img, dy=22, r=18, a=200):
    sh = clear()
    ImageDraw.Draw(sh).polygon([(x, y + dy) for x, y in OUTER], fill=(0, 0, 0, a))
    return Image.alpha_composite(img, blur(sh, r))


def step_glow(img):
    gl = clear()
    ImageDraw.Draw(gl).polygon(OUTER, fill=(255, 170, 70, 255))
    return Image.alpha_composite(img, blur(gl, 28, 0.55))


# ── 방패 몸체 (테두리 · 면 · 무늬 · 성문 띠 · 리벳)
def step_body(img):
    # 금속 테두리 (위 밝음 → 아래 어두운 금)
    img = paste_masked(img, vgrad(TOP, TOP + SH, (255, 238, 170), (150, 90, 25)), mask_of(OUTER))
    # 안쪽 경사(어두운 금)
    img = paste_masked(img, vgrad(TOP, TOP + SH, (120, 70, 20), (255, 215, 120)), mask_of(RIM_IN))
    # 방패 면
    fm = mask_of(FIELD)
    img = paste_masked(img, vgrad(TOP, TOP + SH, (28, 40, 92), (10, 14, 40)), fm)

    # 면 위 무늬: 등각 격자
    pat = clear()
    pd = ImageDraw.Draw(pat)
    step = 64
    for k in range(-20, 40):
        pd.line([(0, k * step), (S, k * step + S // 2)], fill=(120, 160, 255, 34), width=2)
        pd.line([(0, k * step + S // 2), (S, k * step)], fill=(120, 160, 255, 34), width=2)
    img = paste_masked(img, pat, fm)

    # 하이라이트(왼쪽 위 빛)
    hl = clear()
    ImageDraw.Draw(hl).polygon([(0, 0), (S, 0), (S, 380), (0, 620)], fill=(255, 255, 255, 30))
    img = paste_masked(img, hl, fm)

    # 붉은 성문 띠(아래쪽): field 마스크 ∩ y>690
    band = Image.new("L", (S, S), 0)
    ImageDraw.Draw(band).rectangle([0, 700, S, S], fill=255)
    bm = Image.fromarray(np.minimum(np.array(fm), np.array(band)))
    img = paste_masked(img, vgrad(700, 900, (230, 60, 50), (120, 20, 28)), bm)
    edge = clear()
    ImageDraw.Draw(edge).line([(0, 700), (S, 700)], fill=(255, 210, 150, 255), width=5)
    img = paste_masked(img, edge, fm)
    # 성문 빛기둥
    bem = clear()
    bd = ImageDraw.Draw(bem)
    for x in range(300, 740, 55):
        for j in range(24):
            bd.line([(x, 700 - j * 6), (x, 700 - (j + 1) * 6)], fill=(255, 130, 80, int(120 * (1 - j / 24) ** 1.5)), width=int(18 * (1 - j / 40)))
    img = paste_masked(img, blur(bem, 6, 1.4), fm)

    # 방패 테두리 안쪽 빛 라인
    ring = clear()
    ImageDraw.Draw(ring).line(FIELD + [FIELD[0]], fill=(255, 230, 160, 200), width=4, joint="curve")
    img = Image.alpha_composite(img, ring)

    # 리벳
    rv = clear()
    rvd = ImageDraw.Draw(rv)
    for x, y in [(CX - 255, 172), (CX + 255, 172), (CX, 150)]:
        rvd.ellipse([x - 13, y - 13, x + 13, y + 13], fill=(255, 235, 170, 255), outline=(110, 62, 18, 255), width=3)
    img = Image.alpha_composite(img, blur(rv, 3, 1.0))
    return Image.alpha_composite(img, rv)


# ── 숫자 15 (금 그라데이션 + 외곽선 + 발광)
def digits_mask():
    f = ImageFont.truetype(FONT, 410)
    try:
        f.set_variation_by_axes([900])
    except Exception:
        pass
    txt = "15"
    bb = ImageDraw.Draw(Image.new("L", (S, S))).textbbox((0, 0), txt, font=f)
    tx, ty = CX - (bb[2] - bb[0]) // 2 - bb[0], 280 - bb[1]
    mk = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mk).text((tx, ty), txt, font=f, fill=255)
    return mk


def step_number(img):
    mk = digits_mask()
    g2 = clear()
    g2.paste(Image.new("RGBA", (S, S), (255, 120, 50, 255)), (0, 0), mk.filter(ImageFilter.MaxFilter(11)))
    img = Image.alpha_composite(img, blur(g2, 26, 1.1))
    ol = clear()
    ol.paste(Image.new("RGBA", (S, S), (28, 12, 8, 255)), (0, 0), mk.filter(ImageFilter.MaxFilter(17)))
    img = Image.alpha_composite(img, ol)
    y0, y1 = mk.getbbox()[1], mk.getbbox()[3]
    img = paste_masked(img, vgrad(y0, y1, (255, 245, 190), (255, 150, 50)), mk)
    # 숫자 하이라이트 줄
    hi = clear()
    ImageDraw.Draw(hi).rectangle([0, y0, S, y0 + (y1 - y0) * 0.38], fill=(255, 255, 255, 36))
    return paste_masked(img, hi, mk)


# ── 불씨 · 비네트
def step_embers(img):
    random.seed(3)
    sp = clear()
    sd = ImageDraw.Draw(sp)
    for _ in range(50):
        x, y = random.randint(30, S - 30), random.randint(30, S - 30)
        r = random.choice([2, 3, 3, 5])
        sd.ellipse([x - r, y - r, x + r, y + r], fill=random.choice([(255, 200, 120), (255, 130, 80), (190, 225, 255)]) + (random.randint(130, 230),))
    return Image.alpha_composite(img, blur(sp, 2.2, 1.5))


def step_vignette(img):
    vg = Image.new("L", (S, S), 0)
    ImageDraw.Draw(vg).ellipse([-100, -100, S + 100, S + 100], fill=255)
    vg = vg.filter(ImageFilter.GaussianBlur(110))
    return Image.composite(img, Image.blend(img, Image.new("RGBA", (S, S), (0, 0, 0, 255)), 0.45), vg)


def mono_layer():
    """테마(단색) 아이콘: 방패 테두리 띠 + 방패 면 두 덩어리, 사이는 가는 틈, 숫자는 뚫음. 알파만 쓰이므로 흰색."""
    rim = np.array(mask_of(OUTER), dtype=np.int16) - np.array(mask_of(shield(CX, TOP, SW, SH, 0.925)), dtype=np.int16)
    face = np.array(mask_of(shield(CX, TOP, SW, SH, 0.855)), dtype=np.int16)
    cut = np.array(digits_mask().filter(ImageFilter.MaxFilter(5)), dtype=np.int16)
    a = np.clip(np.maximum(rim, 0) + face - cut, 0, 255).astype(np.uint8)
    out = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    out.putalpha(Image.fromarray(a))
    return out


def enclosing_circle(poly):
    """cx=512 고정, 가운데 y 를 훑어 윤곽이 가장 작은 원에 들어가게 하는 (cx, cy, r)"""
    best = None
    for cy in range(380, 620):
        r = max(math.hypot(x - CX, y - cy) for x, y in poly)
        if best is None or r < best[2]:
            best = (CX, cy, r)
    return best


def render_layers():
    # 전체 합성 — 확정 시안과 같은 순서
    full = step_backdrop()
    full = step_halo_rays(full)
    full = step_shadow(full)
    full = step_glow(full)
    full = step_body(full)
    full = step_number(full)
    full = step_embers(full)
    full = step_vignette(full)

    bg = step_halo_rays(step_backdrop())
    bg = step_vignette(step_embers(bg))

    fg = step_number(step_body(step_shadow(clear(), 14, 9, 150)))
    return {"full": full.convert("RGB"), "bg": bg.convert("RGB"), "fg": fg, "mono": mono_layer(),
            "fg_circle": enclosing_circle(OUTER + [(x, y + 34) for x, y in OUTER])}   # 그림자(+14 아래, 번짐 9) 까지 원 안


def fit_adaptive(layer, circle, n=432, diameter=280):
    """1024 레이어 → n×n 적응형 레이어. 방패 윤곽의 가장 작은 원이 가운데 지름 diameter(안전 영역) 안에 들어가게."""
    cx, cy, r = circle
    sc = (diameter / 2) / r
    side = int(round(S * sc))
    small = layer.resize((side, side), Image.LANCZOS)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.alpha_composite(small, (int(round(n / 2 - cx * sc)), int(round(n / 2 - cy * sc))))
    return out


def fit_box(layer, n, frac=0.9):
    """1024 레이어 → n×n 투명 바탕, 보이는 부분의 높이(또는 너비)가 n*frac 이 되게 가운데에 (시작 화면 그림용)"""
    bb = layer.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    crop = layer.crop(bb)
    sc = n * frac / max(crop.size)
    crop = crop.resize((max(1, round(crop.size[0] * sc)), max(1, round(crop.size[1] * sc))), Image.LANCZOS)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.alpha_composite(crop, ((n - crop.size[0]) // 2, (n - crop.size[1]) // 2))
    return out


def main():
    L = render_layers()
    out = os.path.join(HERE, "icon_shield_1024.png")
    L["full"].save(out)
    L["full"].resize((512, 512), Image.LANCZOS).save(os.path.join(HERE, "icon_shield_512.png"))
    print("saved", out)


if __name__ == "__main__":
    main()
