"""기존 2D 캐릭터 시트에서 팔레트·윤곽선 색/굵기를 뽑는다 (pilot3d 셰이더 변수 맞춤용). 읽기만 함."""
import glob, json, sys
import numpy as np
from PIL import Image
files = sorted(glob.glob('godot/assets/image/character/anim/*_01_idle.png') + glob.glob('godot/assets/image/character/anim/*_02_idle.png'))
files = [f for f in files if '_b_' not in f]
acc = []; edge = []; thick = []
for f in files:
    im = np.array(Image.open(f).convert('RGBA'))
    a = im[..., 3] > 200
    acc.append(im[a][:, :3])
    # 가장자리(투명과 맞닿은 불투명) 픽셀
    pad = np.pad(a, 1)
    nb = pad[:-2,1:-1] & pad[2:,1:-1] & pad[1:-1,:-2] & pad[1:-1,2:]
    e = a & ~nb
    edge.append(im[e][:, :3])
    # 윤곽 굵기: 가장자리에서 안쪽으로 밝기가 가장자리 평균+25 넘기 전까지 칸수 (행 방향 샘플)
    lum = im[..., :3].astype(float).mean(axis=2)
    for y in range(0, im.shape[0], 4):
        row = a[y]; xs = np.where(row)[0]
        if len(xs) < 20: continue
        x0 = xs[0]
        if x0 + 12 >= im.shape[1]: continue
        base = lum[y, x0]
        n = 0
        while x0 + n < im.shape[1] and a[y, x0+n] and lum[y, x0+n] < base + 22 and n < 14: n += 1
        thick.append(n)
allp = np.concatenate(acc); alle = np.concatenate(edge)
print('files', len(files), 'opaque px', len(allp))
print('edge mean rgb', alle.mean(axis=0).round(1), 'edge median lum', np.median(alle.mean(axis=1)))
print('all mean rgb', allp.mean(axis=0).round(1), ' luminance pct 5/25/50/75/95', np.percentile(allp.mean(axis=1), [5,25,50,75,95]).round(0))
print('outline thickness (sheet px) median', np.median(thick), 'mean', np.mean(thick).round(2), '→ screen px ≈', (np.median(thick)*0.516).round(2))
# 팔레트 32/48색 (중간값 자르기)
rng = np.random.default_rng(1)
samp = allp[rng.choice(len(allp), 400000, replace=False)].reshape(-1, 1, 3).astype(np.uint8)
img = Image.fromarray(samp.reshape(1000, 400, 3))
out = {}
for n in (24, 32, 48):
    q = img.quantize(colors=n, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()[:n*3]
    cols = ['#%02x%02x%02x' % tuple(pal[i*3:i*3+3]) for i in range(n)]
    out[str(n)] = cols
json.dump({'colors32': out['32'], 'colors48': out['48'], 'colors24': out['24'],
           'edge_rgb': alle.mean(axis=0).round(0).tolist(),
           'outline_px_sheet': float(np.median(thick))}, open('godot/assets/pilot3d/palette.json', 'w'))
# 채도
hsv = np.array(Image.fromarray(allp[:200000].reshape(-1,1,3).astype(np.uint8)).convert('HSV'))[:,0,:]
print('saturation pct 25/50/75/95', np.percentile(hsv[:,1],[25,50,75,95]).round(0), 'value pct', np.percentile(hsv[:,2],[5,50,95]).round(0))
