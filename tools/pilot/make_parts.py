#!/usr/bin/env python3
"""커스터마이징 시범: 기사 조각 그림을 프로그램으로 그림 (16비트 도트, 어두운 외곽선)

사용: python3 tools/pilot/make_parts.py [--preview 출력.png]
출력: godot/assets/pilot/knight/<f|b>/<조각>.png (4배 확대) + godot/assets/pilot/knight/rig.json (조각 위치·관절)

방식: 128x128 '기준 칸' 위에 조각마다 도형(다각형·타원)을 겹쳐 칠하고, 도형마다 어두운 외곽선 1칸 + 왼쪽 위 밝은 띠 + 오른쪽 아래 어두운 띠를 자동으로 얹음.
      조각은 모두 같은 기준 칸 좌표에 그려서(= 서로 맞는 자리) 잘라 저장하고, 위치(왼쪽 위 좌표)를 rig.json 에 적음.
앞(f) = 오른쪽을 보는 3/4 모습(원본 그림과 같은 방향), 뒤(b) = 등을 보임. 왼쪽 방향은 Godot 에서 좌우 뒤집어 씀.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw

W = H = 128
K = 4  # 저장 확대 배율 (기준 칸 1칸 = 4픽셀)
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, 'godot/assets/pilot/knight')

OL = (26, 18, 34, 255)   # 외곽선


def C(r, g, b):
    return (r, g, b, 255)


# 색 (기본, 밝은, 어두운)
PAL = {
    'steel':  (C(136, 142, 170), C(200, 208, 234), C(80, 82, 116)),
    'dsteel': (C(96, 98, 128), C(144, 150, 180), C(54, 54, 86)),
    'gold':   (C(214, 170, 72), C(248, 218, 124), C(150, 106, 52)),
    'red':    (C(180, 48, 56), C(228, 96, 88), C(112, 28, 46)),
    'blue':   (C(52, 92, 172), C(100, 148, 224), C(30, 52, 112)),
    'green':  (C(62, 124, 84), C(112, 176, 122), C(36, 76, 58)),
    'leather': (C(124, 82, 54), C(172, 124, 86), C(78, 48, 40)),
    'dleather': (C(88, 60, 48), C(132, 92, 68), C(54, 36, 36)),
    'cloth':  (C(220, 208, 188), C(248, 240, 222), C(160, 148, 138)),
    'pants':  (C(80, 74, 102), C(116, 110, 142), C(52, 48, 74)),
    'skin':   (C(244, 188, 142), C(255, 224, 188), C(204, 138, 108)),
    'brown':  (C(112, 66, 42), C(166, 112, 72), C(66, 38, 32)),
    'blonde': (C(232, 196, 98), C(255, 234, 152), C(170, 128, 58)),
    'white':  (C(238, 238, 244), C(255, 255, 255), C(176, 178, 200)),
}


def shift(m, dx, dy):
    o = np.zeros_like(m)
    ys, xs = slice(max(dy, 0), H + min(dy, 0)), slice(max(dx, 0), W + min(dx, 0))
    ys0, xs0 = slice(max(-dy, 0), H + min(-dy, 0)), slice(max(-dx, 0), W + min(-dx, 0))
    o[ys, xs] = m[ys0, xs0]
    return o


def dilate(m):
    return m | shift(m, 1, 0) | shift(m, -1, 0) | shift(m, 0, 1) | shift(m, 0, -1)


TX = None   # (기준x, 기준y, 가로배율, 세로배율) — 머리·몸통을 키울 때 도형 좌표를 한꺼번에 늘림


def _t(x, y):
    if TX is None:
        return float(x), float(y)
    ax, ay, sx, sy = TX
    return ax + (x - ax) * sx, ay + (y - ay) * sy


def poly(pts):
    im = Image.new('L', (W, H), 0)
    ImageDraw.Draw(im).polygon([_t(x, y) for x, y in pts], fill=255)
    return np.array(im) > 0


def ell(cx, cy, rx, ry):
    x, y = _t(cx, cy)
    sx, sy = (1, 1) if TX is None else (TX[2], TX[3])
    im = Image.new('L', (W, H), 0)
    ImageDraw.Draw(im).ellipse([x - rx * sx, y - ry * sy, x + rx * sx, y + ry * sy], fill=255)
    return np.array(im) > 0


def rect(x0, y0, x1, y1):
    return poly([(x0, y0), (x1 - 1, y0), (x1 - 1, y1 - 1), (x0, y1 - 1)]) if TX is not None else _rect(x0, y0, x1, y1)


def _rect(x0, y0, x1, y1):
    m = np.zeros((H, W), bool)
    m[int(y0):int(y1), int(x0):int(x1)] = True
    return m


def line(p0, p1, wd=1):
    im = Image.new('L', (W, H), 0)
    ImageDraw.Draw(im).line([_t(*p0), _t(*p1)], fill=255, width=wd)
    return np.array(im) > 0


def grit(m, seed=0):
    """도형 안쪽에 드문드문 밝고 어두운 점을 흩뿌려 원본 그림의 거친 질감을 흉내 (좌표로 정해지는 값이라 항상 같음)"""
    ys, xs = np.mgrid[0:H, 0:W]
    h = ((xs * 73856093) ^ (ys * 19349663) ^ (seed * 83492791)) & 0xFF
    return m & (h < 14), m & (h > 240)


class Layer:
    def __init__(self):
        self.px = np.zeros((H, W, 4), np.uint8)

    def paint(self, m, pal, outline=True, band=2, shade=True, mul=1.0, grit_on=True):
        base, hi, lo = PAL[pal] if isinstance(pal, str) else pal
        if mul != 1.0:
            base, hi, lo = [tuple(int(c * mul) for c in col[:3]) + (255,) for col in (base, hi, lo)]
        if outline:
            self.px[dilate(m) & ~m] = OL
        self.px[m] = base
        if grit_on and isinstance(pal, str) and pal in ('steel', 'dsteel', 'leather', 'dleather'):
            g_hi, g_lo = grit(m, int(base[0]))
            self.px[g_lo] = lo
            self.px[g_hi] = hi
        if shade:
            self.px[m & ~shift(m, -band - 1, -band - 1)] = lo
            self.px[m & ~shift(m, band, band)] = hi
        return self

    def flat(self, m, col):
        self.px[m] = col if len(col) == 4 else tuple(col) + (255,)
        return self

    def dots(self, pts, col):
        for x, y in pts:
            self.px[int(y), int(x)] = col if len(col) == 4 else tuple(col) + (255,)
        return self

    def img(self):
        return Image.fromarray(self.px, 'RGBA')


def crop_save(layer, path):
    """투명 여백 잘라 저장. 반환: 기준 칸에서의 왼쪽 위 좌표와 크기"""
    im = layer.img()
    bb = im.getbbox()
    if bb is None:
        return None
    c = im.crop(bb).resize(((bb[2] - bb[0]) * K, (bb[3] - bb[1]) * K), Image.NEAREST)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    c.save(path, optimize=True)
    return {'x': bb[0], 'y': bb[1], 'w': bb[2] - bb[0], 'h': bb[3] - bb[1]}


# ────────────────────────────────────────────────────────────────
# 관절(기준 칸 좌표). 앞(f): 오른쪽을 봄, 칼 든 팔이 앞쪽(가까운 쪽). 뒤(b): 칼 든 팔이 화면 오른쪽
# ────────────────────────────────────────────────────────────────
JOINTS = {
    'f': {'hip': (60, 88), 'neck': (63, 50), 'sh_n': (53, 58), 'sh_f': (75, 59), 'wr_n': (57, 82), 'wr_f': (75, 80),
          'leg_n': (56, 88), 'leg_f': (66, 88)},
    'b': {'hip': (60, 88), 'neck': (60, 50), 'sh_n': (73, 58), 'sh_f': (47, 58), 'wr_n': (72, 82), 'wr_f': (46, 80),
          'leg_n': (66, 88), 'leg_f': (55, 88)},
}


# ═══════════ 몸 기본형 (직업 고정: 다리·정강이받이·장화) ═══════════
def leg(view, near):
    L = Layer()
    j = JOINTS[view]['leg_n' if near else 'leg_f']
    x, y = j
    mul = 1.0 if near else 0.82
    # 허벅지(천) → 무릎 보호대 → 정강이받이(강철) → 장화(가죽)
    L.paint(rect(x - 6, y - 2, x + 6, y + 14), 'pants', mul=mul)
    L.paint(ell(x, y + 13, 6, 4), 'steel', mul=mul)
    L.paint(rect(x - 5, y + 14, x + 5, y + 26), 'steel', mul=mul)
    boot = poly([(x - 6, y + 24), (x + 6, y + 24), (x + 7, y + 29), (x + (13 if view == 'f' else 7), y + 30),
                 (x + (14 if view == 'f' else 8), y + 32), (x - 7, y + 32)])
    L.paint(boot, 'leather', mul=mul)
    L.flat(rect(x - 6, y + 26, x + 8, y + 27), PAL['gold'][0] if False else PAL['dleather'][2])
    return L


# ═══════════ 옷 (3종): 몸통 + 팔 ═══════════
def torso(view, outfit):
    L = Layer()
    f = view == 'f'
    if outfit == 0:   # 강철 갑옷 + 붉은 겉옷
        if not f:     # 붉은 망토 (등 뒤로 늘어짐)
            L.paint(poly([(44, 54), (76, 54), (80, 96), (72, 104), (60, 100), (48, 104), (40, 96)]), 'red')
            L.paint(rect(58, 60, 62, 98), 'red', outline=False, shade=False, mul=0.78)
        L.paint(poly([(45, 54), (52, 51), (70, 51), (77, 55), (76, 68), (72, 86), (49, 86), (45, 68)]), 'steel')
        if f:
            L.paint(poly([(53, 56), (70, 56), (73, 66), (63, 73), (52, 66)]), 'steel')
            L.paint(poly([(55, 86), (71, 86), (73, 98), (63, 104), (53, 98)]), 'red')
            L.flat(rect(54, 99, 72, 101), PAL['gold'][0])
            L.paint(poly([(45, 85), (55, 85), (54, 96), (46, 93)]), 'dsteel')
            L.paint(rect(47, 82, 74, 87), 'leather')
            L.paint(rect(60, 81, 66, 88), 'gold', band=1)
        else:
            L.paint(poly([(48, 56), (72, 56), (73, 70), (68, 84), (52, 84), (47, 70)]), 'dsteel')
            L.paint(rect(47, 82, 74, 87), 'leather')
            L.flat(rect(59, 58, 62, 82), PAL['dsteel'][2])
        L.paint(ell(61, 52, 9, 3), 'steel')
    elif outfit == 1:  # 푸른 겉옷 + 금 장식
        L.paint(poly([(45, 54), (52, 51), (70, 51), (77, 55), (76, 70), (73, 88), (49, 88), (45, 70)]), 'blue')
        if f:
            L.paint(poly([(48, 86), (74, 86), (77, 104), (64, 100), (62, 106), (47, 102)]), 'blue')
            L.flat(rect(60, 56, 64, 100), PAL['gold'][0])
            L.flat(rect(54, 66, 70, 69), PAL['gold'][0])      # 가슴 십자
            L.paint(rect(47, 82, 74, 87), 'dleather')
            L.paint(rect(60, 81, 66, 88), 'gold', band=1)
            L.paint(ell(61, 52, 9, 3), 'white')
        else:
            L.paint(poly([(47, 86), (75, 86), (78, 104), (62, 100), (61, 106), (45, 102)]), 'blue')
            L.flat(rect(59, 56, 62, 100), PAL['blue'][2])
            L.paint(rect(47, 82, 74, 87), 'dleather')
            L.paint(ell(61, 52, 9, 3), 'white')
        L.paint(poly([(45, 54), (60, 53), (60, 60), (47, 62)]), 'steel')   # 어깨 덧대
    else:              # 가죽 조끼 + 초록 띠
        L.paint(poly([(45, 54), (52, 51), (70, 51), (77, 55), (76, 70), (72, 88), (49, 88), (45, 70)]), 'cloth')
        L.paint(poly([(47, 54), (56, 52), (58, 54), (60, 86), (49, 86), (46, 70)]) if f else
                poly([(47, 54), (73, 54), (74, 72), (71, 86), (50, 86), (46, 72)]), 'dleather')
        if f:
            L.paint(poly([(66, 53), (73, 55), (73, 60), (52, 80), (47, 78), (47, 73)]), 'green')   # 어깨띠
            L.paint(rect(47, 82, 74, 87), 'leather')
            L.paint(rect(61, 80, 67, 89), 'gold', band=1)
            L.paint(poly([(48, 87), (74, 87), (73, 97), (68, 99), (64, 94), (58, 99), (53, 94), (49, 98)]), 'leather')
            L.dots([(52, 60), (52, 66), (52, 72), (55, 78)], PAL['gold'][1])
        else:
            L.paint(poly([(46, 54), (53, 53), (73, 78), (68, 82), (46, 62)]), 'green')
            L.paint(rect(47, 82, 74, 87), 'leather')
            L.paint(poly([(48, 87), (74, 87), (73, 98), (66, 94), (60, 99), (54, 94), (49, 98)]), 'leather')
        L.paint(ell(61, 52, 8, 3), 'cloth')
    return L


def arm(view, outfit, near):
    L = Layer()
    j = JOINTS[view]['sh_n' if near else 'sh_f']
    wr = JOINTS[view]['wr_n' if near else 'wr_f']
    x, y = j
    mul = 1.0 if near else 0.78
    wy = wr[1]
    if outfit == 0:    # 강철 어깨갑옷 + 팔보호대
        L.paint(rect(x - 5, y + 3, x + 5, wy - 6), 'steel', mul=mul)
        L.paint(rect(x - 5, wy - 12, x + 5, wy), 'dsteel', mul=mul)
        L.paint(ell(x, y, 10, 8), 'steel', mul=mul)
        L.flat(rect(x - 8, y + 4, x + 8, y + 6), PAL['red'][0])
    elif outfit == 1:  # 푸른 소매 + 강철 팔꿈치 + 흰 장갑 선
        L.paint(rect(x - 5, y, x + 5, wy - 6), 'blue', mul=mul)
        L.paint(ell(x, y + 1, 8, 6), 'blue', mul=mul)
        L.paint(rect(x - 5, wy - 12, x + 5, wy), 'steel', mul=mul)
        L.paint(ell(x, wy - 13, 5, 3), 'gold', band=1, mul=mul)
    else:              # 천 소매 + 가죽 팔보호대 + 어깨 가죽
        L.paint(rect(x - 5, y, x + 5, wy - 6), 'cloth', mul=mul)
        L.paint(ell(x, y + 1, 8, 6), 'cloth', mul=mul)
        L.paint(rect(x - 5, wy - 11, x + 5, wy), 'leather', mul=mul)
        L.paint(ell(x, y - 1, 9, 5), 'leather', mul=mul)
    return L


# ═══════════ 머리 (피부+얼굴 바탕, 얼굴 표정 2종, 머리 모양 3종) ═══════════
HEAD_C = (64, 34)
HEAD_SCALE = 1.22
BODY_SCALE_X = 1.14


def head_skin(view):
    L = Layer()
    cx, cy = HEAD_C
    if view == 'f':
        L.paint(rect(58, 44, 68, 52), 'skin')   # 목
        L.paint(ell(cx, cy, 16, 15), 'skin')
        L.paint(ell(cx - 14, cy + 1, 3, 4), 'skin')   # 귀(뒤쪽)
    else:
        L.paint(rect(55, 44, 66, 52), 'skin')
        L.paint(ell(60, cy, 16, 15), 'skin')
    return L


def face(kind):
    """앞모습 얼굴 표정: 0 보통, 1 사나움"""
    L = Layer()
    ex = (68, 77)   # 눈 x (가까운 눈, 먼 눈)
    for i, x in enumerate(ex):
        eh = 5 if i == 0 else 4
        L.flat(rect(x - 1, 33, x + 2, 33 + eh), OL)
        L.flat(rect(x, 34, x + 1, 35), (255, 255, 255, 255))
    if kind == 0:
        L.flat(rect(69, 43, 74, 44), (150, 70, 70, 255))
        L.flat(rect(65, 29, 70, 30), (96, 56, 40, 255))
        L.flat(rect(75, 29, 80, 30), (96, 56, 40, 255))
    else:
        L.flat(line((65, 28), (71, 31), 2), OL)
        L.flat(line((80, 28), (75, 31), 2), OL)
        L.flat(rect(69, 42, 75, 45), OL)
        L.flat(rect(70, 43, 74, 44), (170, 60, 60, 255))
    return L


def hair(view, style):
    """머리 모양 3종 → (뒤 겹, 앞 겹). 0 짧은 갈색, 1 긴 금발, 2 깃털 투구"""
    back, front = Layer(), Layer()
    cx, cy = HEAD_C
    f = view == 'f'
    if style == 0:
        if f:
            front.paint(poly([(46, 36), (47, 24), (56, 17), (70, 15), (80, 22), (81, 29), (72, 27), (66, 31), (62, 26), (56, 31), (53, 40), (50, 40)]), 'brown')
            front.paint(poly([(46, 38), (52, 30), (53, 44), (49, 46)]), 'brown')
        else:
            front.paint(poly([(44, 36), (45, 22), (54, 15), (68, 14), (77, 22), (77, 38), (73, 46), (60, 49), (48, 46)]), 'brown')
            front.flat(line((60, 18), (60, 30), 1), PAL['brown'][2])
    elif style == 1:
        if f:
            back.paint(poly([(44, 28), (56, 24), (66, 26), (68, 46), (62, 66), (54, 70), (46, 62), (42, 44)]), 'blonde')
            front.paint(poly([(45, 34), (46, 22), (56, 15), (70, 14), (81, 22), (81, 33), (72, 26), (66, 30), (60, 25), (54, 32), (52, 44), (47, 44)]), 'blonde')
            front.paint(poly([(46, 36), (50, 30), (52, 52), (47, 54)]), 'blonde')
        else:
            back.flat(np.zeros((H, W), bool), (0, 0, 0, 0))
            front.paint(poly([(43, 34), (45, 21), (54, 14), (68, 13), (77, 21), (78, 34), (76, 52), (73, 70), (66, 74), (60, 70), (54, 74), (47, 70), (44, 52)]), 'blonde')
            front.flat(line((60, 18), (60, 66), 1), PAL['blonde'][2])
            front.flat(line((52, 22), (50, 60), 1), PAL['blonde'][2])
            front.flat(line((68, 22), (70, 62), 1), PAL['blonde'][2])
    else:
        if f:
            # 붉은 깃털은 뒤 겹, 투구 몸통은 앞 겹
            back.paint(poly([(54, 16), (50, 6), (40, 2), (30, 6), (26, 16), (34, 14), (40, 18), (48, 22), (56, 24)]), 'red')
            front.paint(poly([(46, 38), (46, 24), (54, 16), (68, 13), (78, 18), (82, 28), (82, 32), (74, 31), (66, 29), (54, 30), (52, 40), (50, 48), (46, 44)]), 'steel')
            front.paint(poly([(72, 18), (76, 18), (80, 30), (74, 30)]), 'dsteel')
            front.paint(rect(70, 30, 74, 42), 'steel', band=1)  # 코 보호대
            front.paint(poly([(47, 38), (56, 38), (58, 46), (52, 50), (46, 46)]), 'steel')   # 뺨 보호대
            front.flat(rect(60, 24, 64, 28), PAL['gold'][0])
        else:
            back.paint(poly([(48, 18), (42, 6), (32, 2), (24, 8), (22, 20), (34, 18), (44, 24), (52, 28)]), 'red')
            front.paint(poly([(43, 36), (44, 22), (53, 14), (66, 12), (76, 17), (79, 28), (78, 42), (72, 50), (58, 51), (46, 46)]), 'steel')
            front.paint(rect(59, 14, 63, 48), 'dsteel', band=1)
            front.paint(rect(44, 40, 78, 44), 'dsteel', band=1)
    return back, front


# ═══════════ 고정 무기: 칼, 방패 ═══════════
def sword(view):
    """세운 모양(칼끝이 위)으로 그림, 자루 쥔 주먹 중심 = 손목 관절. 방향은 Godot 에서 돌림"""
    L = Layer()
    wx, wy = JOINTS[view]['wr_n']
    # 칼날 (위로 길게)
    L.paint(poly([(wx - 3, wy - 6), (wx + 3, wy - 6), (wx + 3, wy - 40), (wx, wy - 46), (wx - 3, wy - 40)]), 'steel', band=1)
    L.flat(rect(wx - 1, wy - 40, wx, wy - 8), PAL['white'][1])
    L.flat(rect(wx + 1, wy - 40, wx + 2, wy - 8), PAL['steel'][2])
    # 날밑 (금)
    L.paint(rect(wx - 8, wy - 8, wx + 8, wy - 4), 'gold', band=1)
    # 자루 + 쥔 주먹
    L.paint(rect(wx - 2, wy - 4, wx + 2, wy + 8), 'dleather', band=1)
    L.paint(ell(wx, wy + 8, 3, 3), 'gold', band=1)
    L.paint(ell(wx, wy, 6, 6), 'dsteel')
    L.flat(rect(wx - 5, wy - 1, wx + 5, wy), PAL['dsteel'][2])
    return L


def shield(view):
    L = Layer()
    wx, wy = JOINTS[view]['wr_f']
    if view == 'f':
        cx, cy = wx + 8, wy - 6
        shp = poly([(cx - 9, cy - 14), (cx + 9, cy - 14), (cx + 9, cy + 4), (cx, cy + 16), (cx - 9, cy + 4)])
        L.paint(shp, 'steel')
        L.paint(poly([(cx - 6, cy - 11), (cx + 6, cy - 11), (cx + 6, cy + 3), (cx, cy + 12), (cx - 6, cy + 3)]), 'dsteel')
        L.flat(rect(cx - 1, cy - 11, cx + 1, cy + 10), PAL['gold'][0])
        L.flat(rect(cx - 6, cy - 4, cx + 6, cy - 2), PAL['gold'][0])
        L.paint(ell(cx, cy - 3, 3, 3), 'red', band=1)
    else:
        cx, cy = wx - 6, wy - 4
        shp = poly([(cx - 9, cy - 14), (cx + 9, cy - 14), (cx + 9, cy + 4), (cx, cy + 16), (cx - 9, cy + 4)])
        L.paint(shp, 'dleather')
        L.paint(rect(cx - 9, cy - 4, cx + 9, cy - 1), 'leather', band=1)
        L.paint(rect(cx - 2, cy - 14, cx + 2, cy + 10), 'leather', band=1)
        L.paint(ell(cx, cy - 2, 3, 3), 'steel', band=1)
    # 방패 든 주먹
    L.paint(ell(wx, wy, 5, 5), 'dsteel')
    return L


# ═══════════ 전체 출력 ═══════════
def build_all(out=OUT_DIR):
    rig = {'K': K, 'grid': W, 'floor': 120, 'joints': JOINTS, 'parts': {}}
    n = 0
    for view in ('f', 'b'):
        def put(name, layer):
            nonlocal n
            info = crop_save(layer, os.path.join(out, view, name + '.png'))
            if info:
                rig['parts'][f'{view}/{name}'] = info
                n += 1
        global TX
        TX = None
        put('leg_n', leg(view, True))
        put('leg_f', leg(view, False))
        put('sword', sword(view))
        put('shield', shield(view))
        TX = (JOINTS[view]['neck'][0], 50, HEAD_SCALE, HEAD_SCALE)   # 머리 키움 (원본 그림은 머리가 큼)
        put('head_skin', head_skin(view))
        if view == 'f':
            put('face_0', face(0))
            put('face_1', face(1))
        for s in range(3):
            b, fr = hair(view, s)
            put(f'hair_back_{s}', b)
            put(f'hair_front_{s}', fr)
        TX = (60, 70, BODY_SCALE_X, 1.0)    # 몸통 넓힘
        for o in range(3):
            put(f'torso_{o}', torso(view, o))
        TX = None
        for o in range(3):
            put(f'arm_n_{o}', arm(view, o, True))
            put(f'arm_f_{o}', arm(view, o, False))
    with open(os.path.join(out, 'rig.json'), 'w') as fh:
        json.dump(rig, fh, indent=1)
    return n


def preview(path, combos=((0, 0, 0, 0), (1, 1, 1, 1), (2, 2, 2, 0)), scale=3):
    """조립한 정지 모습 확인용 (Godot 이전 점검)"""
    rig = json.load(open(os.path.join(OUT_DIR, 'rig.json')))
    tiles = []
    for view in ('f', 'b'):
        for (hd, ou, fc, _) in combos:
            cv = Image.new('RGBA', (W, H), (70, 110, 70, 255))

            def draw(name):
                key = f'{view}/{name}'
                if key not in rig['parts']:
                    return
                p = rig['parts'][key]
                im = Image.open(os.path.join(OUT_DIR, view, name + '.png'))
                im = im.resize((p['w'], p['h']), Image.NEAREST)
                cv.alpha_composite(im, (p['x'], p['y']))
            order = ['leg_f', 'leg_n', f'arm_f_{ou}', 'shield', f'torso_{ou}', f'hair_back_{hd}', 'head_skin', 'face_' + str(fc), f'hair_front_{hd}', f'arm_n_{ou}', 'sword']
            if view == 'b':
                order = ['leg_f', 'leg_n', f'arm_f_{ou}', 'shield', f'torso_{ou}', 'head_skin', f'hair_back_{hd}', f'hair_front_{hd}', f'arm_n_{ou}', 'sword']
            for nme in order:
                draw(nme)
            tiles.append(cv.resize((W * scale, H * scale), Image.NEAREST))
    n = len(combos)
    sheet = Image.new('RGBA', (W * scale * n, H * scale * 2))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % n) * W * scale, (i // n) * H * scale))
    sheet.save(path)


if __name__ == '__main__':
    cnt = build_all()
    print('조각 그림', cnt, '장 →', OUT_DIR)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
