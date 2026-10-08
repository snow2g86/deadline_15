#!/usr/bin/env python3
"""개발용: 자동 플레이 연구 서버 (tools/autoplay.html 전용)

사용: python3 tools/autoplay-server.py <포트> <게임 폴더> <보고서 폴더>
- 게임 폴더를 정적으로 제공 (동시 요청이 많아도 끊기지 않게 멀티스레드 + 큰 대기열)
- POST /ap_report → 보고서 폴더/<포트>.json 에 저장 (연구 페이지가 전투가 끝날 때마다 요약을 보냄)
포트마다 서버를 따로 띄우면 localStorage(저장)가 포트별로 분리돼 여러 조합을 동시에 연구할 수 있다.
"""
import json, os, sys, threading
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler


class Server(ThreadingHTTPServer):
    request_queue_size = 256
    daemon_threads = True


def make_handler(report_dir):
    class Handler(SimpleHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def do_POST(self):
            if self.path != '/ap_report':
                self.send_error(404)
                return
            n = int(self.headers.get('Content-Length') or 0)
            body = self.rfile.read(n)
            try:
                data = json.loads(body)
                port = str(data.get('port') or 'unknown')
                # 보고가 동시에 들어와도 파일이 섞이지 않게: 임시 파일에 쓴 뒤 한 번에 교체
                dst = os.path.join(report_dir, port + '.json')
                tmp = dst + '.%d.tmp' % threading.get_ident()
                with open(tmp, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=1)
                os.replace(tmp, dst)
            except Exception as e:  # 보고 실패는 연구 진행에 영향 없음
                sys.stderr.write('report error: %s\n' % e)
            self.send_response(204)
            self.end_headers()
    return Handler


if __name__ == '__main__':
    port, root, reports = int(sys.argv[1]), sys.argv[2], sys.argv[3]
    os.makedirs(reports, exist_ok=True)
    os.chdir(root)
    Server(('127.0.0.1', port), make_handler(os.path.abspath(reports))).serve_forever()
