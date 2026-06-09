#!/usr/bin/env python3
"""Relay itsm-app incident.created and request.submitted webhooks to chat-app."""

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

        event = payload.get("event")
        if event == "incident.created":
            incident = payload.get("incident") or {}
            public_id = incident.get("public_id") or "?"
            title = incident.get("title") or "Untitled"
            severity = incident.get("severity") or "medium"
            message = f"[incident.created] {public_id} — {title} ({severity})"
        elif event == "request.submitted":
            request = payload.get("request") or {}
            public_id = request.get("public_id") or "?"
            title = request.get("name") or request.get("title") or "Service request"
            message = f"[request.submitted] {public_id} — {title}"
        else:
            self._json_response(200, {"ok": True, "skipped": True})
            return

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
