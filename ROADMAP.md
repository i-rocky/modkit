# Roadmap

The long version, with rationale, lives in [DESIGN.md](DESIGN.md) §10.
This file tracks status; details live there.

- [x] **M0 — Spike.** Pack loading, load-order overrides, live in-game
  editing, export-as-mod. Proved the architecture works.
- [ ] **M1 — Design freeze v0.** DESIGN.md agreed; pack/record formats and
  event-naming conventions written down. *In review — decisions resolved,
  owner read-through of formats pending.*
- [ ] **M2 — ModKit v0.2.** Record schemas + validation, `loadorder.txt`,
  `requires` between packs, zip mods, script-trust prompt, provenance API.
- [ ] **M3 — Game vertical slice.** Several rooms connected by doors,
  player, 2–3 entity types, items, sound, win/lose — 100% records — plus a
  "new lands" test mod that adds a room to prove map modding.
- [ ] **M4 — Editor E1.** Schema-driven property inspector (sliders, color
  pickers) replacing raw JSON as the default, with diff view against the
  load order.
- [ ] **M5 — First outside modder.** Someone who isn't us makes a mod using
  only the README and the in-game editor. Their confusion is the bug list.
- [ ] **M6 — ModKit v1.0.** Pack format freeze, Godot Asset Library
  submission, game demo playable on the web.
