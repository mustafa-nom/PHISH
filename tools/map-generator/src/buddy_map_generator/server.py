"""buddy-map-generator MCP server.

exposes high-level tools that emit Lua and forward it to rbx-studio-mcp.
the studio plugin must be running for the tools that touch Studio; the
"dry_run" variants return the emitted Lua as text without contacting Studio,
which is useful for testing offline.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from typing import Any

from mcp.server.fastmcp import FastMCP

from .studio_client import StudioClient
from .tools.backpack_checkpoint import emit_backpack_checkpoint_lua
from .tools.booth_template import emit_booth_template_lua
from .tools.item_templates import emit_item_templates_lua
from .tools.lobby import emit_lobby_lua
from .tools.npc_templates import emit_npc_templates_lua
from .tools.play_arena_slots import emit_play_arena_slots_lua
from .tools.polish_pass import emit_polish_pass_lua
from .tools.stranger_danger_park import emit_stranger_danger_park_lua
from .tools.verify import emit_verify_style_lua


# environment switches:
# - BUDDY_MAP_DRY_RUN=1 → tools return Lua instead of contacting Studio.
# - RBX_STUDIO_MCP_BIN=/path → override binary location.
def _dry_run() -> bool:
    return os.environ.get("BUDDY_MAP_DRY_RUN", "").lower() in {"1", "true", "yes"}


@dataclass
class ServerState:
    client: StudioClient = field(default_factory=StudioClient)


_state = ServerState()


def _run_or_return(lua: str, *, label: str) -> dict[str, Any]:
    """either ship lua to studio and surface results, or echo it for dry runs."""
    if _dry_run():
        return {
            "mode": "dry_run",
            "label": label,
            "lua_chars": len(lua),
            "lua": lua,
        }
    output = _state.client.run_code(lua)
    parsed: Any
    try:
        parsed = json.loads(output)
    except (json.JSONDecodeError, ValueError):
        parsed = {"raw": output}
    return {
        "mode": "studio",
        "label": label,
        "result": parsed,
    }


mcp = FastMCP(
    "buddy-map-generator",
    instructions=(
        "build a preliminary buddy bridge studio map. invoke build_preliminary_map "
        "to scaffold everything in order, or call individual builders. set "
        "BUDDY_MAP_DRY_RUN=1 to inspect the emitted lua without touching studio."
    ),
)


@mcp.tool()
def build_lobby(pair_count: int = 4) -> dict[str, Any]:
    """build the shared lobby hub: spawn, welcome sign, treehouse, capsule pads.

    pair_count must be 1..8. default 4 matches the spec.
    """
    lua = emit_lobby_lua(pair_count=pair_count)
    return _run_or_return(lua, label="build_lobby")


@mcp.tool()
def build_play_arena_slots(slot_count: int = 4) -> dict[str, Any]:
    """build N play arena slots in a hidden region of Workspace.

    slot_count must be 1..8. default 4.
    """
    lua = emit_play_arena_slots_lua(slot_count=slot_count)
    return _run_or_return(lua, label="build_play_arena_slots")


@mcp.tool()
def build_stranger_danger_park() -> dict[str, Any]:
    """build the StrangerDangerPark level template under ServerStorage/Levels."""
    lua = emit_stranger_danger_park_lua()
    return _run_or_return(lua, label="build_stranger_danger_park")


@mcp.tool()
def build_backpack_checkpoint() -> dict[str, Any]:
    """build the BackpackCheckpoint level template under ServerStorage/Levels."""
    lua = emit_backpack_checkpoint_lua()
    return _run_or_return(lua, label="build_backpack_checkpoint")


@mcp.tool()
def build_npc_templates() -> dict[str, Any]:
    """build the 7 NPC rig templates under ServerStorage/NpcTemplates."""
    lua = emit_npc_templates_lua()
    return _run_or_return(lua, label="build_npc_templates")


@mcp.tool()
def build_item_templates() -> dict[str, Any]:
    """build the 13 item templates under ServerStorage/ItemTemplates."""
    lua = emit_item_templates_lua()
    return _run_or_return(lua, label="build_item_templates")


@mcp.tool()
def build_booth_template() -> dict[str, Any]:
    """build the DefaultBooth template under ServerStorage/GuideBooths."""
    lua = emit_booth_template_lua()
    return _run_or_return(lua, label="build_booth_template")


@mcp.tool()
def build_polish_pass() -> dict[str, Any]:
    """apply lighting/atmosphere defaults and create SFX placeholders."""
    lua = emit_polish_pass_lua()
    return _run_or_return(lua, label="build_polish_pass")


@mcp.tool()
def verify_style() -> dict[str, Any]:
    """walk the map and report material / font / required-tag violations."""
    lua = emit_verify_style_lua()
    return _run_or_return(lua, label="verify_style")


@mcp.tool()
def screenshot() -> dict[str, Any]:
    """capture a screenshot of the studio window. dry_run echoes a stub."""
    if _dry_run():
        return {"mode": "dry_run", "label": "screenshot", "note": "would call capture_screenshot"}
    return {"mode": "studio", "label": "screenshot", "result": _state.client.capture_screenshot()}


@mcp.tool()
def build_preliminary_map(
    pair_count: int = 4,
    slot_count: int = 4,
    capture_screenshots: bool = True,
) -> dict[str, Any]:
    """run every build_* step in order. screenshots after each one if enabled.

    intended as a one-shot kickoff: opens with lobby, then arenas, then the
    two level templates, npcs, items, booth, polish, and finally style verify.
    """
    steps: list[tuple[str, Any]] = []

    def _step(label: str, runner) -> None:
        result = runner()
        steps.append((label, result))
        if capture_screenshots and not _dry_run():
            try:
                shot = _state.client.capture_screenshot()
                steps.append((f"{label}.screenshot", shot))
            except Exception as exc:
                steps.append((f"{label}.screenshot.error", {"error": str(exc)}))

    _step("build_lobby", lambda: build_lobby(pair_count=pair_count))
    _step("build_play_arena_slots", lambda: build_play_arena_slots(slot_count=slot_count))
    _step("build_booth_template", build_booth_template)
    _step("build_stranger_danger_park", build_stranger_danger_park)
    _step("build_backpack_checkpoint", build_backpack_checkpoint)
    _step("build_npc_templates", build_npc_templates)
    _step("build_item_templates", build_item_templates)
    _step("build_polish_pass", build_polish_pass)
    _step("verify_style", verify_style)

    return {"steps": steps, "mode": "dry_run" if _dry_run() else "studio"}


def main() -> None:
    """entrypoint used by the project script."""
    mcp.run()


if __name__ == "__main__":
    main()
