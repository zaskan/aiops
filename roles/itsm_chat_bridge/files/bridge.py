#!/usr/bin/env python3
"""Relay itsm-app incident.created webhooks to chat-app inbound webhook format."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

CHAT_WEBHOOK_URL = os.environ["CHAT_WEBHOOK_URL"]
PORT = int(os.environ.get("PORT", "8080"))


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        if self.path.rstrip("/") != "/hook":
            self.send_error(404)
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            self.send_error(400)
            return

        if payload.get("event") != "incident.created":
            self._json_response(200, {"ok": True, "skipped": True})
            return

        incident = payload.get("incident") or {}
        public_id = incident.get("public_id") or "?"
        title = incident.get("title") or "Untitled"
        severity = incident.get("severity") or "medium"
        message = f"[incident.created] {public_id} — {title} ({severity})"

        request = urllib.request.Request(
            CHAT_WEBHOOK_URL,
            data=json.dumps({"body": message}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                response.read()
        except urllib.error.HTTPError as exc:
            self.send_error(502, explain=f"chat webhook returned {exc.code}")
            return
        except urllib.error.URLError:
            self.send_error(502, explain="chat webhook unreachable")
            return

        self._json_response(200, {"ok": True})

    def _json_response(self, status: int, body: dict) -> None:
        encoded = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format: str, *args) -> None:
        return


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
