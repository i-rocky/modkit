# Changelog

All notable changes to this project are documented in this file — every
change lands here in the same commit that makes it.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/).
Until 1.0.0, minor versions may break formats; the pack format freezes at
1.0.0 (see DESIGN.md §10, milestone M6).

## [Unreleased]

## [0.3.0] - 2026-06-10

### Added

- **Room graph**: the world is now rooms connected by doors. `door` records
  declare which room they sit in (`"room"`) and where they lead
  (`"target_room"`, `"target_spawn"`) — so a mod can hook a new area into
  any existing room without patching it. "New lands" mods are just records.
- **Game vertical slice**: three rooms (start, cave, summit), two enemy
  types (`base:walker` patrols and turns at edges/walls; `base:flyer`
  drifts in a figure-eight), coins, and a win star. HUD tracks coins and
  deaths; touching an enemy or falling respawns you; collecting the star
  wins (R restarts).
- **Sound**: procedurally generated WAVs (jump, coin, hurt, win) in the base
  pack; records reference sounds by pack-relative path; mods can ship their
  own. Played via the `Events.play_sound` bus.
- **Skylands example mod** (`examples/mods/skylands/`): a complete
  new-lands mod — a new room with four coins and a flyer, hooked into the
  summit with two door records. Data-only, no base-game edits.
- New events for mods: `room_changed`, `player_hit`, `item_collected`,
  `game_won`, `play_sound`.
- `MODKIT_START_ROOM` environment variable to boot directly into any room
  (used for testing).

### Changed

- **Entity/item placement format**: rooms now place things as
  `{"ref": "<record-id>", "at": [x, y]}` objects (was a bare id list).
  The player is no longer listed in rooms; the shell spawns it at the room's
  `spawn` or the door's `target_spawn`.
- Pack-relative resource paths now resolve generally at ingest (any string
  field starting with `scripts/` or `assets/`), not just `script`.

## [0.2.0] - 2026-06-10

### Added

- **Record schemas**: schemas are records themselves (`"type": "schema"`,
  `"describes": "<type>"`) declaring fields, types, defaults, and ranges.
  Defaults are applied on read, so records and mods only state what they
  change. Base pack ships `entity` and `room` schemas.
- **Validation**: every record is checked against its schema after load and
  on live edits in the F1 editor — wrong types, out-of-range numbers, and
  unknown fields are reported as warnings. Broken mods never block a load.
- **`user://mods/loadorder.txt`**: user-editable load order, top loads
  first; newly installed mods are appended alphabetically on launch.
- **Zip mods**: a `.zip` of a pack dropped into the mods folder works like
  a folder (single wrapping directory inside the zip is tolerated).
- **`requires`** in `pack.json`: unsatisfied dependencies are reported as
  warnings (never fatal), checked against load order.
- **Script-trust prompt**: packs containing `.gd` scripts are held at boot
  until the player consents ("code can do anything your computer can"),
  remembered per pack version in `user://mod_trust.json`. Data-only packs
  load without prompting. Headless runs leave unconsented script packs
  unloaded.
- **Provenance API**: `Registry.conflicts()`, `Registry.ids_by_type()`,
  `Registry.schema_for()`.

### Fixed

- World builder no longer crashes on malformed record values (e.g. a
  non-string color) — bad data degrades to defaults with a warning.

## [0.1.0] - 2026-06-10

### Added

- **ModKit plugin** (`addons/modkit/`), installable in any Godot 4 project:
  - `ModLoader` — loads content packs in order: the base game as pack #0
    (path configurable via the `modkit/base_pack_path` project setting),
    then mod folders from `user://mods/` alphabetically.
  - `Registry` — record store with stable ids, load-order overrides,
    `"patch": true` shallow-merge semantics, and per-record provenance
    (override chains are logged at load).
  - `Events` — global signal bus (`pack_loaded`, `record_changed`,
    `world_rebuild_requested`) for mods to hook instead of patching code.
  - In-game record editor overlay (F1): browse the load order, edit records
    as JSON, apply live with world rebuild, and export changes as a mod pack.
- **Demo game**: a minimal platformer defined 100% as records
  (`packs/base/`) — room, platforms, and player tuning all live in JSON.
- **Example mod** (`examples/mods/greenjump/`): a two-file pack that patches
  the player's color and jump height, demonstrating override-by-id.
- `DESIGN.md` — full project design: principles, pack/record format drafts,
  trust model, editor roadmap, platform priorities, milestones M0–M6.
- MIT license.
