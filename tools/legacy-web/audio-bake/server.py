import http.server, sys, os, urllib.parse, threading
ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = sys.argv[1]
OUT = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.join(ROOT, 'out')
os.makedirs(OUT, exist_ok=True)
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        p = urllib.parse.urlparse(self.path).path
        if p == '/audio.js': f = os.path.join(REPO, 'js/battle/audio.js')
        elif p == '/bake.html': f = os.path.join(ROOT, 'bake.html')
        else:
            self.send_response(404); self.end_headers(); return
        b = open(f, 'rb').read()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html' if f.endswith('.html') else 'application/javascript')
        self.send_header('Content-Length', str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_POST(self):
        u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query)
        n = int(self.headers.get('Content-Length', 0)); b = self.rfile.read(n)
        if u.path == '/save':
            open(os.path.join(OUT, q['name'][0]), 'wb').write(b)
        elif u.path == '/log':
            print(b.decode(), flush=True)
        self.send_response(200); self.end_headers()
        if u.path == '/done':
            print('DONE', flush=True)
            threading.Thread(target=self.server.shutdown).start()
http.server.ThreadingHTTPServer(('127.0.0.1', 8931), H).serve_forever()
