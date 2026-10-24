#!/usr/bin/env python3
"""Self-hosted server for the training app — serves the app and holds log.json.

Meant to run on a box on the tailnet, bound to localhost, with `tailscale serve`
in front for HTTPS (the service worker and Home Screen install both need it).
The tailnet is the auth: there are no tokens.

    python3 server.py --data ~/workout-data/log.json

API, same shape the GitHub sync used:
    GET  /api/log  -> {"entries": [...], "sha": "<hash>" | null}
    PUT  /api/log  <- {"sha": "<hash the client merged against>", "entries": [...]}
                   -> 200 {"sha": "<new hash>"}, or 409 if the file moved underneath

Standard library only.
"""
import argparse
import datetime
import hashlib
import json
import os
import tempfile
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))

# Only the app itself — never .git or anything else in the checkout.
STATIC = {"/index.html", "/sw.js", "/manifest.json", "/icon-180.png", "/icon-192.png", "/icon-512.png"}
MAX_BODY = 50 * 1024 * 1024

LOCK = threading.Lock()


def file_sha(raw):
    return hashlib.sha256(raw).hexdigest()[:16]


def read_log(path):
    """(raw bytes, sha) — (None, None) when there's no log yet."""
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except FileNotFoundError:
        return None, None
    return raw, file_sha(raw)


def write_log(path, raw):
    d = os.path.dirname(path)
    os.makedirs(d, exist_ok=True)

    # One snapshot of the previous version per day, so a bad write is never the only copy.
    if os.path.exists(path):
        bdir = os.path.join(d, "backups")
        os.makedirs(bdir, exist_ok=True)
        snap = os.path.join(bdir, "log-%s.json" % datetime.date.today().isoformat())
        if not os.path.exists(snap):
            with open(path, "rb") as src, open(snap, "wb") as dst:
                dst.write(src.read())

    # Atomic: a crash mid-write leaves the old file, never half of the new one.
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".log-", suffix=".json")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(raw)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


class Handler(SimpleHTTPRequestHandler):
    data_path = None

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def send_json(self, status, obj):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def route(self):
        return self.path.split("?", 1)[0]

    def do_GET(self):
        p = self.route()
        if p == "/api/log":
            with LOCK:
                raw, sha = read_log(self.data_path)
            if raw is None:
                return self.send_json(200, {"entries": [], "sha": None})
            try:
                data = json.loads(raw)
            except ValueError:
                return self.send_json(500, {"message": "log.json on the server isn't valid JSON"})
            entries = data if isinstance(data, list) else data.get("entries", [])
            return self.send_json(200, {"entries": entries, "sha": sha})
        if p == "/":
            self.path = "/index.html"
        elif p not in STATIC:
            return self.send_error(404)
        return super().do_GET()

    def do_HEAD(self):
        if self.route() not in STATIC | {"/"}:
            return self.send_error(404)
        return super().do_HEAD()

    def do_PUT(self):
        if self.route() != "/api/log":
            return self.send_error(404)
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0 or n > MAX_BODY:
            return self.send_json(413 if n else 400, {"message": "bad body size"})
        try:
            body = json.loads(self.rfile.read(n))
            entries = body["entries"]
            assert isinstance(entries, list)
        except Exception:
            return self.send_json(400, {"message": "expected {sha, entries: [...]}"})

        raw = json.dumps({
            "schema": 1,
            "updated": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
            "entries": entries,
        }, indent=2).encode()
        with LOCK:
            _, cur = read_log(self.data_path)
            if body.get("sha") != cur:
                return self.send_json(409, {"message": "log.json changed; refetch and merge"})
            write_log(self.data_path, raw)
        return self.send_json(200, {"sha": file_sha(raw)})

    def end_headers(self):
        # Code is network-first in the service worker; keep the HTTP cache out of the way too.
        p = self.route()
        if not p.startswith("/icon-") and not p.startswith("/api/"):
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--host", default="127.0.0.1", help="bind address (default 127.0.0.1; tailscale serve proxies to it)")
    ap.add_argument("--port", type=int, default=8777)
    ap.add_argument("--data", default=os.environ.get("WT_DATA", "~/workout-data/log.json"), help="path to log.json")
    args = ap.parse_args()

    Handler.data_path = os.path.abspath(os.path.expanduser(args.data))
    print("serving %s on http://%s:%d — log at %s" % (ROOT, args.host, args.port, Handler.data_path), flush=True)
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
