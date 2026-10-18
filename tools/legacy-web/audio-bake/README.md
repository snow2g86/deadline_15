# audio-bake — 웹판 합성 소리를 Godot 용 파일로 굽기 (5단계, 2026-10-18)

웹판 소리(`js/battle/audio.js`)는 WebAudio 로 그때그때 합성합니다. Godot 판은 이 코드를 **Chrome 의 WebAudio(OfflineAudioContext) 그대로**
돌려 미리 구운 파일(`godot/assets/audio/*.wav`)을 씁니다. 웹 코드는 한 글자도 바꾸지 않고 불러 씁니다 (`/audio.js` = 저장소의 `js/battle/audio.js`).

## 왜 미리 굽는가 (AudioStreamGenerator 실시간 합성 대신)

- **웹과 똑같은 소리**: 배경음은 Chrome `DynamicsCompressor`(문턱 −20dB · 비율 10 · knee 4 · 자동 메이크업 이득 · 미리보기 6ms)와
  `BiquadFilter` 를 거칩니다. 같은 엔진으로 구우면 압축기·필터·지수 감쇠가 웹과 같고, GDScript 로 다시 짜면 근사가 됩니다.
- **비용**: 배경음 한 주기에 발음 약 1만 개 · 잡음 버퍼 수천 개. GDScript 로 매 샘플 합성하면 PC 에서도 CPU 를 많이 쓰고 모바일(6단계)은 더 어렵습니다.
- 대신 잃는 것: 웹은 잡음(`Math.random`)이 칠 때마다 다르지만 구운 파일은 한 가지 — 귀로는 차이가 없습니다 (아래 비교).

## 굽기

```bash
python3 tools/legacy-web/audio-bake/server.py "$(pwd)" /tmp/bake-out &      # 127.0.0.1:8931 (저장소 맨 위에서)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --autoplay-policy=no-user-gesture-required \
  --user-data-dir=/tmp/bake-chrome "http://127.0.0.1:8931/bake.html?mode=bake"    # 서버 로그에 DONE 이 찍히면 Chrome 을 끔
```

- 효과음 23개: `sfx_<이름>.wav` — 웹 `sfxSelect … sfxKill`, 직업별 공격 12개. **웹 기본 효과음 음량(sfxVol 0.7)으로** 구움
  (웹에서 효과음 음량 노드를 거치지 않고 바로 나가는 소리 — 마법사·궁수 공격의 휘는 음, 쓰러짐 — 도 기본값에서 웹과 같게). Godot SFX 버스 = sfxVol / 0.7.
- 배경음: `bgm_battle.wav` — 130 BPM 8분음표 512개(118.1538초)가 한 주기. 두 주기를 이어 구운 뒤 **둘째 주기**만 잘라 씀
  (앞 주기의 꼬리·압축기 상태가 들어 있어 끝 → 처음이 이어짐, 이음매 점프 0). bgmVol 1(웹 master 0.16 포함)로 구움 → Godot BGM 버스 = bgmVol.
  44.1kHz 16비트 모노, TPDF 디더. 굽는 데 약 3분 (M3 Max).
- 가져오기: 배경음 `edit/loop_mode=2`(앞으로 반복) · `compress/mode=2`(QOA, 10MB → 2.1MB), 효과음 `compress/mode=0`(PCM 그대로).
- 웹의 `sfxTurnPlayer` · `sfxTurnEnemy` 는 웹 어디에서도 부르지 않아 굽지 않았습니다.

## 웹과 같은지 확인 (2026-10-18)

`?mode=capture` 는 웹 코드를 **실시간 AudioContext 에서 웹 자신의 타이머로** 돌리며 출력을 녹음합니다 (기본 음량 bgmVol 0.5 · sfxVol 0.7).
`capture_godot.gd` 는 Godot 에서 같은 소리를 Sound 오토로드로 내며 Master 버스를 녹음합니다:

```bash
HOME=<임시> /Applications/Godot.app/Contents/MacOS/Godot --path godot --script "$(pwd)/tools/legacy-web/audio-bake/capture_godot.gd" -- /tmp/cap
```

두 녹음을 첫 소리에 맞춰 20ms 포락선 상관·전체 음량·1/3 옥타브 대역 에너지로 비교한 결과:

| 소리 | 포락선 상관 | 음량 차 | 대역 차 (평균 / 최대) |
|---|---|---|---|
| 전투 배경음 첫 11.5초 | 0.967 | −0.19 dB | 0.54 / 1.53 dB |
| 마법사 공격 | 1.000 | 0.00 dB | 0.07 / 0.73 dB |
| 기사 공격 (잡음 많음) | 0.999 | −0.30 dB | 0.98 / 3.31 dB |
| 승리 | 1.000 | 0.00 dB | 0.00 / 0.01 dB |
| 회복 | 1.000 | 0.00 dB | 0.00 / 0.01 dB |
| 처치 (잡음) | 1.000 | +0.06 dB | 1.32 / 4.02 dB |

음(사인·톱니·세모파)만으로 된 소리는 사실상 같고, 차이는 잡음 소리의 무작위성(웹도 칠 때마다 다름)과 배경음 QOA 압축 정도입니다.
