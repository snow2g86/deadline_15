#!/usr/bin/env python3
"""개발용: 캐릭터 뒷모습 만들기 — 로컬 MiniMax H3로 "뒤로 돌아서는" 영상을 만들고 마지막 장면을 뒷모습으로 저장

사용: python3 tools/local-turn.py <키 예: knight_01> [--seeds 1,2] [--port 11240]
- 입력: tools/_work/anim/<키>_in.png (초록 바탕, 캐릭터 높이 38% — tools/batch-anim.py 와 같은 입력)
- 출력: tools/_work/back/<키>_<시드>.mp4, <키>_<시드>_last.png (마지막 장면 = 뒷모습 후보)
- 첫 장면만 고정 (끝 장면은 자유) → 그림체·장비는 앞모습 그대로, 몸만 돌아섬
서버: "/Applications/MLX Core.app/Contents/MacOS/mlx-serve" serve --host 127.0.0.1 --port 11240 --skip-mem-preflight
"""
import base64, json, os, subprocess, sys, time, urllib.request
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK, OUT = os.path.join(ROOT, 'tools/_work/anim'), os.path.join(ROOT, 'tools/_work/back')
os.makedirs(OUT, exist_ok=True)


def arg(name, default):
    return type(default)(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else default


key = sys.argv[1]
PORT, SEEDS = arg('--port', 11240), [int(s) for s in arg('--seeds', '1,2').split(',')]
who = json.load(open(os.path.join(ROOT, 'tools/anim-prompts.json')))['chars'].get(key, {}).get('who', 'character')
WEAPON = arg('--weapon', '')   # 무기·자세를 직접 지정 (칼로 바뀌는 직업용: 맨주먹·구슬·책 등)
if WEAPON: WEAPON = WEAPON.rstrip('. ') + '. '
# 완전히 등지면(정면 뒷모습) 쿼터뷰에서 방향이 애매함 → 45도만 돌아 등+오른쪽 옆이 보이는 비스듬한 뒷모습 + 경계 자세 (2026-10-11 사용자 피드백)
PROMPT = (f"Retro 16-bit pixel art sprite animation of the same {who}. The character turns about 135 degrees in place, "
          "ending in a diagonal three-quarter rear view: facing away from the camera toward the upper right, "
          "we see the back and the right side of the body, the back of the head with a small part of the side of the face, "
          "NOT a straight back view. At the end the character stands in a ready combat stance, knees slightly bent, "
          + (WEAPON if WEAPON else "holding the same weapon raised forward toward the upper right where it is clearly visible. ") +
          "Do not add any new clothing, cloth, cape or colors that are not in the first frame. Feet stay on the same spot, "
          "same size, same colors and proportions as the first frame. Crisp hard pixel edges, no motion blur, no glow, no effects. "
          "Locked static camera, no zoom, flat solid pure green background, no shadow, no ground.")
TAG = arg('--tag', '')   # 같은 시드로 다른 프롬프트를 시험할 때 파일 이름 구분
img = os.path.join(WORK, key + '_in.png')
b64 = base64.b64encode(open(img, 'rb').read()).decode()
for seed in SEEDS:
    mp4 = os.path.join(OUT, f'{key}{TAG}_{seed}.mp4')
    if os.path.exists(mp4): print('skip', mp4); continue
    body = {'model': 'ddalcu/MiniMax-H3-FL2VA-MLX-Serve-8bit', 'prompt': PROMPT, 'width': 480, 'height': 480, 'num_frames': 73,
            'seed': seed, 'turbo': True, 'stream': False, 'first_frame_image': b64}
    t0 = time.time()
    req = urllib.request.Request(f'http://127.0.0.1:{PORT}/v1/video/generations', data=json.dumps(body).encode(),
                                 headers={'Content-Type': 'application/json'})
    v = json.loads(urllib.request.urlopen(req, timeout=7200).read())
    v = v.get('video', v)
    frames = base64.b64decode(v['data']); W, H, F = v['width'], v['height'], v['frames']
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(v.get('fps', 24)),
                    '-i', '-', '-pix_fmt', 'yuv420p', '-crf', '12', mp4], input=frames, check=True)
    n = W * H * 3
    Image.frombytes('RGB', (W, H), frames[(F - 1) * n:F * n]).save(os.path.join(OUT, f'{key}{TAG}_{seed}_last.png'))
    print(key, seed, 'done', round(time.time() - t0), 's', flush=True)
