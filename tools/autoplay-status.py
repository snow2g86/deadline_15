#!/usr/bin/env python3
"""개발용: 자동 플레이 연구 진행 상황 보기 — tools/autoplay-run.sh가 남긴 보고서 폴더(<포트>.json)를 요약
사용: python3 tools/autoplay-status.py <보고서 폴더> [--tail]"""
import json, os, sys

d = sys.argv[1]
for f in sorted(os.listdir(d)):
    if not f.endswith('.json'):
        continue
    r = json.load(open(os.path.join(d, f), encoding='utf-8'))
    s = r.get('summary', {})
    state = '끝' if r.get('final') else ('진행' if r.get('running') else '대기')
    print(f"[{f[:-5]}] {r.get('profile')} {r.get('combo')} · {state} · 최고 S{s.get('best')} · 전투 {s.get('battles')} (파밍 {s.get('grinds')}, 요일 {s.get('dailies')}) · 보유 {s.get('gold')}G · 첫 전멸 {s.get('firstWipe')}")
    mins = s.get('minBy10') or {}
    if mins:
        print('   예상 시간(분, 구간 평균/최대): ' + '  '.join(f"Ep{k} {v['avg']}/{v['max']}" for k, v in sorted(mins.items(), key=lambda x: int(x[0]))))
    if s.get('over10'):
        print('   10분 초과: ' + ' '.join(s['over10'][-12:]))
    turns = s.get('avgTurnBy10') or {}
    if turns:
        print('   평균 턴: ' + '  '.join(f"Ep{k} {v}" for k, v in sorted(turns.items(), key=lambda x: int(x[0]))))
    if s.get('chests'):
        print('   보물상자: ' + ' '.join(f"{k} {v}" for k, v in s['chests'].items()))
    if s.get('hazards'):
        print('   디버프 맵(판/승/사망): ' + '  '.join(f"{k} {v['n']}/{v['win']}/{v['dead']}" for k, v in s['hazards'].items()))
    if '--tail' in sys.argv:
        print('   ' + '\n   '.join((r.get('tail') or [])[-4:]))
