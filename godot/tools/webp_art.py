#!/usr/bin/env python3
"""개발용: 정면·스토리 일러스트 PNG → 손실 WebP(품질 85) 변환 (배포 용량 줄이기, 2026-10-23)

대상 (godot/assets/image/character/):
  <직업>_01|02.png          전신 정면 그림 (962x1087, 투명 배경)      → <직업>_01|02.webp
  story/<키>.png            스토리 초상화·보스 그림 (962x1087)        → story/<키>.webp
  (portrait/ 초상화 · anim/ 동작 시트는 이 도구의 대상이 아님 — 시트는 칸 경계가 있어 무손실 PNG 유지)

원본(무손실 PNG)은 git 에 올리지 않는 작업 폴더에 보관 (Godot 은 .gdignore 라 읽지 않음, .gitignore 에 있음):
  godot/assets/image/character/art_src/front/<직업>_01|02.png
  godot/assets/image/character/art_src/story/<키>.png
  (잃어버렸으면 변환 직전 커밋 ad48239 의 기록에서 복구:
   git checkout ad48239 -- godot/assets/image/character/archer_01.png  처럼 꺼낸 뒤 이 도구를 다시 돌림)

사용:
  python3 godot/tools/webp_art.py            # character/ 와 character/story/ 에 새로 생긴 *.png 를 변환 → PNG 는 art_src 로 옮김
                                             #   (tools/make-portrait.py 가 story/<키>.png 를 만들면 이어서 이 명령)
  python3 godot/tools/webp_art.py --rebuild  # art_src 의 원본 PNG 로 .webp 를 전부 다시 만듦 (품질·옵션을 바꿀 때)
  python3 godot/tools/webp_art.py --quality 85 --check   # 지금 .webp 와 art_src 원본을 비교만 (PSNR · 알파 차이)

필요: cwebp (libwebp, brew install webp) · Pillow. 변환 옵션: -q 85 -m 6 -sharp_yuv -alpha_q 100
  (알파는 무손실 그대로, sharp_yuv 로 가장자리 색 번짐을 줄임)
변환 뒤 Godot 을 한 번 열어(또는 `Godot --headless --path godot --editor --quit`) .webp.import 를 만들게 하고,
.webp.import 는 이 도구가 없을 때 만들어 줍니다 (압축 모드 '손실' 0.85 — 아래 IMPORT_TEMPLATE).
"""
import argparse, glob, os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHAR = os.path.join(ROOT, 'godot/assets/image/character')
ART_SRC = os.path.join(CHAR, 'art_src')
Q = 85
# 가져오기 설정: 압축 모드 '손실'(1) · 품질 0.85 — 기본값(무손실)이면 Godot 이 손실 WebP 를 풀어 다시 무손실로 넣어 오히려 커짐.
#  uid·path 줄은 Godot 이 처음 가져올 때 채움.
IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/image/character/%s"

[params]

compress/mode=1
compress/high_quality=false
compress/lossy_quality=0.85
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
# (그림이 있는 폴더, art_src 안 하위 폴더, 파일 이름 걸러내기)
GROUPS = [
    (CHAR, 'front', lambda n: n[:-4].endswith(('_01', '_02')) and '.prev' not in n),
    (os.path.join(CHAR, 'story'), 'story', lambda n: True),
]


def cwebp(src, dst, q):
    subprocess.run(['cwebp', '-quiet', '-q', str(q), '-m', '6', '-sharp_yuv', '-alpha_q', '100', src, '-o', dst], check=True)


def files(folder, ok):
    return sorted(f for f in glob.glob(os.path.join(folder, '*.png')) if ok(os.path.basename(f)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--quality', type=int, default=Q)
    ap.add_argument('--rebuild', action='store_true')
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    if shutil.which('cwebp') is None:
        sys.exit('cwebp 가 없습니다 (brew install webp)')
    os.makedirs(ART_SRC, exist_ok=True)
    gd = os.path.join(ART_SRC, '.gdignore')
    if not os.path.exists(gd):
        open(gd, 'w').close()
    if a.check:
        return check(a.quality)
    n = 0
    for folder, sub, ok in GROUPS:
        keep = os.path.join(ART_SRC, sub)
        os.makedirs(keep, exist_ok=True)
        if a.rebuild:
            srcs = sorted(glob.glob(os.path.join(keep, '*.png')))
        else:
            srcs = files(folder, ok)
        for p in srcs:
            name = os.path.splitext(os.path.basename(p))[0]
            dst = os.path.join(folder, name + '.webp')
            cwebp(p, dst, a.quality)
            if not a.rebuild:
                shutil.move(p, os.path.join(keep, name + '.png'))   # 원본 보관 (이미 있으면 덮어씀)
                old = p + '.import'
                if os.path.exists(old):
                    os.remove(old)                                    # 옛 PNG 의 가져오기 옆파일
            imp = dst + '.import'
            if not os.path.exists(imp):
                open(imp, 'w').write(IMPORT_TEMPLATE % os.path.relpath(dst, CHAR))
            n += 1
            print('%-40s %7.0f KB -> %6.0f KB' % (os.path.relpath(dst, CHAR), os.path.getsize(os.path.join(keep, name + '.png')) / 1024, os.path.getsize(dst) / 1024))
    print('변환 %d개 (품질 %d)' % (n, a.quality))


def check(q):
    from PIL import Image
    import math
    worst = 100.0
    for folder, sub, ok in GROUPS:
        for p in sorted(glob.glob(os.path.join(ART_SRC, sub, '*.png'))):
            name = os.path.splitext(os.path.basename(p))[0]
            w = os.path.join(folder, name + '.webp')
            if not os.path.exists(w):
                print('없음', w); continue
            A, B = Image.open(p).convert('RGBA'), Image.open(w).convert('RGBA')
            pa, pb = A.load(), B.load()
            se = n = 0; alpha_bad = 0
            for y in range(A.height):
                for x in range(A.width):
                    r1, g1, b1, a1 = pa[x, y]; r2, g2, b2, a2 = pb[x, y]
                    if a1 != a2: alpha_bad += 1
                    if a1 == 0 and a2 == 0: continue
                    se += (r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2; n += 3
            psnr = 99.0 if se == 0 else 10 * math.log10(255 * 255 * n / se)
            worst = min(worst, psnr)
            print('%-28s PSNR %.1f dB · 알파 다른 픽셀 %d' % (sub + '/' + name, psnr, alpha_bad))
    print('가장 낮은 PSNR %.1f dB' % worst)


if __name__ == '__main__':
    main()
