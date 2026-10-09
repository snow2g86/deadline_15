#!/usr/bin/env python3
"""개발용: 일러스트 → 게임 아이콘 PNG

사용: python3 tools/make-icon.py <원본 이미지> <출력 png> [크기=256] [판정 해상도=512]
- 초록(또는 아이템이 초록이면 자홍) 단색 바탕이면: 가장자리와 이어진 바탕색만 지워 투명하게(안쪽은 남김), 바탕색 번짐 줄임,
  아이템이 칸을 꽉 채우도록 여백을 잘라 정사각형으로 맞춤
- 그 밖(테두리 그림·직업·스킬 효과 아이콘)이면: 바깥 여백을 조금 자르고, webp(Gemini)면 오른쪽 아래 생성 표시(✦)를 왼쪽 아래 모서리를 뒤집어 덮어 지움
"""
import sys, os
from collections import deque
from PIL import Image, ImageOps

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 256
im = Image.open(src).convert('RGB')
w, h = im.size


import colorsys


def _hsv(p): return colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)


def _keyed(p, hue):   # 바탕색(크로마키) 판정: 색상이 바탕 색상 ±45°, 채도 0.35 이상, 밝기 0.2 이상 (아이템에 비친 옅은 색은 제외)
    h, s, v = _hsv(p)
    d = min(abs(h - hue), 1 - abs(h - hue))
    return d <= 45 / 360 and s >= 0.35 and v >= 0.2


# 가장자리 표본으로 바탕색 판정: 초록(120°) 또는 자홍(300°, 아이템이 초록일 때)
edge = [im.getpixel((x, y)) for x in range(0, w, max(1, w // 64)) for y in (0, h - 1)] + \
       [im.getpixel((x, y)) for y in range(0, h, max(1, h // 64)) for x in (0, w - 1)]
KEY = None
for hue in (120 / 360, 300 / 360):
    if sum(_keyed(p, hue) for p in edge) > len(edge) * 0.7: KEY = hue
if os.path.basename(src).split('.')[0].replace('ffx_', '').startswith(('e_', 'jab_')): KEY = None   # 스킬·효과·직업 아이콘은 배경까지 그린 그림 (보라 배경을 자홍으로 오인 방지)
is_item = KEY is not None
greenish = lambda p: _keyed(p, KEY)


if is_item:
    WORK = int(sys.argv[4]) if len(sys.argv) > 4 else 512   # 배경 판정 해상도 (초상화는 1024)
    sm = im.resize((WORK, WORK), Image.LANCZOS) if w > WORK else im.copy()
    W, H = sm.size
    px = sm.load()
    bg = [[False] * W for _ in range(H)]
    q = deque()
    for x in range(W):
        for y in (0, H - 1):
            if greenish(px[x, y]): bg[y][x] = True; q.append((x, y))
    for y in range(H):
        for x in (0, W - 1):
            if greenish(px[x, y]) and not bg[y][x]: bg[y][x] = True; q.append((x, y))
    while q:   # 가장자리와 이어진 초록 바탕만
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < W and 0 <= ny < H and not bg[ny][nx] and greenish(px[nx, ny]):
                bg[ny][nx] = True; q.append((nx, ny))
    # 둘러싸인 바탕(활시위 안쪽 등): 가장자리와 안 이어져도, 바탕색 덩어리가 크면(0.1% 이상) 지움
    seen = [[False] * W for _ in range(H)]
    for sy in range(H):
        for sx in range(W):
            if bg[sy][sx] or seen[sy][sx] or not greenish(px[sx, sy]): continue
            comp, q2 = [], deque([(sx, sy)]); seen[sy][sx] = True
            while q2:
                x, y = q2.popleft(); comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and not bg[ny][nx] and greenish(px[nx, ny]):
                        seen[ny][nx] = True; q2.append((nx, ny))
            if len(comp) > W * H * 0.001:
                for x, y in comp: bg[y][x] = True
    # 떨어진 작은 점(바탕 얼룩·잡티)은 지움: 0.05% 미만 덩어리
    seen = [[False] * W for _ in range(H)]
    for sy in range(H):
        for sx in range(W):
            if bg[sy][sx] or seen[sy][sx]: continue
            comp, q2 = [], deque([(sx, sy)]); seen[sy][sx] = True
            while q2:
                x, y = q2.popleft(); comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < W and 0 <= ny < H and not seen[ny][nx] and not bg[ny][nx]:
                        seen[ny][nx] = True; q2.append((nx, ny))
            if len(comp) < W * H * 0.0005:
                for x, y in comp: bg[y][x] = True
    out = Image.new('RGBA', (W, H))
    op = out.load()
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            if bg[y][x]: op[x, y] = (0, 0, 0, 0); continue
            near = any(0 <= x + dx < W and 0 <= y + dy < H and bg[y + dy][x + dx] for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            if KEY < 0.5:   # 초록 번짐(바탕색 반사): 초록을 다른 두 색 수준 가까이 낮춤, 가장자리는 완전히
                mx = max(r, b)
                if g > mx: g = mx if near else mx + (g - mx) // 5
            else:           # 자홍 번짐: 빨강·파랑이 함께 초록보다 높으면 낮춤
                lo = min(r, b)
                if lo > g:
                    k = (lo - g) if near else (lo - g) * 4 // 5
                    r, b = r - k, b - k
            op[x, y] = (r, g, b, 200 if near else 255)
    bbox = out.getbbox() or (0, 0, W, H)
    out = out.crop(bbox)
    side = int(max(out.size) * 1.06)   # 사방 3% 여백
    sq = Image.new('RGBA', (side, side))
    sq.paste(out, ((side - out.size[0]) // 2, (side - out.size[1]) // 2))
    sq.resize((size, size), Image.LANCZOS).save(dst, optimize=True)
    print(dst, 'item cutout', (size, size))
else:
    m = round(min(w, h) * 0.012)          # 바깥 흰 여백
    im = im.crop((m, m, w - m, h - m))
    w, h = im.size
    if src.lower().endswith('.webp'):     # Gemini 그림(webp)만 오른쪽 아래 생성 표시가 있음 (Firefly jpg는 없음)
        c = round(w * 0.12)               # 모서리 덮개 크기
        corner = im.crop((0, h - c, c, h))
        im.paste(ImageOps.mirror(corner), (w - c, h - c))
    im = im.resize((size, size), Image.LANCZOS)
    im.save(dst, optimize=True)
    print(dst, 'full', im.size)
