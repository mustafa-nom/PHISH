"""build_npc_templates: 6+ npc rigs in ServerStorage/NpcTemplates.

each rig is a chunky cartoon humanoid built from primitives so they share the
same proportions and outline weight (judge andrew flagged shared style).

each rig:
- Anchored Model with HumanoidRootPart as PrimaryPart
- BillboardGui named TraitCard mounted on the head (User 2 fills text)
- distinct outfit / accessory so the explorer can describe them visually

note on the knife archetype: the knife is created as a child Model named
KnifeAccessory, anchored separately, with attribute Detachable=true. server
scenario logic enables/disables it per-round.
"""

from __future__ import annotations

from ..lua_emit import (
    LuaProgram,
    cframe_pos,
    cframe_pos_yaw,
    clear_existing,
    find_or_create_path,
    lua_string,
    make_billboard_gui,
    make_disc,
    make_model,
    make_part,
    set_attribute,
    set_primary_part,
)
from ..style import PALETTE


# (name, body_color, accent_color, accent_kind, holds_knife)
# accent_kind ∈ apron | uniform_badge | stroller | sunglasses | hood | car_lean
_NPCS = [
    ("HotDogVendor", PALETTE.skin_warm, PALETTE.hot_dog_red, "apron", False),
    ("Ranger", PALETTE.skin_warm, PALETTE.ranger_green, "uniform_badge", False),
    ("ParentWithKid", PALETTE.skin_warm, PALETTE.capsule_b, "stroller", False),
    ("CasualParkGoer", PALETTE.skin_warm, PALETTE.capsule_d, "sunglasses", False),
    ("HoodedAdult", PALETTE.skin_neutral, PALETTE.near_black, "hood", False),
    ("VehicleLeaner", PALETTE.skin_neutral, PALETTE.bin_leave_it, "car_lean", False),
    ("KnifeArchetype", PALETTE.skin_neutral, PALETTE.near_black, "hood", True),
]


def _emit_humanoid_rig(
    p: LuaProgram,
    *,
    npc_name: str,
    skin_rgb: tuple[int, int, int],
    accent_rgb: tuple[int, int, int],
    accent_kind: str,
    holds_knife: bool,
) -> None:
    """append the lua that builds a single npc rig as a child of `templates_root`."""
    var = f"npc_{npc_name.lower()}"
    p.line(make_model(var, parent="templates_root", name=npc_name))

    # torso (functions as humanoid root part, but we make a distinct HRP below)
    p.line(
        make_part(
            f"{var}_torso",
            parent=var,
            name="Torso",
            size=(2.4, 2.4, 1.2),
            cframe=cframe_pos(0, 3, 0),
            color_rgb=accent_rgb,
            material_name="SmoothPlastic",
        )
    )
    # humanoid root part — invisible reference at ground center
    p.line(
        make_part(
            f"{var}_hrp",
            parent=var,
            name="HumanoidRootPart",
            size=(2, 2, 1),
            cframe=cframe_pos(0, 1.5, 0),
            color_rgb=PALETTE.sparkle,
            transparency=1,
            can_collide=False,
        )
    )
    p.line(set_primary_part(var, f"{var}_hrp"))

    # head — sphere with simple cartoon face dots so it reads as a person
    p.line(
        make_part(
            f"{var}_head",
            parent=var,
            name="Head",
            size=(1.6, 1.6, 1.6),
            cframe=cframe_pos(0, 5, 0),
            color_rgb=skin_rgb,
            material_name="SmoothPlastic",
            shape="Ball",
        )
    )
    # eye dots
    for side, dx in (("L", -0.3), ("R", 0.3)):
        p.line(
            make_part(
                f"{var}_eye_{side}",
                parent=var,
                name=f"Eye{side}",
                size=(0.18, 0.18, 0.06),
                cframe=cframe_pos(dx, 5.05, 0.78),
                color_rgb=PALETTE.ink_dot,
                material_name="SmoothPlastic",
            )
        )
    # mouth dot
    p.line(
        make_part(
            f"{var}_mouth",
            parent=var,
            name="Mouth",
            size=(0.4, 0.1, 0.06),
            cframe=cframe_pos(0, 4.7, 0.78),
            color_rgb=PALETTE.blush,
            material_name="SmoothPlastic",
        )
    )

    # arms
    for side, dx in [("Left", -1.6), ("Right", 1.6)]:
        p.line(
            make_part(
                f"{var}_{side.lower()}arm",
                parent=var,
                name=f"{side}Arm",
                size=(1, 2.2, 1),
                cframe=cframe_pos(dx, 3, 0),
                color_rgb=skin_rgb,
                material_name="SmoothPlastic",
            )
        )
    # legs
    for side, dx in [("Left", -0.6), ("Right", 0.6)]:
        p.line(
            make_part(
                f"{var}_{side.lower()}leg",
                parent=var,
                name=f"{side}Leg",
                size=(1, 2, 1),
                cframe=cframe_pos(dx, 0.8, 0),
                color_rgb=accent_rgb,
                material_name="SmoothPlastic",
            )
        )

    # accent overlays — one per kind
    if accent_kind == "apron":
        p.line(
            make_part(
                f"{var}_apron",
                parent=var,
                name="Apron",
                size=(2.6, 2, 1.4),
                cframe=cframe_pos(0, 2.6, 0.1),
                color_rgb=(255, 240, 240),
                material_name="SmoothPlastic",
            )
        )
        p.line(
            make_disc(
                f"{var}_hat",
                parent=var,
                name="VendorHat",
                diameter=1.6,
                height=0.6,
                cframe=cframe_pos(0, 6, 0),
                color_rgb=(255, 255, 255),
                material_name="SmoothPlastic",
            )
        )
    elif accent_kind == "uniform_badge":
        p.line(
            make_part(
                f"{var}_badge",
                parent=var,
                name="Badge",
                size=(0.4, 0.4, 0.05),
                cframe=cframe_pos(0.6, 3.5, 0.65),
                color_rgb=PALETTE.capsule_a,
                material_name="SmoothPlastic",
            )
        )
        p.line(
            make_disc(
                f"{var}_hat",
                parent=var,
                name="RangerHat",
                diameter=2.2,
                height=0.5,
                cframe=cframe_pos(0, 6, 0),
                color_rgb=PALETTE.ranger_green,
                material_name="SmoothPlastic",
            )
        )
    elif accent_kind == "stroller":
        p.line(make_model(f"{var}_stroller", parent=var, name="Stroller"))
        p.line(
            make_part(
                f"{var}_str_seat",
                parent=f"{var}_stroller",
                name="Seat",
                size=(1.4, 1.4, 1),
                cframe=cframe_pos(2.6, 1.5, 0),
                color_rgb=PALETTE.capsule_c,
                material_name="SmoothPlastic",
            )
        )
        p.line(
            make_part(
                f"{var}_str_handle",
                parent=f"{var}_stroller",
                name="Handle",
                size=(0.3, 1.6, 1),
                cframe=cframe_pos(2.6, 2.6, 0),
                color_rgb=PALETTE.wood_dark,
                material_name="Wood",
            )
        )
        for i, (ox, oz) in enumerate([(2, 0.6), (3.2, 0.6), (2, -0.6), (3.2, -0.6)]):
            p.line(
                make_part(
                    f"{var}_str_w{i}",
                    parent=f"{var}_stroller",
                    name="Wheel",
                    size=(0.5, 0.5, 0.5),
                    cframe=cframe_pos_yaw(ox, 0.3, oz, 90),
                    color_rgb=PALETTE.wood_dark,
                    material_name="SmoothPlastic",
                    shape="Cylinder",
                )
            )
    elif accent_kind == "sunglasses":
        p.line(
            make_part(
                f"{var}_glasses",
                parent=var,
                name="Sunglasses",
                size=(1.6, 0.3, 0.1),
                cframe=cframe_pos(0, 5.1, 0.85),
                color_rgb=PALETTE.ink_dot,
                material_name="SmoothPlastic",
            )
        )
    elif accent_kind == "hood":
        p.line(
            make_part(
                f"{var}_hood",
                parent=var,
                name="Hood",
                size=(2, 1.6, 2),
                cframe=cframe_pos(0, 5, -0.3),
                color_rgb=PALETTE.near_black,
                material_name="SmoothPlastic",
            )
        )
        p.line(
            make_part(
                f"{var}_hood_drape",
                parent=var,
                name="HoodDrape",
                size=(2.6, 0.8, 1.5),
                cframe=cframe_pos(0, 4.2, -0.6),
                color_rgb=PALETTE.near_black,
                material_name="SmoothPlastic",
            )
        )
    elif accent_kind == "car_lean":
        p.line(
            make_part(
                f"{var}_glasses",
                parent=var,
                name="Sunglasses",
                size=(1.6, 0.3, 0.1),
                cframe=cframe_pos(0, 5.1, 0.85),
                color_rgb=PALETTE.ink_dot,
                material_name="SmoothPlastic",
            )
        )
        p.line(
            make_part(
                f"{var}_arm_lean",
                parent=var,
                name="ArmLean",
                size=(0.5, 0.5, 2.5),
                cframe=cframe_pos(1.6, 3.6, 1.4),
                color_rgb=accent_rgb,
                material_name="SmoothPlastic",
            )
        )

    # trait card billboard — empty text by default; user 2 fills
    p.line(
        make_billboard_gui(
            f"{var}_trait",
            adornee=f"{var}_head",
            text="",
            studs_offset_y=2,
            text_size=22,
        )
    )
    # rename the gui to TraitCard so the scripting layer can find it
    p.line(f"{var}_trait.Name = {lua_string('TraitCard')}")

    # detachable knife accessory — server toggles enabled per round
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
                color_rgb=PALETTE.wood_dark,
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

    p.created(f"NpcTemplates/{npc_name}")


def emit_npc_templates_lua() -> str:
    p = LuaProgram()
    p.comment("buddy bridge npc templates — generated")

    p.line(find_or_create_path("ServerStorage", "NpcTemplates"))
    p.line("local templates_root = _path")
    # idempotency
    for name, *_ in _NPCS:
        p.line(clear_existing("templates_root", name))

    for name, skin, accent, kind, holds_knife in _NPCS:
        _emit_humanoid_rig(
            p,
            npc_name=name,
            skin_rgb=skin,
            accent_rgb=accent,
            accent_kind=kind,
            holds_knife=holds_knife,
        )

    p.note(f"built {len(_NPCS)} npc templates")
    return p.render()


__all__ = ["emit_npc_templates_lua"]
