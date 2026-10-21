#!/bin/bash
# 6b: iOS Xcode 프로젝트 내보내기 (서명 안 함, export_project_only)
#   bash godot/tools/ios_export.sh [Godot 실행 파일]        → godot/build/ios/
# 1) third_party/godot-iap-ios 의 GDExtension(godot-iap 4.0.3 iOS 네이티브)을 addons/godot-iap/bin 으로 잠깐 복사
#    (데스크톱 편집기에 .gdextension 이 있으면 오류가 나므로 평소에는 두지 않음)
# 2) 내보내기  3) 복사본 지움 (실패해도)  4) 내보낸 프로젝트 손질 (tools/ios_post_export.py: 빈 사용 설명 키 · ATT 6개 언어 · 결제 기능 · 프레임워크)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-/Applications/Godot.app/Contents/MacOS/Godot}"   # 시험·자동화는 g.sh 같은 감싼 실행 파일을 넘김
stage() { rm -rf addons/godot-iap/bin; mkdir -p addons/godot-iap/bin; cp -R third_party/godot-iap-ios/bin/. addons/godot-iap/bin/; }
unstage() { rm -rf addons/godot-iap/bin; rm -f .godot/extension_list.cfg; }   # 편집기 캐시의 확장 목록도 (남으면 다음 실행에 오류)
# Godot 은 팀 ID 가 비면 내보내기를 거절함 → 임시 값(AAAAAAAAAA)을 프리셋에 넣었다가 끝나면 되돌림 (서명은 하지 않음 — 사용자가 Xcode 에서 자기 팀으로)
BAK="$(mktemp)"; cp -p export_presets.cfg "$BAK"   # -p: 수정 시각을 보존 (check_pc5 의 빌드 최신 검사)
restore() { cp -p "$BAK" export_presets.cfg; rm -f "$BAK"; unstage; }
trap restore EXIT
sed -i '' 's/^application\/app_store_team_id=""/application\/app_store_team_id="AAAAAAAAAA"/' export_presets.cfg
stage
mkdir -p build/ios
"$GODOT" --headless --path . --export-debug "iOS (App Store)" build/ios/DEADLINE15.ipa
unstage
python3 tools/ios_post_export.py build/ios
