"""build_booth_template: cozy guide booth in ServerStorage/GuideBooths.

DefaultBooth model:
- ~12x12 enclosed cabin (no door — guide can't walk out)
- PrimaryPart on a reference part at the floor center
- GuideSpawn part inside (tag GuideSpawn)
- ControlPanel part on the front wall with a SurfaceGui mounted on top face
- Window — transparent, CanCollide false, on the wall facing the play area

theme cue: "lookout post" or "lighthouse cabin", not corporate ops center.
"""

from __future__ import annotations

from ..lua_emit import (
    LuaProgram,
    add_tag,
    cframe_pos,
    clear_existing,
    find_or_create_path,
    make_billboard_gui,
    make_model,
    make_part,
    make_surface_gui,
    set_primary_part,
)
from ..style import PALETTE, Tags


def emit_booth_template_lua() -> str:
    p = LuaProgram()
    p.comment("buddy bridge default booth template — generated")

    p.line(find_or_create_path("ServerStorage", "GuideBooths"))
    p.line("local booths_root = _path")
    p.line(clear_existing("booths_root", "DefaultBooth"))

    p.line(make_model("booth", parent="booths_root", name="DefaultBooth"))

    # primary part — invisible at floor center
    p.line(
        make_part(
            "booth_origin",
            parent="booth",
            name="BoothOrigin",
            size=(2, 0.2, 2),
            cframe=cframe_pos(0, 0, 0),
            color_rgb=PALETTE.sparkle,
            transparency=1,
            can_collide=False,
        )
    )
    p.line(set_primary_part("booth", "booth_origin"))

    # floor
    p.line(
        make_part(
            "booth_floor",
            parent="booth",
            name="Floor",
            size=(12, 0.4, 12),
            cframe=cframe_pos(0, 0.2, 0),
            color_rgb=PALETTE.wood_warm,
            material_name="WoodPlanks",
        )
    )

    # walls — front (window), back, left, right. all SmoothPlastic, warm cream.
    wall_color = PALETTE.booth_wall
    trim = PALETTE.booth_trim

    # back wall
    p.line(
        make_part(
            "wall_back",
            parent="booth",
            name="BackWall",
            size=(12, 8, 0.6),
            cframe=cframe_pos(0, 4.4, -6),
            color_rgb=wall_color,
            material_name="SmoothPlastic",
        )
    )
    # left wall
    p.line(
        make_part(
            "wall_left",
            parent="booth",
            name="LeftWall",
            size=(0.6, 8, 12),
            cframe=cframe_pos(-6, 4.4, 0),
            color_rgb=wall_color,
            material_name="SmoothPlastic",
        )
    )
    # right wall
    p.line(
        make_part(
            "wall_right",
            parent="booth",
            name="RightWall",
            size=(0.6, 8, 12),
            cframe=cframe_pos(6, 4.4, 0),
            color_rgb=wall_color,
            material_name="SmoothPlastic",
        )
    )
    # front wall — split into two narrow walls leaving a gap for the window
    p.line(
        make_part(
            "wall_front_l",
            parent="booth",
            name="FrontWallL",
            size=(3, 8, 0.6),
            cframe=cframe_pos(-4.5, 4.4, 6),
            color_rgb=wall_color,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "wall_front_r",
            parent="booth",
            name="FrontWallR",
            size=(3, 8, 0.6),
            cframe=cframe_pos(4.5, 4.4, 6),
            color_rgb=wall_color,
            material_name="SmoothPlastic",
        )
    )
    # top trim above the window
    p.line(
        make_part(
            "wall_front_top",
            parent="booth",
            name="FrontWallTop",
            size=(6, 2, 0.6),
            cframe=cframe_pos(0, 7.4, 6),
            color_rgb=wall_color,
            material_name="SmoothPlastic",
        )
    )
    # bottom trim below the window
    p.line(
        make_part(
            "wall_front_bot",
            parent="booth",
            name="FrontWallBot",
            size=(6, 1.5, 0.6),
            cframe=cframe_pos(0, 1.15, 6),
            color_rgb=wall_color,
            material_name="SmoothPlastic",
        )
    )

    # window — transparent, no-collide, fills the gap in front
    p.line(
        make_part(
            "window",
            parent="booth",
            name="Window",
            size=(6, 4.5, 0.4),
            cframe=cframe_pos(0, 4.15, 6),
            color_rgb=PALETTE.booth_window,
            material_name="SmoothPlastic",
            transparency=0.5,
            can_collide=False,
        )
    )

    # roof — chunky cottage feel
    p.line(
        make_part(
            "roof",
            parent="booth",
            name="Roof",
            size=(13, 0.6, 13),
            cframe=cframe_pos(0, 8.7, 0),
            color_rgb=trim,
            material_name="WoodPlanks",
        )
    )
    # roof cap (slightly raised)
    p.line(
        make_part(
            "roof_cap",
            parent="booth",
            name="RoofCap",
            size=(8, 1, 13),
            cframe=cframe_pos(0, 9.5, 0),
            color_rgb=PALETTE.wood_dark,
            material_name="WoodPlanks",
        )
    )

    # control panel — desk-height block in front of the window
    p.line(
        make_part(
            "panel",
            parent="booth",
            name="ControlPanel",
            size=(6, 3, 1.5),
            cframe=cframe_pos(0, 2.4, 4.5),
            color_rgb=trim,
            material_name="WoodPlanks",
        )
    )
    p.line(make_surface_gui("panel_gui", adornee="panel", face="Top"))

    # guide spawn — invisible reference inside the booth
    p.line(
        make_part(
            "guide_spawn",
            parent="booth",
            name="GuideSpawn",
            size=(2, 1, 2),
            cframe=cframe_pos(0, 0.6, -2),
            color_rgb=PALETTE.sparkle,
            transparency=0.6,
            can_collide=False,
            shape="Cylinder",
        )
    )
    p.line(add_tag("guide_spawn", Tags.GUIDE_SPAWN))

    # cozy detail — a tiny cabin lantern sign above the door-less front
    p.line(
        make_part(
            "lantern",
            parent="booth",
            name="Lantern",
            size=(1.2, 1.2, 1.2),
            cframe=cframe_pos(0, 8.4, 6.4),
            color_rgb=PALETTE.sparkle,
            material_name="SmoothPlastic",
            shape="Ball",
        )
    )
    p.line(
        make_billboard_gui(
            "lantern_label",
            adornee="lantern",
            text="Buddy Booth",
            studs_offset_y=1.6,
            text_size=22,
        )
    )

    p.note("DefaultBooth template built")
    p.created("GuideBooths/DefaultBooth")
    return p.render()


__all__ = ["emit_booth_template_lua"]
