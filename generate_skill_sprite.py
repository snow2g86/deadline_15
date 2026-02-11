"""
스킬 아이콘 스프라이트 시트 생성기
50개 개별 64x64 PNG → 8열×7행 512×448 단일 PNG
"""
from PIL import Image
import os, glob

SRC = 'image/icon/skill'
OUT = 'image/icon/skill-sprite.png'
COLS, TILE = 8, 64

# 알파벳순 정렬
files = sorted(glob.glob(os.path.join(SRC, '*.png')))
names = [os.path.splitext(os.path.basename(f))[0] for f in files]
n = len(files)
rows = (n + COLS - 1) // COLS

print(f'{n}개 아이콘 → {COLS}열 × {rows}행 ({COLS*TILE}×{rows*TILE}px)')

sheet = Image.new('RGBA', (COLS * TILE, rows * TILE), (0, 0, 0, 0))

for i, fpath in enumerate(files):
    col, row = i % COLS, i // COLS
    img = Image.open(fpath).convert('RGBA').resize((TILE, TILE), Image.NEAREST)
    sheet.paste(img, (col * TILE, row * TILE))

sheet.save(OUT, 'PNG')
print(f'저장: {OUT}')

# JS 매핑 출력
print('\n// SKILL_SPRITE 매핑:')
print('const SKILL_SPRITE = {')
for i, name in enumerate(names):
    col, row = i % COLS, i // COLS
    print(f'\t{name}: [{col},{row}],')
print('};')
