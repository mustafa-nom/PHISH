"""build_play_arena_slots: 4 PlayArenaSlot models in a hidden region.

each slot under Workspace.PlayArenaSlots:
- Model named Slot1..Slot4 tagged PlayArenaSlot, attribute SlotIndex = i
- ExplorerSpawn part (tag ExplorerSpawn)
- BoothAnchor part (tag BoothAnchor)
- empty PlayArea Folder
- empty Booth Folder
- a small invisible-ish ground plane for visual reference

slots spaced PROPORTIONS.arena_slot_separation studs apart on the X axis at
y = PROPORTIONS.arena_slot_floor_y so they sit far below the lobby.
"""

from __future__ import annotations

from ..lua_emit import (
    LuaProgram,
    add_tag,
    cframe_pos,
    clear_existing,
    make_folder,
    make_model,
    make_part,
    set_attribute,
)
from ..style import PALETTE, PROPORTIONS, Tags, Attributes


def emit_play_arena_slots_lua(*, slot_count: int = 4) -> str:
    if slot_count < 1 or slot_count > 8:
        raise ValueError("slot_count must be 1..8")

    p = LuaProgram()
    p.comment("buddy bridge play arena slots — generated")

    # nuke + rebuild the container so re-runs are idempotent
    p.line(clear_existing("Workspace", "PlayArenaSlots"))
    p.line(make_folder("slots_root", parent="Workspace", name="PlayArenaSlots"))

    base_y = PROPORTIONS.arena_slot_floor_y
    sep = PROPORTIONS.arena_slot_separation

    for idx in range(slot_count):
        sx = idx * sep
        slot_var = f"slot_{idx}"
        slot_name = f"Slot{idx + 1}"
        p.line(make_model(slot_var, parent="slots_root", name=slot_name))
        p.line(add_tag(slot_var, Tags.PLAY_ARENA_SLOT))
        p.line(set_attribute(slot_var, Attributes.SLOT_INDEX, idx + 1))

        # ground plane sized to host both levels side by side (~150 studs of
        # play area each plus the booth offset)
        p.line(
            make_part(
                f"{slot_var}_floor",
                parent=slot_var,
                name="GroundPlane",
                size=(360, 2, 200),
                cframe=cframe_pos(sx, base_y - 1, 0),
                color_rgb=PALETTE.grass,
                material_name="Grass",
            )
        )

        # explorer spawn — small invisible-ish hex marker on the western edge
        p.line(
            make_part(
                f"{slot_var}_xspawn",
                parent=slot_var,
                name="ExplorerSpawn",
                size=(4, 1, 4),
                cframe=cframe_pos(sx - 100, base_y + 0.5, 0),
                color_rgb=PALETTE.sparkle,
                material_name="SmoothPlastic",
                shape="Cylinder",
                transparency=0.3,
                can_collide=False,
            )
        )
        p.line(add_tag(f"{slot_var}_xspawn", Tags.EXPLORER_SPAWN))

        # booth anchor — 30 studs to the side with sightline to play area
        p.line(
            make_part(
                f"{slot_var}_banchor",
                parent=slot_var,
                name="BoothAnchor",
                size=(2, 1, 2),
                cframe=cframe_pos(sx - 100, base_y + 0.5, -30),
                color_rgb=PALETTE.booth_trim,
                material_name="SmoothPlastic",
                transparency=0.5,
                can_collide=False,
            )
        )
        p.line(add_tag(f"{slot_var}_banchor", Tags.BOOTH_ANCHOR))

        # empty container folders for runtime cloning
        p.line(make_folder(f"{slot_var}_play", parent=slot_var, name="PlayArea"))
        p.line(make_folder(f"{slot_var}_booth", parent=slot_var, name="Booth"))

        p.created(f"PlayArenaSlots/{slot_name}")

    p.note(f"built {slot_count} play arena slot(s) at y={base_y}")
    return p.render()


__all__ = ["emit_play_arena_slots_lua"]
