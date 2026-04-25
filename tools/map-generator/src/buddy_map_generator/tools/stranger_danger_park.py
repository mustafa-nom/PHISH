"""build_stranger_danger_park: 4-way street intersection level.

reframed for the new visual style: instead of a green park, the level is a
cartoon city block with two roads crossing in a + shape. asphalt, sidewalks,
crosswalks, lane paint, plus four corner buildings — a hot dog shop, a
ranger/general store, an alley cluster, and a parked white van. NPCs walk
patrol routes around the intersection so the scene reads as alive, not
posed. server-side scenario logic still randomizes which NPCs are safe vs
risky each round; the geometry stays put.

map object conventions remain: ServerStorage.Levels.StrangerDangerPark
with PrimaryPart, LevelEntry, LevelExit, BuddyNpcSpawn anchors,
PuppySpawn candidates, and BuddyPortal to BackpackCheckpoint.
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
    make_folder,
    make_model,
    make_part,
    make_wedge,
    set_attribute,
    set_primary_part,
)
from ..style import PALETTE, Tags, Attributes
from ._props import emit_cone_tree, emit_cottage


# road geometry constants — used everywhere so changing them rescales the
# whole intersection cleanly.
_ROAD_WIDTH = 24
_ROAD_LENGTH = 100
_SIDEWALK_W = 8
_GROUND_HALF = 80


# (npc_spawn_id, anchor_label, x, z, yaw_deg, patrol_offsets)
# patrol_offsets is a list of (dx, dz) waypoint offsets relative to the
# spawn point — gives the npc a small route to walk so the scene feels alive.
_NPC_SPAWNS: list[tuple[str, str, float, float, float, list[tuple[float, float]]]] = [
    # NE corner — hotdog shop, vendor patrols counter
    ("npc_spawn_hotdog", "HotdogShop", 22, -22, 200, [(0, 0), (4, 0), (4, 4), (0, 4)]),
    # NW corner — general store / ranger area, walking the storefront
    ("npc_spawn_ranger", "GeneralStore", -22, -22, 160, [(0, 0), (-6, 0), (-6, 4), (0, 4)]),
    # SE corner — white van + leaner, leans against the van bumper
    ("npc_spawn_whitevan", "WhiteVan", 24, 24, -20, [(0, 0), (3, 2), (-2, 4)]),
    # SW corner — alley cluster, hooded figure pacing the alley mouth
    ("npc_spawn_alley", "AlleyMouth", -24, 26, 30, [(0, 0), (-3, -2), (-6, 1), (-3, 3)]),
    # north sidewalk — casual park-goer / parent with stroller
    ("npc_spawn_north_walk", "NorthSidewalk", -8, -36, 90, [(0, 0), (10, 0), (16, 0), (4, 0)]),
    # south sidewalk — bench/fountain area, casual stroll
    ("npc_spawn_south_walk", "SouthSidewalk", 6, 38, -90, [(0, 0), (-8, 0), (-14, 0), (-4, 0)]),
    # east sidewalk
    ("npc_spawn_east_walk", "EastSidewalk", 36, 8, 180, [(0, 0), (0, -10), (0, -16), (0, -4)]),
    # west sidewalk
    ("npc_spawn_west_walk", "WestSidewalk", -36, -6, 0, [(0, 0), (0, 10), (0, 16), (0, 4)]),
]

_PUPPY_SPAWNS = [
    ("puppy_spawn_intersection_center", 0, 0),
    ("puppy_spawn_north_corner", -28, -32),
    ("puppy_spawn_south_corner", 28, 30),
    ("puppy_spawn_alley_corner", -32, 30),
]


def _emit_road_strip(p: LuaProgram, *, name: str, var: str, axis: str, base_y: float) -> None:
    """horizontal asphalt road plus its yellow center line and end caps.

    axis="ns" runs along the z axis (north-south), axis="ew" along x. body
    wrapped in do/end so the road + ~16 dash locals get released after.
    """
    if axis == "ns":
        sx, sz = _ROAD_WIDTH, _ROAD_LENGTH * 2
    else:
        sx, sz = _ROAD_LENGTH * 2, _ROAD_WIDTH
    p.line("do")
    p.line(
        make_part(
            var,
            parent="streets",
            name=name,
            size=(sx, 0.4, sz),
            cframe=cframe_pos(0, base_y + 0.2, 0),
            color_rgb=PALETTE.asphalt,
            material_name="Concrete",
        )
    )
    # dashed yellow centerline — multiple short paint stripes
    if axis == "ns":
        for i, offset in enumerate(range(-90, 100, 12)):
            p.line(
                make_part(
                    f"{var}_dash_{i}",
                    parent="streets",
                    name=f"CenterDash{i}",
                    size=(0.6, 0.06, 6),
                    cframe=cframe_pos(0, base_y + 0.45, offset),
                    color_rgb=PALETTE.road_yellow,
                    material_name="SmoothPlastic",
                )
            )
    else:
        for i, offset in enumerate(range(-90, 100, 12)):
            p.line(
                make_part(
                    f"{var}_dash_{i}",
                    parent="streets",
                    name=f"CenterDash{i}",
                    size=(6, 0.06, 0.6),
                    cframe=cframe_pos(offset, base_y + 0.45, 0),
                    color_rgb=PALETTE.road_yellow,
                    material_name="SmoothPlastic",
                )
            )
    p.line("end")


def _emit_crosswalks(p: LuaProgram, base_y: float) -> None:
    """four sets of crosswalk stripes, one entering each side of the box.

    each crosswalk side wraps its 6 stripe locals in do/end so the 24 total
    stripes don't pile up against lua's local-register cap.
    """
    half = _ROAD_WIDTH / 2
    stripe_w = 1.4
    stripe_l = _ROAD_WIDTH - 4
    # n side stripes (running east-west along z = -half - 1)
    p.line("do")
    for i in range(6):
        x = -half + 2 + i * 4
        p.line(
            make_part(
                f"cw_n_{i}",
                parent="streets",
                name=f"CrosswalkN{i}",
                size=(stripe_w, 0.06, stripe_l),
                cframe=cframe_pos(x, base_y + 0.45, -half - 6),
                color_rgb=PALETTE.crosswalk_paint,
                material_name="SmoothPlastic",
            )
        )
    for i in range(6):
        x = -half + 2 + i * 4
        p.line(
            make_part(
                f"cw_s_{i}",
                parent="streets",
                name=f"CrosswalkS{i}",
                size=(stripe_w, 0.06, stripe_l),
                cframe=cframe_pos(x, base_y + 0.45, half + 6),
                color_rgb=PALETTE.crosswalk_paint,
                material_name="SmoothPlastic",
            )
        )
    for i in range(6):
        z = -half + 2 + i * 4
        p.line(
            make_part(
                f"cw_w_{i}",
                parent="streets",
                name=f"CrosswalkW{i}",
                size=(stripe_l, 0.06, stripe_w),
                cframe=cframe_pos(-half - 6, base_y + 0.45, z),
                color_rgb=PALETTE.crosswalk_paint,
                material_name="SmoothPlastic",
            )
        )
    for i in range(6):
        z = -half + 2 + i * 4
        p.line(
            make_part(
                f"cw_e_{i}",
                parent="streets",
                name=f"CrosswalkE{i}",
                size=(stripe_l, 0.06, stripe_w),
                cframe=cframe_pos(half + 6, base_y + 0.45, z),
                color_rgb=PALETTE.crosswalk_paint,
                material_name="SmoothPlastic",
            )
        )
    p.line("end")


def _emit_sidewalks(p: LuaProgram, base_y: float) -> None:
    """four L-shaped sidewalk corners around the intersection.

    corners are quadrants that fill from the road edge out to the ground edge.
    they curl inward at the intersection so pedestrians have a corner to
    stand on, plus curbs along the road edges. body wrapped in do/end so the
    12 sidewalk + curb locals get released after.
    """
    p.line("do")
    half = _ROAD_WIDTH / 2
    far = _GROUND_HALF
    # quadrant slabs — each (cx, cz, sx, sz)
    quadrants = [
        ("NW", -(far + half) / 2, -(far + half) / 2, far - half, far - half),
        ("NE", (far + half) / 2, -(far + half) / 2, far - half, far - half),
        ("SW", -(far + half) / 2, (far + half) / 2, far - half, far - half),
        ("SE", (far + half) / 2, (far + half) / 2, far - half, far - half),
    ]
    for name, cx, cz, sx, sz in quadrants:
        p.line(
            make_part(
                f"sidewalk_{name}",
                parent="streets",
                name=f"Sidewalk{name}",
                size=(sx, 0.6, sz),
                cframe=cframe_pos(cx, base_y + 0.3, cz),
                color_rgb=PALETTE.sidewalk,
                material_name="Concrete",
            )
        )
    # curbs running along the road edges — slightly raised dark strips. lua
    # identifiers can't contain '-' so each (sign_x, sign_z) gets a tag like
    # "neg_pos" rather than embedding the raw signs into the var name.
    curb_thickness = 0.4
    curb_h = 0.4
    edge_len = far - half
    for sign_x in (-1, 1):
        for sign_z in (-1, 1):
            tag_x = "neg" if sign_x < 0 else "pos"
            tag_z = "neg" if sign_z < 0 else "pos"
            label = f"{tag_x}_{tag_z}"
            # vertical curb between corner and intersection along z
            cz = sign_z * (half + edge_len / 2)
            cx = sign_x * (half - curb_thickness / 2)
            p.line(
                make_part(
                    f"curb_v_{label}",
                    parent="streets",
                    name=f"CurbV_{label}",
                    size=(curb_thickness, curb_h, edge_len),
                    cframe=cframe_pos(cx, base_y + 0.7, cz),
                    color_rgb=PALETTE.curb,
                    material_name="Concrete",
                )
            )
            # horizontal curb along x
            cz2 = sign_z * (half - curb_thickness / 2)
            cx2 = sign_x * (half + edge_len / 2)
            p.line(
                make_part(
                    f"curb_h_{label}",
                    parent="streets",
                    name=f"CurbH_{label}",
                    size=(edge_len, curb_h, curb_thickness),
                    cframe=cframe_pos(cx2, base_y + 0.7, cz2),
                    color_rgb=PALETTE.curb,
                    material_name="Concrete",
                )
            )
    p.line("end")


def _emit_corner_buildings(p: LuaProgram) -> None:
    """four corner buildings — hotdog shop NE, general store NW, alley cluster SW, parked van SE."""
    p.line(make_model("buildings", parent="level", name="CornerBuildings"))

    # NE — hotdog shop cottage with red roof and big sign. each corner gets
    # its own do/end so its sign post / sign / billboard locals don't pile up
    p.line("do")
    emit_cottage(
        p,
        var_prefix="b_hotdog",
        parent="buildings",
        cx=30,
        cz=-30,
        base_y=0.6,
        yaw_deg=200,
        width=14,
        depth=11,
        wall_h=7,
        wall_color=PALETTE.hot_dog_red,
        roof_color=PALETTE.roof_red_dark,
    )
    p.line(
        make_part(
            "b_hotdog_signpost",
            parent="buildings",
            name="HotdogSignPost",
            size=(0.8, 9, 0.8),
            cframe=cframe_pos(20, 5, -22),
            color_rgb=PALETTE.cottage_trim,
            material_name="Wood",
        )
    )
    p.line(
        make_part(
            "b_hotdog_sign",
            parent="buildings",
            name="HotdogSign",
            size=(5, 2.5, 0.4),
            cframe=cframe_pos(20, 9, -22),
            color_rgb=PALETTE.sign_face,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_billboard_gui(
            "b_hotdog_sign_label",
            adornee="b_hotdog_sign",
            text="HOT DOGS",
            studs_offset_y=2,
            text_size=32,
        )
    )
    p.line("end")

    # NW — general store / ranger station, ranger green walls
    p.line("do")
    emit_cottage(
        p,
        var_prefix="b_store",
        parent="buildings",
        cx=-30,
        cz=-30,
        base_y=0.6,
        yaw_deg=160,
        width=14,
        depth=11,
        wall_h=7,
        wall_color=PALETTE.ranger_green,
        roof_color=PALETTE.roof_red,
    )
    p.line(
        make_part(
            "b_store_sign",
            parent="buildings",
            name="StoreSign",
            size=(6, 2, 0.4),
            cframe=cframe_pos(-22, 6, -22),
            color_rgb=PALETTE.sign_face,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_billboard_gui(
            "b_store_sign_label",
            adornee="b_store_sign",
            text="GENERAL STORE",
            studs_offset_y=2,
            text_size=24,
        )
    )
    p.line("end")

    # SW — alley cluster: two narrow buildings with a gap that forms the alley
    p.line("do")
    p.line(make_model("alley_cluster", parent="buildings", name="AlleyCluster"))
    p.line(
        make_part(
            "ac_left_wall",
            parent="alley_cluster",
            name="LeftBuilding",
            size=(8, 10, 14),
            cframe=cframe_pos(-34, 5.6, 26),
            color_rgb=PALETTE.alley_brick,
            material_name="Concrete",
        )
    )
    p.line(
        make_part(
            "ac_right_wall",
            parent="alley_cluster",
            name="RightBuilding",
            size=(8, 10, 14),
            cframe=cframe_pos(-22, 5.6, 26),
            color_rgb=PALETTE.cottage_wall,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_part(
            "ac_alley_floor",
            parent="alley_cluster",
            name="AlleyFloor",
            size=(4, 0.4, 12),
            cframe=cframe_pos(-28, 0.8, 26),
            color_rgb=PALETTE.asphalt_dark,
            material_name="Concrete",
        )
    )
    p.line(
        make_part(
            "ac_dumpster",
            parent="alley_cluster",
            name="Dumpster",
            size=(2.5, 2, 3),
            cframe=cframe_pos(-28, 1.7, 30),
            color_rgb=PALETTE.bin_pack_it,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "ac_lamp_post",
            parent="alley_cluster",
            name="StreetLampPost",
            size=(0.6, 8, 0.6),
            cframe=cframe_pos(-28, 4.6, 22),
            color_rgb=PALETTE.cottage_trim,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "ac_lamp_bulb",
            parent="alley_cluster",
            name="StreetLampBulb",
            size=(1, 1, 1),
            cframe=cframe_pos(-28, 8.4, 22),
            color_rgb=PALETTE.sparkle,
            material_name="SmoothPlastic",
            shape="Ball",
        )
    )
    p.line("end")

    # SE — parked white van and a small storefront behind it
    p.line("do")
    p.line(make_model("vanblock", parent="buildings", name="VanBlock"))
    emit_cottage(
        p,
        var_prefix="b_van_shop",
        parent="vanblock",
        cx=32,
        cz=32,
        base_y=0.6,
        yaw_deg=-20,
        width=14,
        depth=11,
        wall_h=7,
        wall_color=PALETTE.bench_wood,
        roof_color=PALETTE.roof_red,
    )
    # parked van
    p.line(make_model("whitevan", parent="vanblock", name="WhiteVan"))
    p.line(
        make_part(
            "wv_body",
            parent="whitevan",
            name="VanBody",
            size=(8, 5, 4),
            cframe=cframe_pos(20, 3, 24),
            color_rgb=PALETTE.white_van_body,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "wv_top",
            parent="whitevan",
            name="VanTop",
            size=(8, 2, 4),
            cframe=cframe_pos(20, 6.5, 24),
            color_rgb=PALETTE.white_van_body,
            material_name="SmoothPlastic",
        )
    )
    for i, wx in enumerate([17, 23]):
        for j, wz in enumerate([22, 26]):
            p.line(
                make_part(
                    f"wv_wheel_{i}_{j}",
                    parent="whitevan",
                    name="Wheel",
                    size=(1.6, 1.6, 1.6),
                    cframe=cframe_pos_yaw(wx, 1.1, wz, 90),
                    color_rgb=PALETTE.cottage_trim,
                    material_name="SmoothPlastic",
                    shape="Cylinder",
                )
            )
    p.line(
        make_part(
            "wv_door",
            parent="whitevan",
            name="OpenSideDoor",
            size=(0.4, 4, 4),
            cframe=cframe_pos_yaw(16, 3, 24, 60),
            color_rgb=PALETTE.white_van_body,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "wv_windshield",
            parent="whitevan",
            name="Windshield",
            size=(0.3, 2.4, 3.6),
            cframe=cframe_pos(24, 5.5, 24),
            color_rgb=PALETTE.fountain_water,
            material_name="SmoothPlastic",
            transparency=0.3,
        )
    )
    p.line("end")


def _emit_npc_spawns_and_patrols(p: LuaProgram) -> None:
    """anchor each npc spawn AND a PatrolPath folder of waypoints next to it.

    each (spawn + waypoints) iteration is wrapped in do/end so the spawn
    disc local + 3-4 waypoint locals get released before the next iteration.
    """
    p.line(make_folder("patrol_root", parent="level", name="PatrolPaths"))
    for spawn_id, anchor, x, z, yaw, offsets in _NPC_SPAWNS:
        var = f"spawn_{spawn_id}"
        p.line("do")
        p.line(
            make_disc(
                var,
                parent="level",
                name=spawn_id,
                diameter=3,
                height=0.6,
                cframe=cframe_pos_yaw(x, 0.6, z, yaw),
                color_rgb=PALETTE.sparkle,
                material_name="SmoothPlastic",
                transparency=0.6,
                can_collide=False,
            )
        )
        p.line(add_tag(var, Tags.BUDDY_NPC_SPAWN))
        p.line(set_attribute(var, Attributes.NPC_SPAWN_ID, spawn_id))
        p.line(set_attribute(var, Attributes.ANCHOR, anchor))
        # patrol path folder: a list of small invisible waypoint parts
        path_var = f"patrol_{spawn_id}"
        p.line(make_folder(path_var, parent="patrol_root", name=spawn_id))
        for idx, (dx, dz) in enumerate(offsets):
            wp_var = f"{path_var}_wp_{idx}"
            p.line(
                make_part(
                    wp_var,
                    parent=path_var,
                    name=f"Waypoint{idx}",
                    size=(1, 0.2, 1),
                    cframe=cframe_pos(x + dx, 1.1, z + dz),
                    color_rgb=PALETTE.sparkle,
                    transparency=1,
                    can_collide=False,
                )
            )
            p.line(add_tag(wp_var, Tags.NPC_PATROL_NODE))
            p.line(set_attribute(wp_var, "WaypointIndex", idx))
        p.line(set_attribute(var, "PatrolPath", spawn_id))
        p.created(f"NpcSpawn/{spawn_id}")
        p.line("end")


def emit_stranger_danger_park_lua() -> str:
    p = LuaProgram()
    p.comment("buddy bridge stranger danger — 4-way intersection level")

    p.line(find_or_create_path("ServerStorage", "Levels"))
    p.line("local levels_root = _path")
    p.line(clear_existing("levels_root", "StrangerDangerPark"))

    p.line(make_model("level", parent="levels_root", name="StrangerDangerPark"))
    p.line(set_attribute("level", Attributes.LEVEL_TYPE, "StrangerDangerPark"))

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

    # ground plane — sandy lot extending past the sidewalks so empty corners
    # read as "outskirts" not "void"
    p.line(
        make_part(
            "ground",
            parent="level",
            name="GroundPlane",
            size=(_GROUND_HALF * 2 + 20, 2, _GROUND_HALF * 2 + 20),
            cframe=cframe_pos(0, -1, 0),
            color_rgb=PALETTE.sand_warm,
            material_name="Sand",
        )
    )

    # streets folder bundles asphalt + paint + sidewalks
    p.line(make_model("streets", parent="level", name="Streets"))
    _emit_road_strip(p, name="RoadNS", var="road_ns", axis="ns", base_y=0)
    _emit_road_strip(p, name="RoadEW", var="road_ew", axis="ew", base_y=0)
    _emit_sidewalks(p, base_y=0)
    _emit_crosswalks(p, base_y=0)

    # level entry — explorer arrives at the south sidewalk
    p.line(
        make_disc(
            "level_entry",
            parent="level",
            name="LevelEntry",
            diameter=4,
            height=1,
            cframe=cframe_pos(0, 0.9, 50),
            color_rgb=PALETTE.sparkle,
            transparency=0.4,
            can_collide=False,
        )
    )
    p.line(add_tag("level_entry", Tags.LEVEL_ENTRY))

    # corner buildings — hotdog, general store, alley, van block
    _emit_corner_buildings(p)

    # decorative cone-stack trees scattered along the perimeter sand
    tree_positions = [
        (-70, -70, 1.0), (-50, -70, 0.9), (50, -70, 0.95), (70, -70, 1.0),
        (-70, 70, 1.0), (-50, 70, 0.9), (50, 70, 0.95), (70, 70, 1.0),
        (-70, -25, 1.0), (-70, 25, 0.95),
        (70, -25, 1.0), (70, 25, 0.95),
        (-15, -70, 0.85), (15, -70, 0.85),
        (-15, 70, 0.85), (15, 70, 0.85),
    ]
    p.line(make_model("trees", parent="level", name="Trees"))
    for i, (tx, tz, scale) in enumerate(tree_positions):
        emit_cone_tree(
            p,
            var_prefix=f"tree_{i}",
            parent="trees",
            cx=tx,
            cz=tz,
            base_y=0,
            scale=scale,
        )

    # public bench on the SW sidewalk so a "neutral parkgoer" archetype has
    # somewhere to sit
    p.line(
        make_part(
            "bench_seat",
            parent="level",
            name="ParkBench",
            size=(7, 0.4, 1.5),
            cframe=cframe_pos(-30, 1.5, 14),
            color_rgb=PALETTE.bench_wood,
            material_name="Wood",
        )
    )
    p.line(
        make_part(
            "bench_back",
            parent="level",
            name="BenchBack",
            size=(7, 2, 0.4),
            cframe=cframe_pos(-30, 2.5, 14.6),
            color_rgb=PALETTE.bench_wood,
            material_name="Wood",
        )
    )

    # npc patrol spawns
    _emit_npc_spawns_and_patrols(p)

    # puppy spawn candidates (server picks one per round). each disc in its
    # own do/end so the per-iteration local doesn't pile up.
    for spawn_id, x, z in _PUPPY_SPAWNS:
        var = f"puppy_{spawn_id}"
        p.line("do")
        p.line(
            make_disc(
                var,
                parent="level",
                name=spawn_id,
                diameter=2,
                height=0.6,
                cframe=cframe_pos(x, 0.9, z),
                color_rgb=PALETTE.capsule_a,
                material_name="SmoothPlastic",
                transparency=0.7,
                can_collide=False,
            )
        )
        p.line(add_tag(var, Tags.PUPPY_SPAWN))
        p.created(f"PuppySpawn/{spawn_id}")
        p.line("end")

    # level exit zone (server activates near the chosen puppy spawn)
    p.line(
        make_part(
            "level_exit",
            parent="level",
            name="LevelExit",
            size=(6, 4, 6),
            cframe=cframe_pos(0, 2, 0),
            color_rgb=PALETTE.sparkle,
            transparency=0.85,
            can_collide=False,
        )
    )
    p.line(add_tag("level_exit", Tags.LEVEL_EXIT))

    # buddy portal to the next level — placed off the east sidewalk past the
    # corner so the duo can see it from the intersection center. portal block
    # in its own do/end so its 4 part locals are released after.
    p.line("do")
    p.line(make_model("portal", parent="level", name="BuddyPortal"))
    p.line(
        make_part(
            "portal_arch",
            parent="portal",
            name="ArchTop",
            size=(8, 1, 1),
            cframe=cframe_pos(60, 9, 0),
            color_rgb=PALETTE.capsule_b,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "portal_l",
            parent="portal",
            name="PostL",
            size=(1, 8, 1),
            cframe=cframe_pos(56, 4, 0),
            color_rgb=PALETTE.capsule_b,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "portal_r",
            parent="portal",
            name="PostR",
            size=(1, 8, 1),
            cframe=cframe_pos(64, 4, 0),
            color_rgb=PALETTE.capsule_b,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "portal_field",
            parent="portal",
            name="Field",
            size=(7, 7, 0.4),
            cframe=cframe_pos(60, 4.5, 0),
            color_rgb=PALETTE.capsule_c,
            material_name="SmoothPlastic",
            transparency=0.5,
            can_collide=False,
        )
    )
    p.line(add_tag("portal", Tags.BUDDY_PORTAL))
    p.line(
        make_billboard_gui(
            "portal_label",
            adornee="portal_arch",
            text="To Backpack Checkpoint",
            text_size=22,
        )
    )
    p.line("end")

    p.note("StrangerDangerPark intersection level built")
    p.created("Levels/StrangerDangerPark")
    return p.render()


__all__ = ["emit_stranger_danger_park_lua"]
_ = make_wedge  # imported for parity with sibling tools
