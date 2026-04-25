"""build_item_templates: 13 cartoon item models in ServerStorage/ItemTemplates.

each model is named exactly its ItemKey from docs/GAME_DESIGN.md so the
scripting layer can clone by name. items are anchored, have PrimaryPart set,
and use the visual style bible's palette.
"""

from __future__ import annotations

from typing import Callable

from ..lua_emit import (
    LuaProgram,
    cframe_pos,
    cframe_pos_yaw,
    clear_existing,
    find_or_create_path,
    make_billboard_gui,
    make_model,
    make_part,
    set_primary_part,
)
from ..style import PALETTE


def _emit_simple_item(
    p: LuaProgram,
    name: str,
    primary_emitter: Callable[[str, str], None],
) -> None:
    """create a Model + a "Root" part as PrimaryPart, then call emitter."""
    var = f"item_{name.lower()}"
    p.line(make_model(var, parent="templates_root", name=name))
    p.line(
        make_part(
            f"{var}_root",
            parent=var,
            name="Root",
            size=(0.4, 0.4, 0.4),
            cframe=cframe_pos(0, 1, 0),
            color_rgb=PALETTE.sparkle,
            transparency=1,
            can_collide=False,
        )
    )
    p.line(set_primary_part(var, f"{var}_root"))
    primary_emitter(var, name)
    p.created(f"ItemTemplates/{name}")


# each builder takes (parent_var, item_name) and appends parts. they must keep
# size around the 1-2 stud range so items read on the conveyor belt.
def _favorite_game(p: LuaProgram, parent: str, _name: str) -> None:
    # game controller — chunky pad with two grips and two thumbsticks
    p.line(
        make_part(
            f"{parent}_pad",
            parent=parent,
            name="ControllerBody",
            size=(2, 0.8, 1.2),
            cframe=cframe_pos(0, 1, 0),
            color_rgb=PALETTE.capsule_b,
            material_name="SmoothPlastic",
        )
    )
    for side, dx in [("L", -0.9), ("R", 0.9)]:
        p.line(
            make_part(
                f"{parent}_grip_{side}",
                parent=parent,
                name=f"Grip{side}",
                size=(0.6, 0.6, 0.8),
                cframe=cframe_pos(dx, 0.7, 0),
                color_rgb=PALETTE.capsule_b,
                material_name="SmoothPlastic",
            )
        )
    for side, dx in [("L", -0.4), ("R", 0.4)]:
        p.line(
            make_part(
                f"{parent}_stick_{side}",
                parent=parent,
                name=f"Stick{side}",
                size=(0.3, 0.3, 0.3),
                cframe=cframe_pos(dx, 1.4, 0),
                color_rgb=(60, 60, 64),
                material_name="SmoothPlastic",
                shape="Ball",
            )
        )


def _favorite_color(p: LuaProgram, parent: str, _name: str) -> None:
    # paint palette — wide flat oval with five color blobs
    p.line(
        make_part(
            f"{parent}_palette",
            parent=parent,
            name="Palette",
            size=(2, 0.2, 1.4),
            cframe=cframe_pos(0, 1, 0),
            color_rgb=PALETTE.sign_face,
            material_name="SmoothPlastic",
        )
    )
    blobs = [
        (-0.7, 0.4, PALETTE.bin_leave_it),
        (-0.3, 0.4, PALETTE.bin_ask_first),
        (0.1, 0.4, PALETTE.bin_pack_it),
        (0.5, 0.4, PALETTE.capsule_b),
        (0.85, 0.4, PALETTE.capsule_c),
    ]
    for i, (bx, bz, color) in enumerate(blobs):
        p.line(
            make_part(
                f"{parent}_blob_{i}",
                parent=parent,
                name=f"Blob{i}",
                size=(0.3, 0.15, 0.3),
                cframe=cframe_pos(bx, 1.15, bz),
                color_rgb=color,
                material_name="SmoothPlastic",
                shape="Cylinder",
            )
        )


def _funny_meme(p: LuaProgram, parent: str, _name: str) -> None:
    p.line(
        make_part(
            f"{parent}_card",
            parent=parent,
            name="MemeCard",
            size=(1.6, 1, 0.1),
            cframe=cframe_pos(0, 1, 0),
            color_rgb=(255, 255, 255),
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_billboard_gui(
            f"{parent}_card_label",
            adornee=f"{parent}_card",
            text="LOL",
            studs_offset_y=0.6,
            text_size=24,
        )
    )


def _pet_drawing(p: LuaProgram, parent: str, _name: str) -> None:
    p.line(
        make_part(
            f"{parent}_paper",
            parent=parent,
            name="Drawing",
            size=(1.6, 1, 0.05),
            cframe=cframe_pos(0, 1, 0),
            color_rgb=(255, 252, 232),
            material_name="SmoothPlastic",
        )
    )
    # blob "pet" doodle
    p.line(
        make_part(
            f"{parent}_pet",
            parent=parent,
            name="Pet",
            size=(0.6, 0.4, 0.06),
            cframe=cframe_pos(0, 1, 0.05),
            color_rgb=PALETTE.wood_warm,
            material_name="SmoothPlastic",
        )
    )


def _real_name(p: LuaProgram, parent: str, _name: str) -> None:
    # name tag with handwritten name slot
    p.line(
        make_part(
            f"{parent}_tag",
            parent=parent,
            name="NameTag",
            size=(1.6, 1, 0.08),
            cframe=cframe_pos(0, 1, 0),
            color_rgb=PALETTE.sign_face,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_billboard_gui(
            f"{parent}_tag_label",
            adornee=f"{parent}_tag",
            text="HELLO MY NAME IS",
            studs_offset_y=0.7,
            text_size=18,
        )
    )


def _personal_photo(p: LuaProgram, parent: str, _name: str) -> None:
    # polaroid frame
    p.line(
        make_part(
            f"{parent}_frame",
            parent=parent,
            name="Polaroid",
            size=(1.4, 1.6, 0.08),
            cframe=cframe_pos(0, 1, 0),
            color_rgb=(252, 252, 248),
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{parent}_photo",
            parent=parent,
            name="Photo",
            size=(1.1, 1.1, 0.09),
            cframe=cframe_pos(0, 1.15, 0.01),
            color_rgb=PALETTE.capsule_b,
            material_name="SmoothPlastic",
        )
    )


def _birthday(p: LuaProgram, parent: str, _name: str) -> None:
    p.line(
        make_part(
            f"{parent}_balloon",
            parent=parent,
            name="Balloon",
            size=(1.2, 1.6, 1.2),
            cframe=cframe_pos(0, 1.5, 0),
            color_rgb=PALETTE.capsule_a,
            material_name="SmoothPlastic",
            shape="Ball",
        )
    )
    p.line(
        make_part(
            f"{parent}_string",
            parent=parent,
            name="String",
            size=(0.05, 1.2, 0.05),
            cframe=cframe_pos(0, 0.7, 0),
            color_rgb=(255, 255, 255),
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_billboard_gui(
            f"{parent}_balloon_label",
            adornee=f"{parent}_balloon",
            text="BIRTHDAY",
            studs_offset_y=1.2,
            text_size=22,
        )
    )


def _big_achievement(p: LuaProgram, parent: str, _name: str) -> None:
    # trophy
    p.line(
        make_part(
            f"{parent}_base",
            parent=parent,
            name="Base",
            size=(1.2, 0.4, 1.2),
            cframe=cframe_pos(0, 0.6, 0),
            color_rgb=PALETTE.wood_dark,
            material_name="Wood",
        )
    )
    p.line(
        make_part(
            f"{parent}_stem",
            parent=parent,
            name="Stem",
            size=(0.4, 1.2, 0.4),
            cframe=cframe_pos(0, 1.4, 0),
            color_rgb=(252, 208, 88),
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{parent}_cup",
            parent=parent,
            name="Cup",
            size=(1.2, 0.8, 1.2),
            cframe=cframe_pos(0, 2.4, 0),
            color_rgb=(252, 208, 88),
            material_name="SmoothPlastic",
        )
    )


def _home_address(p: LuaProgram, parent: str, _name: str) -> None:
    # glowing tiny house
    p.line(
        make_part(
            f"{parent}_house",
            parent=parent,
            name="House",
            size=(1.4, 1, 1.4),
            cframe=cframe_pos(0, 1, 0),
            color_rgb=PALETTE.sparkle,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{parent}_roof",
            parent=parent,
            name="Roof",
            size=(1.6, 0.8, 1.6),
            cframe=cframe_pos_yaw(0, 1.9, 0, 0),
            color_rgb=PALETTE.bin_leave_it,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{parent}_door",
            parent=parent,
            name="Door",
            size=(0.4, 0.7, 0.05),
            cframe=cframe_pos(0, 0.8, 0.7),
            color_rgb=PALETTE.wood_dark,
            material_name="Wood",
        )
    )


def _school_name(p: LuaProgram, parent: str, _name: str) -> None:
    # school crest banner
    p.line(
        make_part(
            f"{parent}_banner",
            parent=parent,
            name="Banner",
            size=(1.4, 1.8, 0.1),
            cframe=cframe_pos(0, 1.2, 0),
            color_rgb=PALETTE.bin_leave_it,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{parent}_crest",
            parent=parent,
            name="Crest",
            size=(0.9, 1.1, 0.12),
            cframe=cframe_pos(0, 1.3, 0.01),
            color_rgb=PALETTE.sign_face,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_billboard_gui(
            f"{parent}_banner_label",
            adornee=f"{parent}_banner",
            text="SCHOOL",
            studs_offset_y=0.8,
            text_size=22,
        )
    )


def _password(p: LuaProgram, parent: str, _name: str) -> None:
    # padlock card
    p.line(
        make_part(
            f"{parent}_card",
            parent=parent,
            name="Card",
            size=(1.4, 1.8, 0.1),
            cframe=cframe_pos(0, 1.2, 0),
            color_rgb=(60, 60, 64),
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{parent}_lock_body",
            parent=parent,
            name="LockBody",
            size=(0.8, 0.8, 0.15),
            cframe=cframe_pos(0, 1, 0.05),
            color_rgb=(252, 208, 88),
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{parent}_lock_shackle",
            parent=parent,
            name="Shackle",
            size=(0.5, 0.5, 0.15),
            cframe=cframe_pos(0, 1.55, 0.05),
            color_rgb=(180, 180, 192),
            material_name="SmoothPlastic",
        )
    )


def _phone_number(p: LuaProgram, parent: str, _name: str) -> None:
    p.line(
        make_part(
            f"{parent}_body",
            parent=parent,
            name="PhoneBody",
            size=(0.8, 1.6, 0.15),
            cframe=cframe_pos(0, 1, 0),
            color_rgb=(60, 60, 64),
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{parent}_screen",
            parent=parent,
            name="Screen",
            size=(0.7, 1.4, 0.18),
            cframe=cframe_pos(0, 1, 0.01),
            color_rgb=PALETTE.fountain_water,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_billboard_gui(
            f"{parent}_phone_label",
            adornee=f"{parent}_body",
            text="555-HOME",
            studs_offset_y=1,
            text_size=20,
        )
    )


def _private_secret(p: LuaProgram, parent: str, _name: str) -> None:
    # locked diary
    p.line(
        make_part(
            f"{parent}_book",
            parent=parent,
            name="Diary",
            size=(1.3, 1.6, 0.4),
            cframe=cframe_pos(0, 1.1, 0),
            color_rgb=PALETTE.bin_leave_it,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            f"{parent}_clasp",
            parent=parent,
            name="Clasp",
            size=(0.3, 0.3, 0.45),
            cframe=cframe_pos(0.65, 1.1, 0),
            color_rgb=(252, 208, 88),
            material_name="SmoothPlastic",
        )
    )


_BUILDERS: list[tuple[str, Callable[[LuaProgram, str, str], None]]] = [
    ("FavoriteGame", _favorite_game),
    ("FavoriteColor", _favorite_color),
    ("FunnyMeme", _funny_meme),
    ("PetDrawing", _pet_drawing),
    ("RealName", _real_name),
    ("PersonalPhoto", _personal_photo),
    ("Birthday", _birthday),
    ("BigAchievement", _big_achievement),
    ("HomeAddress", _home_address),
    ("SchoolName", _school_name),
    ("Password", _password),
    ("PhoneNumber", _phone_number),
    ("PrivateSecret", _private_secret),
]


def emit_item_templates_lua() -> str:
    p = LuaProgram()
    p.comment("buddy bridge item templates — generated")

    p.line(find_or_create_path("ServerStorage", "ItemTemplates"))
    p.line("local templates_root = _path")

    for name, _ in _BUILDERS:
        p.line(clear_existing("templates_root", name))

    for name, builder in _BUILDERS:
        _emit_simple_item(p, name, lambda parent, n, b=builder: b(p, parent, n))

    p.note(f"built {len(_BUILDERS)} item templates")
    return p.render()


__all__ = ["emit_item_templates_lua"]
