"""build_stranger_danger_park: park level template under ServerStorage.Levels.

scene anchors (judge andrew's "different backgrounds and scenes"):
- hot dog stand (safe archetype)
- playground (safe archetype — parent with kids)
- white van (risky archetype)
- alley behind a shop (risky archetype)
- ranger booth (safe archetype)
- public bench / fountain (neutral / safe)

each anchor gets a distinct visible identity so the level reads as a series
of recognizable vignettes. server-side scenario logic randomizes which
NPCs go where each round; the geometry stays put.
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
    set_attribute,
    set_primary_part,
)
from ..style import PALETTE, Tags, Attributes


# spawn anchors — six npc spawns, each tagged with the scene archetype.
# coordinates are LOCAL to the level model (origin at PrimaryPart). the
# play-area service will reposition the cloned level via PrimaryPart CFrame.
_NPC_SPAWNS = [
    # (npc_spawn_id, anchor_label, x, y, z, yaw_deg)
    ("npc_spawn_hotdog", "HotdogStand", -30, 1, -10, 0),
    ("npc_spawn_playground", "Playground", 28, 1, -18, 180),
    ("npc_spawn_whitevan", "WhiteVan", 38, 1, 22, -90),
    ("npc_spawn_alley", "AlleyBehindShop", -38, 1, 22, 90),
    ("npc_spawn_ranger", "RangerBooth", 0, 1, -28, 0),
    ("npc_spawn_bench", "BenchFountain", -8, 1, 8, 180),
]

_PUPPY_SPAWNS = [
    # (puppy_spawn_id, x, y, z) — four candidates, server picks one
    ("puppy_spawn_fountain", 0, 1, 12),
    ("puppy_spawn_bench", -10, 1, 4),
    ("puppy_spawn_playground_slide", 26, 1, -22),
    ("puppy_spawn_alley_corner", -34, 1, 26),
]


def emit_stranger_danger_park_lua() -> str:
    p = LuaProgram()
    p.comment("buddy bridge stranger danger park level template — generated")

    # ensure ServerStorage/Levels exists, then nuke any old level model
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

    # ground — generous park footprint
    p.line(
        make_part(
            "park_ground",
            parent="level",
            name="ParkGround",
            size=(120, 2, 120),
            cframe=cframe_pos(0, -1, 0),
            color_rgb=PALETTE.grass,
            material_name="Grass",
        )
    )
    # winding path through the middle
    p.line(
        make_part(
            "park_path",
            parent="level",
            name="ParkPath",
            size=(8, 0.3, 80),
            cframe=cframe_pos(0, 0.15, 0),
            color_rgb=PALETTE.path,
            material_name="Sand",
        )
    )

    # level entry — explorer spawns at the south end of the park
    p.line(
        make_disc(
            "level_entry",
            parent="level",
            name="LevelEntry",
            diameter=4,
            height=1,
            cframe=cframe_pos(0, 0.5, -50),
            color_rgb=PALETTE.sparkle,
            transparency=0.4,
            can_collide=False,
        )
    )
    p.line(add_tag("level_entry", Tags.LEVEL_ENTRY))

    # ----- scene: hot dog stand (safe archetype anchor)
    p.line(make_model("hotdog", parent="level", name="HotdogStand"))
    p.line(
        make_part(
            "hd_counter",
            parent="hotdog",
            name="Counter",
            size=(10, 4, 4),
            cframe=cframe_pos(-30, 2, -10),
            color_rgb=PALETTE.hot_dog_red,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "hd_roof",
            parent="hotdog",
            name="Roof",
            size=(12, 0.5, 5),
            cframe=cframe_pos(-30, 6, -10),
            color_rgb=PALETTE.sign_face,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_billboard_gui(
            "hd_sign",
            adornee="hd_roof",
            text="HOT DOGS",
            studs_offset_y=2,
            text_size=32,
        )
    )
    # roof support poles flanking the counter
    for side, dx in (("L", -5.5), ("R", 5.5)):
        p.line(
            make_part(
                f"hd_post_{side}",
                parent="hotdog",
                name=f"RoofPost{side}",
                size=(0.4, 5.6, 0.4),
                cframe=cframe_pos(-30 + dx, 2.8, -10),
                color_rgb=PALETTE.wood_dark,
                material_name="Wood",
            )
        )
    # cartoon hot dog on the counter — bun + sausage
    p.line(
        make_part(
            "hd_bun",
            parent="hotdog",
            name="DisplayBun",
            size=(2.4, 0.6, 0.8),
            cframe=cframe_pos(-30, 4.4, -8.2),
            color_rgb=(232, 196, 132),
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "hd_sausage",
            parent="hotdog",
            name="DisplaySausage",
            size=(2.6, 0.4, 0.5),
            cframe=cframe_pos(-30, 4.8, -8.2),
            color_rgb=(196, 96, 70),
            material_name="SmoothPlastic",
        )
    )
    # menu board on the counter face
    p.line(
        make_part(
            "hd_menu",
            parent="hotdog",
            name="MenuBoard",
            size=(3.4, 2, 0.2),
            cframe=cframe_pos(-32, 3, -8.05),
            color_rgb=PALETTE.sign_face,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_billboard_gui(
            "hd_menu_label",
            adornee="hd_menu",
            text="$2 — open!",
            studs_offset_y=0,
            text_size=22,
        )
    )

    # ----- scene: playground
    p.line(make_model("playground", parent="level", name="Playground"))
    p.line(
        make_part(
            "pg_floor",
            parent="playground",
            name="Padding",
            size=(20, 0.5, 16),
            cframe=cframe_pos(28, 0.25, -18),
            color_rgb=PALETTE.playground_blue,
            material_name="SmoothPlastic",
        )
    )
    # cartoon slide
    p.line(
        make_part(
            "pg_slide_top",
            parent="playground",
            name="SlideTop",
            size=(3, 1, 4),
            cframe=cframe_pos(26, 5, -22),
            color_rgb=PALETTE.capsule_a,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "pg_slide_ramp",
            parent="playground",
            name="SlideRamp",
            size=(3, 0.5, 8),
            cframe=cframe_pos_yaw(26, 3, -19, 25),
            color_rgb=PALETTE.capsule_a,
            material_name="SmoothPlastic",
        )
    )
    # swing frame
    p.line(
        make_part(
            "pg_swing_l",
            parent="playground",
            name="SwingPostL",
            size=(0.6, 6, 0.6),
            cframe=cframe_pos(32, 3, -16),
            color_rgb=PALETTE.wood_dark,
            material_name="Wood",
        )
    )
    p.line(
        make_part(
            "pg_swing_r",
            parent="playground",
            name="SwingPostR",
            size=(0.6, 6, 0.6),
            cframe=cframe_pos(32, 3, -20),
            color_rgb=PALETTE.wood_dark,
            material_name="Wood",
        )
    )
    p.line(
        make_part(
            "pg_swing_top",
            parent="playground",
            name="SwingTop",
            size=(0.6, 0.6, 5),
            cframe=cframe_pos(32, 6, -18),
            color_rgb=PALETTE.wood_dark,
            material_name="Wood",
        )
    )
    # actual swings hanging from the frame
    for i, sz in enumerate((-16.5, -19.5)):
        p.line(
            make_part(
                f"pg_swing_chain_{i}",
                parent="playground",
                name=f"SwingChain{i}",
                size=(0.15, 3.4, 0.15),
                cframe=cframe_pos(32, 4.1, sz),
                color_rgb=PALETTE.wood_dark,
                material_name="SmoothPlastic",
            )
        )
        p.line(
            make_part(
                f"pg_swing_seat_{i}",
                parent="playground",
                name=f"SwingSeat{i}",
                size=(1.6, 0.3, 0.6),
                cframe=cframe_pos(32, 2.4, sz),
                color_rgb=PALETTE.bin_pack_it,
                material_name="SmoothPlastic",
            )
        )

    # ----- scene: white van (risky)
    p.line(make_model("whitevan", parent="level", name="WhiteVan"))
    p.line(
        make_part(
            "wv_body",
            parent="whitevan",
            name="VanBody",
            size=(8, 5, 4),
            cframe=cframe_pos(38, 2.5, 22),
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
            cframe=cframe_pos(38, 6, 22),
            color_rgb=PALETTE.white_van_body,
            material_name="SmoothPlastic",
        )
    )
    # wheels
    for i, wx in enumerate([35, 41]):
        for j, wz in enumerate([20, 24]):
            p.line(
                make_part(
                    f"wv_wheel_{i}_{j}",
                    parent="whitevan",
                    name="Wheel",
                    size=(1.6, 1.6, 1.6),
                    cframe=cframe_pos_yaw(wx, 0.8, wz, 90),
                    color_rgb=PALETTE.wood_dark,
                    material_name="SmoothPlastic",
                    shape="Cylinder",
                )
            )
    # open side door — cue the "calling you over" pose
    p.line(
        make_part(
            "wv_door",
            parent="whitevan",
            name="OpenSideDoor",
            size=(0.4, 4, 4),
            cframe=cframe_pos_yaw(34, 2.5, 22, 60),
            color_rgb=PALETTE.white_van_body,
            material_name="SmoothPlastic",
        )
    )
    # windshield (front of the van)
    p.line(
        make_part(
            "wv_windshield",
            parent="whitevan",
            name="Windshield",
            size=(0.3, 2.4, 3.6),
            cframe=cframe_pos(42, 5, 22),
            color_rgb=PALETTE.fountain_water,
            material_name="SmoothPlastic",
            transparency=0.3,
        )
    )
    # brake lights — small red squares at the rear
    for i, wz in enumerate((20.5, 23.5)):
        p.line(
            make_part(
                f"wv_brake_{i}",
                parent="whitevan",
                name=f"BrakeLight{i}",
                size=(0.2, 0.6, 0.6),
                cframe=cframe_pos(34.1, 1.6, wz),
                color_rgb=PALETTE.bin_leave_it,
                material_name="SmoothPlastic",
            )
        )
    # license plate
    p.line(
        make_part(
            "wv_plate",
            parent="whitevan",
            name="LicensePlate",
            size=(0.2, 0.7, 1.6),
            cframe=cframe_pos(34.05, 1.2, 22),
            color_rgb=PALETTE.sign_face,
            material_name="SmoothPlastic",
        )
    )

    # ----- scene: alley behind shop
    p.line(make_model("alley", parent="level", name="Alley"))
    # back wall of the "shop"
    p.line(
        make_part(
            "al_shopwall",
            parent="alley",
            name="ShopBackWall",
            size=(20, 10, 1),
            cframe=cframe_pos(-32, 5, 24),
            color_rgb=PALETTE.alley_brick,
            material_name="SmoothPlastic",
        )
    )
    # narrow passage marker
    p.line(
        make_part(
            "al_floor",
            parent="alley",
            name="AlleyFloor",
            size=(8, 0.4, 12),
            cframe=cframe_pos(-38, 0.2, 22),
            color_rgb=PALETTE.alley_brick,
            material_name="Concrete",
        )
    )
    p.line(
        make_part(
            "al_dumpster",
            parent="alley",
            name="Dumpster",
            size=(2.5, 2, 3),
            cframe=cframe_pos(-39, 1, 26),
            color_rgb=PALETTE.bin_pack_it,
            material_name="SmoothPlastic",
        )
    )
    # service door at the back of the shop — exit cue for an alley scene
    p.line(
        make_part(
            "al_door_frame",
            parent="alley",
            name="DoorFrame",
            size=(0.3, 4.4, 2.4),
            cframe=cframe_pos(-31.7, 2.2, 18),
            color_rgb=PALETTE.wood_dark,
            material_name="Wood",
        )
    )
    p.line(
        make_part(
            "al_door",
            parent="alley",
            name="ServiceDoor",
            size=(0.2, 3.8, 1.8),
            cframe=cframe_pos(-31.6, 2, 18),
            color_rgb=PALETTE.wood_warm,
            material_name="Wood",
        )
    )
    # streetlamp — long stem with a glowing top, anchors "lurking spot lit
    # from above". the light part is sparkle-yellow but kept as
    # SmoothPlastic because Neon is forbidden by the visual style bible.
    p.line(
        make_part(
            "al_lamp_post",
            parent="alley",
            name="StreetLampPost",
            size=(0.6, 7, 0.6),
            cframe=cframe_pos(-36, 3.5, 22),
            color_rgb=PALETTE.wood_dark,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "al_lamp_arm",
            parent="alley",
            name="StreetLampArm",
            size=(2, 0.4, 0.4),
            cframe=cframe_pos(-37, 7, 22),
            color_rgb=PALETTE.wood_dark,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "al_lamp_bulb",
            parent="alley",
            name="StreetLampBulb",
            size=(1, 1, 1),
            cframe=cframe_pos(-38, 6.7, 22),
            color_rgb=PALETTE.sparkle,
            material_name="SmoothPlastic",
            shape="Ball",
        )
    )
    # cardboard boxes — stacked alley clutter, gives the scene texture
    p.line(
        make_part(
            "al_box_a",
            parent="alley",
            name="CardboardBoxA",
            size=(2, 1.6, 1.6),
            cframe=cframe_pos(-37.5, 0.8, 19),
            color_rgb=PALETTE.wood_warm,
            material_name="SmoothPlastic",
        )
    )
    p.line(
        make_part(
            "al_box_b",
            parent="alley",
            name="CardboardBoxB",
            size=(1.4, 1.2, 1.2),
            cframe=cframe_pos(-36.5, 2.2, 19),
            color_rgb=PALETTE.wood_warm,
            material_name="SmoothPlastic",
        )
    )

    # ----- scene: ranger booth
    p.line(make_model("ranger", parent="level", name="RangerBooth"))
    p.line(
        make_part(
            "rb_walls",
            parent="ranger",
            name="BoothWalls",
            size=(8, 6, 6),
            cframe=cframe_pos(0, 3, -28),
            color_rgb=PALETTE.ranger_green,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_part(
            "rb_roof",
            parent="ranger",
            name="BoothRoof",
            size=(10, 0.6, 8),
            cframe=cframe_pos(0, 6.4, -28),
            color_rgb=PALETTE.wood_dark,
            material_name="WoodPlanks",
        )
    )
    p.line(
        make_billboard_gui(
            "rb_sign",
            adornee="rb_roof",
            text="PARK RANGER",
            studs_offset_y=2,
            text_size=28,
        )
    )

    # ----- scene: fountain + bench
    p.line(make_model("fountain", parent="level", name="Fountain"))
    p.line(
        make_disc(
            "ft_base",
            parent="fountain",
            name="Base",
            diameter=8,
            height=1,
            cframe=cframe_pos(0, 0.5, 12),
            color_rgb=PALETTE.fountain_stone,
            material_name="Concrete",
        )
    )
    p.line(
        make_disc(
            "ft_water",
            parent="fountain",
            name="Water",
            diameter=6,
            height=0.6,
            cframe=cframe_pos(0, 1.3, 12),
            color_rgb=PALETTE.fountain_water,
            material_name="SmoothPlastic",
            transparency=0.2,
        )
    )
    p.line(
        make_part(
            "ft_pillar",
            parent="fountain",
            name="Pillar",
            size=(1, 2.5, 1),
            cframe=cframe_pos(0, 2, 12),
            color_rgb=PALETTE.fountain_stone,
            material_name="Concrete",
        )
    )
    # tiered top bowl (saucer) for a more "centerpiece" fountain
    p.line(
        make_disc(
            "ft_top_bowl",
            parent="fountain",
            name="TopBowl",
            diameter=3,
            height=0.6,
            cframe=cframe_pos(0, 3.4, 12),
            color_rgb=PALETTE.fountain_stone,
            material_name="Concrete",
        )
    )
    p.line(
        make_disc(
            "ft_top_water",
            parent="fountain",
            name="TopWater",
            diameter=2.4,
            height=0.3,
            cframe=cframe_pos(0, 3.8, 12),
            color_rgb=PALETTE.fountain_water,
            material_name="SmoothPlastic",
            transparency=0.25,
        )
    )
    # cartoon water spout — small upward jet
    p.line(
        make_part(
            "ft_spout",
            parent="fountain",
            name="WaterSpout",
            size=(0.6, 1.2, 0.6),
            cframe=cframe_pos(0, 4.4, 12),
            color_rgb=PALETTE.fountain_water,
            material_name="SmoothPlastic",
            transparency=0.3,
        )
    )
    # decorative pebbles along the rim
    for i, ang in enumerate(range(0, 360, 60)):
        import math

        ang_rad = math.radians(ang)
        px = math.cos(ang_rad) * 4.2
        pz = 12 + math.sin(ang_rad) * 4.2
        p.line(
            make_part(
                f"ft_pebble_{i}",
                parent="fountain",
                name=f"Pebble{i}",
                size=(0.6, 0.4, 0.6),
                cframe=cframe_pos(px, 1.2, pz),
                color_rgb=PALETTE.fountain_stone,
                material_name="SmoothPlastic",
                shape="Ball",
            )
        )
    # public bench
    p.line(
        make_part(
            "bench_seat",
            parent="level",
            name="ParkBench",
            size=(7, 0.4, 1.5),
            cframe=cframe_pos(-8, 1.5, 8),
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
            cframe=cframe_pos(-8, 2.5, 8.6),
            color_rgb=PALETTE.bench_wood,
            material_name="Wood",
        )
    )

    # ----- decorative cartoon trees, ringed around the park edges
    for i, (tx, tz) in enumerate(
        [(-50, -40), (50, -40), (-50, 40), (50, 40), (-25, -45), (25, -45)]
    ):
        p.line(
            make_part(
                f"tree_trunk_{i}",
                parent="level",
                name=f"TreeTrunk{i}",
                size=(2, 8, 2),
                cframe=cframe_pos(tx, 4, tz),
                color_rgb=PALETTE.wood_warm,
                material_name="Wood",
            )
        )
        p.line(
            make_part(
                f"tree_canopy_{i}",
                parent="level",
                name=f"TreeCanopy{i}",
                size=(8, 8, 8),
                cframe=cframe_pos(tx, 11, tz),
                color_rgb=PALETTE.treehouse_leaf,
                material_name="Grass",
                shape="Ball",
            )
        )

    # ----- npc spawn points (six total)
    for spawn_id, anchor, x, y, z, yaw in _NPC_SPAWNS:
        var = f"spawn_{spawn_id}"
        p.line(
            make_disc(
                var,
                parent="level",
                name=spawn_id,
                diameter=3,
                height=0.6,
                cframe=cframe_pos_yaw(x, y - 0.2, z, yaw),
                color_rgb=PALETTE.sparkle,
                material_name="SmoothPlastic",
                transparency=0.6,
                can_collide=False,
            )
        )
        p.line(add_tag(var, Tags.BUDDY_NPC_SPAWN))
        p.line(set_attribute(var, Attributes.NPC_SPAWN_ID, spawn_id))
        p.line(set_attribute(var, Attributes.ANCHOR, anchor))
        p.created(f"NpcSpawn/{spawn_id}")

    # ----- puppy spawn candidates (server picks one per round)
    for spawn_id, x, y, z in _PUPPY_SPAWNS:
        var = f"puppy_{spawn_id}"
        p.line(
            make_disc(
                var,
                parent="level",
                name=spawn_id,
                diameter=2,
                height=0.6,
                cframe=cframe_pos(x, y - 0.2, z),
                color_rgb=PALETTE.capsule_a,
                material_name="SmoothPlastic",
                transparency=0.7,
                can_collide=False,
            )
        )
        p.line(add_tag(var, Tags.PUPPY_SPAWN))
        p.created(f"PuppySpawn/{spawn_id}")

    # ----- level exit (server activates near the chosen puppy spawn)
    p.line(
        make_part(
            "level_exit",
            parent="level",
            name="LevelExit",
            size=(6, 4, 6),
            cframe=cframe_pos(0, 2, 12),
            color_rgb=PALETTE.sparkle,
            transparency=0.85,
            can_collide=False,
        )
    )
    p.line(add_tag("level_exit", Tags.LEVEL_EXIT))

    # ----- buddy portal to the next level (initially low-vis)
    p.line(make_model("portal", parent="level", name="BuddyPortal"))
    p.line(
        make_part(
            "portal_arch",
            parent="portal",
            name="ArchTop",
            size=(8, 1, 1),
            cframe=cframe_pos(50, 9, 0),
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
            cframe=cframe_pos(46, 4, 0),
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
            cframe=cframe_pos(54, 4, 0),
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
            cframe=cframe_pos(50, 4.5, 0),
            color_rgb=PALETTE.capsule_c,
            material_name="SmoothPlastic",
            transparency=0.5,
            can_collide=False,
        )
    )
    p.line(add_tag("portal", Tags.BUDDY_PORTAL))
    p.line(make_billboard_gui("portal_label", adornee="portal_arch", text="To Backpack Checkpoint", text_size=22))

    p.note("StrangerDangerPark template built")
    p.created("Levels/StrangerDangerPark")
    return p.render()


__all__ = ["emit_stranger_danger_park_lua"]
