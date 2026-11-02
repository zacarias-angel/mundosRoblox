"""Local-only bridge for exporting Studio source snapshots into this workspace.

Run from the project root. POST exports from Studio; no Roblox credentials used.
"""

import json
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKEN = "recovery-hitos-01-local-20261102"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/qa" or self.headers.get("X-Recovery-Token") != TOKEN:
            self.send_error(404)
            return
        content = (ROOT / "tools" / "playtest_recovery.server.luau").read_bytes()
        self.send_response(200)
        self.end_headers()
        self.wfile.write(content)

    def do_POST(self):
        if self.headers.get("X-Recovery-Token") != TOKEN:
            self.send_error(403)
            return
        name = self.path.removeprefix("/snapshot/")
        if not self.path.startswith("/snapshot/") or not re.fullmatch(r"[a-zA-Z0-9_-]+", name):
            self.send_error(400)
            return
        size = int(self.headers.get("Content-Length", "0"))
        if not 0 < size < 15_000_000:
            self.send_error(413)
            return
        payload = json.loads(self.rfile.read(size))
        destination = ROOT / "backups" / name
        destination.mkdir(parents=True, exist_ok=True)
        scripts = payload.pop("scripts")
        for index, item in enumerate(scripts, 1):
            safe_name = re.sub(r"[^a-zA-Z0-9_.-]", "_", item["path"])
            (destination / f"{index:02d}_{safe_name}.luau").write_text(item.pop("source"), encoding="utf-8")
        payload["scripts"] = scripts
        (destination / "manifest.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps({"saved": len(scripts), "directory": str(destination)}).encode())


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8766), Handler).serve_forever()
