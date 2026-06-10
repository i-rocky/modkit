extends Node
## Loads content packs in order. The base game has zero privilege: it is just
## pack #0, living at res://packs/base in the same format as any mod.
##
## User packs are folders dropped into user://mods/<name>/, loaded in
## alphabetical order after the base pack. Later packs override earlier
## records by id (see Registry).
##
## Pack layout:
##   pack.json          manifest: {"id", "name", "version"}
##   records/*.json     one record object, or an array of records, per file
##   scripts/*.gd       behaviors referenced by records via relative path

const MODS_DIR := "user://mods"

## Where the host game keeps its own content (pack #0). Override per project
## with the "modkit/base_pack_path" project setting.
var base_pack_path: String = ProjectSettings.get_setting("modkit/base_pack_path", "res://packs/base")

var loaded_packs: Array[Dictionary] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(MODS_DIR)
	_load_pack(base_pack_path)
	for mod_path in _discover_mods():
		_load_pack(mod_path)
	print("[ModLoader] %d pack(s) loaded, %d record(s) in registry." % [
		loaded_packs.size(), Registry.ids().size()])
	print("[ModLoader] Drop mod folders into: %s" % ProjectSettings.globalize_path(MODS_DIR))


func _discover_mods() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(MODS_DIR)
	if dir == null:
		return result
	var names := dir.get_directories()
	names.sort()
	for name in names:
		result.append(MODS_DIR.path_join(name))
	return result


func _load_pack(path: String) -> void:
	var manifest_path := path.path_join("pack.json")
	if not FileAccess.file_exists(manifest_path):
		push_warning("[ModLoader] Skipping %s: no pack.json" % path)
		return
	var manifest: Variant = _read_json(manifest_path)
	if typeof(manifest) != TYPE_DICTIONARY or not manifest.has("id"):
		push_warning("[ModLoader] Skipping %s: pack.json needs an \"id\"" % path)
		return
	manifest["path"] = path

	var records_dir := path.path_join("records")
	var dir := DirAccess.open(records_dir)
	if dir:
		var files := dir.get_files()
		files.sort()
		for file in files:
			if file.ends_with(".json"):
				_ingest(_read_json(records_dir.path_join(file)), manifest)

	loaded_packs.append(manifest)
	Events.pack_loaded.emit(manifest["id"])
	print("[ModLoader] Loaded pack '%s' from %s" % [manifest.get("name", manifest["id"]), path])


func _ingest(data: Variant, manifest: Dictionary) -> void:
	if typeof(data) == TYPE_ARRAY:
		for item in data:
			_ingest(item, manifest)
	elif typeof(data) == TYPE_DICTIONARY and data.has("id"):
		var record: Dictionary = data
		# Script paths in records are relative to their pack.
		if record.has("script") and not String(record["script"]).contains("://"):
			record["script"] = String(manifest["path"]).path_join(record["script"])
		Registry.put(record["id"], record, manifest["id"])


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())
