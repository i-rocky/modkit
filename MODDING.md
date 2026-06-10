# How to mod this game — the one-pager

This game ships with its own editor and treats your mods exactly like its
own content. You need a text editor at most; for simple mods, not even that.

## The 60-second mod (no files involved)

1. Play, then press **F1**. Every record in the game appears — the player,
   enemies, rooms, items.
2. Pick `base:player`, drag a slider, change the color. **Apply.** Press F1
   and play your change.
3. Type a name in the box, hit **Export as mod**. Done — your edits load on
   every launch from now on, and the editor shows you the folder it wrote.
4. Send that folder to a friend. They drop it in their mods folder. Now
   it's their game too.

## Where the mods folder is

The game prints the exact path in its console on launch. By default:

| OS      | Path                                                          |
|---------|---------------------------------------------------------------|
| Windows | `%APPDATA%\Godot\app_userdata\modkit-demo\mods\`              |
| Linux   | `~/.local/share/godot/app_userdata/modkit-demo/mods/`         |
| macOS   | `~/Library/Application Support/Godot/app_userdata/modkit-demo/mods/` |

Mods are folders (or zips). Load order lives in `mods/loadorder.txt` — top
loads first, later mods override earlier ones. Edit it freely.

## Anatomy of a mod

```
my-mod/
├── pack.json       {"id": "my-mod", "name": "My Mod", "version": "1.0.0", "requires": ["base"]}
├── records/        what your mod adds or changes (JSON)
├── scripts/        optional new behaviors (GDScript)
└── assets/         optional sounds, images
```

Everything in the game is a **record** with a stable id. To change one, you
redeclare it. To change just a few fields, patch it — this is a complete
record file:

```json
{"id": "base:player", "patch": true, "color": "#41d97a", "jump_velocity": -950}
```

Green player, higher jump. That plus a `pack.json` is a whole mod.

## Adding new places

The world is rooms connected by doors, and a door record says which room it
sits in — so your mod can add a new area to the existing world without
touching any base file:

```json
[
	{"id": "my-mod:secret_room", "type": "room",
	 "platforms": [[0, 656, 1280, 64], [500, 450, 200, 24]],
	 "items": [{"ref": "base:coin", "at": [560, 414]}]},
	{"id": "my-mod:way_in", "type": "door", "room": "base:room_start",
	 "at": [600, 576], "target_room": "my-mod:secret_room", "target_spawn": [100, 560]}
]
```

A door appears in the first room of the game, leading to your room.

## New behaviors

Records can reference scripts (`"script": "scripts/boss.gd"`, relative to
your mod). Scripts are GDScript with full engine access — which is why the
game asks the player once before loading any mod that contains code. Mods
that are data-only (JSON + assets) never trigger that prompt. Hook into the
game through the `Events` bus (`room_changed`, `player_hit`,
`item_collected`, `game_won`, `play_sound`) rather than reaching into other
packs.

## Rules of the road

- Your ids are namespaced by your pack id: `my-mod:thing`. Never reuse
  someone else's namespace.
- Overriding a base record is normal and encouraged — that's the system
  working, not a hack.
- If something's wrong, the game says so at launch (bad fields, missing
  dependencies) but keeps running. Broken mods warn; they don't crash.

Full docs: https://github.com/i-rocky/modkit
