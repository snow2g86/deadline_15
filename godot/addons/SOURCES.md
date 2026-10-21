# addons/ — 받아 온 플러그인의 출처 (6b, 2026-10-21)

사용자가 허락한 세 가지 플러그인만 받았고, 모두 GitHub 공식 릴리스입니다. 받은 압축 파일은 풀어서 **읽기만** 했고(스크립트·바이너리를 실행하지 않음),
경로 이탈(`../`)·절대 경로·심볼릭 링크가 든 압축은 없었습니다. 프로젝트에 넣은 파일은 아래 표의 '넣은 것'뿐입니다. (원본 압축 파일은 프로젝트 밖에 두었다가 작업이 끝나며 지웠습니다.)

| 플러그인 | 버전 | 라이선스 | 받은 파일 (크기 · sha256) | 출처 |
|---|---|---|---|---|
| Godot Google Play Billing | 3.3.0 (Play Billing Library 9.1.0) | MIT, © 2020 Godot Engine contributors | `godot-google-play-billing.zip` 43,050 B · `20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568` | https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/3.3.0/godot-google-play-billing.zip |
| Godot AdMob Plugin (Poing Studios) | 5.1.0 (Google GMA Next-Gen SDK 1.4.0 · iOS GoogleMobileAds 13.9.0 · UMP 3.1.0) | MIT, © 2020-present Poing Studios | `poing-godot-admob-v5.1.0.zip` 2,918,625 B · `8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f` | https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/poing-godot-admob-v5.1.0.zip |
| (위의 네이티브 바이너리) | 5.1.0, Godot 4.5.1 용 | 〃 | `android-template-v4.5.1.zip` 359,197 B · `f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee` · `ios-template-v4.5.1.zip` 3,315,171 B · `9ea4f5044577f16b98a4afd8c20e646a9fad67e016f1ad10d70d956e2db8c41d` | 같은 릴리스 `https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/` — 플러그인 본체 압축에는 네이티브 라이브러리(aar · xcframework)가 없어서(편집기가 따로 받는 구조) 같은 릴리스의 Godot 4.5.1 용 두 개를 받음 |
| godot-iap (OpenIAP) — iOS StoreKit 2 | 4.0.3 (2026-10-16) | MIT, © 2025 hyo.dev (+ SwiftGodot 런타임 MIT, © 2020-2024 Miguel de Icaza) | `godot-iap-4.0.3.zip` 1,790,181 B · `3d94f9d6daae82e9479690a8c4da955714d436c1e6dce4854b82dd925ed1ab9a` (같이 받은 SBOM `godot-iap-4.0.3.cdx.json` 7,067 B · `43a019fc934f2e19ca80336f2720c3aafd5eadb41757859ebe9071530502ef8e` 는 프로젝트에 넣지 않음) | https://github.com/hyodotdev/openiap/releases/download/godot-iap-4.0.3/godot-iap-4.0.3.zip |

받은 날: 2026-10-21. 확인한 메타데이터(릴리스 목록 · 라이선스 · README · 소스의 공개 API)는 GitHub API 와 raw 파일을 읽은 것입니다.

## 프로젝트에 넣은 것 · 뺀 것 · 고친 것

- `addons/GodotGooglePlayBilling/` — 압축 그대로 (`BillingClient.gd` · `export_plugin.gd` · `plugin.cfg` · `LICENSE` · `bin/{debug,release}/*.aar`). 편집기 플러그인으로 켬(`project.godot` `editor_plugins`).
- `addons/admob/` — `admob.gd` · `plugin.cfg` · `LICENSE` · `assets/` · `docs/` · `gdscript/src/`(API) · `internal/`(편집기·내보내기 도구) + 네이티브 바이너리 `android/bin/{package.gd, ads/}` · `ios/bin/{package.gd, ads/}`.
  뺀 것: `csharp/`(C# 판) · `skills/`(AI 도우미 문서) · `gdscript/sample/` · 모든 중개(mediation) 어댑터 바이너리(광고는 구글 것만).
  고친 것: 바이너리를 git 에 올리려고 `android/.gitignore`·`ios/.gitignore` 의 `/bin` 줄을 지움 (플러그인이 헤드리스 편집기에서 바이너리를 스스로 내려받는 코드(`internal/services/network/binary_installer.gd`)가 있어서, `package.gd` 를 함께 두어 받지 않게 함).
  `project.godot` 에 플러그인이 만드는 `[admob]` 설정(앱 ID · 중개 꺼짐)을 미리 적어 둠 (편집기가 열 때 project.godot 을 다시 쓰지 않게).
- `addons/godot-iap/` — **스크립트만**: `godot_iap.gd`(래퍼 `GodotIapWrapper`) · `types.gd` · `android_store.gd` · `LICENSE` · `THIRD_PARTY_NOTICES.md`. 편집기 플러그인은 켜지 않음(자동 로드(autoload)·안드로이드 aar 를 쓰지 않음 — 안드로이드는 Google 플러그인).
  iOS 네이티브(`bin/godot_iap.gdextension` · `bin/ios/*.framework` 2개, arm64 기기용)는 `third_party/godot-iap-ios/` 에 두고(`third_party/.gdignore` 로 Godot 이 읽지 않음),
  **iOS 내보내기 때만** `tools/ios_export.sh` 가 `addons/godot-iap/bin/` 으로 복사했다가 끝나면 지움 — 데스크톱 편집기·내보내기에 `.gdextension` 이 있으면 "No GDExtension library found" 오류가 나고(맥/윈도 라이브러리가 없음) 시험이 오류 0 을 요구하기 때문.
  뺀 것: `godot_iap_plugin.gd` · `plugin.cfg` · `android_export.gd` · `android/`(GodotIap aar) · `scripts/fix_ios_embed.sh`(받은 스크립트는 실행하지 않음 — 필요한 일은 `tools/ios_post_export.py` 에 직접 씀).

## Gradle 이 받은 Maven 의존성 (안드로이드, 2026-10-21 첫 내보내기)

플러그인(billing-ktx 9.1.0 · ads-mobile-sdk 1.4.0)이 선언한 의존성입니다. Godot 의 Gradle 빌드가 `google()` → `mavenCentral()` 순서로 받았고(androidx·com.google.android.*·play 계열은 Google Maven `dl.google.com/dl/android/maven2`, 그 밖은 Maven Central 로 보이나, 파일마다 어느 저장소였는지는 Gradle 캐시에 남지 않아 **추정**),
`org.gradle.offline=true` 가 먹히지 않아 의도하지 않은 다운로드가 일어났습니다 (이후는 `gradlew --offline` 감싸개로 막음). 아래 해시는 이 맥의 `~/.gradle/caches/modules-2/files-2.1` 로컬 파일을 읽은 값입니다 (67개 파일, 16.7 MB).

| 좌표 | 버전 | 파일 | 크기 | sha256 |
|---|---|---|---|---|
| androidx.annotation:annotation-jvm | 1.8.2 | annotation-jvm-1.8.2.pom | 1826 | `7d3b2860ea36511153a9713559dab60d77f72167fadc9c1c3198c23035fbc480` |
| androidx.annotation:annotation-jvm | 1.8.2 | annotation-jvm-1.8.2.jar | 56126 | `9aab326d9492800991854360ac248f493ce7f7c3183519309b78ace9e240f6f6` |
| androidx.annotation:annotation-jvm | 1.8.2 | annotation-jvm-1.8.2.module | 3225 | `d004657cf28982ae8da8317c0c1fec663c627d0d0c54330f0baa92cbc360cdc1` |
| androidx.constraintlayout:constraintlayout-core | 1.1.0 | constraintlayout-core-1.1.0.module | 3963 | `d8d1b4ae950996d17ff6a5601cd8d106c3a30ff2dcc96815a9f32220d1d82c5f` |
| androidx.constraintlayout:constraintlayout-core | 1.1.0 | constraintlayout-core-1.1.0.jar | 585267 | `a8b90d19f7d758f7cb8962491547cf57cb7837c31fe3b00e01c4e85df7bf4851` |
| androidx.constraintlayout:constraintlayout-core | 1.1.0 | constraintlayout-core-1.1.0.pom | 1935 | `6181f8f022889eec2bd11b55f5b58ebc7602e55d611bc1144f13530db6636633` |
| androidx.constraintlayout:constraintlayout | 2.2.0 | constraintlayout-2.2.0.module | 4202 | `b968130636d2fcac654fa4012ddc36ab95a5ce044fb355ff75cbcea32e57bfa5` |
| androidx.constraintlayout:constraintlayout | 2.2.0 | constraintlayout-2.2.0.aar | 507991 | `c7c244100e68af49c99a6ad17694893c1be4fc55a6f539c8d78261dbbd2ce34a` |
| androidx.constraintlayout:constraintlayout | 2.2.0 | constraintlayout-2.2.0.pom | 2524 | `a5e523a9a7996b892610b9a940dbc8df98f4943a8642d6c07d5b2f0420fde611` |
| androidx.webkit:webkit | 1.15.0 | webkit-1.15.0.aar | 256171 | `241c90aac937b6562592976da5cc73100538bf255000f490ed37296da1773960` |
| androidx.webkit:webkit | 1.15.0 | webkit-1.15.0.module | 4797 | `c5d34727dfb45d6df66faf1d74927a7f118808a48ef44d0d9f33ab8d1c8df4fe` |
| androidx.webkit:webkit | 1.15.0 | webkit-1.15.0.pom | 2534 | `c1bf001ee88f75f8e94d944f596e98abc22d758182b19e981e024fa42197de1f` |
| com.android.billingclient:billing-ktx | 9.1.0 | billing-ktx-9.1.0.aar | 71724 | `21883d01509e984c2555374d710700e1cfa56996f95c7cb4cb7b384e167aa41c` |
| com.android.billingclient:billing-ktx | 9.1.0 | billing-ktx-9.1.0.pom | 1355 | `3be97981b9f759ecd1e70ea3ce9b0ab0129290a23bbc80c7f8faf17cf7d20bca` |
| com.google.android.gms:play-services-cronet | 18.0.1 | play-services-cronet-18.0.1.aar | 78576 | `b5e4c54a3ccb0200c7bf28d769c382c153954135a54096843f54160f89a7ddd0` |
| com.google.android.gms:play-services-cronet | 18.0.1 | play-services-cronet-18.0.1.pom | 1596 | `140732ce446f9018d8be88f31a8e864291244d3b6701ab9fc59c1ddff53bc7ec` |
| com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk | 1.4.0 | ads-mobile-sdk-1.4.0.aar | 5811670 | `d3fed6c8208ee00ebdffc03ea7a577e1f786b0eb12817b387ef217611ae58780` |
| com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk | 1.4.0 | ads-mobile-sdk-1.4.0.pom | 5185 | `40943be80f764280afeb052a57b7ef42131a31fc505691e4a29f9c3ba89beca1` |
| com.google.android.play:hsdp | 2.0.1 | hsdp-2.0.1.aar | 174578 | `5e57065e411d985f4e4eb0cd028c617c3a5d3bf836d20fc524ec23a0df39af75` |
| com.google.code.gson:gson-parent | 2.13.2 | gson-parent-2.13.2.pom | 27017 | `83ab528a9d50fd76aeb8ad6f727b3ee9cb766586255774ed16ca8c4c76d9dacd` |
| com.google.code.gson:gson | 2.13.2 | gson-2.13.2.jar | 289901 | `dd0ce1b55a3ed2080cb70f9c655850cda86c206862310009dcb5e5c95265a5e0` |
| com.google.code.gson:gson | 2.13.2 | gson-2.13.2.pom | 13490 | `3aa06aa7c0f9af092961a42d09578e4324be146348a0ee6ed47857f7c2677b76` |
| com.google.crypto.tink:tink-android | 1.20.0 | tink-android-1.20.0.pom | 4083 | `ce599495f721300f0dc184156352dac7077e75b7b652a15212c89906c7761ee0` |
| com.google.crypto.tink:tink-android | 1.20.0 | tink-android-1.20.0.jar | 3298443 | `0341f5a23366370144733bc7edb1adee115c059928dad32e73fe59e3503d3485` |
| com.google.errorprone:error_prone_annotations | 2.41.0 | error_prone_annotations-2.41.0.pom | 4252 | `a151df1e2e0b48618d8b06a180748a29b3abb39b1b2396f6a1c879a727488c6e` |
| com.google.errorprone:error_prone_annotations | 2.41.0 | error_prone_annotations-2.41.0.jar | 20389 | `a56e782b5b50811ac204073a355a21d915a2107fce13ec711331ad036f660fcc` |
| com.google.errorprone:error_prone_parent | 2.41.0 | error_prone_parent-2.41.0.pom | 15920 | `c538388d760a5c1c98dcf06f6ed3cfe5f11a651827db5cbd2ed8288c795cad42` |
| com.google.guava:guava-parent | 32.0.0-android | guava-parent-32.0.0-android.pom | 20916 | `74bf7cc1c585689baca2a45613955e755a6f6d3f9e4d455eed2a63db9be663d9` |
| com.google.guava:guava | 32.0.0-android | guava-32.0.0-android.jar | 2848827 | `96952b394133aa20ad3f18f4fb09582b12a8aa95e78c40203c7fb9efedcc2f7c` |
| com.google.guava:guava | 32.0.0-android | guava-32.0.0-android.pom | 11358 | `5da3afea915a4aad9897e2212f9c938a48268b0a0963d05a03d95b713f2771a1` |
| com.google.j2objc:j2objc-annotations | 2.8 | j2objc-annotations-2.8.jar | 9301 | `f02a95fa1a5e95edb3ed859fd0fb7df709d121a35290eff8b74dce2ab7f4d6ed` |
| com.google.protobuf:protobuf-bom | 3.22.3 | protobuf-bom-3.22.3.pom | 3547 | `13a32dfb9de6fc1c3c3f7af53e4d5c77fd77d2b476bae38b74b7581cdee2e655` |
| com.google.protobuf:protobuf-javalite | 3.22.3 | protobuf-javalite-3.22.3.pom | 1561 | `8e4099ee719994af66508b36028ae44e5e4745ba1351393e80d1e4fbe52d051f` |
| com.google.protobuf:protobuf-javalite | 3.22.3 | protobuf-javalite-3.22.3.jar | 713936 | `9d26bebd2607fd0553cedbfc3e4a3d3f06c6e7a207d2b74c87fa6181838ed1bf` |
| com.google.protobuf:protobuf-parent | 3.22.3 | protobuf-parent-3.22.3.pom | 9024 | `399133d7f6f57934dd76c4b18e86348f424532108daf4a01c8f820b8665f0929` |
| com.squareup.okhttp3:okhttp | 4.11.0 | okhttp-4.11.0.jar | 786969 | `ee8f6bd6cd1257013d748330f4ca147638a9fbcb52fb388d5ac93cf53408745d` |
| com.squareup.okhttp3:okhttp | 4.11.0 | okhttp-4.11.0.pom | 2003 | `7a2d427b38b17e076da64ee8d2102e64888dcb238aee5e2dba4a7752c94a3fde` |
| com.squareup.okhttp3:okhttp | 4.11.0 | okhttp-4.11.0.module | 4716 | `567c25b51d77796174439184d752412ba97ed9fdb65fc71840dbc5563beb8fa8` |
| com.squareup.okio:okio-jvm | 3.2.0 | okio-jvm-3.2.0.jar | 345115 | `b642baef4c570055de4cb3d1667b2b16dced901ff8066345a063691aa06025a4` |
| com.squareup.okio:okio-jvm | 3.2.0 | okio-jvm-3.2.0.pom | 1857 | `5c451f94a76bea861b6ef2bf84e8f57200545968c86555abdfed13c7ca2d489d` |
| com.squareup.okio:okio-jvm | 3.2.0 | okio-jvm-3.2.0.module | 2642 | `a778f39085ed6abfcd687112986c6385aa57ac2d8840b21d946b3c2095f30ea4` |
| com.squareup.okio:okio | 3.2.0 | okio-3.2.0.module | 20768 | `681f5cec170de45b95493e9ee705868eb35adf898ee06f96e22d197250c1b104` |
| com.squareup.okio:okio | 3.2.0 | okio-3.2.0.pom | 1645 | `8b46f58d9b9aeb1178361d58a6865f4dad665930c5ff7b55e0baa61ef3a972a1` |
| org.checkerframework:checker-qual | 3.33.0 | checker-qual-3.33.0.jar | 223979 | `e316255bbfcd9fe50d165314b85abb2b33cb2a66a93c491db648e498a82c2de1` |
| org.chromium.net:cronet-api | 143.7445.0 | cronet-api-143.7445.0.pom | 959 | `9e6dce46bce2a99710ffde3aef1a1eb4f5f61f189e88477a46aaf38900b76086` |
| org.chromium.net:cronet-api | 143.7445.0 | cronet-api-143.7445.0.aar | 84776 | `8397f5b3752e3387571a0ff33e19a0db4cc14da16f4337872dcf3aa66ad9372a` |
| org.chromium.net:cronet-common | 143.7445.0 | cronet-common-143.7445.0.pom | 1207 | `4dfeeb7ecb63fb8b61cdef6cec1fbe36706a63e7f615f63e8bdb0c976527d161` |
| org.chromium.net:cronet-common | 143.7445.0 | cronet-common-143.7445.0.aar | 82528 | `cc88d8f1eadda836b7eb95408a2ebbb0cb99454c2cd66c6da93b13f1cb4f4524` |
| org.chromium.net:cronet-fallback | 143.7445.0 | cronet-fallback-143.7445.0.pom | 1448 | `20ca023ff5a9109ad0e90c703e2100c51f94a0fe3611ee7a21bd826736cc0cce` |
| org.chromium.net:cronet-fallback | 143.7445.0 | cronet-fallback-143.7445.0.aar | 35856 | `ff0af1d9bd41d58f4c6f2a53ede07635ec3e42d1ea7ff8fa3cf34b236a727770` |
| org.chromium.net:cronet-shared | 143.7445.0 | cronet-shared-143.7445.0.pom | 1093 | `3febaf03babf2c91c2c29e811a66821ab110bf29cecd2846f9ed2f0dac438f9d` |
| org.chromium.net:cronet-shared | 143.7445.0 | cronet-shared-143.7445.0.aar | 99356 | `4c4e615be83ca05e9b4138322ca89c92452f2340278333f44ee6aab5bff13b3d` |
| org.chromium.net:httpengine-native-provider | 143.7445.0 | httpengine-native-provider-143.7445.0.pom | 1347 | `3870234ff592d521ad7e58c2f15fd83334b97d836986b285b1a5d4c809be7568` |
| org.chromium.net:httpengine-native-provider | 143.7445.0 | httpengine-native-provider-143.7445.0.aar | 31842 | `50d8e3f3c16b9a199b48f8df2aafa58ae115058a68a29696da888248c638ad6d` |
| org.jetbrains.kotlin:kotlin-stdlib-jdk8 | 1.6.20 | kotlin-stdlib-jdk8-1.6.20.pom | 1581 | `1846a9f8604b0be1c71a2128bdbd9d8902720279427f622d2b9a440ac9a3c309` |
| org.jetbrains.kotlinx:kotlinx-coroutines-bom | 1.6.0 | kotlinx-coroutines-bom-1.6.0.pom | 4290 | `da2327250eabf2adeb5ba4d015a437f34475102d15ba3d7448da71dfcfd196de` |
| org.jetbrains.kotlinx:kotlinx-coroutines-bom | 1.9.0 | kotlinx-coroutines-bom-1.9.0.pom | 4291 | `bea5511e9001f2c593ab5080df131b219ab5e2085cc5979ce583eacd4946fd78` |
| org.jetbrains.kotlinx:kotlinx-coroutines-core-jvm | 1.6.0 | kotlinx-coroutines-core-jvm-1.6.0.module | 3432 | `2cdc60217b955ce213fca1f14ee960b85dbd30f8a6966361237410d38a602ef1` |
| org.jetbrains.kotlinx:kotlinx-coroutines-core-jvm | 1.6.0 | kotlinx-coroutines-core-jvm-1.6.0.pom | 2214 | `d11fdf1c07d83682dc6f73a16a6fa010c2de5f45d7049cf2bf6ff09ceeda3001` |
| org.jetbrains.kotlinx:kotlinx-coroutines-core | 1.6.0 | kotlinx-coroutines-core-1.6.0.pom | 2056 | `225504eb87207013296dfd69e21acc60f56240546e6ea8d4252783bdcfb324d9` |
| org.jetbrains.kotlinx:kotlinx-coroutines-core | 1.6.0 | kotlinx-coroutines-core-1.6.0.module | 22890 | `512cfab68f00d7363461b5dd02637dd19048b364a89e1960f99784c705a27a7c` |
| org.jetbrains.kotlinx:kotlinx-coroutines-guava | 1.5.0 | kotlinx-coroutines-guava-1.5.0.module | 3318 | `6574c5bc97e45025f682e22f578beba1595de06117391c90ccf959c0cc61be3d` |
| org.jetbrains.kotlinx:kotlinx-coroutines-guava | 1.5.0 | kotlinx-coroutines-guava-1.5.0.pom | 2075 | `204e773709a2415a0b84d5e89b8ba623971d3d4daeb6ea290582b8f2ea0069ac` |
| org.jetbrains.kotlinx:kotlinx-coroutines-guava | 1.9.0 | kotlinx-coroutines-guava-1.9.0.jar | 18010 | `ca68323328a85a2df3c03429d5e7b124bc784f07fbace958399a5bba4118d7a0` |
| org.jetbrains.kotlinx:kotlinx-coroutines-guava | 1.9.0 | kotlinx-coroutines-guava-1.9.0.module | 3865 | `3e0791a5731d1dda9e08588432d06a65b9175228b2a00355fb082c71a2b0f107` |
| org.jetbrains.kotlinx:kotlinx-coroutines-guava | 1.9.0 | kotlinx-coroutines-guava-1.9.0.pom | 2395 | `3bb987bae11b2d61d3917ac1a7f732355e8b2d79a19581d35eb5085477176731` |
| org.sonatype.oss:oss-parent | 7 | oss-parent-7.pom | 4824 | `b51f8867c92b6a722499557fc3a1fdea77bdf9ef574722fe90ce436a29559454` |

## iOS Xcode SwiftPM 이 쓰는 것 (GitHub)

AdMob 플러그인의 `admob_spm/Package.swift` 가 `https://github.com/googleads/swift-package-manager-google-mobile-ads.git` **13.9.0** 과 `https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git` **3.1.0** 을 가리킵니다 — Xcode(SwiftPM)가 빌드할 때 GitHub·dl.google.com 에서 받는 구조입니다.
이번 시험 빌드는 이 맥에 이미 있던 SwiftPM 캐시(다른 프로젝트가 받아 둔 같은 두 패키지)를 복사해 `-clonedSourcePackagesDirPath` 로 쓰고 프록시를 막아서 새로 받지 않았습니다. 새 환경에서 처음 빌드하면 Xcode 가 이 두 패키지를 받습니다.

## 플러그인 주요 바이너리의 개별 sha256 (프로젝트 안 로컬 파일)

| 파일 | 크기 | sha256 |
|---|---|---|
| `addons/GodotGooglePlayBilling/bin/release/GodotGooglePlayBilling-release.aar` | 18307 | `b667b4ae3ecf91d7dea90bebd4ba5a7aef56cfc2cd7de4787aeb51a1927dcef7` |
| `addons/GodotGooglePlayBilling/bin/debug/GodotGooglePlayBilling-debug.aar` | 19665 | `f7f8f3f1c8099e58127332c8c27f353a7eea079e749682d2ebd83d1bd4bd6f3d` |
| `addons/admob/android/bin/ads/libs/poing-godot-admob-ads-debug.aar` | 134019 | `fac3128d6e64b59666b1bac3097952bbbde2f1b1573656cd51b9f64f745edd79` |
| `addons/admob/android/bin/ads/libs/poing-godot-admob-ads-release.aar` | 127494 | `aeca6a3c813da770390dc1d574765b17d8ba78fe0cf1cb61438dc08df1fe1c67` |
| `addons/admob/android/bin/ads/libs/poing-godot-admob-core-debug.aar` | 4776 | `f78a4075635d4d3f27d7de66d350fb77c16f21e60e24ceee702c80efe5b96e29` |
| `addons/admob/android/bin/ads/libs/poing-godot-admob-core-release.aar` | 4674 | `f89e3f1096047fabc83208e4e00a3f0aef847229bcb68cc01e791bd57468fda0` |
| `addons/admob/ios/bin/ads/libs/poing-godot-admob-ads.release.xcframework/ios-arm64_x86_64-simulator/poing-godot-admob-ads.simulator.release.a` | 2481896 | `8c6ad74adf0e1288fbb12158e39100849bdbdf5b258ab933179126b092e1bd91` |
| `addons/admob/ios/bin/ads/libs/poing-godot-admob-ads.release.xcframework/ios-arm64/libpoing-godot-admob-ads.arm64-ios.release.a` | 1357088 | `ed4a04ea7c27d7d8bba720a597edaacf2486bb68796eab006c11635b2d240213` |
| `addons/admob/ios/bin/ads/libs/poing-godot-admob-ads.debug.xcframework/ios-arm64_x86_64-simulator/poing-godot-admob-ads.simulator.release_debug.a` | 2906184 | `65957ed43e8eaaeedaa8b03fdff332ca2adf61090cc727ba1445a7c33a503e14` |
| `addons/admob/ios/bin/ads/libs/poing-godot-admob-ads.debug.xcframework/ios-arm64/libpoing-godot-admob-ads.arm64-ios.release_debug.a` | 1547168 | `8eb86aef26245d6440caa3e7d668d484c412125df7ea488fccefba10075d0b3c` |
| `third_party/godot-iap-ios/bin/ios/GodotIap.framework/GodotIap` | 2519176 | `8ecbd82101457d6fe268977b56bac05c749ce54ec0e7fd74dc59baa1bd0bc78f` |
| `third_party/godot-iap-ios/bin/ios/SwiftGodotRuntime.framework/SwiftGodotRuntime` | 1992432 | `335242be996a2d7055ab680fd2489963a5099c713c320708e0e8c9435cba950c` |
