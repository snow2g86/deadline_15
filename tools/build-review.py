#!/usr/bin/env python3
"""개발용: tools/_work/anim 의 생성 영상을 모두 시트로 변환(이펙트 제거 포함)하고 검토 페이지용 목록을 만든다.

사용: python3 tools/build-review.py [-j 4]
  - 영상 이름: <key>_<seed>.mp4 (공격) / <key>_<motion>_<seed>.mp4
  - 결과: tools/_work/anim/sheets/<영상이름>.png(+.json), tools/_work/anim/sheets/manifest.json
  - 이미 변환된 시트는 건너뜀 (영상이 더 새로우면 다시 변환)
"""
import glob, json, os, re, subprocess, sys
from multiprocessing import Pool

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, 'tools', '_work', 'anim'); OUT = os.path.join(D, 'sheets')
os.makedirs(OUT, exist_ok=True)
# 동작별 변환 구간: (프레임 수, 시작초, 끝초, 추가 옵션)
SPEC = {'idle': (12, 0, 2.3, []), 'combat': (12, 0, 2.3, []), 'run': (14, 0.25, 2.75, ['--body-median']),
        'hit': (9, 0, 1.55, []), 'attack': (18, 0.1, 2.95, [])}

def parse(path):
    name = os.path.basename(path)[:-4]
    m = re.match(r'^([a-z]+_0[12])(?:_(idle|combat|run|hit))?_(\d+)$', name)
    return (name, m.group(1), m.group(2) or 'attack', int(m.group(3))) if m else None

def conv(item):
    name, key, motion, seed = item
    src = os.path.join(D, name + '.mp4'); dst = os.path.join(OUT, name + '.png')
    if os.path.exists(dst + '.json') and os.path.getmtime(dst + '.json') > os.path.getmtime(src): return name, True
    n, a, b, extra = SPEC[motion]
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'video-to-sheet.py'), src, dst, '--frames', str(n), '--height', '160',
                        '--start', str(a), '--end', str(b), '--char', os.path.join(ROOT, 'image', 'character', key + '.png')] + extra,
                       capture_output=True, text=True)
    return name, r.returncode == 0

if __name__ == '__main__':  # macOS 병렬 처리(spawn)는 워커가 이 파일을 다시 읽으므로 실행부를 감싸야 함
    items = [p for p in (parse(f) for f in sorted(glob.glob(os.path.join(D, '*.mp4')))) if p]
    jobs = int(sys.argv[sys.argv.index('-j') + 1]) if '-j' in sys.argv else 4
    with Pool(jobs) as pool:
        res = dict(pool.map(conv, items))
    man = {}
    for name, key, motion, seed in items:
        if not res.get(name): continue
        meta = json.load(open(os.path.join(OUT, name + '.png.json')))
        man.setdefault(key, {}).setdefault(motion, []).append({'seed': seed, 'src': f'_work/anim/sheets/{name}.png', **meta})
    json.dump(man, open(os.path.join(OUT, 'manifest.json'), 'w'), ensure_ascii=False)
    print('sheets', sum(res.values()), '/', len(items), 'failed', [k for k, v in res.items() if not v])
