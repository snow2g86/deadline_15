#!/usr/bin/env python3
"""개발용: image/icon/src 의 일러스트를 게임 아이콘으로 한 번에 적용

사용: python3 tools/import-icons.py
1) image/icon/src/<키>.png|webp|jpg → image/icon/item/<키>.png (256px, 테두리 여백·생성 표시 정리 — tools/make-icon.py)
   jab_<직업> 키는 직업 아이콘 image/icon/jab/<직업>.png (64px) 로 교체
   이미 변환된 것은 원본이 더 새로울 때만 다시 변환
2) 아이콘 시트 다시 만들기 (tools/build-icon-sheet.py → image/icon/item-sprite.webp, js/common/item-icons.js)
3) 프롬프트 문서 진행 표시·이모지 교체표 갱신 (tools/icon-catalog.py)
원본(src)은 용량이 커서 git에 올리지 않음 (.gitignore)
"""
import os, glob, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC, DST = os.path.join(ROOT, 'image/icon/src'), os.path.join(ROOT, 'image/icon/item')
os.makedirs(SRC, exist_ok=True); os.makedirs(DST, exist_ok=True)
n = 0
for f in sorted(glob.glob(os.path.join(SRC, '*'))):
    key, ext = os.path.splitext(os.path.basename(f))
    if ext.lower() not in ('.png', '.webp', '.jpg', '.jpeg'): continue
    if key.startswith('jab_'):   # 직업 아이콘: image/icon/jab/<직업>.png 를 64px로 바로 교체
        out, size = os.path.join(ROOT, 'image/icon/jab', key[4:] + '.png'), '64'
    elif key.startswith('frame_'):   # 등급 테두리: 시트에 함께 (아이템 뒤에 깔림)
        out, size = os.path.join(DST, key + '.png'), '256'
    else:
        out, size = os.path.join(DST, key + '.png'), '256'
    if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(f): continue
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools/make-icon.py'), f, out, size], check=True); n += 1
print('converted', n)
subprocess.run([sys.executable, os.path.join(ROOT, 'tools/build-icon-sheet.py')], check=True)
subprocess.run([sys.executable, os.path.join(ROOT, 'tools/icon-catalog.py')], check=True)
