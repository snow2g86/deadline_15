#!/usr/bin/env python3
"""개발용: 로컬 MLX Core(mlx-serve) MiniMax H3로 첫·끝 프레임 고정 영상 생성 → mp4 저장

사용: python3 tools/local-video.py <첫·끝 프레임 이미지> <출력.mp4> [--port 11240] [--frames 73] [--size 480] [--seed 1] [--prompt-file f]
서버는 먼저 띄워 둔다: "/Applications/MLX Core.app/Contents/MacOS/mlx-serve" serve --host 127.0.0.1 --port 11240
"""
import base64, json, subprocess, sys, time, urllib.request

def arg(name, default):
    return type(default)(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else default

img, out = sys.argv[1], sys.argv[2]
PORT, NF, SIZE, SEED = arg('--port', 11240), arg('--frames', 73), arg('--size', 480), arg('--seed', 1)
PROMPT = open(arg('--prompt-file', '')).read().strip() if '--prompt-file' in sys.argv else (
    "Retro 16-bit pixel art sprite animation of the same armored knight, side view, always facing right toward the enemy. "
    "He never turns around and his body stays in the same spot. Motion: he raises the sword high above his helmet, then chops it "
    "straight down in front of him toward the right, over the top of his shield, a single clean forward strike, then lowers the "
    "sword and returns to the exact starting pose. The sword only moves forward to the right, never behind him. The shield stays "
    "on his front arm. Crisp hard pixel edges, same colors and proportions as the first frame, no motion blur, no glow, no sparks, "
    "no flash, no smoke, no trails. Locked static camera, no zoom, flat solid pure green background, no shadow, no ground.")

b64 = base64.b64encode(open(img, 'rb').read()).decode()
body = {
    'model': 'ddalcu/MiniMax-H3-FL2VA-MLX-Serve-8bit', 'prompt': PROMPT,
    'width': SIZE, 'height': SIZE, 'num_frames': NF, 'seed': SEED, 'turbo': True, 'stream': False,
    'first_frame_image': b64, 'last_frame_image': b64,
}
t0 = time.time()
req = urllib.request.Request(f'http://127.0.0.1:{PORT}/v1/video/generations', data=json.dumps(body).encode(),
                             headers={'Content-Type': 'application/json'})
raw = urllib.request.urlopen(req, timeout=7200).read()
print('elapsed', round(time.time() - t0, 1), 's, bytes', len(raw))
try:
    res = json.loads(raw)
except Exception:
    open(out, 'wb').write(raw); print('saved raw', out); sys.exit()

# 응답 형식 확인용 요약 (큰 data 필드는 길이만)
def summ(o, d=0):
    if isinstance(o, dict): return {k: summ(v, d + 1) for k, v in o.items()}
    if isinstance(o, list): return [summ(o[0], d + 1), f'...x{len(o)}'] if o else []
    if isinstance(o, str) and len(o) > 200: return f'<str {len(o)}>'
    return o
print(json.dumps(summ(res), ensure_ascii=False)[:1500])

# rgb8 원시 프레임이면 ffmpeg로 mp4 인코딩
v = res.get('video', res) if isinstance(res, dict) else res
if isinstance(v, dict) and v.get('format') == 'rgb8' and v.get('data'):
    frames = base64.b64decode(v['data']); W, H, F = v['width'], v['height'], v['frames']
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(v.get('fps', 24)),
                    '-i', '-', '-pix_fmt', 'yuv420p', '-crf', '12', out], input=frames, check=True)
    print('saved', out, W, H, F)
