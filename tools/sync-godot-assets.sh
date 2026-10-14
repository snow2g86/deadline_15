#!/usr/bin/env bash
# ═══════════════════════════════════════════
#  tools/sync-godot-assets.sh — 웹 image/ → godot/assets/image/ 복사 (rsync)
#
#  그림 원본은 웹 image/ 한 곳에만 둔다 (git 에 두 벌 올리지 않음). godot/assets/ 는 .gitignore 대상.
#  Godot 이 만드는 *.import 옆파일은 godot/assets/ 안에만 생기므로 웹 image/ 폴더는 깨끗하게 유지된다.
#
#  제외: 원본·작업 폴더(*/src/), 미리보기(*.prev.png), .DS_Store, 빈 폴더
#  chmod u+w: 웹 쪽 일부 폴더(icon/64x64)가 읽기 전용이라, 사본에는 쓰기 권한을 줘야 Godot 이 .import 옆파일을 만들 수 있다
#           (macOS 기본 rsync(openrsync)는 --chmod 가 없어 복사 뒤 따로 처리)
#  --delete: 웹 쪽에서 지운 그림은 godot 쪽에서도 지운다 (Godot 의 .import 옆파일은 보호)
#
#  사용: bash tools/sync-godot-assets.sh          (실제 복사)
#        bash tools/sync-godot-assets.sh --dry-run (무엇이 바뀔지만 보기)
# ═══════════════════════════════════════════
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/image/"
DST="$ROOT/godot/assets/image/"

if [[ ! -d "$SRC" ]]; then
  echo "[sync-godot-assets] image/ 폴더가 없습니다: $SRC" >&2
  exit 1
fi
mkdir -p "$DST"

EXTRA=()
if [[ "${1:-}" == "--dry-run" ]]; then EXTRA+=(--dry-run); fi

# rsync 실패는 그대로 실패로 끝나도록 출력만 따로 받는다
CHANGES="$(rsync -a --delete --prune-empty-dirs "${EXTRA[@]+"${EXTRA[@]}"}" \
  --exclude='src/' \
  --exclude='_work/' \
  --exclude='*.prev.png' \
  --exclude='.DS_Store' \
  --exclude='*.psd' --exclude='*.kra' --exclude='*.xcf' \
  --filter='protect *.import' \
  --itemize-changes \
  "$SRC" "$DST")"
CHANGED="$(printf '%s\n' "$CHANGES" | grep -c -E '^(>|\*deleting|c)' || true)"
printf '%s\n' "$CHANGES" | grep -E '^(>|\*deleting)' | tail -n 20 | sed 's/^/  /' || true
echo "[sync-godot-assets] 바뀐 항목 ${CHANGED}개"
if [[ "${1:-}" != "--dry-run" ]]; then chmod -R u+w "$DST"; fi

# 웹 image/ 에 Godot 옆파일이 새어 들어가지 않았는지 확인
LEAK="$(find "$ROOT/image" -name '*.import' | head -n 5)"
if [[ -n "$LEAK" ]]; then
  echo "[sync-godot-assets] 경고: 웹 image/ 안에 .import 파일이 있습니다 (Godot 이 웹 폴더를 열었던 흔적):" >&2
  echo "$LEAK" >&2
fi

COUNT="$(find "$DST" -type f ! -name '*.import' | wc -l | tr -d ' ')"
SIZE="$(du -sh "$DST" | cut -f1)"
echo "[sync-godot-assets] 완료: 그림 ${COUNT}개, ${SIZE} → godot/assets/image/"
