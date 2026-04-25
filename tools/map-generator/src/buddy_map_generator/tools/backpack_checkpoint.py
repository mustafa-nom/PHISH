"""build_backpack_checkpoint: tsa-style sorting level under ServerStorage.Levels.

contains:
- conveyor visual (BeltStart / BeltEnd reference parts, tagged + named)
- 3 BuddyBin parts with LaneId attributes (PackIt / AskFirst / LeaveIt)
- ProximityPrompt on each bin
- LevelEntry, LevelExit, RoundFinishZone

server-side ScenarioService spawns items between BeltStart and BeltEnd.
"""

from __future__ import annotations

from ..lua_emit import (
    LuaProgram,
    add_tag,
    cframe_pos,
    cframe_pos_yaw,
    clear_existing,
    find_or_create_path,
    make_billboard_gui,
    make_disc,
    make_model,
    make_part,
    make_proximity_prompt,
    set_attribute,
    set_primary_part,
)
from ..style import PALETTE, Tags, Attributes


_BINS = [
    ("PackIt", "Pack It", PALETTE.bin_pack_it, -8),
    ("AskFirst", "Ask First", PALETTE.bin_ask_first, 0),
    ("LeaveIt", "Leave It", PALETTE.bin_leave_it, 8),
]


def emit_backpack_checkpoint_lua() -> str:
    p = LuaProgram()
    p.comment("buddy bridge backpack checkpoint level template — generated")

    p.line(find_or_create_path("ServerStorage", "Levels"))
    p.line("local levels_root = _path")
    p.line(clear_existing("levels_root", "BackpackCheckpoint"))

    p.line(make_model("level", parent="levels_root", name="BackpackCheckpoint"))
    p.line(set_attribute("level", Attributes.LEVEL_TYPE, "BackpackCheckpoint"))

    # primary part — invisible reference at the origin
    p.line(
        make_part(
            "level_origin",
            parent="level",
            name="LevelOrigin",
            size=(2, 0.2, 2),
            cframe=cframe_pos(0, 0, 0),
            color_rgb=PALETTE.sparkle,
            transparency=1,
            can_collide=False,
        )
    )
    p.line(set_primary_part("level", "level_origin"))

    # checkpoint floor
    p.line(
        make_part(
            "floor",
            parent="level",
            name="CheckpointFloor",
            size=(50, 0.6, 30),
            cframe=cframe_pos(0, 0.3, 0),
            color_rgb=PALETTE.fountain_stone,
            material_name="SmoothPlastic",
        )
    )
    # accent stripe down the middle (cartoon airport tile)
    p.line(
        make_part(
            "stripe",
            parent="level",
            name="FloorStripe",
            size=(50, 0.7, 4),
            cframe=cframe_pos(0, 0.35, 0),
            color_rgb=PALETTE.capsule_b,
            material_name="SmoothPlastic",
        )
    )

    # standing pad for the explorer (south of the belt)
    p.line(
        make_disc(
            "level_entry",
            parent="level",
            name="LevelEntry",
            diameter=4,
            height=1,
            cframe=cframe_pos(0, 0.7, -10),
            color_rgb=PALETTE.sparkle,
            transparency=0.4,
            can_collide=False,
        )
    )
    p.line(add_tag("level_entry", Tags.LEVEL_ENTRY))

    # conveyor belt — long flat segment with cartoon arrows on top
    p.line(make_model("belt", parent="level", name="ConveyorBelt"))
    p.line(add_tag("belt", Tags.BUDDY_CONVEYOR))
    p.line(
        make_part(
            "belt_surface",
            parent="belt",
            name="BeltSurface",
            size=(36, 0.8, 4),
            cframe=cframe_pos(0, 1, 4),
            color_rgb=PALETTE.wood_dark,
            material_name="SmoothPlastic",
        )
    )
    # arrows — three short stripes
    for idx, ax in enumerate([-12, 0, 12]):
        p.line(
            make_part(
                f"belt_arrow_{idx}",
                parent="belt",
                name=f"BeltArrow{idx}",
                size=(4, 0.85, 0.8),
                cframe=cframe_pos_yaw(ax, 1.4, 4, 0),
                color_rgb=PALETTE.sparkle,
                material_name="SmoothPlastic",
            )
        )
    # belt rails
    for side, sz in [("LFront", 6), ("RBack", 2)]:
        rail_z = sz
        p.line(
            make_part(
                f"belt_rail_{side}",
                parent="belt",
                name=f"BeltRail{side}",
                size=(36, 0.4, 0.4),
                cframe=cframe_pos(0, 1.4, rail_z),
                color_rgb=PALETTE.wood_warm,
                material_name="Wood",
            )
        )

    # belt start — east end (items spawn here)
    p.line(
        make_part(
            "belt_start",
            parent="belt",
            name="BeltStart",
            size=(2, 0.4, 4),
            cframe=cframe_pos(-18, 1.6, 4),
            color_rgb=PALETTE.bin_pack_it,
            material_name="SmoothPlastic",
            transparency=0.4,
            can_collide=False,
        )
    )
    p.line(add_tag("belt_start", Tags.BELT_START))

    # belt end — west end (items disappear)
    p.line(
        make_part(
            "belt_end",
            parent="belt",
            name="BeltEnd",
            size=(2, 0.4, 4),
            cframe=cframe_pos(18, 1.6, 4),
            color_rgb=PALETTE.bin_leave_it,
            material_name="SmoothPlastic",
            transparency=0.4,
            can_collide=False,
        )
    )
    p.line(add_tag("belt_end", Tags.BELT_END))

    # back wall behind the belt — bins mount on this
    p.line(
        make_part(
            "back_wall",
            parent="level",
            name="BackWall",
            size=(50, 12, 1),
            cframe=cframe_pos(0, 6, 8),
            color_rgb=PALETTE.booth_wall,
            material_name="SmoothPlastic",
        )
    )

    # 3 bins along the back wall
    for lane_id, label, color, x_offset in _BINS:
        bin_var = f"bin_{lane_id}"
        p.line(
            make_part(
                bin_var,
                parent="level",
                name=f"{lane_id}Bin",
                size=(8, 6, 4),
                cframe=cframe_pos(x_offset, 3, 6),
                color_rgb=color,
                material_name="SmoothPlastic",
            )
        )
        p.line(add_tag(bin_var, Tags.BUDDY_BIN))
        p.line(set_attribute(bin_var, Attributes.LANE_ID, lane_id))
        p.line(
            make_billboard_gui(
                f"{bin_var}_gui",
                adornee=bin_var,
                text=label.upper(),
                studs_offset_y=4,
                text_size=36,
            )
        )
        p.line(
            make_proximity_prompt(
                f"{bin_var}_prompt",
                adornee=bin_var,
                action_text=f"Drop in {label}",
                object_text=label,
            )
        )
        p.created(f"BackpackCheckpoint/Bin/{lane_id}")

    # level exit — north of the bins (between bin and back wall edges)
    p.line(
        make_part(
            "level_exit",
            parent="level",
            name="LevelExit",
            size=(8, 4, 4),
            cframe=cframe_pos(20, 2, 6),
            color_rgb=PALETTE.sparkle,
            transparency=0.85,
            can_collide=False,
        )
    )
    p.line(add_tag("level_exit", Tags.LEVEL_EXIT))

    # round finish zone — beyond the level exit (triggers score screen)
    p.line(
        make_part(
            "finish",
            parent="level",
            name="RoundFinishZone",
            size=(8, 4, 6),
            cframe=cframe_pos(28, 2, 6),
            color_rgb=PALETTE.capsule_a,
            transparency=0.85,
            can_collide=False,
        )
    )
    p.line(add_tag("finish", Tags.ROUND_FINISH_ZONE))

    p.note("BackpackCheckpoint template built")
    p.created("Levels/BackpackCheckpoint")
    return p.render()


__all__ = ["emit_backpack_checkpoint_lua"]
