#!/usr/bin/env python3
"""개발용: 맵 오브젝트(나무·바위·둔덕·평지 장식) 로컬 생성 — Qwen-Image-Edit-2509 + Lightning 8스텝 (mflux, 크로노 엘레멘탈과 같은 방식)

화풍 기준 = 우리 캐릭터 그림(기본 knight_01) → 같은 16비트 픽셀 화풍으로 오브젝트만 그림
사용: python3 tools/gen-props.py <이름 ...> [--seeds 1,2] [--ref image/character/knight_01.png]
  이름: tree_a tree_b pine rock_a rock_b mound grass stones (아래 P 참고, all = 전부)
출력: tools/_work/props/<이름>_<시드>.png (크로마키 바탕: 초록 #00FF00, 초록 물체는 자홍 #FF00FF)
한 번에 하나씩 순서대로 (메모리 많이 씀 — 영상 서버와 동시에 돌리지 말 것)
"""
import os, subprocess, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'tools/_work/props')
LORA = os.path.expanduser('~/.cache/huggingface/hub/models--lightx2v--Qwen-Image-Lightning/snapshots/'
                          'e74da8d4e71a54b341de86aa9f8d2509165aa513/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-8steps-V1.0-bf16.safetensors')
GEN = os.path.expanduser('~/.local/bin/mflux-generate-qwen-edit')

# 이름: (바탕색, 물체 설명)
P = {
    'tree_a': ('magenta', 'a single round leafy deciduous tree with a short brown trunk and a big bushy green canopy'),
    'tree_b': ('magenta', 'a small cluster of two leafy green bushy trees of different heights, brown trunks'),
    'pine':   ('magenta', 'a single tall dark green pine tree with layered pointed branches and a short brown trunk'),
    'rock_a': ('magenta',   'a single large grey granite boulder, chunky and angular, with cracks and a few moss patches'),
    'rock_b': ('magenta',   'a pile of three big grey stones stacked together, angular, with cracks'),
    'mound':  ('magenta', 'a small rounded grassy earth mound hill with a brown dirt side and green grass on top, a few small pebbles'),
    'grass':  ('magenta', 'a small loose tuft of green grass blades with two tiny yellow wildflowers, just the blades growing from a single point, NO ground tile, NO square base, NO platform, NO soil block'),
    'stones': ('green',   'three small grey pebbles lying on the ground close together'),
}
BG = {'green': 'pure bright green #00FF00', 'magenta': 'pure bright magenta #FF00FF'}


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def ref_image(path):
    # 캐릭터 그림을 흰 바탕에 붙여 넣은 화풍 기준 (투명 바탕은 모델이 검게 볼 수 있음)
    out = os.path.join(OUT, '_ref.png')
    im = Image.open(path).convert('RGBA'); bg = Image.new('RGB', im.size, 'white'); bg.paste(im, mask=im.split()[3])
    bg.save(out); return out


def main():
    os.makedirs(OUT, exist_ok=True)
    names = [a for a in sys.argv[1:] if not a.startswith('--') and a not in (arg('--seeds', ''), arg('--ref', ''))]
    if names == ['all']: names = list(P)
    seeds = [int(s) for s in arg('--seeds', '1,2').split(',')]
    ref = ref_image(os.path.join(ROOT, arg('--ref', 'image/character/knight_01.png')))
    for n in names:
        bg, what = P[n]
        prompt = (f"Using exactly the same retro 16-bit pixel art style, palette and dark outline as this character sprite, "
                  f"draw a game map object instead of the character: {what}. "
                  "Seen from a high three-quarter isometric angle (camera looking down about 30 degrees), as a prop for an isometric tactics game. "
                  "Only the object, no character, no people. Crisp hard pixel edges, no anti-aliasing, no blur, no text. "
                  f"Centered, the whole object fully visible. The background is completely flat {BG[bg]}, no ground plane, no shadow.")
        for s in seeds:
            out = os.path.join(OUT, f'{n}_{s}.png')
            if os.path.exists(out): print('skip', out); continue
            cmd = [GEN, '--model', 'qwen-image-edit', '-q', '8', '--lora', LORA, '1.0', '--image-paths', ref, '--prompt', prompt,
                   '--width', '768', '--height', '768', '--steps', '8', '--guidance', '1.0', '--seed', str(s), '--output', out]
            r = subprocess.run(cmd, capture_output=True, text=True)
            print(n, s, 'ok' if r.returncode == 0 else 'FAIL ' + r.stderr[-400:], flush=True)


if __name__ == '__main__':
    main()
