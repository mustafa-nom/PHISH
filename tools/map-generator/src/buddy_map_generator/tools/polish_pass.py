"""build_polish_pass: lighting + atmosphere + sfx placeholders.

actions:
- set Lighting properties for warm cartoon daylight
- ensure Atmosphere child exists with sensible defaults
- add Sound placeholders to SoundService for the canonical SFX names
- add a looped (disabled) background music placeholder
"""

from __future__ import annotations

from ..lua_emit import LuaProgram, lua_string
from ..style import PALETTE


_SFX_NAMES = [
    "ConfirmPair",
    "RoundStart",
    "LevelComplete",
    "WrongSort",
    "CorrectSort",
    "ClueCollected",
    "RiskyTalk",
    "RoundComplete",
]


def emit_polish_pass_lua() -> str:
    p = LuaProgram()
    p.comment("buddy bridge polish pass — lighting + sfx placeholders")

    # lighting — warm cartoon daylight
    sky = PALETTE.sky_warm
    p.line(
        f"Lighting.Ambient = Color3.fromRGB({sky[0]}, {sky[1]}, {sky[2]})"
    )
    p.line(
        f"Lighting.OutdoorAmbient = Color3.fromRGB(160, 168, 144)"
    )
    p.line("Lighting.Brightness = 2")
    p.line("Lighting.ClockTime = 14")
    p.line("Lighting.GeographicLatitude = 41.7")
    p.line("Lighting.FogStart = 200")
    p.line("Lighting.FogEnd = 1500")
    p.line(
        "Lighting.FogColor = Color3.fromRGB(232, 224, 200)"
    )

    # atmosphere — soft warm haze
    p.line(
        "do\n"
        "  local atm = Lighting:FindFirstChildOfClass(\"Atmosphere\")\n"
        "  if not atm then\n"
        "    atm = Instance.new(\"Atmosphere\")\n"
        "    atm.Parent = Lighting\n"
        "  end\n"
        "  atm.Density = 0.3\n"
        "  atm.Offset = 0.25\n"
        "  atm.Color = Color3.fromRGB(232, 224, 200)\n"
        "  atm.Decay = Color3.fromRGB(110, 80, 70)\n"
        "  atm.Glare = 0.1\n"
        "  atm.Haze = 0.4\n"
        "end"
    )

    # sun rays for cozy bloom
    p.line(
        "do\n"
        "  local rays = Lighting:FindFirstChildOfClass(\"SunRaysEffect\")\n"
        "  if not rays then\n"
        "    rays = Instance.new(\"SunRaysEffect\")\n"
        "    rays.Parent = Lighting\n"
        "  end\n"
        "  rays.Intensity = 0.18\n"
        "  rays.Spread = 0.6\n"
        "end"
    )

    # sfx placeholders — empty Sound instances ready for User 2 to fill
    for sfx in _SFX_NAMES:
        p.line(
            f"do\n"
            f"  local s = SoundService:FindFirstChild({lua_string(sfx)})\n"
            f"  if not s then\n"
            f"    s = Instance.new(\"Sound\")\n"
            f"    s.Name = {lua_string(sfx)}\n"
            f"    s.Volume = 0.5\n"
            f"    s.Parent = SoundService\n"
            f"  end\n"
            f"end"
        )
        p.created(f"SoundService/{sfx}")

    # background music placeholder — looped, disabled by default
    p.line(
        "do\n"
        "  local bgm = SoundService:FindFirstChild(\"LobbyMusic\")\n"
        "  if not bgm then\n"
        "    bgm = Instance.new(\"Sound\")\n"
        "    bgm.Name = \"LobbyMusic\"\n"
        "    bgm.Looped = true\n"
        "    bgm.Volume = 0\n"
        "    bgm.Parent = SoundService\n"
        "  end\n"
        "end"
    )
    p.created("SoundService/LobbyMusic")

    p.note("polish pass applied")
    return p.render()


__all__ = ["emit_polish_pass_lua"]
