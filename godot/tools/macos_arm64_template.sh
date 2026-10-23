#!/bin/bash
# macOS 내보내기를 arm64(애플 실리콘) 전용으로 하기 위한 맞춤 템플릿 만들기 (2026-10-23)
#  Godot 공식 macos.zip 에는 universal(x86_64+arm64) 실행 파일만 있어서, 프리셋을 binary_format/architecture="arm64" 로 두면
#  'godot_macos_release.arm64 를 찾을 수 없습니다' 로 실패함. 공식 템플릿의 실행 파일을 lipo 로 arm64 만 남겨 같은 구조의 zip 으로 다시 묶음.
#  → build/templates/macos_arm64.zip  (git 제외 · 다운로드 없음 · 약 1분)
#  프리셋 [preset.1.options] 의 custom_template/debug · custom_template/release 가 이 파일을 가리킴 (프로젝트 폴더 기준 상대 경로 —
#  Godot 을 `--path godot` 로 열었을 때 / 편집기에서 열었을 때 모두 프로젝트 폴더가 기준)
#  사용: bash godot/tools/macos_arm64_template.sh   (Godot 버전을 올리면 다시 돌릴 것)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
VER="${GODOT_TEMPLATE_VERSION:-4.5.1.stable}"
SRC="${GODOT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$VER}/macos.zip"
[ -f "$SRC" ] || { echo "공식 macOS 템플릿이 없습니다: $SRC"; exit 1; }
OUT="$HERE/build/templates"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
unzip -q "$SRC" -d "$TMP"
MACOS="$TMP/macos_template.app/Contents/MacOS"
for kind in release debug; do
  lipo -thin arm64 "$MACOS/godot_macos_$kind.universal" -output "$MACOS/godot_macos_$kind.arm64"
  rm "$MACOS/godot_macos_$kind.universal"
  chmod +x "$MACOS/godot_macos_$kind.arm64"
done
rm -f "$OUT/macos_arm64.zip"
(cd "$TMP" && zip -q -r -y "$OUT/macos_arm64.zip" macos_template.app)
ls -l "$OUT/macos_arm64.zip"
