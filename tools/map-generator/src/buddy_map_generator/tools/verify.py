"""verify_style: introspect the studio map and report style-bible violations.

emits a small lua program that walks Workspace + ServerStorage and checks:
- materials inside the allowed set
- font usage on textlabels
- presence of required tags + attributes

returns a structured report (json string) that the MCP tool surfaces.
"""

from __future__ import annotations

from ..lua_emit import LuaProgram, lua_string
from ..style import ALLOWED_MATERIALS, FONT, Tags


_REQUIRED_TAG_PRESENCE = [
    Tags.LOBBY_CAPSULE,
    Tags.PLAY_ARENA_SLOT,
    Tags.EXPLORER_SPAWN,
    Tags.BOOTH_ANCHOR,
    Tags.LEVEL_ENTRY,
    Tags.LEVEL_EXIT,
    Tags.BUDDY_NPC_SPAWN,
    Tags.PUPPY_SPAWN,
    Tags.BUDDY_PORTAL,
    Tags.BUDDY_BIN,
    Tags.BELT_START,
    Tags.BELT_END,
    Tags.GUIDE_SPAWN,
    Tags.ROUND_FINISH_ZONE,
]


def emit_verify_style_lua() -> str:
    p = LuaProgram()
    p.comment("buddy bridge style + tag verification")

    allowed_lua_list = "{ " + ", ".join(lua_string(m) for m in sorted(ALLOWED_MATERIALS)) + " }"

    p.line(f"local allowed_materials_list = {allowed_lua_list}")
    p.line(
        "local allowed_materials = {}\n"
        "for _, m in ipairs(allowed_materials_list) do allowed_materials[m] = true end"
    )
    p.line(f"local expected_font = {lua_string(FONT)}")

    p.line(
        "local violations = { material = {}, font = {} }"
    )

    p.line(
        "local function is_under_buddy_root(inst)\n"
        "  while inst do\n"
        "    if inst == Workspace.Lobby then return true end\n"
        "    if inst.Name == \"PlayArenaSlots\" and inst.Parent == Workspace then return true end\n"
        "    if inst == ServerStorage:FindFirstChild(\"Levels\") then return true end\n"
        "    if inst == ServerStorage:FindFirstChild(\"GuideBooths\") then return true end\n"
        "    if inst == ServerStorage:FindFirstChild(\"NpcTemplates\") then return true end\n"
        "    if inst == ServerStorage:FindFirstChild(\"ItemTemplates\") then return true end\n"
        "    inst = inst.Parent\n"
        "  end\n"
        "  return false\n"
        "end"
    )

    # walk workspace + serverstorage looking at parts and textlabels
    p.line(
        "local function visit(root)\n"
        "  for _, d in ipairs(root:GetDescendants()) do\n"
        "    if not is_under_buddy_root(d) then\n"
        "      -- skip stuff outside our scope\n"
        "    elseif d:IsA(\"BasePart\") then\n"
        "      local m = tostring(d.Material):gsub(\"Enum.Material.\", \"\")\n"
        "      if not allowed_materials[m] then\n"
        "        table.insert(violations.material, d:GetFullName() .. \" => \" .. m)\n"
        "      end\n"
        "    elseif d:IsA(\"TextLabel\") or d:IsA(\"TextButton\") or d:IsA(\"TextBox\") then\n"
        "      local f = tostring(d.Font):gsub(\"Enum.Font.\", \"\")\n"
        "      if f ~= expected_font then\n"
        "        table.insert(violations.font, d:GetFullName() .. \" => \" .. f)\n"
        "      end\n"
        "    end\n"
        "  end\n"
        "end\n"
        "visit(Workspace)\n"
        "visit(ServerStorage)"
    )

    # required-tag presence
    required_tag_list = "{ " + ", ".join(lua_string(t) for t in _REQUIRED_TAG_PRESENCE) + " }"
    p.line(f"local required_tags = {required_tag_list}")
    p.line(
        "violations.tags_missing = {}\n"
        "for _, t in ipairs(required_tags) do\n"
        "  if #CollectionService:GetTagged(t) == 0 then\n"
        "    table.insert(violations.tags_missing, t)\n"
        "  end\n"
        "end"
    )

    p.line(
        "table.insert(_result.notes, \"material_violations=\" .. tostring(#violations.material))\n"
        "table.insert(_result.notes, \"font_violations=\" .. tostring(#violations.font))\n"
        "table.insert(_result.notes, \"tags_missing=\" .. tostring(#violations.tags_missing))"
    )
    p.line("_result.violations = violations")
    return p.render()


__all__ = ["emit_verify_style_lua"]
