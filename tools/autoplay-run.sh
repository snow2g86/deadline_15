#!/bin/bash
# 개발용: 자동 플레이 연구를 화면 없이(헤드리스) 백그라운드로 돌린다. 연구 중에도 다른 작업 가능.
#
# 사용: tools/autoplay-run.sh start <보고서 폴더> "<포트>|<프로필>|<조합>" ...
#       tools/autoplay-run.sh stop
#   예) tools/autoplay-run.sh start /tmp/ap "8766|managed|knight,priest,mage,mage,mage" "8767|naive|knight,priest,mage,archer,warrior"
# 진행 상황: <보고서 폴더>/<포트>.json (전투가 끝날 때마다 갱신)
# 환경 변수: FROM(기본 1) TO(기본 100) FRESH(기본 1: 새 게임, 0: 이어서) WARP(기본 25)
# 헤드리스 크롬: Playwright가 받아 둔 chrome-headless-shell (CHROME 환경 변수로 바꿀 수 있음)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIDS="${TMPDIR:-/tmp}/autoplay-pids"
CHROME="${CHROME:-$(ls -d "$HOME"/Library/Caches/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-*/chrome-headless-shell 2>/dev/null | tail -1)}"

stop() {
  [ -f "$PIDS" ] && while read -r pid; do kill "$pid" 2>/dev/null || true; done < "$PIDS"
  rm -f "$PIDS"
}

case "$1" in
  stop) stop; echo "stopped"; exit 0 ;;
  start) ;;
  *) sed -n '2,10p' "$0"; exit 1 ;;
esac

REPORTS="$2"; shift 2
[ -x "$CHROME" ] || { echo "헤드리스 크롬을 찾지 못했습니다 (CHROME=...)"; exit 1; }
stop
mkdir -p "$REPORTS"
for spec in "$@"; do
  IFS='|' read -r port profile combo <<< "$spec"
  python3 "$ROOT/tools/autoplay-server.py" "$port" "$ROOT" "$REPORTS" > /dev/null 2>&1 &
  echo $! >> "$PIDS"
  sleep 0.5
  url="http://127.0.0.1:$port/tools/autoplay.html?auto=1&profile=$profile&combo=$combo&from=${FROM:-1}&to=${TO:-100}&fresh=${FRESH:-1}&warp=${WARP:-25}"
  # 창마다 별도 프로필, 백그라운드 감속 끄기 (헤드리스라 화면에 아무것도 뜨지 않음)
  "$CHROME" --user-data-dir="$REPORTS/profile-$port" --mute-audio --no-first-run \
    --disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows \
    --window-size=1200,900 "$url" > /dev/null 2>&1 &
  echo $! >> "$PIDS"
  echo "started $port ($profile / $combo)"
done
