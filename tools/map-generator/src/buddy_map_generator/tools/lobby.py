"""build_lobby: lobby hub model with welcome sign, spawn, treehouse, capsule pads.

cartoon park aesthetic — warm sandy ground, polygonal stone path wedges,
stacked-cone trees, cottage huts with red pitched roofs. matches the
reference style ("wildlife park" cartoon look) so judges immediately read
it as a cozy roblox social space, not a default baseplate.

map object conventions:
- Workspace.Lobby (Model)
- Workspace.Lobby.SpawnLocation
- 4 capsule pad pairs (8 pads total) tagged LobbyCapsule
  with CapsuleId + CapsulePairId attributes
- BillboardGui over each pad: "Step here to find a buddy"
- decorative cottage huts + cone-stack trees ring the play area
"""

from __future__ import annotations

import math

from ..lua_emit import (
    LuaProgram,
    add_tag,
    cframe_pos,
    cframe_pos_yaw,
    clear_existing,
    lua_string,
    make_billboard_gui,
    make_disc,
    make_model,
    make_part,
    set_attribute,
)
from ..style import PALETTE, Tags, Attributes
from ._props import emit_cone_tree, emit_cottage, emit_polygonal_path


# capsule pad colors keyed by pair index
_PAIR_COLORS = [
    PALETTE.capsule_a,
    PALETTE.capsule_b,
    PALETTE.capsule_c,
    PALETTE.capsule_d,
]


def emit_lobby_lua(
    *,
    pair_count: int = 4,
    origin: tuple[float, float, float] = (0, 0, 0),
) -> str:
    """return a complete lua program that builds the lobby."""
    if pair_count < 1 or pair_count > 8:
        raise ValueError("pair_count must be 1..8")

    p = LuaProgram()
    p.comment("buddy bridge lobby — cartoon park aesthetic")

    ox, oy, oz = origin
    # idempotency: nuke any existing lobby + the studio-default baseplate /
    # spawn so re-running on a fresh place is one call instead of three.
    p.line(clear_existing("Workspace", "Lobby"))
    p.line(clear_existing("Workspace", "Baseplate"))
    p.line(clear_existing("Workspace", "SpawnLocation"))

    p.line(make_model("lobby", parent="Workspace", name="Lobby"))

    # ground plane — warm sandy field, not green grass. matches the reference.
    p.line(
        make_part(
            "ground",
            parent="lobby",
            name="LobbyGround",
            size=(240, 2, 240),
            cframe=cframe_pos(ox, oy - 1, oz),
            color_rgb=PALETTE.sand_warm,
            material_name="Sand",
        )
    )

    # polygonal stone path runs from spawn to the welcome sign
    p.line(make_model("path_model", parent="lobby", name="WelcomePath"))
    emit_polygonal_path(
        p,
        var_prefix="step",
        parent="path_model",
        points=[
            (ox, oz - 50),
            (ox - 1, oz - 42),
            (ox + 1, oz - 34),
            (ox - 1, oz - 26),
            (ox + 1, oz - 18),
            (ox, oz - 10),
            (ox, oz - 2),
            (ox, oz + 6),
            (ox, oz + 14),
        ],
        base_y=oy,
    )

    # spawn location at the south end of the path — kept neutral plastic
    p.line(
        f"local spawn_part = Instance.new(\"SpawnLocation\")\n"
        f"spawn_part.Name = \"LobbySpawn\"\n"
        f"spawn_part.Size = Vector3.new(8, 1, 8)\n"
        f"spawn_part.CFrame = {cframe_pos(ox, oy + 0.5, oz - 56)}\n"
        f"spawn_part.Anchored = true\n"
        f"spawn_part.Material = Enum.Material.SmoothPlastic\n"
        f"spawn_part.Color = {color_palette('cottage_wall')}\n"
        f"spawn_part.TopSurface = Enum.SurfaceType.Smooth\n"
        f"spawn_part.Neutral = true\n"
        f"spawn_part.Parent = lobby"
    )

    # welcome sign + mission subtitle — billboard guis spawn 4 sub-locals each
    # so we scope the whole section in a do/end to keep the chunk under cap
    p.line("do")
    p.line(
        make_part(
            "sign_post_l",
            parent="lobby",
            name="WelcomePost1",
            size=(1.0, 9, 1.0),
            cframe=cframe_pos(ox - 6, oy + 4.5, oz + 18),
            color_rgb=PALETTE.cottage_trim,
            material_name="Wood",
        )
    )
    p.line(
        make_part(
            "sign_post_r",
            parent="lobby",
            name="WelcomePost2",
            size=(1.0, 9, 1.0),
            cframe=cframe_pos(ox + 6, oy + 4.5, oz + 18),
            color_rgb=PALETTE.cottage_trim,
            material_name="Wood",
        )
    )
    p.line(
        make_part(
            "sign_face",
            parent="lobby",
            name="WelcomeBoard",
            size=(13, 4, 0.6),
            cframe=cframe_pos(ox, oy + 7, oz + 18),
            color_rgb=PALETTE.sign_face,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_billboard_gui(
            "welcome_gui",
            adornee="sign_face",
            text="Buddy Bridge — Find a buddy and start a run",
            studs_offset_y=4,
            text_size=42,
        )
    )
    # mission subtitle
    p.line(
        make_part(
            "mission_face",
            parent="lobby",
            name="MissionBoard",
            size=(11, 1.6, 0.3),
            cframe=cframe_pos(ox, oy + 4.5, oz + 18),
            color_rgb=PALETTE.sign_face,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_billboard_gui(
            "mission_gui",
            adornee="mission_face",
            text="Pause. Talk. Choose together.",
            studs_offset_y=1.5,
            text_size=28,
        )
    )
    p.line("end")

    # central treehouse — hero feature: tall trunk with cottage perched on top
    # ringed by a cone-tree cluster so it reads as the lobby focal point.
    # whole block scoped so its trunk + 4 canopy locals (and emit_cottage's
    # locals) get released after the treehouse is built.
    p.line("do")
    p.line(make_model("treehouse", parent="lobby", name="Treehouse"))
    p.line(
        make_part(
            "th_trunk",
            parent="treehouse",
            name="Trunk",
            size=(6, 22, 6),
            cframe=cframe_pos(ox + 60, oy + 11, oz - 10),
            color_rgb=PALETTE.cottage_trim,
            material_name="Wood",
        )
    )
    for idx, (cx, cy, cz, cs, color) in enumerate(
        [
            (ox + 60, oy + 26, oz - 10, 14, PALETTE.tree_top_dark),
            (ox + 56, oy + 28, oz - 14, 10, PALETTE.tree_top_mid),
            (ox + 64, oy + 28, oz - 6, 10, PALETTE.tree_top_mid),
            (ox + 60, oy + 31, oz - 10, 7, PALETTE.tree_top_light),
        ]
    ):
        p.line(
            make_part(
                f"th_leaf_{idx}",
                parent="treehouse",
                name=f"Canopy{idx}",
                size=(cs, cs, cs),
                cframe=cframe_pos(cx, cy, cz),
                color_rgb=color,
                material_name="Grass",
                shape="Ball",
            )
        )
    # cottage cabin perched on the trunk
    emit_cottage(
        p,
        var_prefix="th_cabin",
        parent="treehouse",
        cx=ox + 60,
        cz=oz - 10,
        base_y=oy + 22,
        yaw_deg=180,
        width=10,
        depth=8,
        wall_h=5,
    )
    p.created("Treehouse")
    p.line("end")

    # capsule pads — four pairs in a soft arc north of spawn
    arc_radius = 30
    for pair_idx in range(pair_count):
        if pair_count == 1:
            angle = 0
        else:
            spread_deg = 130
            angle = -spread_deg / 2 + spread_deg * pair_idx / (pair_count - 1)

        ang_rad = math.radians(angle)
        cx = ox + math.sin(ang_rad) * arc_radius
        cz = oz + 2 + (-math.cos(ang_rad) * arc_radius)
        pair_color = _PAIR_COLORS[pair_idx % len(_PAIR_COLORS)]

        # each pair builds in its own do/end so its arch + 2 pad locals are
        # released before the next pair's locals are declared
        p.line("do")
        # pair archway — two posts and a beam, signage stays simple
        p.line(
            make_part(
                f"arch_{pair_idx}",
                parent="lobby",
                name=f"PairArch{pair_idx + 1}",
                size=(7, 0.6, 0.6),
                cframe=cframe_pos(cx, oy + 8, cz),
                color_rgb=PALETTE.cottage_trim,
                material_name="Wood",
            )
        )
        p.line(
            make_part(
                f"arch_l_{pair_idx}",
                parent="lobby",
                name=f"PairArchPostL{pair_idx + 1}",
                size=(0.5, 8, 0.5),
                cframe=cframe_pos(cx - 3.5, oy + 4, cz),
                color_rgb=PALETTE.cottage_trim,
                material_name="Wood",
            )
        )
        p.line(
            make_part(
                f"arch_r_{pair_idx}",
                parent="lobby",
                name=f"PairArchPostR{pair_idx + 1}",
                size=(0.5, 8, 0.5),
                cframe=cframe_pos(cx + 3.5, oy + 4, cz),
                color_rgb=PALETTE.cottage_trim,
                material_name="Wood",
            )
        )
        p.line(
            make_billboard_gui(
                f"arch_label_{pair_idx}",
                adornee=f"arch_{pair_idx}",
                text=f"Buddy Pair {pair_idx + 1}",
                studs_offset_y=2,
                text_size=32,
            )
        )

        for side_idx, side_letter in enumerate(("a", "b")):
            offset = -3 if side_idx == 0 else 3
            pad_var = f"pad_{pair_idx}_{side_letter}"
            p.line(
                make_disc(
                    pad_var,
                    parent="lobby",
                    name=f"CapsulePad_{pair_idx + 1}{side_letter.upper()}",
                    diameter=6,
                    height=1,
                    cframe=cframe_pos(cx + offset, oy + 0.5, cz),
                    color_rgb=pair_color,
                    material_name="SmoothPlastic",
                )
            )
            p.line(add_tag(pad_var, Tags.LOBBY_CAPSULE))
            p.line(
                set_attribute(
                    pad_var,
                    Attributes.CAPSULE_ID,
                    f"capsule_{pair_idx + 1}{side_letter}",
                )
            )
            p.line(
                set_attribute(
                    pad_var,
                    Attributes.CAPSULE_PAIR_ID,
                    f"pair_{pair_idx + 1}",
                )
            )
            p.line(
                make_billboard_gui(
                    f"{pad_var}_gui",
                    adornee=pad_var,
                    text="Step here to find a buddy",
                    studs_offset_y=3,
                    text_size=22,
                )
            )
            p.created(f"CapsulePad_{pair_idx + 1}{side_letter.upper()}")
        p.line("end")

    # ----- decorative pass: cottages, trees, benches ringing the lobby
    p.line(make_model("decor", parent="lobby", name="Decor"))

    # corner cottages — soft "village" framing around the play space
    cottage_specs = [
        (-90, -60, 30, 12, 10),
        (90, -60, -30, 12, 10),
        (-95, 80, 90, 14, 11),
        (95, 80, -90, 14, 11),
    ]
    for i, (cx, cz, yaw, w, d) in enumerate(cottage_specs):
        emit_cottage(
            p,
            var_prefix=f"cottage_{i}",
            parent="decor",
            cx=ox + cx,
            cz=oz + cz,
            base_y=oy,
            yaw_deg=yaw,
            width=w,
            depth=d,
        )

    # cone-stack trees scattered around the perimeter at varying scales
    tree_positions = [
        (-100, -100, 1.0), (-60, -110, 0.9), (-20, -110, 1.1),
        (20, -110, 0.9), (60, -110, 1.0), (100, -100, 1.1),
        (-110, -50, 1.0), (-110, 0, 0.9), (-110, 50, 1.1),
        (110, -50, 1.1), (110, 0, 1.0), (110, 50, 0.9),
        (-100, 100, 1.0), (-50, 110, 0.9), (0, 110, 1.1),
        (50, 110, 0.9), (100, 100, 1.0),
        # mid-field clusters so the open field reads as a clearing, not empty
        (-40, -50, 0.85), (40, -55, 0.85), (-30, 60, 0.95), (35, 65, 0.95),
    ]
    for i, (tx, tz, scale) in enumerate(tree_positions):
        emit_cone_tree(
            p,
            var_prefix=f"tree_{i}",
            parent="decor",
            cx=ox + tx,
            cz=oz + tz,
            base_y=oy,
            scale=scale,
        )

    # park benches flanking the welcome path. each bench in its own do/end
    # block so the four part locals it spawns get released between iterations.
    bench_specs = [(-12, -25, 0), (12, -25, 0), (-12, 5, 0), (12, 5, 0)]
    for i, (bx, bz, _yaw) in enumerate(bench_specs):
        p.line("do")
        p.line(
            make_part(
                f"bench_seat_{i}",
                parent="decor",
                name=f"BenchSeat{i}",
                size=(5, 0.4, 1.4),
                cframe=cframe_pos(ox + bx, oy + 1.4, oz + bz),
                color_rgb=PALETTE.bench_wood,
                material_name="Wood",
            )
        )
        p.line(
            make_part(
                f"bench_back_{i}",
                parent="decor",
                name=f"BenchBack{i}",
                size=(5, 1.6, 0.3),
                cframe=cframe_pos(ox + bx, oy + 2.2, oz + bz - 0.6),
                color_rgb=PALETTE.bench_wood,
                material_name="Wood",
            )
        )
        for side, dx in (("L", -2.2), ("R", 2.2)):
            p.line(
                make_part(
                    f"bench_leg_{i}_{side}",
                    parent="decor",
                    name=f"BenchLeg{i}{side}",
                    size=(0.4, 1.4, 1.4),
                    cframe=cframe_pos(ox + bx + dx, oy + 0.7, oz + bz),
                    color_rgb=PALETTE.cottage_trim,
                    material_name="Wood",
                )
            )
        p.line("end")

    # flower bed flanking the welcome sign — same per-side do/end scoping
    flower_colors = [
        PALETTE.capsule_a,
        PALETTE.capsule_b,
        PALETTE.capsule_c,
        PALETTE.capsule_d,
    ]
    for side, side_x in (("L", -10), ("R", 10)):
        p.line("do")
        p.line(
            make_part(
                f"flowerbed_{side}",
                parent="decor",
                name=f"FlowerBed{side}",
                size=(8, 0.6, 4),
                cframe=cframe_pos(ox + side_x, oy + 0.4, oz + 16),
                color_rgb=PALETTE.cottage_trim,
                material_name="Wood",
            )
        )
        for j, fx in enumerate((-3, -1, 1, 3)):
            p.line(
                make_part(
                    f"flower_{side}_{j}",
                    parent="decor",
                    name=f"Flower{side}{j}",
                    size=(1, 1, 1),
                    cframe=cframe_pos(ox + side_x + fx, oy + 1.2, oz + 16),
                    color_rgb=flower_colors[j % len(flower_colors)],
                    material_name="SmoothPlastic",
                    shape="Ball",
                )
            )
        p.line("end")

    p.note(f"lobby built with {pair_count} capsule pair(s)")
    return p.render()


def color_palette(field_name: str) -> str:
    """small accessor used inside f-strings — keeps lua emission readable."""
    rgb = getattr(PALETTE, field_name)
    return f"Color3.fromRGB({rgb[0]}, {rgb[1]}, {rgb[2]})"


__all__ = ["emit_lobby_lua"]
_ = lua_string  # keep import parity with sibling tools
