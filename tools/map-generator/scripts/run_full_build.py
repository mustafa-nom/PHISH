"""end-to-end build runner for live studio.

assumes studio is open with the active studio plugin (boshyxd robloxstudio-mcp
by default). drives every emitter in order, captures screenshots after each
section, and writes them to ../screenshots/.

usage:
  cd tools/map-generator
  python3 scripts/run_full_build.py

env:
  BUDDY_STUDIO_BACKEND=robloxstudio | rbx-studio  (default: robloxstudio)
  BUDDY_STUDIO_BIN, BUDDY_STUDIO_ARGS              (override executable)

screenshot strategy:
  the boshyxd backend captures via the studio plugin and works anywhere.
  the rbx-studio backend's `capture_screenshot` only works on macOS/Windows
  hosts. when running from WSL we fall back to a powershell.exe interop
  script (capture_studio.ps1) that calls the windows PrintWindow API.
"""

from __future__ import annotations

import base64
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_PKG_ROOT = _HERE.parent
sys.path.insert(0, str(_PKG_ROOT / "src"))

from buddy_map_generator.studio_client import StudioClient, StudioClientError  # noqa: E402
from buddy_map_generator.tools.backpack_checkpoint import emit_backpack_checkpoint_lua  # noqa: E402
from buddy_map_generator.tools.booth_template import emit_booth_template_lua  # noqa: E402
from buddy_map_generator.tools.item_templates import emit_item_templates_lua  # noqa: E402
from buddy_map_generator.tools.lobby import emit_lobby_lua  # noqa: E402
from buddy_map_generator.tools.npc_templates import emit_npc_templates_lua  # noqa: E402
from buddy_map_generator.tools.play_arena_slots import emit_play_arena_slots_lua  # noqa: E402
from buddy_map_generator.tools.polish_pass import emit_polish_pass_lua  # noqa: E402
from buddy_map_generator.tools.stranger_danger_park import emit_stranger_danger_park_lua  # noqa: E402
from buddy_map_generator.tools.verify import emit_verify_style_lua  # noqa: E402


SHOTS_DIR = _PKG_ROOT / "screenshots"
SHOTS_DIR.mkdir(exist_ok=True)


# (label, lua-emitter, optional camera-aim-lua)
# camera aim lua is run after the build emitter to frame the result. None
# means leave the camera alone (e.g. server-storage builds aren't visible
# in workspace).
def _camera(cframe_lua: str) -> str:
    return (
        "workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable\n"
        f"workspace.CurrentCamera.CFrame = {cframe_lua}\n"
        "return \"camera placed\""
    )


_STEPS = [
    (
        "01_lobby",
        emit_lobby_lua,
        _camera("CFrame.new(Vector3.new(80, 70, -90), Vector3.new(0, 8, 0))"),
    ),
    (
        "02_play_arena_slots",
        emit_play_arena_slots_lua,
        _camera("CFrame.new(Vector3.new(-150, -440, 70), Vector3.new(0, -495, 0))"),
    ),
    (
        "03_booth_template",
        emit_booth_template_lua,
        # clone booth into workspace temporarily so it's visible
        (
            "local ServerStorage = game:GetService(\"ServerStorage\")\n"
            "local preview = workspace:FindFirstChild(\"_Preview\")\n"
            "if preview then preview:Destroy() end\n"
            "preview = Instance.new(\"Folder\")\n"
            "preview.Name = \"_Preview\"\n"
            "preview.Parent = workspace\n"
            "local b = ServerStorage.GuideBooths.DefaultBooth:Clone()\n"
            "b:PivotTo(CFrame.new(0, 0, 100))\n"
            "b.Parent = preview\n"
            "workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable\n"
            "workspace.CurrentCamera.CFrame = CFrame.new(Vector3.new(20, 12, 90), Vector3.new(0, 4, 100))\n"
            "return \"booth previewed\""
        ),
    ),
    (
        "04_stranger_danger_park",
        emit_stranger_danger_park_lua,
        (
            "local ServerStorage = game:GetService(\"ServerStorage\")\n"
            "local preview = workspace:FindFirstChild(\"_Preview\")\n"
            "if preview then preview:Destroy() end\n"
            "preview = Instance.new(\"Folder\")\n"
            "preview.Name = \"_Preview\"\n"
            "preview.Parent = workspace\n"
            "local lvl = ServerStorage.Levels.StrangerDangerPark:Clone()\n"
            "lvl:PivotTo(CFrame.new(0, 0, 200))\n"
            "lvl.Parent = preview\n"
            "workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable\n"
            "workspace.CurrentCamera.CFrame = CFrame.new(Vector3.new(80, 60, 130), Vector3.new(0, 4, 200))\n"
            "return \"park previewed\""
        ),
    ),
    (
        "05_backpack_checkpoint",
        emit_backpack_checkpoint_lua,
        (
            "local ServerStorage = game:GetService(\"ServerStorage\")\n"
            "local preview = workspace:FindFirstChild(\"_Preview\")\n"
            "if preview then preview:Destroy() end\n"
            "preview = Instance.new(\"Folder\")\n"
            "preview.Name = \"_Preview\"\n"
            "preview.Parent = workspace\n"
            "local lvl = ServerStorage.Levels.BackpackCheckpoint:Clone()\n"
            "lvl:PivotTo(CFrame.new(0, 0, 300))\n"
            "lvl.Parent = preview\n"
            "workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable\n"
            "workspace.CurrentCamera.CFrame = CFrame.new(Vector3.new(0, 16, 280), Vector3.new(0, 4, 305))\n"
            "return \"checkpoint previewed\""
        ),
    ),
    (
        "06_npc_templates",
        emit_npc_templates_lua,
        (
            "local ServerStorage = game:GetService(\"ServerStorage\")\n"
            "local preview = workspace:FindFirstChild(\"_Preview\")\n"
            "if preview then preview:Destroy() end\n"
            "preview = Instance.new(\"Folder\")\n"
            "preview.Name = \"_Preview\"\n"
            "preview.Parent = workspace\n"
            "local floor = Instance.new(\"Part\")\n"
            "floor.Size = Vector3.new(80, 1, 16)\n"
            "floor.CFrame = CFrame.new(0, -0.5, 400)\n"
            "floor.Anchored = true\n"
            "floor.Color = Color3.fromRGB(133, 196, 92)\n"
            "floor.Material = Enum.Material.Grass\n"
            "floor.Parent = preview\n"
            "local i = 0\n"
            "for _, tpl in ipairs(ServerStorage.NpcTemplates:GetChildren()) do\n"
            "  local clone = tpl:Clone()\n"
            "  clone:PivotTo(CFrame.new(-30 + i * 10, 1.5, 400) * CFrame.Angles(0, math.rad(180), 0))\n"
            "  clone.Parent = preview\n"
            "  i = i + 1\n"
            "end\n"
            "workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable\n"
            "workspace.CurrentCamera.CFrame = CFrame.new(Vector3.new(0, 8, 380), Vector3.new(0, 3, 400))\n"
            "return (\"placed \" .. i .. \" npcs\")"
        ),
    ),
    (
        "07_item_templates",
        emit_item_templates_lua,
        (
            "local ServerStorage = game:GetService(\"ServerStorage\")\n"
            "local preview = workspace:FindFirstChild(\"_Preview\")\n"
            "if preview then preview:Destroy() end\n"
            "preview = Instance.new(\"Folder\")\n"
            "preview.Name = \"_Preview\"\n"
            "preview.Parent = workspace\n"
            "local floor = Instance.new(\"Part\")\n"
            "floor.Size = Vector3.new(72, 1, 12)\n"
            "floor.CFrame = CFrame.new(0, -0.5, 500)\n"
            "floor.Anchored = true\n"
            "floor.Color = Color3.fromRGB(212, 200, 178)\n"
            "floor.Material = Enum.Material.Concrete\n"
            "floor.Parent = preview\n"
            "local i = 0\n"
            "for _, tpl in ipairs(ServerStorage.ItemTemplates:GetChildren()) do\n"
            "  local clone = tpl:Clone()\n"
            "  clone:PivotTo(CFrame.new(-30 + i * 5, 1, 500))\n"
            "  clone.Parent = preview\n"
            "  i = i + 1\n"
            "end\n"
            "workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable\n"
            "workspace.CurrentCamera.CFrame = CFrame.new(Vector3.new(0, 18, 484), Vector3.new(0, 1.5, 500))\n"
            "return (\"placed \" .. i .. \" items\")"
        ),
    ),
    ("08_polish_pass", emit_polish_pass_lua, None),
    ("09_verify_style", emit_verify_style_lua, None),
]


_PS1 = _HERE / "capture_studio.ps1"


def _save_via_powershell(label: str) -> Path | None:
    """fallback: ask windows powershell to capture studio's window via PrintWindow.

    only useful from WSL pointing at a windows-hosted studio. requires the
    capture_studio.ps1 script next to this one.
    """
    powershell = shutil.which("powershell.exe")
    if not powershell:
        return None
    if not _PS1.exists():
        return None
    out_win = r"C:\Users\mathe\AppData\Local\Temp\buddy_shot_" + label + ".png"
    out_wsl = Path("/mnt/c/Users/mathe/AppData/Local/Temp") / f"buddy_shot_{label}.png"
    try:
        ps1_win = subprocess.check_output(
            ["wslpath", "-w", str(_PS1)], text=True
        ).strip()
    except Exception:
        return None
    cmd = [
        powershell,
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        ps1_win,
        "-OutPath",
        out_win,
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=30)
    except Exception:
        return None
    if not out_wsl.exists():
        return None
    final = SHOTS_DIR / f"{label}.png"
    final.write_bytes(out_wsl.read_bytes())
    try:
        out_wsl.unlink()
    except Exception:
        pass
    return final


def _save_screenshot(client: StudioClient, label: str) -> Path | None:
    try:
        result = client.capture_screenshot()
    except StudioClientError as exc:
        print(f"  ! mcp screenshot errored: {exc}")
        return _save_via_powershell(label)
    content = result.get("content")
    if isinstance(content, list):
        for item in content:
            if not isinstance(item, dict):
                continue
            if item.get("type") == "image":
                data = base64.b64decode(item.get("data", ""))
                out = SHOTS_DIR / f"{label}.png"
                out.write_bytes(data)
                return out
            if item.get("type") == "text":
                # rbx-studio-mcp returns a text "Screenshot capture is only
                # supported on macOS and Windows" error here. trigger fallback.
                msg = str(item.get("text", "")).lower()
                if "only supported" in msg or "failed to capture" in msg:
                    return _save_via_powershell(label)
    return _save_via_powershell(label)


def main() -> int:
    client = StudioClient()
    try:
        client.start()
    except Exception as exc:
        print(f"failed to start studio backend: {exc}")
        return 1

    # baseline
    print("00_baseline", end=" ", flush=True)
    shot = _save_screenshot(client, "00_baseline")
    print(f"-> {shot.name if shot else 'no shot'}")

    for label, emitter, camera_lua in _STEPS:
        print(label, end=" ", flush=True)
        try:
            run_out = client.run_code(emitter())
        except StudioClientError as exc:
            print(f"FAILED — {exc}")
            return 2
        if camera_lua is not None:
            try:
                client.run_code(camera_lua)
                # small settle so the camera frame has time to update
                time.sleep(0.4)
            except StudioClientError as exc:
                print(f"camera failed: {exc}")
        shot = _save_screenshot(client, label)
        print(f"-> {shot.name if shot else 'no shot'}")

    # cleanup the temporary preview clones
    try:
        client.run_code(
            "local preview = workspace:FindFirstChild(\"_Preview\")\n"
            "if preview then preview:Destroy() end\n"
            "return \"preview cleaned\""
        )
    except StudioClientError:
        pass

    client.stop()
    print(f"\nscreenshots saved to {SHOTS_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
