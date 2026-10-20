#!/bin/bash
# 6a: 안드로이드 Gradle 빌드 틀 설치 + 이 맥의 캐시만으로 빌드되게 고침 (다운로드 없음)
#
#   bash godot/tools/android_build_template.sh            # godot/android/build 를 새로 만듦 (있으면 지우고 다시)
#
# - Godot 이 편집기 메뉴 '안드로이드 빌드 템플릿 설치'로 하는 일과 같음: 내보내기 템플릿의 android_source.zip 을
#   godot/android/build 에 풀고 godot/android/.build_version 에 버전, build/.gdignore 를 만듦.
# - godot/android/ 는 git 에 넣지 않음 (.gitignore — godot-lib aar 가 약 100MB × 2). 새로 받은 저장소에서는 이 스크립트를 한 번 실행.
# - 고치는 것 (Godot 4.5.1 원본 → 이 맥 ~/.gradle 캐시에 있는 판, 2026 Play 요구 targetSdk 36):
#     Gradle 8.11.1 → 8.14.3 · Android Gradle Plugin 8.6.1 → 8.11.0 · compile/targetSdk 35 → 36 · build-tools 35 → 36.0.0 ·
#     NDK 28.1 → 27.1.12297006(설치된 것) · androidx.fragment 1.8.6 → 1.8.9 · core-splashscreen 1.0.1 → 1.2.0 · core-ktx 1.16.0 고정 ·
#     플러그인 id → 모듈 직접 지정(캐시에 플러그인 표식 파일이 없어서)
#   다운로드가 허용되면 고치지 않은 원본(Godot 기본)으로 돌아가도 됨: 이 스크립트에서 PATCH=0 으로 실행.
# - 6b(결제·광고 플러그인)에서 aar 플러그인을 넣으면 그 의존성은 받아야 할 수 있음 (그때 판단).
set -euo pipefail
cd "$(dirname "$0")/.."
VER="4.5.1.stable"
TPL="${GODOT_TEMPLATES:-$HOME/Library/Application Support/Godot/export_templates}/$VER/android_source.zip"
PATCH="${PATCH:-1}"
[ -f "$TPL" ] || { echo "내보내기 템플릿이 없습니다: $TPL"; exit 1; }
KEEP=""
if [ -d android/keystore ]; then KEEP=$(mktemp -d); cp -R android/keystore "$KEEP/"; fi
rm -rf android/build
mkdir -p android/build
unzip -q "$TPL" -d android/build
printf '%s' "$VER" > android/.build_version
touch android/build/.gdignore
if [ -n "$KEEP" ]; then cp -R "$KEEP/keystore" android/; rm -rf "$KEEP"; fi

if [ "$PATCH" = "1" ]; then
	B=android/build
	sed -i '' 's#gradle-8.11.1-bin.zip#gradle-8.14.3-bin.zip#' $B/gradle/wrapper/gradle-wrapper.properties
	sed -i '' \
		-e "s/androidGradlePlugin: '8.6.1'/androidGradlePlugin: '8.11.0'/" \
		-e "s/compileSdk         : 35/compileSdk         : 36/" \
		-e "s/targetSdk          : 35/targetSdk          : 36/" \
		-e "s/buildTools         : '35.0.0'/buildTools         : '36.0.0'/" \
		-e "s/ndkVersion         : '28.1.13356709'/ndkVersion         : '27.1.12297006'/" \
		-e "s/fragmentVersion    : '1.8.6'/fragmentVersion    : '1.8.9'/" \
		-e "s/splashscreenVersion: '1.0.1'/splashscreenVersion: '1.2.0'/" \
		$B/config.gradle
	python3 - "$B" <<'EOF'
import sys, pathlib
b = pathlib.Path(sys.argv[1])
s = (b / "settings.gradle").read_text()
if "resolutionStrategy" not in s:
    s = s.replace("""    repositories {
        google()""", """    // 6a: 플러그인 표식(marker) 없이 캐시된 모듈을 바로 씀 (다운로드 없음)
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id == 'com.android.application') useModule("com.android.tools.build:gradle:8.11.0")
            if (requested.id.id == 'org.jetbrains.kotlin.android') useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.20")
        }
    }
    repositories {
        google()""", 1)
    (b / "settings.gradle").write_text(s)
g = (b / "build.gradle").read_text()
if "core-ktx" not in g:
    g = g.replace('dependencies {\n    implementation "androidx.fragment', 'dependencies {\n    implementation "androidx.core:core-ktx:1.16.0"   // 6a: 캐시에 있는 판으로 고정\n    implementation "androidx.fragment', 1)
    (b / "build.gradle").write_text(g)
EOF
	for f in "8.14.3-bin.zip" "8.11.0" "compileSdk         : 36" "1.8.9" "1.2.0"; do
		grep -rq "$f" $B/gradle/wrapper/gradle-wrapper.properties $B/config.gradle || { echo "고치기 실패: $f"; exit 1; }
	done
	grep -q resolutionStrategy $B/settings.gradle && grep -q core-ktx $B/build.gradle || { echo "고치기 실패: settings/build.gradle"; exit 1; }
	echo "android/build 설치 + 캐시용 고침 완료 ($VER)"
else
	echo "android/build 설치 완료 ($VER, 원본 그대로)"
fi

# 디버그 키스토어 (로컬 전용, git 제외). 출시 업로드 키는 만들지 않음 — README '6a — 서명'
if [ ! -f android/keystore/debug.keystore ]; then
	mkdir -p android/keystore
	keytool -genkeypair -v -keystore android/keystore/debug.keystore -storepass android -alias androiddebugkey -keypass android \
		-keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
	echo "디버그 키스토어 만듦: godot/android/keystore/debug.keystore (android / androiddebugkey / android)"
fi
