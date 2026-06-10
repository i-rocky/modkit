extends Node
## Loads content packs in order. The base game has zero privilege: it is just
## pack #0, living at res://packs/base in the same format as any mod.
##
## User packs are folders (or .zip files with the same layout) dropped into
## user://mods/. Order comes from user://mods/loadorder.txt — top loads
## first, unlisted mods are appended alphabetically, and the file is
## rewritten after each launch so it always lists what's installed. Later
## packs override earlier records by id (see Registry).
##
## Packs containing scripts are held until the player consents once per
## pack version ("code can do anything your computer can") — data-only packs
## are safe by construction and load without a prompt.
##
## Pack layout:
##   pack.json          manifest: {"id", "name", "version", "requires": []}
##   records/*.json     one record object, or an array of records, per file
##   scripts/*.gd       behaviors referenced by records via relative path

const MODS_DIR := "user://mods"
const LOAD_ORDER_FILE := "user://mods/loadorder.txt"
const EXTRACT_DIR := "user://mods/.extracted"
const TRUST_FILE := "user://mod_trust.json"

## Where the host game keeps its own content (pack #0). Override per project
## with the "modkit/base_pack_path" project setting.
var base_pack_path: String = ProjectSettings.get_setting("modkit/base_pack_path", "res://packs/base")

var loaded_packs: Array[Dictionary] = []
var pending_packs: Array[Dictionary] = []
var _trust: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(MODS_DIR)
	var stored: Variant = _read_json(TRUST_FILE)
	_trust = stored if typeof(stored) == TYPE_DICTIONARY else {}

	_load_pack(base_pack_path)
	for path in _discover_mods():
		var manifest := _read_manifest(path)
		if manifest.is_empty():
			continue
		if _has_scripts(path) and not _trust.get(_trust_key(manifest), false):
			pending_packs.append(manifest)
			print("[ModLoader] '%s' contains code — held for player consent." % manifest["id"])
		else:
			_load_pack_with_manifest(path, manifest)

	print("[ModLoader] %d pack(s) loaded, %d record(s) in registry." % [
		loaded_packs.size(), Registry.ids().size()])
	print("[ModLoader] Drop mod folders or zips into: %s" % ProjectSettings.globalize_path(MODS_DIR))
	var issues := Registry.validate_all()
	for id in issues:
		push_warning("[ModKit] %s: %s" % [id, "; ".join(issues[id])])


## Call from a scene once UI is possible: shows one consent dialog per held
## script-bearing pack, loads the approved ones, and remembers the answer
## per pack version. Returns true if anything was loaded (rebuild the world).
func resolve_pending(parent: Node) -> bool:
	if pending_packs.is_empty():
		return false
	if DisplayServer.get_name() == "headless":
		for manifest in pending_packs:
			print("[ModLoader] Headless run: script pack '%s' stays unloaded (no consent UI)." % manifest["id"])
		pending_packs.clear()
		return false
	var any_loaded := false
	for manifest in pending_packs:
		if await _ask_consent(parent, manifest):
			_trust[_trust_key(manifest)] = true
			_load_pack_with_manifest(manifest["path"], manifest)
			any_loaded = true
		else:
			print("[ModLoader] Skipped '%s' (player declined)." % manifest["id"])
	pending_packs.clear()
	_write_json(TRUST_FILE, _trust)
	return any_loaded


func _discover_mods() -> Array[String]:
	var entries: Dictionary = {}
	var dir := DirAccess.open(MODS_DIR)
	if dir == null:
		return []
	for name in dir.get_directories():
		if not name.begins_with("."):
			entries[name] = MODS_DIR.path_join(name)
	for file in dir.get_files():
		if file.ends_with(".zip"):
			var extracted := _extract_zip(MODS_DIR.path_join(file))
			if extracted != "":
				entries[file.get_basename()] = extracted

	var ordered: Array[String] = []
	for name in _read_load_order():
		if entries.has(name) and not ordered.has(name):
			ordered.append(name)
	var rest: Array[String] = []
	for name in entries:
		if not ordered.has(name):
			rest.append(name)
	rest.sort()
	ordered.append_array(rest)
	_write_load_order(ordered)

	var result: Array[String] = []
	for name in ordered:
		result.append(entries[name])
	return result


func _read_load_order() -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(LOAD_ORDER_FILE):
		return out
	var file := FileAccess.open(LOAD_ORDER_FILE, FileAccess.READ)
	if file == null:
		return out
	for raw_line in file.get_as_text().split("\n"):
		var line := raw_line.strip_edges()
		if line != "" and not line.begins_with("#"):
			out.append(line)
	return out


func _write_load_order(names: Array[String]) -> void:
	var file := FileAccess.open(LOAD_ORDER_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("# Mod load order — top loads first, later packs override earlier ones.\n")
	file.store_string("# Reorder lines freely; newly installed mods are appended on launch.\n")
	for name in names:
		file.store_line(name)


func _read_manifest(path: String) -> Dictionary:
	var manifest_path := path.path_join("pack.json")
	if not FileAccess.file_exists(manifest_path):
		push_warning("[ModLoader] Skipping %s: no pack.json" % path)
		return {}
	var manifest: Variant = _read_json(manifest_path)
	if typeof(manifest) != TYPE_DICTIONARY or not manifest.has("id"):
		push_warning("[ModLoader] Skipping %s: pack.json needs an \"id\"" % path)
		return {}
	manifest["path"] = path
	return manifest


func _load_pack(path: String) -> void:
	var manifest := _read_manifest(path)
	if not manifest.is_empty():
		_load_pack_with_manifest(path, manifest)


func _load_pack_with_manifest(path: String, manifest: Dictionary) -> void:
	for required in manifest.get("requires", []):
		var satisfied := false
		for pack in loaded_packs:
			if pack["id"] == required:
				satisfied = true
				break
		if not satisfied:
			push_warning("[ModLoader] Pack '%s' requires '%s', which is not loaded before it." % [manifest["id"], required])

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


func _has_scripts(path: String) -> bool:
	var dir := DirAccess.open(path.path_join("scripts"))
	if dir == null:
		return false
	for file in dir.get_files():
		if file.ends_with(".gd"):
			return true
	return false


func _trust_key(manifest: Dictionary) -> String:
	return "%s@%s" % [manifest["id"], manifest.get("version", "0")]


func _ask_consent(parent: Node, manifest: Dictionary) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Mod contains code"
	dialog.dialog_text = "\"%s\" contains scripts.\n\nCode can do anything your computer can.\nOnly load mods from people you trust.\n\nLoad it?" % manifest.get("name", manifest["id"])
	dialog.ok_button_text = "Load it"
	dialog.cancel_button_text = "Skip"
	var approved := [false]
	dialog.confirmed.connect(func(): approved[0] = true)
	parent.add_child(dialog)
	dialog.popup_centered()
	while dialog.visible:
		await parent.get_tree().process_frame
	dialog.queue_free()
	return approved[0]


func _extract_zip(zip_path: String) -> String:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		push_warning("[ModLoader] Could not open zip: " + zip_path)
		return ""
	var dest := EXTRACT_DIR.path_join(zip_path.get_file().get_basename())
	for file in reader.get_files():
		if file.ends_with("/"):
			continue
		var target := dest.path_join(file)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var out := FileAccess.open(target, FileAccess.WRITE)
		if out:
			out.store_buffer(reader.read_file(file))
	reader.close()
	if FileAccess.file_exists(dest.path_join("pack.json")):
		return dest
	# Tolerate zips that wrap the pack in a single top-level folder.
	var sub := DirAccess.open(dest)
	if sub:
		var dirs := sub.get_directories()
		if dirs.size() == 1 and FileAccess.file_exists(dest.path_join(dirs[0]).path_join("pack.json")):
			return dest.path_join(dirs[0])
	push_warning("[ModLoader] Zip has no pack.json: " + zip_path)
	return ""


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
