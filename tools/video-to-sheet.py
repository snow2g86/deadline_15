#!/usr/bin/env python3
"""개발용: 초록 배경 캐릭터 영상 → 배경 제거된 스프라이트 시트 PNG

사용: python3 tools/video-to-sheet.py <영상.mp4> <출력.png> [--frames 12] [--height 128] [--start 0] [--end 영상끝]
     [--char image/character/knight_01.png]  ← 주면 이펙트 제거: 원본 캐릭터에 없는 색 + 몸에서 떨어진 작은 조각을 지움
  1) ffmpeg로 영상 전체에서 프레임을 고르게 N장 추출
  2) 초록(크로마키) 배경을 투명으로, 가장자리 초록 번짐 제거
  3) 모든 프레임에 공통인 영역으로 잘라(위치 흔들림 방지) 높이를 맞춰 가로로 이어 붙임
출력과 함께 <출력>.json 에 { frames, w, h } 를 기록한다.
"""
import json, subprocess, sys, tempfile, glob, os
from PIL import Image

def arg(name, default):
    return type(default)(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else default

src, out = sys.argv[1], sys.argv[2]
N, H = arg('--frames', 12), arg('--height', 128)
T0 = arg('--start', 0.0)
MIN_BLOB = arg('--min-blob', 60)
CHAR = arg('--char', '')

# 원본 캐릭터 팔레트 (RGB를 8단계 칸으로 묶고 ±TOL칸까지 허용) — 영상이 넣은 불꽃·궤적·섬광 색을 걸러냄
PAL, TOL = None, 2
if CHAR:
    ci = Image.open(CHAR).convert('RGBA').resize((240, 271), Image.NEAREST)
    base = {(r >> 3, g >> 3, b >> 3) for r, g, b, a in ci.get_flattened_data() if a > 128}
    PAL = {(r + i, g + j, b + k) for r, g, b in base for i in range(-TOL, TOL + 1) for j in range(-TOL, TOL + 1) for k in range(-TOL, TOL + 1)}

tmp = tempfile.mkdtemp()
full = float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', src]).decode().strip())
T1 = arg('--end', full); dur = T1 - T0
subprocess.run(['ffmpeg', '-v', 'error', '-ss', str(T0), '-t', str(dur), '-i', src, '-vf', f'fps={N / dur:.4f}', os.path.join(tmp, 'f%03d.png')], check=True)
files = sorted(glob.glob(os.path.join(tmp, 'f*.png')))[:N]

def key(im):
    im = im.convert('RGBA'); px = im.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # 초록이 다른 채널보다 확연히 강하면 배경
            if g > 120 and g > r * 1.35 and g > b * 1.35:
                px[x, y] = (0, 0, 0, 0)
            elif g > max(r, b):  # 가장자리 초록 번짐 → 초록을 빨강·파랑 평균으로 눌러 줌
                px[x, y] = (r, max(r, b), b, a)
    if PAL:
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a and (r >> 3, g >> 3, b >> 3) not in PAL: px[x, y] = (0, 0, 0, 0)
    # 잡티 제거: 이어진 불투명 덩어리 중 MIN_BLOB 픽셀 미만인 작은 덩어리(영상 배경 노이즈 점)는 투명으로
    seen = bytearray(w * h); blobs = []
    for y0 in range(h):
        for x0 in range(w):
            i0 = y0 * w + x0
            if seen[i0] or not px[x0, y0][3]: continue
            stack, blob = [(x0, y0)], []; seen[i0] = 1
            while stack:
                x, y = stack.pop(); blob.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and px[nx, ny][3]:
                        seen[ny * w + nx] = 1; stack.append((nx, ny))
            blobs.append(blob)
    # 작은 덩어리 + (이펙트 제거 시) 가장 큰 덩어리(몸)의 25% 미만인 떨어진 조각 제거
    big = max((len(b) for b in blobs), default=0)
    lim = max(MIN_BLOB, big * 0.25) if PAL else MIN_BLOB
    for blob in blobs:
        if len(blob) < lim:
            for x, y in blob: px[x, y] = (0, 0, 0, 0)
    return im

frames = [key(Image.open(f)) for f in files]
# 공통 영역: 모든 프레임의 불투명 픽셀을 합친 뒤, 픽셀이 몇 개 안 되는 행·열(잡티)은 무시
W0, H0 = frames[0].size
cols, rows = [0] * W0, [0] * H0
for f in frames:
    a = f.split()[3].load()
    for y in range(0, H0, 2):
        for x in range(0, W0, 2):
            if a[x, y] > 128: cols[x] += 1; rows[y] += 1
ok = lambda c: c >= 4
xs = [i for i, c in enumerate(cols) if ok(c)]; ys = [i for i, c in enumerate(rows) if ok(c)]
# 영상 테두리에 닿은 쪽 = 영상 밖으로 잘린 동작이 있다는 뜻 (프롬프트·여백을 바꿔 다시 뽑아야 함)
edge = [n for n, hit in (('left', xs[0] <= 1), ('right', xs[-1] >= W0 - 2), ('top', ys[0] <= 1), ('bottom', ys[-1] >= H0 - 2)) if hit]
PAD = 8  # 시트 칸 안쪽 여백 (게임에서 칸 가장자리에 붙어 잘려 보이지 않게)
box = (xs[0] - PAD, ys[0] - PAD, xs[-1] + 1 + PAD, ys[-1] + 1 + PAD)
frames = [f.crop(box) for f in frames]
w0, h0 = frames[0].size
W = round(w0 * H / h0)
sheet = Image.new('RGBA', (W * len(frames), H))
for i, f in enumerate(frames):
    sheet.paste(f.resize((W, H), Image.LANCZOS), (i * W, 0))
sheet.save(out)
# 기준 몸 범위: 영상 맨 처음(0초, 원본과 같은 서 있는 자세) 프레임을 같은 영역으로 잘라 잼 — 게임에서 몸 높이·발끝 맞춤
ref = os.path.join(tmp, 'ref.png')
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', src, '-frames:v', '1', ref], check=True)
body = key(Image.open(ref)).crop(box).resize((W, H), Image.LANCZOS).getbbox()
if '--body-median' in sys.argv:
    # 동작 중 캐릭터 크기가 변하는 영상(달리기 등): 모든 프레임 몸 높이·발끝의 중앙값으로 기준을 잡음
    bbs = [b for b in (sheet.crop((i * W, 0, (i + 1) * W, H)).getbbox() for i in range(len(frames))) if b]
    med = lambda v: sorted(v)[len(v) // 2]
    hh, bot = med([b[3] - b[1] for b in bbs]), med([b[3] for b in bbs])
    body = (med([b[0] for b in bbs]), bot - hh, med([b[2] for b in bbs]), bot)
meta = {'frames': len(frames), 'w': W, 'h': H, 'crop': box, 'body': [body[1], body[3]], 'cx': (body[0] + body[2]) / 2}
meta['edge_touch'] = edge
json.dump(meta, open(out + '.json', 'w'))
print('video edge touch', edge or 'none')
print('frames', len(frames), 'cell', W, H, 'crop', box)
