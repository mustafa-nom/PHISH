"""shared decorative props used by both the lobby and stranger danger park.

these are higher-level than lua_emit primitives — they assemble several parts
into a single named cluster (a cottage, a cone-stack tree, a polygonal
stone path). centralized here so the lobby and the city corners share the
same visual identity.
"""

from __future__ import annotations

import math

from ..lua_emit import (
    LuaProgram,
    cframe_pos,
    cframe_pos_yaw,
    make_part,
    make_wedge,
)
from ..style import PALETTE


def emit_cone_tree(
    p: LuaProgram,
    *,
    var_prefix: str,
    parent: str,
    cx: float,
    cz: float,
    base_y: float = 0,
    scale: float = 1.0,
) -> None:
    """tall thin trunk + three stacked green layers.

    body wrapped in `do ... end` so the four part-local variables get freed
    after the tree finishes — lua's 200-local-per-function cap eats lobbies
    fast otherwise.
    """
    trunk_h = 8 * scale
    p.line("do")
    p.line(
        make_part(
            f"{var_prefix}_trunk",
            parent=parent,
            name="Trunk",
            size=(1.6 * scale, trunk_h, 1.6 * scale),
            cframe=cframe_pos(cx, base_y + trunk_h / 2, cz),
            color_rgb=PALETTE.cottage_trim,
            material_name="Wood",
        )
    )
    layers = [
        (PALETTE.tree_top_dark, 8.0 * scale, trunk_h + 1.5 * scale),
        (PALETTE.tree_top_mid, 6.5 * scale, trunk_h + 4.5 * scale),
        (PALETTE.tree_top_light, 4.5 * scale, trunk_h + 7.5 * scale),
    ]
    for idx, (rgb, dim, cy) in enumerate(layers):
        p.line(
            make_part(
                f"{var_prefix}_layer_{idx}",
                parent=parent,
                name=f"Canopy{idx}",
                size=(dim, dim, dim),
                cframe=cframe_pos(cx, base_y + cy, cz),
                color_rgb=rgb,
                material_name="Grass",
                shape="Ball",
            )
        )
    p.line("end")


def emit_cottage(
    p: LuaProgram,
    *,
    var_prefix: str,
    parent: str,
    cx: float,
    cz: float,
    base_y: float = 0,
    yaw_deg: float = 0,
    width: float = 12,
    depth: float = 10,
    wall_h: float = 6,
    wall_color: tuple[int, int, int] | None = None,
    roof_color: tuple[int, int, int] | None = None,
) -> None:
    """cartoon cottage hut: walls, foundation, pitched red roof, door, window.

    wrapped in `do ... end` so its ~7 part locals get freed after the cottage
    is built, keeping the chunk under lua's 200-local cap.
    """
    wall_rgb = wall_color if wall_color is not None else PALETTE.cottage_wall
    roof_rgb = roof_color if roof_color is not None else PALETTE.roof_red
    cy = base_y + wall_h / 2
    p.line("do")
    p.line(
        make_part(
            f"{var_prefix}_walls",
            parent=parent,
            name="Walls",
            size=(width, wall_h, depth),
            cframe=cframe_pos_yaw(cx, cy, cz, yaw_deg),
            color_rgb=wall_rgb,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_part(
            f"{var_prefix}_base",
            parent=parent,
            name="Foundation",
            size=(width + 0.6, 0.8, depth + 0.6),
            cframe=cframe_pos_yaw(cx, base_y + 0.4, cz, yaw_deg),
            color_rgb=PALETTE.stone_path_dark,
            material_name="Concrete",
        )
    )
    roof_h = wall_h * 0.7
    roof_top_y = base_y + wall_h + roof_h / 2
    yaw_rad = math.radians(yaw_deg)
    side_dx = math.cos(yaw_rad) * (width / 4)
    side_dz = -math.sin(yaw_rad) * (width / 4)
    p.line(
        make_wedge(
            f"{var_prefix}_roof_l",
            parent=parent,
            name="RoofLeft",
            size=(width / 2 + 0.4, roof_h, depth + 0.8),
            cframe=cframe_pos_yaw(cx - side_dx, roof_top_y, cz - side_dz, yaw_deg + 180),
            color_rgb=roof_rgb,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_wedge(
            f"{var_prefix}_roof_r",
            parent=parent,
            name="RoofRight",
            size=(width / 2 + 0.4, roof_h, depth + 0.8),
            cframe=cframe_pos_yaw(cx + side_dx, roof_top_y, cz + side_dz, yaw_deg),
            color_rgb=roof_rgb,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_part(
            f"{var_prefix}_ridge",
            parent=parent,
            name="RoofRidge",
            size=(0.6, 0.4, depth + 1.2),
            cframe=cframe_pos_yaw(cx, base_y + wall_h + roof_h, cz, yaw_deg),
            color_rgb=PALETTE.roof_red_dark,
            material_name="WoodPlanks",
        )
    )
    front_dx = math.sin(yaw_rad) * (depth / 2 + 0.05)
    front_dz = math.cos(yaw_rad) * (depth / 2 + 0.05)
    p.line(
        make_part(
            f"{var_prefix}_door",
            parent=parent,
            name="Door",
            size=(2.4, 4, 0.3),
            cframe=cframe_pos_yaw(cx + front_dx, base_y + 2, cz + front_dz, yaw_deg),
            color_rgb=PALETTE.cottage_door,
            material_name="Wood",
        )
    )
    side_dx2 = math.sin(yaw_rad) * (depth / 2 + 0.05) + math.cos(yaw_rad) * 3
    side_dz2 = math.cos(yaw_rad) * (depth / 2 + 0.05) - math.sin(yaw_rad) * 3
    p.line(
        make_part(
            f"{var_prefix}_window",
            parent=parent,
            name="Window",
            size=(2.0, 2.0, 0.25),
            cframe=cframe_pos_yaw(cx + side_dx2, base_y + 3.5, cz + side_dz2, yaw_deg),
            color_rgb=PALETTE.cottage_window,
            material_name="SmoothPlastic",
            transparency=0.2,
        )
    )
    p.line("end")


def emit_polygonal_path(
    p: LuaProgram,
    *,
    var_prefix: str,
    parent: str,
    points: list[tuple[float, float]],
    base_y: float = 0,
) -> None:
    """drop irregular polygonal stones along the given (x, z) path."""
    sizes = [(5.5, 0.4, 4.6), (5.0, 0.4, 4.0), (5.8, 0.4, 4.4), (4.6, 0.4, 5.2)]
    colors = [PALETTE.stone_path, PALETTE.stone_path_dark]
    for idx, (px, pz) in enumerate(points):
        nxt = points[min(idx + 1, len(points) - 1)]
        dx = nxt[0] - px
        dz = nxt[1] - pz
        yaw = math.degrees(math.atan2(dx, dz))
        sx, sy, sz = sizes[idx % len(sizes)]
        # each stone in its own do/end so the per-stone local goes out of
        # scope before the next stone declares its own.
        p.line("do")
        p.line(
            make_wedge(
                f"{var_prefix}_{idx}",
                parent=parent,
                name=f"Stone{idx}",
                size=(sx, sy, sz),
                cframe=cframe_pos_yaw(px, base_y + 0.2, pz, yaw + (idx * 13 % 30 - 15)),
                color_rgb=colors[idx % len(colors)],
                material_name="Concrete",
            )
        )
        p.line("end")


__all__ = ["emit_cone_tree", "emit_cottage", "emit_polygonal_path"]
