#!/usr/bin/env python3
"""개발용: tools/anim-prompts.json의 캐릭터별 공격 영상을 로컬 MLX Core(MiniMax H3)로 일괄 생성

사용: python3 tools/batch-anim.py [--motions attack,idle,combat,run,hit] [--only warrior_02,lancer_01] [--skip knight_01] [--seeds 19,8,77] [--port 11240]
  - 캐릭터마다 초록 배경 + 높이 38%로 작게 배치한 입력 그림을 만들고(동작이 영상 밖으로 잘리지 않게)
  - 공격은 tools/_work/anim/<key>_<seed>.mp4, 그 밖의 동작은 <key>_<motion>_<seed>.mp4. 이미 있으면 건너뜀(중단 후 다시 실행 가능)
  - 진행 상황은 tools/_work/anim/progress.log 에 한 줄씩 기록
"""
import json, os, subprocess, sys, time
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'tools', '_work', 'anim')
os.makedirs(OUT, exist_ok=True)

def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default

cfg = json.load(open(os.path.join(ROOT, 'tools', 'anim-prompts.json')))
only = [k for k in arg('--only', '').split(',') if k]
skip = [k for k in arg('--skip', 'knight_01').split(',') if k]
seeds = [int(s) for s in arg('--seeds', '19,8,77').split(',')]
port = arg('--port', '11240')
keys = [k for k in cfg['chars'] if (not only or k in only) and k not in skip]
motions = [m for m in arg('--motions', 'attack').split(',') if m]
log = open(os.path.join(OUT, 'progress.log'), 'a')

def note(msg):
    line = time.strftime('%H:%M:%S ') + msg
    print(line, flush=True); log.write(line + '\n'); log.flush()

def padded_input(key):
    path = os.path.join(OUT, key + '_in.png')
    if os.path.exists(path): return path
    im = Image.open(os.path.join(ROOT, 'image', 'character', key + '.png')).convert('RGBA')
    ch = im.crop(im.getbbox())
    S = 1024; bg = Image.new('RGBA', (S, S), (0, 255, 0, 255))
    h = int(S * 0.38); w = int(ch.width * h / ch.height)
    if w > S * 0.5: w = int(S * 0.5); h = int(ch.height * w / ch.width)  # 가로로 넓은 그림은 폭 기준
    ch = ch.resize((w, h), Image.NEAREST)
    bg.alpha_composite(ch, ((S - w) // 2, int(S * 0.88) - h))
    bg.convert('RGB').save(path)
    return path

total = len(keys) * len(seeds) * len(motions); done = 0
note(f'start {len(keys)} chars x {len(motions)} motions x {len(seeds)} seeds = {total}')
for mo in motions:
  for key in keys:
    c = cfg['chars'][key]
    fill = lambda t: t.replace('{who}', c['who']).replace('{action}', c.get('action', '')).replace('{Pron}', c['pron'].capitalize()).replace('{pron}', c['pron'])
    if mo == 'attack': prompt, nf, tag = fill(cfg['template']), 73, ''
    else: prompt, nf, tag = fill(cfg['motions'][mo]['text']), cfg['motions'][mo]['frames'], '_' + mo
    pf = os.path.join(OUT, f'{key}{tag}_prompt.txt'); open(pf, 'w').write(prompt)
    src = padded_input(key)
    for sd in seeds:
        done += 1
        mp4 = os.path.join(OUT, f'{key}{tag}_{sd}.mp4')
        if os.path.exists(mp4):
            note(f'[{done}/{total}] {key}{tag} seed {sd} skip (exists)'); continue
        t0 = time.time()
        r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'local-video.py'), src, mp4,
                            '--port', port, '--frames', str(nf), '--size', '480', '--seed', str(sd), '--prompt-file', pf],
                           capture_output=True, text=True)
        ok = r.returncode == 0 and os.path.exists(mp4)
        note(f'[{done}/{total}] {key}{tag} seed {sd} {"ok" if ok else "FAIL"} {time.time() - t0:.0f}s' +
             ('' if ok else ' ' + (r.stderr or r.stdout)[-300:].replace('\n', ' ')))
note('ALL_DONE')
