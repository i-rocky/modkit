# ModKit

**Skyrim-style moddability for any Godot game** — content packs,
load-order overrides, and an in-game editor that ships with your game.

Built on [Godot 4](https://godotengine.org). The core rule: **the base game
has zero privilege over a mod.** The game you play is just pack #0 in a load
order; every mod is a pack with the same powers. This repo contains the
ModKit plugin (`addons/modkit/`) and a small demo game built entirely with
it.

[Design](DESIGN.md) · [Roadmap](ROADMAP.md) · [Changelog](CHANGELOG.md) ·
MIT licensed ([code](LICENSE); game content CC-BY)

## Run it

```sh
godot --path .        # play (F1 opens the in-game editor)
godot --path . -e     # open the Godot editor
```

Move with arrow keys, jump with Space. Press **F1** to open the record editor,
change something (try the player's `color` or `jump_velocity`), hit
**Apply**, press F1 again, and you're playing your edit. **Export as mod**
writes your changes as a pack that loads automatically on every launch.

## How it works

- `addons/modkit/` — **ModKit**, the moddability layer as a reusable Godot
  plugin: pack loader, record registry, event bus, and the in-game editor.
  This is the only privileged code, and it ships with the game.
- `packs/base/` — the game itself, in the exact format mods use.
- `main.gd` — builds the world purely from registry records and can rebuild
  it at any moment (that's what makes live editing work).

## Using ModKit in your own Godot game

ModKit is a standard Godot plugin — this repo doubles as its demo project.

1. Copy `addons/modkit/` into your project and enable **ModKit** under
   Project Settings → Plugins. It registers three autoloads: `ModLoader`,
   `Registry`, and `Events`.
2. Put your game's content in a pack (default `res://packs/base`; change it
   with the `modkit/base_pack_path` project setting). Content is JSON
   records with stable ids — see *Records* below.
3. Build your world by reading records from `Registry` instead of hardcoding
   values, and rebuild it when `Events.world_rebuild_requested` fires.
4. Instantiate the overlay (`addons/modkit/overlay.gd`) and call `toggle()`
   on a hotkey to give players the in-game editor.

Your players drop mod folders into `user://mods/` and your game is moddable
with load-order overrides — no engine fork, no custom builds.

## Modding

Mods are folders dropped into the user mods directory (the game prints the
exact path on launch — on Linux it's
`~/.local/share/godot/app_userdata/gamengine/mods/`). They load in
alphabetical order after the base pack. Later packs win.

### Pack layout

```
my-mod/
├── pack.json            {"id": "my-mod", "name": "My Mod", "version": "0.1.0"}
├── records/*.json       one record object (or an array of them) per file
└── scripts/*.gd         optional behaviors, referenced by records
```

### Records

A record is a JSON object with a stable `id`, namespaced by pack:

```json
{
	"id": "base:player",
	"type": "entity",
	"script": "scripts/player.gd",
	"color": "#e8554d",
	"size": [48, 48],
	"move_speed": 320,
	"jump_velocity": -680,
	"gravity": 1600
}
```

A mod overrides a record by redeclaring its `id`. To change only some fields,
add `"patch": true` and the record is shallow-merged instead of replaced:

```json
{
	"id": "base:player",
	"patch": true,
	"color": "#41d97a",
	"jump_velocity": -950
}
```

That's a complete mod (with a `pack.json` next to it): the player turns green
and jumps half again as high. `script` paths are relative to the pack that
declares them, so mods can ship new behaviors, not just new numbers.

### Events

Mod scripts can connect to the global `Events` bus (`pack_loaded`,
`record_changed`, `world_rebuild_requested`) instead of patching core code.
More hooks will be added as the game grows — every new system should announce
itself through events.
