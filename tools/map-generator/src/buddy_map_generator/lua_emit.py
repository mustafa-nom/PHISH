"""lua snippet builders.

each generator composes one big lua program out of these helpers, which is
then sent to roblox studio via rbx-studio-mcp's run_code tool. keeping the
emitters as pure-text composers (no instance objects, no roundtrips) means
generators stay testable as plain string assertions.
"""

from __future__ import annotations

import json
from dataclasses import dataclass

from .style import (
    DEFAULT_MATERIAL,
    PALETTE,
    PROPORTIONS,
    color3,
    font,
    material,
)


# ---------------------------------------------------------------------------
# low-level helpers
# ---------------------------------------------------------------------------


def lua_string(value: str) -> str:
    """safely encode a python str as a lua string literal."""
    # json.dumps uses double quotes and escapes the same chars lua expects
    return json.dumps(value, ensure_ascii=False)


def vec3(x: float, y: float, z: float) -> str:
    return f"Vector3.new({x}, {y}, {z})"


def cframe_pos(x: float, y: float, z: float) -> str:
    return f"CFrame.new({x}, {y}, {z})"


def cframe_pos_yaw(x: float, y: float, z: float, yaw_degrees: float) -> str:
    """position + yaw rotation in degrees around Y axis."""
    return (
        f"CFrame.new({x}, {y}, {z}) * CFrame.Angles(0, math.rad({yaw_degrees}), 0)"
    )


# ---------------------------------------------------------------------------
# program builder
# ---------------------------------------------------------------------------


@dataclass
class LuaProgram:
    """accumulator for an emitted lua program.

    has a header that imports common services and a body that gets appended
    to via the helper methods. emits a single string via .render().
    """

    body: list[str]

    def __init__(self) -> None:
        self.body = []
        # header — gets prepended once at render time. avoid repeating service
        # lookups inside loops; cache them up front.
        self._header = [
            "local Workspace = game:GetService(\"Workspace\")",
            "local ServerStorage = game:GetService(\"ServerStorage\")",
            "local CollectionService = game:GetService(\"CollectionService\")",
            "local Lighting = game:GetService(\"Lighting\")",
            "local SoundService = game:GetService(\"SoundService\")",
            "local TweenService = game:GetService(\"TweenService\")",
            # local results table used for the run_code reply.
            "local _result = { created = {}, notes = {} }",
        ]

    def line(self, lua: str) -> "LuaProgram":
        self.body.append(lua)
        return self

    def comment(self, text: str) -> "LuaProgram":
        # lowercase comment style per project convention
        self.body.append(f"-- {text.lower()}")
        return self

    def note(self, message: str) -> "LuaProgram":
        """log a short note that appears in the run_code result."""
        self.body.append(f"table.insert(_result.notes, {lua_string(message)})")
        return self

    def created(self, label: str) -> "LuaProgram":
        self.body.append(f"table.insert(_result.created, {lua_string(label)})")
        return self

    def render(self) -> str:
        footer = [
            "local HttpService = game:GetService(\"HttpService\")",
            "print(HttpService:JSONEncode(_result))",
        ]
        return "\n".join(self._header + self.body + footer)


# ---------------------------------------------------------------------------
# instance creation helpers
# ---------------------------------------------------------------------------


def make_part(
    var_name: str,
    *,
    parent: str,
    name: str,
    size: tuple[float, float, float],
    cframe: str,
    color_rgb: tuple[int, int, int] | None = None,
    material_name: str = DEFAULT_MATERIAL,
    shape: str | None = None,
    transparency: float = 0,
    can_collide: bool = True,
    anchored: bool = True,
    cast_shadow: bool = True,
) -> str:
    """emit lua that creates a Part with sensible defaults.

    `parent` is a lua expression evaluating to an Instance — for example
    `"Workspace.Lobby"` or a previously-declared local var.
    """
    sx, sy, sz = size
    color = color3(color_rgb) if color_rgb is not None else color3(PALETTE.grass)
    lines = [
        f"local {var_name} = Instance.new(\"Part\")",
        f"{var_name}.Name = {lua_string(name)}",
        f"{var_name}.Size = Vector3.new({sx}, {sy}, {sz})",
        f"{var_name}.CFrame = {cframe}",
        f"{var_name}.Color = {color}",
        f"{var_name}.Material = {material(material_name)}",
        f"{var_name}.Anchored = {str(anchored).lower()}",
        f"{var_name}.CanCollide = {str(can_collide).lower()}",
        f"{var_name}.Transparency = {transparency}",
        f"{var_name}.CastShadow = {str(cast_shadow).lower()}",
    ]
    if shape is not None:
        lines.append(f"{var_name}.Shape = Enum.PartType.{shape}")
    lines.append(f"{var_name}.Parent = {parent}")
    return "\n".join(lines)


def make_disc(
    var_name: str,
    *,
    parent: str,
    name: str,
    diameter: float,
    height: float,
    cframe: str,
    color_rgb: tuple[int, int, int] | None = None,
    material_name: str = DEFAULT_MATERIAL,
    transparency: float = 0,
    can_collide: bool = True,
    anchored: bool = True,
    cast_shadow: bool = True,
) -> str:
    """flat circular puck lying on its side (axis pointing up).

    roblox `Enum.PartType.Cylinder` extends along the part's local X axis with
    Size = (length, diameter, diameter). To make a puck (axis up) we use that
    size order AND rotate the part 90deg around Z so X points up.
    """
    color = color3(color_rgb) if color_rgb is not None else color3(PALETTE.grass)
    upright_cframe = f"({cframe}) * CFrame.Angles(0, 0, math.rad(90))"
    lines = [
        f"local {var_name} = Instance.new(\"Part\")",
        f"{var_name}.Name = {lua_string(name)}",
        f"{var_name}.Size = Vector3.new({height}, {diameter}, {diameter})",
        f"{var_name}.CFrame = {upright_cframe}",
        f"{var_name}.Color = {color}",
        f"{var_name}.Material = {material(material_name)}",
        f"{var_name}.Anchored = {str(anchored).lower()}",
        f"{var_name}.CanCollide = {str(can_collide).lower()}",
        f"{var_name}.Transparency = {transparency}",
        f"{var_name}.CastShadow = {str(cast_shadow).lower()}",
        f"{var_name}.Shape = Enum.PartType.Cylinder",
        f"{var_name}.TopSurface = Enum.SurfaceType.Smooth",
        f"{var_name}.BottomSurface = Enum.SurfaceType.Smooth",
        f"{var_name}.Parent = {parent}",
    ]
    return "\n".join(lines)


def make_folder(var_name: str, *, parent: str, name: str) -> str:
    return "\n".join(
        [
            f"local {var_name} = Instance.new(\"Folder\")",
            f"{var_name}.Name = {lua_string(name)}",
            f"{var_name}.Parent = {parent}",
        ]
    )


def make_model(var_name: str, *, parent: str, name: str) -> str:
    return "\n".join(
        [
            f"local {var_name} = Instance.new(\"Model\")",
            f"{var_name}.Name = {lua_string(name)}",
            f"{var_name}.Parent = {parent}",
        ]
    )


def set_primary_part(model_var: str, part_var: str) -> str:
    return f"{model_var}.PrimaryPart = {part_var}"


def add_tag(instance_var: str, tag: str) -> str:
    return f"CollectionService:AddTag({instance_var}, {lua_string(tag)})"


def set_attribute(instance_var: str, attr: str, value: str | int | float | bool) -> str:
    if isinstance(value, bool):
        lua_value = str(value).lower()
    elif isinstance(value, (int, float)):
        lua_value = str(value)
    else:
        lua_value = lua_string(value)
    return f"{instance_var}:SetAttribute({lua_string(attr)}, {lua_value})"


def make_billboard_gui(
    var_name: str,
    *,
    adornee: str,
    text: str,
    size_studs: tuple[float, float] = (8, 2),
    studs_offset_y: float = 4,
    text_color_rgb: tuple[int, int, int] | None = None,
    background_rgb: tuple[int, int, int] | None = None,
    text_size: int | None = None,
) -> str:
    """create a BillboardGui above an adornee with a single TextLabel inside."""
    text_color = color3(text_color_rgb if text_color_rgb is not None else PALETTE.sign_ink)
    bg_color = color3(background_rgb if background_rgb is not None else PALETTE.sign_face)
    ts = text_size if text_size is not None else PROPORTIONS.billboard_text_size
    sx, sy = size_studs
    lines = [
        f"local {var_name} = Instance.new(\"BillboardGui\")",
        f"{var_name}.Adornee = {adornee}",
        f"{var_name}.Size = UDim2.new(0, 200, 0, 50)",
        f"{var_name}.SizeOffset = Vector2.new(0, 0)",
        f"{var_name}.StudsOffsetWorldSpace = Vector3.new(0, {studs_offset_y}, 0)",
        f"{var_name}.AlwaysOnTop = false",
        f"{var_name}.MaxDistance = 80",
        f"{var_name}.Parent = {adornee}",
        f"local {var_name}_bg = Instance.new(\"Frame\")",
        f"{var_name}_bg.Size = UDim2.new(1, 0, 1, 0)",
        f"{var_name}_bg.BackgroundColor3 = {bg_color}",
        f"{var_name}_bg.BackgroundTransparency = 0.15",
        f"{var_name}_bg.BorderSizePixel = 0",
        f"{var_name}_bg.Parent = {var_name}",
        f"local {var_name}_corner = Instance.new(\"UICorner\")",
        f"{var_name}_corner.CornerRadius = UDim.new(0.25, 0)",
        f"{var_name}_corner.Parent = {var_name}_bg",
        f"local {var_name}_label = Instance.new(\"TextLabel\")",
        f"{var_name}_label.Size = UDim2.new(1, -8, 1, -8)",
        f"{var_name}_label.Position = UDim2.new(0, 4, 0, 4)",
        f"{var_name}_label.BackgroundTransparency = 1",
        f"{var_name}_label.Text = {lua_string(text)}",
        f"{var_name}_label.Font = {font()}",
        f"{var_name}_label.TextSize = {ts}",
        f"{var_name}_label.TextColor3 = {text_color}",
        f"{var_name}_label.TextWrapped = true",
        f"{var_name}_label.Parent = {var_name}_bg",
        # ignore the unused size hint — kept for future tweakers
        f"local _ = {sx} + {sy}",
    ]
    return "\n".join(lines)


def make_proximity_prompt(
    var_name: str,
    *,
    adornee: str,
    action_text: str,
    object_text: str = "",
    hold_duration: float = 0,
) -> str:
    return "\n".join(
        [
            f"local {var_name} = Instance.new(\"ProximityPrompt\")",
            f"{var_name}.ActionText = {lua_string(action_text)}",
            f"{var_name}.ObjectText = {lua_string(object_text)}",
            f"{var_name}.HoldDuration = {hold_duration}",
            f"{var_name}.RequiresLineOfSight = false",
            f"{var_name}.Parent = {adornee}",
        ]
    )


def make_surface_gui(
    var_name: str,
    *,
    adornee: str,
    face: str = "Top",
) -> str:
    return "\n".join(
        [
            f"local {var_name} = Instance.new(\"SurfaceGui\")",
            f"{var_name}.Face = Enum.NormalId.{face}",
            f"{var_name}.LightInfluence = 0",
            f"{var_name}.AlwaysOnTop = false",
            f"{var_name}.CanvasSize = Vector2.new(600, 400)",
            f"{var_name}.PixelsPerStud = 50",
            f"{var_name}.Parent = {adornee}",
        ]
    )


def find_or_create_path(parent_lua: str, *segments: str) -> str:
    """emit lua that walks/creates a Folder chain under `parent_lua`.

    e.g. `find_or_create_path("ServerStorage", "Levels")` returns lua that
    leaves a local `_path` pointing at ServerStorage.Levels (creating Levels
    if missing). caller must immediately consume `_path` because the name
    is reused.
    """
    body = [f"local _path = {parent_lua}"]
    for seg in segments:
        body.append(
            "do\n"
            f"  local _existing = _path:FindFirstChild({lua_string(seg)})\n"
            f"  if not _existing then\n"
            f"    _existing = Instance.new(\"Folder\")\n"
            f"    _existing.Name = {lua_string(seg)}\n"
            f"    _existing.Parent = _path\n"
            f"  end\n"
            "  _path = _existing\n"
            "end"
        )
    return "\n".join(body)


def clear_existing(parent_lua: str, *child_names: str) -> str:
    """remove pre-existing children with the given names so reruns are safe."""
    chunks = []
    for name in child_names:
        chunks.append(
            f"do local _x = ({parent_lua}):FindFirstChild({lua_string(name)}) "
            f"if _x then _x:Destroy() end end"
        )
    return "\n".join(chunks)
