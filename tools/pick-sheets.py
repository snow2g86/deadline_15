#!/usr/bin/env python3
"""개발용: 시드별 시트(tools/_work/anim/sheets) 중 캐릭터·동작마다 가장 깨끗한 것을 골라 게임에 등록

사용: python3 tools/pick-sheets.py [--dry] [--only knight_02,...]
점수(낮을수록 좋음):
  - 영상 테두리에 닿음(동작이 잘림) → 큰 감점
  - 프레임 간 몸 높이·위치 흔들림 (대기·전투대기는 특히 작아야 함)
  - 첫 프레임과 마지막 프레임 차이 (반복 동작은 이음새가 자연스러워야 함)
  - 프레임마다 떨어진 조각 수(남은 이펙트·잡티)
공격은 오른쪽으로 가장 멀리 뻗은 프레임을 타격 프레임(hit)으로 잡는다.
"""
import json, os, subprocess, sys
from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, 'tools', '_work', 'anim', 'sheets')
man = json.load(open(os.path.join(D, 'manifest.json')))
only = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None
DUR = {'idle': 2400, 'combat': 1600, 'run': 1500, 'hit': 520}
SKIP = {'knight_01'}  # 이미 직접 골라 적용함

def frames(meta):
    im = Image.open(os.path.join(ROOT, 'tools', meta['src'])).convert('RGBA')
    return [im.crop((i * meta['w'], 0, (i + 1) * meta['w'], meta['h'])) for i in range(meta['frames'])]

def score(meta, motion):
    fs = frames(meta); bbs = [f.getbbox() for f in fs]
    if any(b is None for b in bbs): return 1e9, None
    s = 0.0
    if meta.get('edge_touch'): s += 500 * len(meta['edge_touch'])
    hs = [b[3] - b[1] for b in bbs]; bots = [b[3] for b in bbs]; cxs = [(b[0] + b[2]) / 2 for b in bbs]
    w = {'idle': 6, 'combat': 4, 'run': 1.5, 'hit': 1, 'attack': 0.5}[motion]
    s += w * ((max(hs) - min(hs)) + (max(bots) - min(bots)) + 0.5 * (max(cxs) - min(cxs)))
    if motion in ('idle', 'combat', 'run'):
        diff = ImageChops.difference(fs[0].convert('RGB'), fs[-1].convert('RGB')).convert('L')
        s += 0.002 * sum(diff.getdata())
    # 몸 크기 대비 너무 작거나 큰 프레임(변형) 감점
    s += 2 * sum(abs(h - hs[0]) > hs[0] * 0.35 for h in hs) * 20
    hit = None
    if motion == 'attack':
        rights = [b[2] for b in bbs]
        k = max(range(len(fs)), key=lambda i: rights[i])
        hit = k
        if k < 3: s += 200  # 너무 이른 타격 = 동작이 이상함
        if rights[k] - rights[0] < meta['w'] * 0.08: s += 300  # 앞으로 거의 안 뻗음
    return s, hit

# 몸에 붙은 섬광·궤적이 남은 프레임(몸 크기에 비해 너무 넓거나 높음)을 바로 앞의 깨끗한 프레임으로 바꾼 사본을 만듦
def clean_frames(meta, src):
    fs = frames(meta); bbs = [f.getbbox() for f in fs]
    ws = sorted(b[2] - b[0] for b in bbs); hs = sorted(b[3] - b[1] for b in bbs)
    mw, mh_ = ws[len(ws) // 2], hs[len(hs) // 2]
    bad = [(b[2] - b[0]) > mw * 1.45 or (b[3] - b[1]) > mh_ * 1.25 for b in bbs]
    if not any(bad): return src
    out = Image.new('RGBA', (meta['w'] * meta['frames'], meta['h']))
    last = next(i for i in range(len(fs)) if not bad[i])
    for i, f in enumerate(fs):
        if not bad[i]: last = i
        out.paste(fs[last], (i * meta['w'], 0))
    dst = src[:-4] + '_clean.png'; out.save(dst)
    json.dump(meta, open(dst + '.json', 'w'))
    return dst

# 공격: 처음 자세의 몸 영역 바깥에 있는 섬광(아주 밝은 흰색·강한 노란/주황 빛)을 지우고, 몸에서 떨어진 작은 조각도 지움
def strip_flash(meta, src):
    fs = frames(meta); b0 = fs[0].getbbox(); m = 6
    out = Image.new('RGBA', (meta['w'] * meta['frames'], meta['h']))
    body = sum(1 for p in fs[0].getdata() if p[3]); prev = None
    for i, f in enumerate(fs):
        f = f.copy(); px = f.load(); W, H = f.size; stripped = 0
        for y in range(H):
            for x in range(W):
                r, g, b, a = px[x, y]
                if not a or (b0[0] - m <= x <= b0[2] + m and b0[1] - m <= y <= b0[3] + m): continue
                white = min(r, g, b) >= 236
                glow = r > 215 and g > 160 and b < 140 and r - b > 90
                cyan = b > 220 and g > 200 and r < 200
                if white or glow or cyan: px[x, y] = (0, 0, 0, 0); stripped += 1
        # 작은 조각 제거 (몸 덩어리의 6% 미만)
        a = f.split()[3].point(lambda v: 255 if v else 0)
        seen = bytearray(W * H); blobs = []
        for y0 in range(H):
            for x0 in range(W):
                if seen[y0 * W + x0] or not a.getpixel((x0, y0)): continue
                st = [(x0, y0)]; seen[y0 * W + x0] = 1; bl = []
                while st:
                    x, y = st.pop(); bl.append((x, y))
                    for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
                        if 0 <= nx < W and 0 <= ny < H and not seen[ny*W+nx] and a.getpixel((nx, ny)):
                            seen[ny*W+nx] = 1; st.append((nx, ny))
                blobs.append(bl)
        big = max((len(b) for b in blobs), default=0)
        for bl in blobs:
            if len(bl) < big * 0.06:
                for x, y in bl: px[x, y] = (0, 0, 0, 0)
        # 섬광이 컸던 프레임은 흔적이 남으므로 바로 앞 프레임으로 대체
        if stripped > body * 0.04 and prev is not None: f = prev
        out.paste(f, (i * meta['w'], 0)); prev = f
    dst = src[:-4] + '_noflash.png'; out.save(dst); json.dump(meta, open(dst + '.json', 'w'))
    return dst

picked = {}
for key in sorted(man):
    if key in SKIP or (only and key not in only): continue
    for motion, cands in man[key].items():
        best = None
        for c in cands:
            sc, hit = score(c, motion)
            if best is None or sc < best[0]: best = (sc, c, hit)
        sc, c, hit = best
        picked[f'{key}.{motion}'] = {'seed': c['seed'], 'score': round(sc, 1), 'hit': hit}
        if '--dry' in sys.argv: continue
        src = os.path.join(ROOT, 'tools', c['src'])
        src = clean_frames(c, src) if motion != 'attack' else strip_flash(c, src)
        if motion == 'attack':
            dur = max(700, min(1100, c['frames'] * 60))
            args = [key, 'attack', src, str(dur), str(hit)]
        elif motion == 'hit':
            args = [key, 'hit', src, str(DUR['hit']), '3']
        else:
            args = [key, motion, src, str(DUR[motion])]
        subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'apply-sheet.py')] + args, check=True, capture_output=True)
json.dump(picked, open(os.path.join(D, 'picked.json'), 'w'), ensure_ascii=False, indent=1)
print(len(picked), 'picked')
bad = {k: v for k, v in picked.items() if v['score'] >= 300}
print('주의(점수 300 이상):', json.dumps(bad, ensure_ascii=False))
