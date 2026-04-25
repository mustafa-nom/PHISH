"""thin client for a roblox-studio mcp backend.

defaults to boshyxd's `robloxstudio-mcp` (npx-spawned, 43 tools incl
`execute_luau` and `capture_screenshot`). can be pointed at the official
rbx-studio-mcp via env vars for legacy use.

env switches:
- BUDDY_STUDIO_BACKEND=robloxstudio | rbx-studio  (default: robloxstudio)
- BUDDY_STUDIO_BIN=/explicit/path                  (override executable)
- BUDDY_STUDIO_ARGS="extra args space separated"   (override args)

each backend implements two operations exposed by this module:
- run_code(lua) -> printed output as text
- capture_screenshot() -> raw mcp result (caller flattens content)
"""

from __future__ import annotations

import json
import os
import shutil
import shlex
import subprocess
import threading
from dataclasses import dataclass, field
from typing import Any


# default backend command lines. each is a list of [executable, *args].
_BACKENDS = {
    "robloxstudio": ("npx", ["-y", "robloxstudio-mcp@latest"]),
    "rbx-studio": ("rbx-studio-mcp", ["--stdio"]),
}

# rbx-studio-mcp lives here on this machine; npx is on $PATH so we don't fall
# back for it. these paths are only consulted if the resolver fails on PATH.
_FALLBACK_BIN_PATHS = {
    "rbx-studio": [
        os.path.expanduser("~/.local/bin/rbx-studio-mcp"),
        "/usr/local/bin/rbx-studio-mcp",
    ],
    "robloxstudio": [],
}

# tool name mapping: each backend uses a different name for "run lua" /
# "screenshot". every other tool that we surface routes through these two.
_TOOL_RUN_CODE = {
    "robloxstudio": "execute_luau",
    "rbx-studio": "run_code",
}
_TOOL_RUN_CODE_ARG = {
    "robloxstudio": "code",
    "rbx-studio": "command",
}
_TOOL_SCREENSHOT = {
    "robloxstudio": "capture_screenshot",
    "rbx-studio": "capture_screenshot",
}


def _resolve_backend() -> str:
    backend = os.environ.get("BUDDY_STUDIO_BACKEND", "robloxstudio")
    if backend not in _BACKENDS:
        raise ValueError(
            f"unknown BUDDY_STUDIO_BACKEND={backend!r}; "
            f"valid: {sorted(_BACKENDS)}"
        )
    return backend


def _resolve_command(backend: str) -> tuple[str, list[str]]:
    explicit_bin = os.environ.get("BUDDY_STUDIO_BIN")
    explicit_args = os.environ.get("BUDDY_STUDIO_ARGS")
    default_bin, default_args = _BACKENDS[backend]
    binary = explicit_bin or default_bin
    args = (
        shlex.split(explicit_args)
        if explicit_args is not None
        else list(default_args)
    )
    if not os.path.isabs(binary):
        on_path = shutil.which(binary)
        if on_path:
            binary = on_path
        else:
            for candidate in _FALLBACK_BIN_PATHS.get(backend, []):
                if os.path.exists(candidate):
                    binary = candidate
                    break
            else:
                raise FileNotFoundError(
                    f"backend {backend!r} executable {binary!r} not found"
                )
    return binary, args


class StudioClientError(RuntimeError):
    pass


@dataclass
class StudioClient:
    """one client per MCP-server instance. starts lazily on first call."""

    backend: str | None = None
    proc: subprocess.Popen[bytes] | None = field(default=None, init=False, repr=False)
    _backend_resolved: str = field(default="", init=False, repr=False)
    _next_id: int = field(default=1, init=False)
    _lock: threading.Lock = field(default_factory=threading.Lock, init=False, repr=False)
    _stderr_thread: threading.Thread | None = field(default=None, init=False, repr=False)

    def start(self) -> None:
        if self.proc is not None:
            return
        backend = self.backend or _resolve_backend()
        self._backend_resolved = backend
        binary, args = _resolve_command(backend)
        self.proc = subprocess.Popen(
            [binary, *args],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        self._stderr_thread = threading.Thread(target=self._drain_stderr, daemon=True)
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
        # drain stderr so the subprocess never blocks on a full pipe
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
            raise StudioClientError("backend closed stdout unexpectedly")
        try:
            return json.loads(line.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise StudioClientError(f"non-json from backend: {line!r}") from exc

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
        """run lua in studio. returns the printed output as text."""
        self.start()
        backend = self._backend_resolved
        tool = _TOOL_RUN_CODE[backend]
        arg_key = _TOOL_RUN_CODE_ARG[backend]
        result = self.call_tool(tool, {arg_key: lua})
        return _flatten_text_content(result)

    def capture_screenshot(self) -> dict[str, Any]:
        """returns the raw mcp result so callers can pass image content along."""
        self.start()
        backend = self._backend_resolved
        return self.call_tool(_TOOL_SCREENSHOT[backend], {})


def _flatten_text_content(result: dict[str, Any]) -> str:
    """flatten mcp CallToolResult content[] into a single text blob."""
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
