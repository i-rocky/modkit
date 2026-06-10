---
layout: default
title: ModKit
---

# Games that players own

ModKit is a [Godot 4](https://godotengine.org) plugin that gives any game
**Skyrim-style moddability**: content packs with load-order overrides, a
mods folder, and an in-game editor that ships with the game.

Remember when games came with their own creation tools? When a kid with a
text editor could change the rules at midnight and send the result to a
friend? Modern engines locked that door. ModKit is the crowbar.

## The core rule

**The base game has zero privilege over a mod.** A ModKit game is just
pack #0 in a load order — the same JSON-records-and-scripts format every mod
uses. If the game can do it, a mod can do it. Moddability isn't a feature
bolted on; it's the only way the game loads itself.

## What a mod looks like

A complete mod is a folder with two small files. This one makes the player
green and jump half again as high:

```json
// pack.json
{ "id": "greenjump", "name": "Green Jump", "version": "0.1.0" }

// records/player_patch.json
{ "id": "base:player", "patch": true, "color": "#41d97a", "jump_velocity": -950 }
```

Drop it in the mods folder. Done. Records with stable ids, override by load
order, shallow patches — the ESM/ESP mechanic, generalized.

## The editor ships inside the game

Press **F1** while playing: browse every record in the load order, edit it,
watch the world rebuild live, then export your changes as a mod pack to
share. The editor is built from the same primitives mods use — so the editor
itself is moddable.

## For Godot developers

ModKit is a standard plugin: copy `addons/modkit/` into your project, enable
it, put your content in packs, build your world from the record registry.
Your game ships moddable — no engine fork, no custom builds. MIT licensed.

## Status

Early and moving. The spike is done and proven; the design is public; the
pack format freezes at v1.0. Follow along:

- [Download the demo game](https://github.com/i-rocky/modkit/releases/latest) (Windows · Linux)
- [Source on GitHub](https://github.com/i-rocky/modkit)
- [Design document](https://github.com/i-rocky/modkit/blob/main/DESIGN.md)
- [Roadmap](https://github.com/i-rocky/modkit/blob/main/ROADMAP.md)
- [Changelog](https://github.com/i-rocky/modkit/blob/main/CHANGELOG.md)
