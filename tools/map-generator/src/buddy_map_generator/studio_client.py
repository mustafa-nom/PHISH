"""thin client for rbx-studio-mcp.

spawns the binary as a subprocess in --stdio mode, performs the JSON-RPC
handshake, and exposes a small surface (run_code, capture_screenshot,
get_studio_state, read_output) that the MCP tools layer can call.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import threading
from dataclasses import dataclass, field
from typing import Any


DEFAULT_BINARY_NAME = "rbx-studio-mcp"
DEFAULT_BINARY_PATHS = [
    os.path.expanduser("~/.local/bin/rbx-studio-mcp"),
    "/usr/local/bin/rbx-studio-mcp",
]


def _resolve_binary(explicit: str | None) -> str:
    if explicit:
        return explicit
    env = os.environ.get("RBX_STUDIO_MCP_BIN")
    if env:
        return env
    on_path = shutil.which(DEFAULT_BINARY_NAME)
    if on_path:
        return on_path
    for candidate in DEFAULT_BINARY_PATHS:
        if os.path.exists(candidate):
            return candidate
    raise FileNotFoundError(
        "rbx-studio-mcp binary not found. set RBX_STUDIO_MCP_BIN or install it."
    )


class StudioClientError(RuntimeError):
    pass


@dataclass
class StudioClient:
    """one client per MCP-server instance. starts lazily on first call."""

    binary: str | None = None
    proc: subprocess.Popen[bytes] | None = field(default=None, init=False, repr=False)
    _next_id: int = field(default=1, init=False)
    _lock: threading.Lock = field(default_factory=threading.Lock, init=False, repr=False)
    _stderr_thread: threading.Thread | None = field(default=None, init=False, repr=False)

    def start(self) -> None:
        if self.proc is not None:
            return
        binary = _resolve_binary(self.binary)
        self.proc = subprocess.Popen(
            [binary, "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        # drain stderr so the subprocess never blocks on a full pipe.
        # we don't surface stderr lines unless something goes wrong upstream.
        self._stderr_thread = threading.Thread(
            target=self._drain_stderr, daemon=True
        )
        self._stderr_thread.start()
        self._handshake()

    def stop(self) -> None:
        if self.proc is None:
            return
        try:
            self.proc.terminate()
            self.proc.wait(timeout=5)
        except Exception:
            try:
                self.proc.kill()
            except Exception:
                pass
        self.proc = None

    def _drain_stderr(self) -> None:
        assert self.proc is not None and self.proc.stderr is not None
        try:
            for _ in iter(self.proc.stderr.readline, b""):
                pass
        except Exception:
            pass

    def _send(self, payload: dict[str, Any]) -> None:
        assert self.proc is not None and self.proc.stdin is not None
        line = (json.dumps(payload) + "\n").encode("utf-8")
        self.proc.stdin.write(line)
        self.proc.stdin.flush()

    def _recv(self) -> dict[str, Any]:
        assert self.proc is not None and self.proc.stdout is not None
        line = self.proc.stdout.readline()
        if not line:
            raise StudioClientError("rbx-studio-mcp closed stdout unexpectedly")
        try:
            return json.loads(line.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise StudioClientError(f"non-json from rbx-studio-mcp: {line!r}") from exc

    def _handshake(self) -> None:
        self._send(
            {
                "jsonrpc": "2.0",
                "id": self._next_id,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "buddy-map-generator", "version": "0.1.0"},
                },
            }
        )
        self._next_id += 1
        _ = self._recv()  # initialize response — discard
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call_tool(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            self.start()
            request_id = self._next_id
            self._next_id += 1
            self._send(
                {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "method": "tools/call",
                    "params": {"name": name, "arguments": arguments},
                }
            )
            # rbx-studio-mcp is currently single-threaded over stdio — the very
            # next message will be our response. if the server later starts
            # interleaving notifications, this loop drops them.
            while True:
                msg = self._recv()
                if msg.get("id") == request_id:
                    if "error" in msg:
                        err = msg["error"]
                        raise StudioClientError(
                            f"{name} failed: {err.get('message')} ({err.get('code')})"
                        )
                    return msg.get("result", {})

    # convenience wrappers ----------------------------------------------------

    def run_code(self, lua: str) -> str:
        """run lua in the studio plugin context. returns the printed output."""
        result = self.call_tool("run_code", {"command": lua})
        return _flatten_text_content(result)

    def capture_screenshot(self) -> dict[str, Any]:
        """returns the raw mcp result so callers can pass image content along."""
        return self.call_tool("capture_screenshot", {})

    def get_studio_state(self) -> str:
        result = self.call_tool("get_studio_state", {})
        return _flatten_text_content(result)

    def read_output(self, *, max_lines: int = 200, level: str = "all") -> str:
        result = self.call_tool(
            "read_output",
            {"max_lines": max_lines, "filter": level, "clear_after_read": True},
        )
        return _flatten_text_content(result)


def _flatten_text_content(result: dict[str, Any]) -> str:
    """rbx-studio-mcp returns CallToolResult-shaped objects with content[]."""
    content = result.get("content")
    if not isinstance(content, list):
        return json.dumps(result)
    chunks: list[str] = []
    for item in content:
        if not isinstance(item, dict):
            continue
        if item.get("type") == "text":
            chunks.append(str(item.get("text", "")))
    return "\n".join(chunks)
