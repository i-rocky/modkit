extends CanvasLayer
## In-game record editor (toggle with F1). This is the Creation Kit seed:
## browse every record in the load order, edit it as JSON, apply it live,
## then export your changes as a mod pack that loads on next launch.
##
## It is deliberately built from the same primitives mods use — it reads and
## writes registry records and has no private engine access.

var record_list: ItemList
var json_edit: TextEdit
var status: Label
var mod_name_edit: LineEdit
var listed_ids: Array = []
var changed_ids: Dictionary = {}


func _init() -> void:
	layer = 10
	visible = false
	_build_ui()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_list()
		status.text = "Game paused while editing. F1 to resume."


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.custom_minimum_size.x = 480
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Record Editor — everything in the load order"
	vbox.add_child(title)

	record_list = ItemList.new()
	record_list.custom_minimum_size.y = 160
	record_list.item_selected.connect(_on_record_selected)
	vbox.add_child(record_list)

	json_edit = TextEdit.new()
	json_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	json_edit.placeholder_text = "Select a record above…"
	vbox.add_child(json_edit)

	var apply_row := HBoxContainer.new()
	vbox.add_child(apply_row)
	var apply_btn := Button.new()
	apply_btn.text = "Apply (rebuild world)"
	apply_btn.pressed.connect(_on_apply)
	apply_row.add_child(apply_btn)

	var save_row := HBoxContainer.new()
	vbox.add_child(save_row)
	mod_name_edit = LineEdit.new()
	mod_name_edit.placeholder_text = "my-first-mod"
	mod_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(mod_name_edit)
	var save_btn := Button.new()
	save_btn.text = "Export as mod"
	save_btn.pressed.connect(_on_export_mod)
	save_row.add_child(save_btn)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 48
	vbox.add_child(status)


func _refresh_list() -> void:
	record_list.clear()
	listed_ids = Registry.ids()
	for id in listed_ids:
		var label: String = id
		var sources: Array = Registry.sources(id)
		if sources.size() > 1:
			label += "   (overridden by: %s)" % sources.back()
		record_list.add_item(label)


func _on_record_selected(index: int) -> void:
	var id: String = listed_ids[index]
	json_edit.text = JSON.stringify(Registry.get_record(id), "\t")
	status.text = "Editing %s — sources: %s" % [id, ", ".join(Registry.sources(id))]


func _on_apply() -> void:
	var parsed: Variant = JSON.parse_string(json_edit.text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("id"):
		status.text = "Invalid: needs a JSON object with an \"id\" field."
		return
	Registry.put(parsed["id"], parsed, "live-edit")
	changed_ids[parsed["id"]] = true
	Events.world_rebuild_requested.emit()
	_refresh_list()
	var issues := Registry.validate(parsed["id"])
	if issues.is_empty():
		status.text = "Applied %s. F1 to play with it." % parsed["id"]
	else:
		status.text = "Applied %s, with warnings: %s" % [parsed["id"], "; ".join(issues)]


func _on_export_mod() -> void:
	if changed_ids.is_empty():
		status.text = "No applied changes to export yet."
		return
	var mod_id := mod_name_edit.text.strip_edges().to_lower().replace(" ", "-")
	if mod_id.is_empty():
		mod_id = "my-mod"
	var mod_path := ModLoader.MODS_DIR.path_join(mod_id)
	DirAccess.make_dir_recursive_absolute(mod_path.path_join("records"))
	_write_json(mod_path.path_join("pack.json"), {
		"id": mod_id,
		"name": mod_name_edit.text.strip_edges() if not mod_name_edit.text.is_empty() else mod_id,
		"version": "0.1.0",
	})
	for id in changed_ids:
		var file_name: String = String(id).replace(":", "_") + ".json"
		_write_json(mod_path.path_join("records").path_join(file_name), Registry.get_record(id))
	status.text = "Mod exported to %s — it loads automatically on next launch. Send that folder to a friend." % ProjectSettings.globalize_path(mod_path)


func _write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
