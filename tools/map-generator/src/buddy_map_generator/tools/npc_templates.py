"""build_npc_templates: roblox R6 character rigs in ServerStorage/NpcTemplates.

each rig is a real R6 humanoid — same proportions as a default roblox avatar.
the only thing customized per archetype is face decal, body part colors,
plus optional Shirt/Pants asset placeholders. they walk patrol routes via an
embedded Script that drives Humanoid:MoveTo around the level's PatrolPaths
folder.

map object conventions:
- ServerStorage.NpcTemplates.<NpcName> (Model)
- PrimaryPart = HumanoidRootPart
- Humanoid (RigType = R6)
- BillboardGui named TraitCard mounted on the head (User 2 fills text)
- KnifeAccessory model with attribute Detachable=true on knife archetype
"""

from __future__ import annotations

from ..lua_emit import (
    LuaProgram,
    add_tag,
    cframe_pos,
    clear_existing,
    find_or_create_path,
    lua_string,
    make_billboard_gui,
    make_clothing,
    make_decal,
    make_humanoid,
    make_model,
    make_motor6d,
    make_part,
    make_script,
    set_attribute,
    set_primary_part,
)
from ..style import PALETTE, Tags


# (name, skin_color, shirt_color, pants_color, face_id, shirt_id, pants_id, holds_knife)
# face_id is a roblox texture asset (rbxasset:// or rbxassetid://). user 2 swaps.
# shirt_id / pants_id are asset id placeholders ("0" until customized).
_DEFAULT_FACE = "rbxasset://textures/face.png"

_NPCS = [
    (
        "HotDogVendor",
        PALETTE.skin_warm,
        PALETTE.hot_dog_red,
        PALETTE.cottage_door,
        _DEFAULT_FACE,
        "rbxassetid://0",
        "rbxassetid://0",
        False,
    ),
    (
        "Ranger",
        PALETTE.skin_warm,
        PALETTE.ranger_green,
        PALETTE.cottage_trim,
        _DEFAULT_FACE,
        "rbxassetid://0",
        "rbxassetid://0",
        False,
    ),
    (
        "ParentWithKid",
        PALETTE.skin_warm,
        PALETTE.capsule_b,
        PALETTE.cottage_trim,
        _DEFAULT_FACE,
        "rbxassetid://0",
        "rbxassetid://0",
        False,
    ),
    (
        "CasualParkGoer",
        PALETTE.skin_warm,
        PALETTE.capsule_d,
        PALETTE.cottage_trim,
        _DEFAULT_FACE,
        "rbxassetid://0",
        "rbxassetid://0",
        False,
    ),
    (
        "HoodedAdult",
        PALETTE.skin_neutral,
        PALETTE.near_black,
        PALETTE.near_black,
        _DEFAULT_FACE,
        "rbxassetid://0",
        "rbxassetid://0",
        False,
    ),
    (
        "VehicleLeaner",
        PALETTE.skin_neutral,
        PALETTE.bin_leave_it,
        PALETTE.cottage_door,
        _DEFAULT_FACE,
        "rbxassetid://0",
        "rbxassetid://0",
        False,
    ),
    (
        "KnifeArchetype",
        PALETTE.skin_neutral,
        PALETTE.near_black,
        PALETTE.near_black,
        _DEFAULT_FACE,
        "rbxassetid://0",
        "rbxassetid://0",
        True,
    ),
]


# patrol script source — embedded as a server Script inside each rig.
# walks between waypoints found via a sibling PatrolPaths folder.
_PATROL_SCRIPT = """\
-- buddy bridge npc patrol — auto-generated. drives the rig along the
-- waypoint folder named after the rig's PatrolPathName attribute.
local model = script.Parent
local humanoid = model:WaitForChild("Humanoid")
local hrp = model:WaitForChild("HumanoidRootPart")

-- un-anchor every body part so the humanoid can drive physics
for _, part in ipairs(model:GetDescendants()) do
    if part:IsA("BasePart") then
        part.Anchored = false
    end
end

-- give the rig a moment to settle, then look for waypoints
task.wait(0.5)

local pathName = model:GetAttribute("PatrolPathName")
if not pathName then
    return
end

local function findPatrolFolder(inst)
    local cursor = inst
    while cursor do
        local paths = cursor:FindFirstChild("PatrolPaths")
        if paths then
            local match = paths:FindFirstChild(pathName)
            if match then return match end
        end
        cursor = cursor.Parent
    end
end

local folder = findPatrolFolder(model)
if not folder then return end

local waypoints = {}
for _, child in ipairs(folder:GetChildren()) do
    if child:IsA("BasePart") then
        table.insert(waypoints, child)
    end
end
table.sort(waypoints, function(a, b)
    return (a:GetAttribute("WaypointIndex") or 0) < (b:GetAttribute("WaypointIndex") or 0)
end)

if #waypoints == 0 then return end

task.spawn(function()
    local i = 1
    while model.Parent do
        local target = waypoints[i].Position
        humanoid:MoveTo(target)
        local reached = humanoid.MoveToFinished:Wait()
        i = (i % #waypoints) + 1
        if not reached then
            task.wait(0.2)
        else
            task.wait(0.5 + math.random() * 1.5)
        end
    end
end)
"""


def _emit_r6_rig(
    p: LuaProgram,
    *,
    npc_name: str,
    skin_rgb: tuple[int, int, int],
    shirt_rgb: tuple[int, int, int],
    pants_rgb: tuple[int, int, int],
    face_id: str,
    shirt_id: str,
    pants_id: str,
    holds_knife: bool,
) -> None:
    """build a roblox-standard R6 rig with face/shirt/pants placeholders.

    each rig declares ~30 locals (body parts + humanoid + 6 motor6ds + face
    decal + clothing + trait gui sub-locals) so the body is wrapped in a
    do/end block — without it, 7 rigs blow past lua's 200-local cap.
    """
    var = f"npc_{npc_name.lower()}"
    p.line("do")
    p.line(make_model(var, parent="templates_root", name=npc_name))

    # body parts at default R6 sizes positioned around y in [0, 5]
    p.line(
        make_part(
            f"{var}_hrp",
            parent=var,
            name="HumanoidRootPart",
            size=(2, 2, 1),
            cframe=cframe_pos(0, 3, 0),
            color_rgb=skin_rgb,
            material_name="SmoothPlastic",
            transparency=1,
            can_collide=False,
        )
    )
    p.line(set_primary_part(var, f"{var}_hrp"))
    p.line(
        make_part(
            f"{var}_torso",
            parent=var,
            name="Torso",
            size=(2, 2, 1),
            cframe=cframe_pos(0, 3, 0),
            color_rgb=shirt_rgb,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{var}_head",
            parent=var,
            name="Head",
            size=(2, 1, 1),
            cframe=cframe_pos(0, 4.5, 0),
            color_rgb=skin_rgb,
            material_name="SmoothPlastic",
        )
    )
    # add a Head-type SpecialMesh so the head reads as the classic roblox shape
    p.line(
        f"do\n"
        f"  local _mesh = Instance.new(\"SpecialMesh\")\n"
        f"  _mesh.MeshType = Enum.MeshType.Head\n"
        f"  _mesh.Scale = Vector3.new(1.25, 1.25, 1.25)\n"
        f"  _mesh.Parent = {var}_head\n"
        f"end"
    )
    # face decal — the classic roblox smile by default. user 2 swaps.
    p.line(
        make_decal(
            f"{var}_face",
            parent=f"{var}_head",
            name="face",
            texture_id=face_id,
            face="Front",
        )
    )
    # arms
    for side, dx in (("Left", -1.5), ("Right", 1.5)):
        p.line(
            make_part(
                f"{var}_{side.lower()}arm",
                parent=var,
                name=f"{side} Arm",
                size=(1, 2, 1),
                cframe=cframe_pos(dx, 3, 0),
                color_rgb=skin_rgb,
                material_name="SmoothPlastic",
            )
        )
    # legs
    for side, dx in (("Left", -0.5), ("Right", 0.5)):
        p.line(
            make_part(
                f"{var}_{side.lower()}leg",
                parent=var,
                name=f"{side} Leg",
                size=(1, 2, 1),
                cframe=cframe_pos(dx, 1, 0),
                color_rgb=pants_rgb,
                material_name="SmoothPlastic",
            )
        )

    # humanoid — required for the rig to be drivable by MoveTo
    p.line(
        make_humanoid(
            f"{var}_humanoid",
            parent=var,
            rig_type="R6",
            walk_speed=8,
            health=100,
            display_name=npc_name,
        )
    )

    # Motor6D welds (parented to torso). C0/C1 follow roblox defaults so the
    # rig holds together under physics.
    p.line(
        make_motor6d(
            f"{var}_root_joint",
            parent=f"{var}_torso",
            name="RootJoint",
            part0=f"{var}_hrp",
            part1=f"{var}_torso",
            c0="CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1)",
            c1="CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1)",
        )
    )
    p.line(
        make_motor6d(
            f"{var}_neck",
            parent=f"{var}_torso",
            name="Neck",
            part0=f"{var}_torso",
            part1=f"{var}_head",
            c0="CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)",
            c1="CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)",
        )
    )
    p.line(
        make_motor6d(
            f"{var}_right_shoulder",
            parent=f"{var}_torso",
            name="Right Shoulder",
            part0=f"{var}_torso",
            part1=f"{var}_rightarm",
            c0="CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)",
            c1="CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)",
        )
    )
    p.line(
        make_motor6d(
            f"{var}_left_shoulder",
            parent=f"{var}_torso",
            name="Left Shoulder",
            part0=f"{var}_torso",
            part1=f"{var}_leftarm",
            c0="CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)",
            c1="CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)",
        )
    )
    p.line(
        make_motor6d(
            f"{var}_right_hip",
            parent=f"{var}_torso",
            name="Right Hip",
            part0=f"{var}_torso",
            part1=f"{var}_rightleg",
            c0="CFrame.new(0.5, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)",
            c1="CFrame.new(0, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)",
        )
    )
    p.line(
        make_motor6d(
            f"{var}_left_hip",
            parent=f"{var}_torso",
            name="Left Hip",
            part0=f"{var}_torso",
            part1=f"{var}_leftleg",
            c0="CFrame.new(-0.5, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)",
            c1="CFrame.new(0, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)",
        )
    )

    # shirt + pants placeholders — user 2 swaps the asset ids
    p.line(
        make_clothing(
            f"{var}_shirt",
            parent=var,
            kind="Shirt",
            asset_id=shirt_id,
        )
    )
    p.line(
        make_clothing(
            f"{var}_pants",
            parent=var,
            kind="Pants",
            asset_id=pants_id,
        )
    )

    # trait card billboard mounted on head — guide manual annotates this
    p.line(
        make_billboard_gui(
            f"{var}_trait",
            adornee=f"{var}_head",
            text="",
            studs_offset_y=2,
            text_size=22,
        )
    )
    p.line(f"{var}_trait.Name = {lua_string('TraitCard')}")

    # detachable knife accessory — server scenario logic toggles per round
    if holds_knife:
        p.line(make_model(f"{var}_knife", parent=var, name="KnifeAccessory"))
        p.line(set_attribute(f"{var}_knife", "Detachable", True))
        p.line(
            make_part(
                f"{var}_knife_handle",
                parent=f"{var}_knife",
                name="Handle",
                size=(0.3, 0.8, 0.3),
                cframe=cframe_pos(1.6, 2.4, 0.6),
                color_rgb=PALETTE.cottage_trim,
                material_name="Wood",
            )
        )
        p.line(
            make_part(
                f"{var}_knife_blade",
                parent=f"{var}_knife",
                name="Blade",
                size=(0.15, 1.2, 0.5),
                cframe=cframe_pos(1.6, 3.5, 0.6),
                color_rgb=PALETTE.pale_steel,
                material_name="SmoothPlastic",
            )
        )
        p.line(set_primary_part(f"{var}_knife", f"{var}_knife_handle"))

    # tag the rig + embed the patrol script
    p.line(add_tag(var, Tags.NPC_PATROL))
    p.line(
        make_script(
            f"{var}_patrol",
            parent=var,
            name="PatrolScript",
            source=_PATROL_SCRIPT,
        )
    )

    p.created(f"NpcTemplates/{npc_name}")
    p.line("end")


def emit_npc_templates_lua() -> str:
    p = LuaProgram()
    p.comment("buddy bridge npc templates — R6 rigs with face/shirt/pants slots")

    p.line(find_or_create_path("ServerStorage", "NpcTemplates"))
    p.line("local templates_root = _path")
    for name, *_ in _NPCS:
        p.line(clear_existing("templates_root", name))

    for (
        name,
        skin,
        shirt,
        pants,
        face,
        shirt_id,
        pants_id,
        holds_knife,
    ) in _NPCS:
        _emit_r6_rig(
            p,
            npc_name=name,
            skin_rgb=skin,
            shirt_rgb=shirt,
            pants_rgb=pants,
            face_id=face,
            shirt_id=shirt_id,
            pants_id=pants_id,
            holds_knife=holds_knife,
        )

    p.note(f"built {len(_NPCS)} R6 npc templates")
    return p.render()


__all__ = ["emit_npc_templates_lua"]
