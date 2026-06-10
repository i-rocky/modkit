extends Node
## Headless smoke test for the in-game editor. Run with:
##   godot --headless --path . res://tests/ui_smoke.tscn
## Exits 0 on pass, 1 on failure.

var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	var overlay: CanvasLayer = preload("res://addons/modkit/overlay.gd").new()
	add_child(overlay)
	overlay.toggle()

	# Building the inspector for every record covers every schema type.
	for i in overlay.listed_ids.size():
		overlay._on_record_selected(i)

	# Inspector apply: simulate a control edit via its getter.
	overlay._on_record_selected(overlay.listed_ids.find("base:player"))
	overlay._getters["move_speed"] = func(): return 500.0
	overlay._on_apply()
	_check(Registry.get_record("base:player").get("move_speed") == 500.0,
		"inspector apply changes move_speed")
	_check(overlay.diff_label.text.contains("move_speed"),
		"diff view reports the change")

	# Raw JSON apply (full record replace).
	overlay.raw_toggle.button_pressed = true
	overlay._on_raw_toggled(true)
	overlay.json_edit.text = JSON.stringify({"id": "base:coin", "type": "item", "value": 5})
	overlay._on_apply()
	_check(Registry.get_record("base:coin").get("value") == 5, "raw apply changes value")

	# Export: player should come out as a minimal patch, coin as full record.
	overlay.mod_name_edit.text = "smoke-test"
	overlay._on_export_mod()
	var player_patch: Variant = _read_json("user://mods/smoke-test/records/base_player.json")
	_check(typeof(player_patch) == TYPE_DICTIONARY and player_patch.get("patch") == true
		and player_patch.get("move_speed") == 500.0 and not player_patch.has("gravity"),
		"export writes minimal patch for player")
	var coin_export: Variant = _read_json("user://mods/smoke-test/records/base_coin.json")
	_check(typeof(coin_export) == TYPE_DICTIONARY and not coin_export.get("patch", false),
		"export writes full record when fields were removed")

	_cleanup("user://mods/smoke-test")
	print("UI smoke: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _check(condition: bool, what: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: " + what)


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _cleanup(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_cleanup(dir_path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(dir_path)
