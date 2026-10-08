#!/usr/bin/env python3
"""개발용: 일러스트(금테 정사각형) → 게임 아이콘 PNG

사용: python3 tools/make-icon.py <원본 이미지> <출력 png> [크기=256]
- 바깥 여백을 잘라 금테가 가장자리에 오게 맞춤
- 오른쪽 아래 생성 표시(✦)를 왼쪽 아래 모서리를 좌우 뒤집어 덮어 지움
- 지정 크기로 축소 (아이콘 시트는 tools/build-icon-sheet.py 가 64px로 묶음)
"""
import sys
from PIL import Image, ImageOps

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 256
im = Image.open(src).convert('RGB')
w, h = im.size
m = round(min(w, h) * 0.012)          # 바깥 흰 여백
im = im.crop((m, m, w - m, h - m))
w, h = im.size
c = round(w * 0.12)                   # 모서리 덮개 크기
corner = im.crop((0, h - c, c, h))    # 왼쪽 아래 모서리
im.paste(ImageOps.mirror(corner), (w - c, h - c))
im = im.resize((size, size), Image.LANCZOS)
im.save(dst, optimize=True)
print(dst, im.size)
