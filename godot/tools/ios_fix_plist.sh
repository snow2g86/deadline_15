#!/bin/bash
# 6a: 내보낸 iOS 프로젝트의 Info.plist 에서 '빈' 사용 설명 키(카메라·사진·마이크)를 지움.
#  Godot 4.5.1 은 프리셋 값이 비어 있어도 키를 늘 넣는데, 이 게임은 카메라·사진·마이크를 쓰지 않으므로 App Store 심사에서 '빈 사용 설명' 지적을 받을 수 있음.
#  사용: bash godot/tools/ios_fix_plist.sh godot/build/ios      (내보낸 뒤, Xcode 에서 열기 전에 — 내보낼 때마다 다시)
set -euo pipefail
DIR="${1:-$(dirname "$0")/../build/ios}"
PL=$(ls "$DIR"/*/*-Info.plist | head -1)
for k in NSCameraUsageDescription NSPhotoLibraryUsageDescription NSMicrophoneUsageDescription; do
	v=$(/usr/libexec/PlistBuddy -c "Print :$k" "$PL" 2>/dev/null || echo "__none__")
	if [ "$v" = "" ]; then
		/usr/libexec/PlistBuddy -c "Delete :$k" "$PL"
		echo "지움: $k"
	fi
done
