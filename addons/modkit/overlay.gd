extends CanvasLayer
## In-game record editor (toggle with F1). This is the Creation Kit seed:
## browse every record in the load order, edit it with schema-driven
## controls (or raw JSON), apply it live, then export your changes as a
## minimal patch-mod that loads on next launch.
##
## It is deliberately built from the same primitives mods use — it reads and
## writes registry records and has no private engine access.

var record_list: ItemList
var inspector_scroll: ScrollContainer
var inspector_box: VBoxContainer
var json_edit: TextEdit
var raw_toggle: CheckButton
var diff_label: Label
var status: Label
var mod_name_edit: LineEdit

var listed_ids: Array = []
var current_id := ""
var baselines := {}
var changed_ids := {}
var _getters := {}


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
	panel.custom_minimum_size.x = 520
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Record Editor — everything in the load order"
	vbox.add_child(title)

	record_list = ItemList.new()
	record_list.custom_minimum_size.y = 150
	record_list.item_selected.connect(_on_record_selected)
	vbox.add_child(record_list)

	raw_toggle = CheckButton.new()
	raw_toggle.text = "Raw JSON"
	raw_toggle.toggled.connect(_on_raw_toggled)
	vbox.add_child(raw_toggle)

	inspector_scroll = ScrollContainer.new()
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(inspector_scroll)
	inspector_box = VBoxContainer.new()
	inspector_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.add_child(inspector_box)

	json_edit = TextEdit.new()
	json_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	json_edit.placeholder_text = "Select a record above…"
	json_edit.visible = false
	vbox.add_child(json_edit)

	diff_label = Label.new()
	diff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(diff_label)

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
		var rec_type: String = Registry.get_record(id).get("type", "")
		if rec_type != "":
			label += "  ·  " + rec_type
		var sources: Array = Registry.sources(id)
		if sources.size() > 1:
			label += "   (overridden by: %s)" % sources.back()
		record_list.add_item(label)
	var idx := listed_ids.find(current_id)
	if idx >= 0:
		record_list.select(idx)


func _on_record_selected(index: int) -> void:
	current_id = listed_ids[index]
	var rec := Registry.get_record(current_id)
	json_edit.text = JSON.stringify(rec, "\t")
	_build_inspector(rec)
	_update_diff()
	status.text = "%s — sources: %s" % [current_id, ", ".join(Registry.sources(current_id))]


func _on_raw_toggled(pressed: bool) -> void:
	inspector_scroll.visible = not pressed
	json_edit.visible = pressed
	if current_id == "":
		return
	var rec := Registry.get_record(current_id)
	if pressed:
		json_edit.text = JSON.stringify(rec, "\t")
	else:
		_build_inspector(rec)


# --- Inspector -------------------------------------------------------------


func _build_inspector(rec: Dictionary) -> void:
	for child in inspector_box.get_children():
		child.queue_free()
	_getters.clear()
	if rec.is_empty():
		return
	var fields: Dictionary = Registry.schema_for(rec.get("type", "")).get("fields", {})
	for key in rec:
		if key == "id" or key == "type":
			continue
		inspector_box.add_child(_make_row(key, rec[key], fields.get(key, {})))


func _make_row(key: String, value: Variant, spec: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = key
	label.custom_minimum_size.x = 130
	row.add_child(label)

	match spec.get("type", _infer_type(value)):
		"number":
			if spec.has("min") and spec.has("max"):
				_add_slider(row, key, value, spec)
			else:
				_add_spinbox(row, key, value, spec)
		"color":
			var picker := ColorPickerButton.new()
			picker.custom_minimum_size.x = 90
			if typeof(value) == TYPE_STRING and Color.html_is_valid(value):
				picker.color = Color(value)
			row.add_child(picker)
			_getters[key] = func(): return "#" + picker.color.to_html(false)
		"bool":
			var check := CheckBox.new()
			check.button_pressed = bool(value)
			row.add_child(check)
			_getters[key] = func(): return check.button_pressed
		"vec2":
			var pair: Array = value if typeof(value) == TYPE_ARRAY and value.size() == 2 else [0, 0]
			var x := _bare_spinbox(pair[0])
			var y := _bare_spinbox(pair[1])
			row.add_child(x)
			row.add_child(y)
			_getters[key] = func(): return [x.value, y.value]
		"string", "id":
			var line := LineEdit.new()
			line.text = str(value)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(line)
			_getters[key] = func(): return line.text
		_:
			var text := TextEdit.new()
			text.text = JSON.stringify(value, "\t")
			text.custom_minimum_size.y = 76
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text)
			var original: Variant = value
			_getters[key] = func():
				var parsed: Variant = JSON.parse_string(text.text)
				return parsed if parsed != null else original
	return row


func _add_slider(row: HBoxContainer, key: String, value: Variant, spec: Dictionary) -> void:
	var slider := HSlider.new()
	slider.min_value = spec["min"]
	slider.max_value = spec["max"]
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var readout := Label.new()
	readout.text = str(value)
	readout.custom_minimum_size.x = 56
	slider.value_changed.connect(func(v: float): readout.text = ("%.2f" % v).rstrip("0").rstrip("."))
	row.add_child(slider)
	row.add_child(readout)
	_getters[key] = func(): return slider.value


func _add_spinbox(row: HBoxContainer, key: String, value: Variant, spec: Dictionary) -> void:
	var spin := SpinBox.new()
	spin.step = 0.01
	spin.min_value = spec.get("min", -100000.0)
	spin.max_value = spec.get("max", 100000.0)
	spin.allow_lesser = not spec.has("min")
	spin.allow_greater = not spec.has("max")
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	_getters[key] = func(): return spin.value


func _bare_spinbox(value: Variant) -> SpinBox:
	var spin := SpinBox.new()
	spin.step = 1
	spin.min_value = -100000.0
	spin.max_value = 100000.0
	spin.allow_lesser = true
	spin.allow_greater = true
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


func _infer_type(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL:
			return "bool"
		TYPE_FLOAT, TYPE_INT:
			return "number"
		TYPE_STRING:
			return "string"
	return "json"


# --- Apply / diff / export --------------------------------------------------


func _on_apply() -> void:
	if raw_toggle.button_pressed:
		var parsed: Variant = JSON.parse_string(json_edit.text)
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("id"):
			status.text = "Invalid: needs a JSON object with an \"id\" field."
			return
		_apply_record(parsed)
		return
	if current_id == "":
		status.text = "Select a record first."
		return
	var rec := Registry.get_record(current_id)
	var new_rec := {"id": current_id, "type": rec.get("type", "")}
	for key in _getters:
		new_rec[key] = _getters[key].call()
	_apply_record(new_rec)


func _apply_record(parsed: Dictionary) -> void:
	var id: String = parsed["id"]
	if not baselines.has(id):
		baselines[id] = Registry.get_record(id)
	Registry.put(id, parsed, "live-edit")
	changed_ids[id] = true
	current_id = id
	Events.world_rebuild_requested.emit()
	_refresh_list()
	_update_diff()
	var issues := Registry.validate(id)
	if issues.is_empty():
		status.text = "Applied %s. F1 to play with it." % id
	else:
		status.text = "Applied %s, with warnings: %s" % [id, "; ".join(issues)]


func _update_diff() -> void:
	if current_id == "" or not baselines.has(current_id):
		diff_label.text = "No session changes to this record."
		return
	var changes := _changed_fields(baselines[current_id], Registry.get_record(current_id))
	if changes.is_empty():
		diff_label.text = "No session changes to this record."
		return
	var lines: Array[String] = []
	for key in changes:
		lines.append("%s: %s → %s" % [key, changes[key][0], changes[key][1]])
	diff_label.text = "Your changes — " + ";  ".join(lines)


## key -> [old, new]; a missing old/new is shown as "—".
func _changed_fields(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for key in after:
		if key == "id":
			continue
		if not before.has(key) or before[key] != after[key]:
			out[key] = [JSON.stringify(before.get(key, "—")), JSON.stringify(after[key])]
	for key in before:
		if key != "id" and not after.has(key):
			out[key] = [JSON.stringify(before[key]), "—"]
	return out


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
		"requires": ["base"],
	})
	var written := 0
	for id in changed_ids:
		var record := _export_record(id)
		if record.is_empty():
			continue
		var file_name: String = String(id).replace(":", "_").replace("/", "_") + ".json"
		_write_json(mod_path.path_join("records").path_join(file_name), record)
		written += 1
	status.text = "%d record(s) exported to %s — loads on next launch. Send that folder to a friend." % [
		written, ProjectSettings.globalize_path(mod_path)]


## Minimal export: a patch with only the fields that changed this session.
## Brand-new records, or ones with removed fields, export whole.
func _export_record(id: String) -> Dictionary:
	var rec := Registry.get_record(id)
	var base: Dictionary = baselines.get(id, {})
	if base.is_empty():
		return rec
	for key in base:
		if not rec.has(key):
			return rec
	var out := {"id": id, "patch": true}
	for key in rec:
		if key == "id":
			continue
		if not base.has(key) or base[key] != rec[key]:
			out[key] = rec[key]
	if out.size() <= 2:
		return {}
	return out


func _write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
