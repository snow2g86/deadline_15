#!/usr/bin/env python3
"""앱 아이콘 전부 — 방패 엠블럼('15') 확정 시안(2026-10)에서 만듦. 새 그림 아님·AI 아님 (코드로 그린 그림)

사용: python3 godot/tools/make_mobile_icons.py   → godot/icon.png + godot/assets/app_icon/*.png

그림 원본은 docs/store/graphics/make_icon_shield.py (render_layers) — 이 도구는 그 레이어를 파일 이름·크기·형식 그대로 저장만 한다.
- icon.png (1024 RGBA, 전부 불투명): 데스크톱(Windows .exe · macOS .icns) · 프로젝트 아이콘 = 전체 합성 (확정 시안과 같은 그림)
- ios_1024.png (1024 RGB, 알파 없음): App Store 요구. Godot 이 나머지 크기를 이것으로 줄임. 모서리는 직각(iOS 가 둥글게 자름)
- android_192.png (192 RGB): 기본(레거시) 아이콘 = 전체 합성을 줄인 것
- android_bg_432.png (432 RGB): 적응형 배경 — 남색 바탕 + 후광 + 광선 + 불씨 (방패·숫자 없음)
- android_fg_432.png (432 RGBA): 적응형 전경 — 투명 바탕에 방패 + 숫자만, 방패 윤곽이 가운데 지름 280px(약 65%, 런처 안전 영역 66% 안 — 그림자까지) 원 안
- android_mono_432.png (432 RGBA): 테마 아이콘(monochrome) — 방패 테두리 띠 + 방패 면을 흰색 단색으로, 숫자는 뚫림. 전경과 같은 크기·자리
- launch_400.png · launch_600.png: iOS 시작 화면 그림 @2x · @3x (투명 + 방패, 바탕은 프리셋의 바탕색 #0a0e1a)
"""
import importlib.util
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "app_icon")
SHIELD = os.path.join(os.path.dirname(ROOT), "docs", "store", "graphics", "make_icon_shield.py")


def load_shield():
    spec = importlib.util.spec_from_file_location("make_icon_shield", SHIELD)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def main():
    sh = load_shield()
    L = sh.render_layers()
    os.makedirs(OUT, exist_ok=True)
    full = L["full"]
    full.convert("RGBA").save(os.path.join(ROOT, "icon.png"))
    full.save(os.path.join(OUT, "ios_1024.png"))
    full.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "android_192.png"))
    L["bg"].resize((432, 432), Image.LANCZOS).save(os.path.join(OUT, "android_bg_432.png"))
    sh.fit_adaptive(L["fg"], L["fg_circle"]).save(os.path.join(OUT, "android_fg_432.png"))
    sh.fit_adaptive(L["mono"], L["fg_circle"]).save(os.path.join(OUT, "android_mono_432.png"))
    sh.fit_box(L["fg"], 400).save(os.path.join(OUT, "launch_400.png"))
    sh.fit_box(L["fg"], 600).save(os.path.join(OUT, "launch_600.png"))
    print("icon.png", Image.open(os.path.join(ROOT, "icon.png")).size)
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".png"):
            im = Image.open(os.path.join(OUT, f))
            print(f, im.size, im.mode, im.getchannel("A").getbbox() if im.mode == "RGBA" else "")


if __name__ == "__main__":
    main()
