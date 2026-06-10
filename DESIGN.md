# Design — ModKit & the first game

Status: v0 FROZEN 2026-06-10 (M1). Format changes from here are versioned
and land in CHANGELOG.md; the pack format freezes fully at v1.0 (M6).

## 1. Vision

Bring back games that players own. A game built on this stack ships with its
own creation tools, stores all content in open formats, and treats mods as
first-class citizens — the way Skyrim, Quake, and Doom did, and the way
locked modern ecosystems don't.

Two deliverables, deliberately entangled:

- **ModKit** — a Godot plugin that gives any game Skyrim-style moddability:
  content packs, load-order overrides, an in-game editor, a mods folder.
- **The game** — small in scope, built *entirely* as ModKit packs. It is the
  proof, the demo, the template, and the tutorial.

### Non-goals

- Not a Godot fork. Public APIs only.
- Not a general-purpose engine. Godot is the engine; we are the freedom layer.
- Not a content marketplace with accounts/DRM/payments. Mods are files.
  Sharing them is the player's right, not a service we gatekeep.
- No mobile-first compromises. Desktop is home; web is the demo medium;
  Android only while it stays a checkbox; iOS not targeted.

## 2. Design principles

1. **Zero privilege.** The base game is pack #0 in the load order. If the
   game can do it, a mod can do it. Any feature that only the base game can
   use is a design bug.
2. **Records, not code.** All content — entities, rooms, items, dialogue —
   is data records with stable ids. Scripts implement *behaviors*; records
   decide *everything tunable*. New systems must be added as record types.
3. **The editor ships inside the game.** And the editor is built from the
   same primitives mods use, so the editor itself is moddable.
4. **Formats are the contract.** Once v1.0 freezes, record/pack formats only
   change backward-compatibly. Migrations are ModKit's job, not the modder's.
5. **Docs are part of the product.** Every record type and event is
   documented when it's added. We are modder #1.
6. **Boring technology.** JSON, folders, GDScript. A 14-year-old with a text
   editor is the design target for the modding floor.

## 3. Architecture (layers, top of each uses only the one below)

```
┌────────────────────────────────────────────────┐
│ Mods (packs #1..N)                             │
├────────────────────────────────────────────────┤
│ The game (pack #0) + in-game editor            │
├────────────────────────────────────────────────┤
│ ModKit plugin: ModLoader · Registry · Events   │
│ + record schemas + world builder contract      │
├────────────────────────────────────────────────┤
│ Godot 4.x (rendering, physics, input, export)  │
└────────────────────────────────────────────────┘
```

ModKit's public surface (the API mods and games program against):

- `Registry` — record store: `get_record(id)`, `put(id, rec, source)`,
  `ids()`, `sources(id)`, query-by-type.
- `ModLoader` — pack discovery and load order.
- `Events` — global signal bus; every gameplay system announces itself here.
- Record schemas — per-type field definitions (drives validation + editor UI).

## 4. Pack format (v0 — working draft)

```
<pack-id>/
├── pack.json        manifest (required)
├── records/         *.json — one record or an array per file (recursive)
├── scripts/         *.gd — behaviors referenced by records
└── assets/          images, audio, fonts — referenced by records
```

`pack.json`:

```json
{
	"id": "greenjump",            // stable, lowercase, no spaces — the namespace
	"name": "Green Jump",
	"version": "1.2.0",            // semver
	"modkit": "1",                 // pack-format major version it targets
	"requires": ["base"],          // packs that must load before this one
	"description": "...",
	"authors": ["..."]
}
```

- Mods are **folders** in `user://mods/` (hackable with a text editor) or
  **.zip** of the same layout (easy sharing). `.pck` is an internal detail
  for the base game only.
- Load order: base pack, then mods sorted by a user-editable
  `user://mods/loadorder.txt` (missing entries appended alphabetically).
  Dependency violations (`requires` not satisfied) are reported, not fatal.

## 5. Record system (v0 — working draft)

A record is a JSON object: `{"id": "<pack>:<name>", "type": "<schema>", ...}`.

- **Ids are forever.** `base:player` must mean the player in every version.
  Renames are aliases, never replacements.
- **Override**: redeclaring an id replaces the record. **Patch**
  (`"patch": true`): shallow-merge into the current record. Future
  (pre-1.0): list operations (`append`, `remove`) and delete tombstones.
- **Schemas**: each `type` declares its fields, types, defaults, and ranges
  in a schema record (schemas are themselves records — so mods can add new
  record *types*). Schemas drive validation at load and the editor's
  property UI.
- **Provenance**: the registry remembers which packs touched each record —
  the conflict-inspection story (load-order debugging is half of modding).

Initial record types for the game: `room`, `door`, `entity`, `sprite`,
`sound`, `item`, plus `schema` itself. Grown one at a time, each with docs.

**New maps are first-class.** The world is a graph: `room` records linked by
`door` records (a door names its target room id and entry point). A
Skyrim-style "new lands" mod is therefore just a pack shipping new `room` and
`door` records — including a door that hooks its area into an existing base
room. No special casing, no world editor required (though E2 makes it nicer).

## 6. Scripting & trust model

- Mod scripts are GDScript, loaded at runtime, with **full engine access** —
  the Skyrim trust model. Sandboxing GDScript is not realistically
  achievable, and pretending otherwise is worse than honesty.
- Tiering: **data-only mods are safe by construction** (JSON + assets, no
  scripts). The loader knows whether a pack contains scripts and tells the
  player before first load ("This mod contains code. Code can do anything
  your computer can."). One prompt, remembered per pack version.
- Scripts integrate via `Events` and record references — never by patching
  other packs' scripts. Hooks grow with the game (entity lifecycle, input,
  room transitions, save/load).

## 7. In-game editor roadmap

- **E0 (done, spike)**: raw JSON per record, apply-live, export-as-mod.
- **E1**: schema-driven property inspector (sliders, color pickers, dropdowns
  generated from schemas) with raw-JSON fallback. Diff view: what your mod
  changes vs. the load order beneath it.
- **E2**: visual room editing — click platforms/entities to select, drag to
  move, with records updating live. The bridge from "tweaker" to "creator".
- **E3**: asset import (drop a PNG, it lands in your mod's `assets/`),
  zip-export and a "share" flow.

## 8. Saves vs. load order

Saves store record ids + instance state, never copies of record data, so
content updates apply to old saves. A save remembers the load order that
produced it; loading with mods missing → warn and offer to continue (orphan
instances despawn gracefully). This is the Skyrim problem; we design for it
from the first save file rather than retrofitting.

## 9. Platforms

Priority follows real-world usage: biggest platform first, lesser ones after,
and only while they stay cheap.

| Target   | Priority | Notes                                              |
|----------|----------|----------------------------------------------------|
| Windows  | P0       | where the players and modders are                  |
| Linux    | P0       | dev platform; comes free with Windows support      |
| Web      | P1       | shareable demo; ships data-mods-only at first      |
| Android  | P2       | only while it remains a checkbox                   |
| iOS      | —        | not targeted                                       |

## 10. Milestones

- **M0 — Spike.** DONE. Pack loading, overrides, live edit, export-as-mod.
- **M1 — Design freeze v0.** This document agreed; record/pack format and
  event-naming conventions written down; open decisions below resolved.
- **M2 — ModKit v0.2.** Schemas + validation, load-order file, `requires`,
  zip mods, script-trust prompt, provenance API. Demo game updated.
- **M3 — Game vertical slice.** One complete, *fun* slice of the game:
  several rooms connected by doors, player, 2–3 entity types, items, sound,
  win/lose. 100% records — and a "new lands" test mod that adds a room.
- **M4 — Editor E1.** Property inspector + diff view.
- **M5 — First outside modder.** A friend makes a mod using only README +
  in-game editor. Their confusion is the bug list. (This is the real test.)
- **M6 — ModKit v1.0 format freeze** + Asset Library submission + game demo
  on the web/itch.io.

## 11. Decisions (resolved 2026-06-10)

1. **The game is room-graph-first.** Hard requirement from the owner:
   adding new maps must be as easy as it is in Skyrim. Hence `room` + `door`
   records form a world graph and a new-lands mod is just more records (§5).
   Genre: multi-room platformer, building on the spike — revisit only if it
   fights the moddability goals.
2. **Name: ModKit.** Godot Asset Library has no existing asset by that name
   (checked 2026-06-10). Prior art to track and differentiate from:
   GodotModding/godot-mod-loader (script-patching mod loader, Steam
   Workshop/Thunderstore focus), audse/mod-system, Modular Godot. Our
   distinction: records/load-order architecture + the editor ships in-game.
   Monorepo until v1.0, then split plugin and game.
3. **Platform order follows usage** (§9): Windows/Linux first-class, web
   next as data-mods-only, Android while it stays a checkbox, no iOS.
4. **License: MIT** for all code (plugin + game code), matching Godot's
   spirit. Game content (art, audio, records) CC-BY so remixing is
   maximally legal. LICENSE file in repo root.
