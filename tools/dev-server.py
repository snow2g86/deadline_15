#!/usr/bin/env python3
"""개발용 정적 서버 — 캐시 금지 (브라우저가 예전 스크립트와 새 스크립트를 섞어 읽어 로딩이 멈추는 일 방지)
사용: python3 tools/dev-server.py [포트=8799]   (저장소 루트에서 실행)"""
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class NoCache(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *a):
        pass


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8799
ThreadingHTTPServer(('127.0.0.1', port), NoCache).serve_forever()
