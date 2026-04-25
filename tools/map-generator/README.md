# buddy-map-generator

high-level mcp server that scaffolds the **buddy bridge** studio map. it emits
lua and ships it to roblox studio via the official `rbx-studio-mcp` (which
exposes a `run_code` tool). the goal is one button — `build_preliminary_map`
— that produces a tag-correct, attribute-correct, palette-consistent skeleton
of the lobby, play arena slots, both level templates, npc rigs, item models,
and the guide booth, ready for user 1 to polish in studio.

read `prompts/user1_map_prompt.md` and `docs/TECHNICAL_DESIGN.md` first —
those documents are the spec this generator implements.

## why this exists

user 1's job is to build the entire map by hand in studio. the spec is
~80% mechanical (parts at coordinates with the right tags + attributes).
this mcp does the mechanical part so user 1 can spend time on the
judgment-call work: visual polish, decoration, tone.

## prerequisites

- roblox studio open with the place file
- the boshyxd `robloxstudio-mcp` studio plugin installed and **active**
  (download `MCPPlugin.rbxmx` from
  https://github.com/boshyxd/robloxstudio-mcp/releases and drop it in your
  studio plugins folder)
- "allow http requests" enabled in studio's experience settings → security
- node + npx on `$PATH` (the npm package `robloxstudio-mcp@latest` is fetched
  on demand)
- python 3.11+

### backend choice

`buddy-map-generator` can drive either backend:

- **boshyxd `robloxstudio-mcp` (default)** — npx-spawned, 43 tools, cleaner
  api. uses the `MCPPlugin.rbxmx` studio plugin.
- **official `rbx-studio-mcp`** — stdio binary at `~/.local/bin/rbx-studio-mcp`
  with its own `MCPStudioPlugin.rbxm`. switch with
  `BUDDY_STUDIO_BACKEND=rbx-studio`.

> **note:** because `buddy-map-generator` spawns its own studio backend, do
> not also load the standalone `robloxstudio` mcp at the same time — they
> race for the same studio plugin connection. choose one. for ad-hoc studio
> work pick the standalone; for building the map pick `buddy-map-generator`.

## install

```bash
cd tools/map-generator
pip install -e .
```

## usage

the mcp is wired into `LAHacks/buddy-bridge/.mcp.json`. opening claude code
in the project dir picks it up automatically alongside the official
`roblox-studio` mcp.

### tools

- `build_lobby(pair_count=4)` — lobby hub, spawn, treehouse, capsule pads
- `build_play_arena_slots(slot_count=4)` — 4 hidden slots at y=-500
- `build_stranger_danger_park` — park level template (hot dog stand, playground,
  white van, alley, ranger booth, fountain, npc spawns, puppy spawns, portal)
- `build_backpack_checkpoint` — tsa-style sorting level (conveyor, 3 bins, exit)
- `build_npc_templates` — 7 npc rigs (vendor, ranger, parent, casual, hooded,
  vehicle-leaner, knife-archetype with detachable accessory)
- `build_item_templates` — 13 cartoon item models named per gameplay spec
- `build_booth_template` — cozy lookout-cabin guide booth
- `build_polish_pass` — lighting, atmosphere, sfx placeholders
- `verify_style` — walks the map and reports material / font / tag drift
- `screenshot` — captures the studio window
- `build_preliminary_map(...)` — runs every step in order, screenshots after
  each step

### dry-run mode

set `BUDDY_MAP_DRY_RUN=1` to short-circuit each tool. the tool returns the
emitted lua instead of contacting studio. useful for unit-test-style
inspection without studio open.

```bash
BUDDY_MAP_DRY_RUN=1 python3 -m buddy_map_generator.server
```

### tests

```bash
cd tools/map-generator
python3 -m unittest discover tests
```

52 contract tests covering: emitter output is non-empty; canonical tags +
attributes appear in the right emitters; all 13 item keys + 6 park scene
anchors + 3 lane ids appear; no forbidden materials; only `Cartoon` font.

## design notes

- **single source of truth for style.** `style.py` owns the palette, allowed
  materials, font, and proportions. every tool imports constants from there.
  judge andrew flagged consistency as make-or-break — never inline a color
  inside a tool.
- **single source of truth for tag/attribute names.** `style.Tags` and
  `style.Attributes` mirror `docs/TECHNICAL_DESIGN.md` "map object
  conventions". rename in one place, not seven.
- **idempotent.** every tool removes any prior copy of its outputs before
  rebuilding so re-runs converge on the same state.
- **lua emission as pure text.** generators are testable as plain string
  assertions. `lua_emit.LuaProgram` is the only stateful surface.
- **studio is optional during dev.** the dry-run path means you can iterate
  on emitters without studio open.

## visual style bible (pulled from `prompts/user1_map_prompt.md`)

- palette: warm cartoon — soft greens, friendly oranges, cozy browns
- materials: smoothplastic, plastic, wood, woodplanks, grass, sand, concrete,
  cobblestone (verified by `verify_style`)
- font: `Cartoon` everywhere
- proportions: chunky, multiples of 2 studs where possible
- avoid: metal, glass, neon (except sparkle accents), forcefield, diamondplate,
  slate, horror lighting, nightclub lighting

## extending

adding a new builder:

1. create `src/buddy_map_generator/tools/<name>.py` exposing
   `emit_<name>_lua() -> str`
2. add a `@mcp.tool()` wrapper in `server.py` that calls
   `_run_or_return(lua, label="build_<name>")`
3. (optional) add to the `build_preliminary_map` orchestrator's step list
