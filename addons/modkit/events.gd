extends Node
## Global event bus. Mods (and the in-game editor) connect to these signals
## instead of patching core code, so packs never need to know about each other.

signal pack_loaded(pack_id: String)
signal record_changed(record_id: String)
signal world_rebuild_requested
