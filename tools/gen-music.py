#!/usr/bin/env python3
"""개발용: 로컬 ACE-Step 1.5 서버(soundtube/start_acestep.sh, 127.0.0.1:8001)로 게임 음원 생성

사용: python3 tools/gen-music.py [트랙id ...] [--seeds 2]
  - 트랙 정의는 아래 TRACKS. 결과: tools/_work/music/<id>_<n>.flac (원본) + .mp3 (게임용)
  - loop=True 트랙은 끝 LOOP_XF초를 처음과 겹쳐(크로스페이드) 이음새 없이 반복되게 만든다
  - 호출 방식은 ~/Desktop/workspace/soundtube/soundtube.py 의 AceStep 클래스와 같음 (release_task → query_result → 파일)
"""
import json, os, subprocess, sys, time
import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'tools', '_work', 'music'); os.makedirs(OUT, exist_ok=True)
URL = os.environ.get('ACESTEP_URL', 'http://127.0.0.1:8001')
LOOP_XF = 3.0  # 반복 이음새 크로스페이드(초)

COMMON = 'instrumental video game soundtrack, no vocals, clean mix, consistent volume'
NEG = 'vocals, singing, speech, lyrics, crowd noise, lo-fi hiss, distortion, abrupt ending'
TRACKS = {
    # 로비·메인: 클랜 거점의 따뜻하고 결의에 찬 분위기
    'lobby': dict(dur=96, bpm=88, loop=True, prompt=f'{COMMON}, medieval fantasy guild hall theme, warm acoustic guitar and lute, soft strings, '
                  'light hand percussion, flute melody, hopeful and determined, calm before an adventure, 16-bit JRPG town theme feel'),
    # 일반 전투: 전술 RPG 전투 — 긴장감 있지만 오래 들어도 피곤하지 않게
    'battle': dict(dur=110, bpm=128, loop=True, prompt=f'{COMMON}, tactical RPG battle theme, orchestral strings ostinato, snare and timpani, '
                   'heroic brass hits, driving but not chaotic, minor key, tense and focused, Final Fantasy Tactics style'),
    # 보스 전투: 더 어둡고 웅장하게
    'boss': dict(dur=110, bpm=150, loop=True, prompt=f'{COMMON}, epic dark boss battle theme, pounding taiko and timpani, low brass, '
                 'aggressive string runs, pipe organ, choir pads without words, menacing and climactic, final boss of a fantasy tactics game'),
    # 승리·패배 징글 (반복 없음)
    'victory': dict(dur=10, bpm=120, loop=False, prompt=f'{COMMON}, short triumphant victory fanfare jingle, bright brass and timpani, '
                    'rising major-key melody, ends with a strong final chord'),
    'defeat': dict(dur=10, bpm=70, loop=False, prompt=f'{COMMON}, short sad defeat jingle, slow descending strings and solo piano, '
                   'minor key, somber, ends softly on a sustained chord'),
}

s = requests.Session()

def data(r):
    r.raise_for_status(); body = r.json()
    if body.get('code') != 200: raise RuntimeError(body.get('error') or body)
    return body['data']

def wait_up(t=600):
    end = time.time() + t
    while time.time() < end:
        try:
            s.get(f'{URL}/health', timeout=5).raise_for_status(); return True
        except requests.RequestException: time.sleep(5)
    return False

def generate(tr, seed):
    req = {'prompt': tr['prompt'], 'lyrics': '[Instrumental]', 'audio_duration': tr['dur'], 'bpm': tr['bpm'],
           'thinking': True, 'batch_size': 1, 'audio_format': 'flac', 'lm_negative_prompt': NEG, 'seed': seed, 'use_random_seed': False}
    tid = data(s.post(f'{URL}/release_task', json=req, timeout=60))['task_id']
    t0 = time.time()
    while True:
        time.sleep(3)
        item = data(s.post(f'{URL}/query_result', json={'task_id_list': [tid]}, timeout=60))[0]
        if item['status'] == 2: raise RuntimeError(str(item.get('result'))[:300])
        if item['status'] == 1:
            res = item['result']; res = json.loads(res) if isinstance(res, str) else res
            f = res[0]['file']; a = s.get(f'{URL}{f}' if f.startswith('/') else f, timeout=300); a.raise_for_status()
            return a.content, time.time() - t0
        if time.time() - t0 > 1800: raise RuntimeError('30분 초과')

def to_game(flac, ogg, loop):
    dur = float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', flac]).decode())
    if loop:
        # [X..끝] 뒤에 [0..X]를 X초 겹쳐 이어 붙임 → 길이 끝-X, 끝 부분이 처음으로 자연스럽게 넘어감
        x = LOOP_XF
        fl = f'[0:a]atrim={x}:{dur},asetpts=PTS-STARTPTS[a];[0:a]atrim=0:{x},asetpts=PTS-STARTPTS[b];[a][b]acrossfade=d={x}:c1=tri:c2=tri,loudnorm=I=-16:TP=-1.5[o]'
    else:
        fl = '[0:a]afade=t=out:st=%.2f:d=0.6,loudnorm=I=-16:TP=-1.5[o]' % max(0, dur - 0.6)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', flac, '-filter_complex', fl, '-map', '[o]', '-ar', '44100', '-c:a', 'libmp3lame', '-q:a', '3', ogg], check=True)

if __name__ == '__main__':
    ids = [a for a in sys.argv[1:] if not a.startswith('--') and not a.isdigit()] or list(TRACKS)
    seeds = int(sys.argv[sys.argv.index('--seeds') + 1]) if '--seeds' in sys.argv else 2
    if not wait_up(): sys.exit('ACE-Step 서버가 응답하지 않습니다 (soundtube/start_acestep.sh)')
    for tid in ids:
        tr = TRACKS[tid]
        for n in range(1, seeds + 1):
            flac = os.path.join(OUT, f'{tid}_{n}.flac'); ogg = flac[:-5] + '.mp3'
            if os.path.exists(ogg): print('skip', tid, n, flush=True); continue
            audio, sec = generate(tr, seed=1000 * n + len(tid))
            open(flac, 'wb').write(audio); to_game(flac, ogg, tr['loop'])
            print(f'{tid}_{n} ok {sec:.0f}s', flush=True)
    print('ALL_DONE', flush=True)
