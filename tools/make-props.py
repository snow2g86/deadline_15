#!/usr/bin/env python3
"""개발용: gen-props.py 결과(크로마키 바탕) → 게임용 맵 오브젝트 그림 image/map/<이름>.png

사용: python3 tools/make-props.py <이름>=<시드> [...]   예: tree_a=1 rock_a=2 rock_b=rock_a:1 (다른 이름의 후보)
- 바탕(초록 또는 자홍)과 그 색이 섞인 그림자를 투명으로, 가장 큰 덩어리만 남김
- 화면 표시 크기(data/props.js PROP_ART 의 h, CSS px)의 2배 높이로 줄여 저장 (고해상도 화면에서도 선명)
"""
import os, sys
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, OUT = os.path.join(ROOT, 'tools/_work/props'), os.path.join(ROOT, 'image/map')
# 화면 표시 높이(CSS px) — data/props.js PROP_ART 와 맞출 것
# rock_a·rock_b·mound 는 게임에서 안 씀 (2026-10-13 언덕·바위 그림 대체 취소)
HEIGHT = {'tree_a': 41, 'tree_b': 58, 'pine': 48, 'rock_a': 80, 'rock_b': 80, 'mound': 66, 'grass': 16, 'stones': 12}


def is_bg(r, g, b, key):
    if key == 'magenta':   # 자홍 바탕 + 자홍빛 그림자
        return r > g + 40 and b > g + 40 and abs(r - b) < 90
    return g > r + 40 and g > b + 40   # 초록 바탕


def cut(path, key):
    im = Image.open(path).convert('RGBA'); W, H = im.size; px = im.load()
    mask = [[not is_bg(*px[x, y][:3], key) for x in range(W)] for y in range(H)]
    # 가장 큰 덩어리만 (떨어진 부스러기·그림자 조각 제거)
    seen = [[False] * W for _ in range(H)]; best = []
    for y in range(H):
        for x in range(W):
            if mask[y][x] and not seen[y][x]:
                comp, q = [], deque([(x, y)]); seen[y][x] = True
                while q:
                    cx, cy = q.popleft(); comp.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < W and 0 <= ny < H and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True; q.append((nx, ny))
                if len(comp) > len(best): best = comp
    keep = set(best)
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0)); op = out.load()
    for (x, y) in keep:
        r, g, b, _ = px[x, y]
        # 가장자리에 남은 바탕색 번짐 줄이기
        if key == 'magenta' and r > g + 20 and b > g + 20: r = b = g
        if key == 'green' and g > r + 20 and g > b + 20: g = max(r, b)
        op[x, y] = (r, g, b, 255)
    return out.crop(out.getbbox())


def main():
    os.makedirs(OUT, exist_ok=True)
    import importlib.util   # gen-props.py 의 P(이름별 바탕색)를 그대로 씀
    spec = importlib.util.spec_from_file_location('gp', os.path.join(ROOT, 'tools/gen-props.py')); gp = importlib.util.module_from_spec(spec); spec.loader.exec_module(gp)
    for a in sys.argv[1:]:
        name, seed = a.split('=')   # 다른 이름의 후보를 쓸 때: rock_b=rock_a:1
        src, seed = seed.split(':') if ':' in seed else (name, seed)
        im = cut(os.path.join(SRC, f'{src}_{seed}.png'), gp.P[src][0])
        h = HEIGHT[name] * 2; w = max(1, round(im.width * h / im.height))
        im = im.resize((w, h), Image.LANCZOS)
        # 반투명 가장자리 정리 (픽셀 그림이라 또렷하게)
        a_ = im.split()[3].point(lambda v: 255 if v > 110 else 0); im.putalpha(a_)
        im.save(os.path.join(OUT, name + '.png'), optimize=True)
        print(name, seed, im.size)


if __name__ == '__main__':
    main()
