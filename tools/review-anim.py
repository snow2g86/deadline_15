#!/usr/bin/env python3
"""개발용: 캐릭터별 시드 영상들을 한 장의 검토용 이미지로 (tools/_work/anim/<key>_review.png)

사용: python3 tools/review-anim.py <key> [<key> ...]
각 영상을 초당 5프레임으로 뽑아 시드별로 한 줄씩 쌓고, 프레임 번호(0.2초 간격)를 적는다.
"""
import glob, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, 'tools', '_work', 'anim')
for key in sys.argv[1:]:
    vids = sorted(glob.glob(os.path.join(D, f'{key}_*.mp4')))
    rows = []
    for v in vids:
        tmp = tempfile.mkdtemp()
        subprocess.run(['ffmpeg', '-v', 'error', '-i', v, '-vf', 'fps=5,scale=150:-1', os.path.join(tmp, 'f%02d.png')], check=True)
        fr = [Image.open(f) for f in sorted(glob.glob(os.path.join(tmp, 'f*.png')))]
        row = Image.new('RGB', (150 * len(fr), 168), (20, 24, 32)); d = ImageDraw.Draw(row)
        for i, f in enumerate(fr):
            row.paste(f, (150 * i, 18)); d.text((150 * i + 3, 3), f'{i}', fill=(255, 255, 0))
        d.text((150 * len(fr) - 90, 3), os.path.basename(v)[len(key) + 1:-4], fill=(0, 255, 255))
        rows.append(row)
    if not rows: continue
    out = Image.new('RGB', (max(r.width for r in rows), sum(r.height for r in rows)), (0, 0, 0)); y = 0
    for r in rows: out.paste(r, (0, y)); y += r.height
    out.save(os.path.join(D, f'{key}_review.png')); print('saved', key, len(rows))
