"""Receives one JSON POST from Studio (execute_luau, HttpService:PostAsync to
http://localhost:<port>/) and writes its body to a file, then exits:

    python assets/models/tools/receive.py <out .json> [port, default 34880]

So asset IDs read in "FTGG Art" (mesh IDs from InsertService:LoadAsset, image
IDs from Decals) reach the repo without copying them by hand.
"""

import http.server
import sys

OUT = sys.argv[1]
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 34880


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        with open(OUT, "wb") as f:
            f.write(body)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")
        print(f"received {len(body)} bytes -> {OUT}", flush=True)
        raise SystemExit(0)

    def log_message(self, *args):
        pass


http.server.HTTPServer(("127.0.0.1", PORT), Handler).handle_request()
