# Changelog

All notable changes to this project are documented in this file — every
change lands here in the same commit that makes it.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/).
Until 1.0.0, minor versions may break formats; the pack format freezes at
1.0.0 (see DESIGN.md §10, milestone M6).

## [Unreleased]

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
