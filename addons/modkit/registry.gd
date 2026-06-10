extends Node
## Record store with load-order override semantics (the ESM/ESP mechanic).
##
## A record is a Dictionary with a stable string id, e.g. "base:player".
## Packs are ingested in load order; a later record with the same id replaces
## the earlier one. A record carrying `"patch": true` is shallow-merged into
## the existing record instead of replacing it, so a mod can change one field
## without restating the whole record.
##
## Schemas are records too (`"type": "schema"`, `"describes": "<type>"`):
## they declare fields, defaults, and ranges for a record type. Defaults are
## applied on read; validation reports issues but never blocks a load —
## a broken mod is a warning, not a crash.

const RESERVED_KEYS := ["id", "type", "patch"]

var _records: Dictionary = {}
var _sources: Dictionary = {}
var _schemas: Dictionary = {}


func put(id: String, record: Dictionary, pack_id: String) -> void:
	if record.get("patch", false) and _records.has(id):
		var merged: Dictionary = _records[id].duplicate(true)
		for key in record:
			if key != "patch":
				merged[key] = record[key]
		_records[id] = merged
	else:
		var clean := record.duplicate(true)
		clean.erase("patch")
		_records[id] = clean
	if _records[id].get("type", "") == "schema" and _records[id].has("describes"):
		_schemas[_records[id]["describes"]] = id
	if not _sources.has(id):
		_sources[id] = []
	_sources[id].append(pack_id)
	if _sources[id].size() > 1:
		print("[Registry] %s overridden by '%s' (chain: %s)" % [id, pack_id, " -> ".join(_sources[id])])
	Events.record_changed.emit(id)


## Returns a copy of the record with schema defaults filled in for missing
## fields, so records (and mods) only state what they change.
func get_record(id: String) -> Dictionary:
	var rec: Dictionary = _records.get(id, {})
	if rec.is_empty():
		return {}
	var out := rec.duplicate(true)
	var fields: Dictionary = schema_for(rec.get("type", "")).get("fields", {})
	for field in fields:
		if not out.has(field) and fields[field] is Dictionary and fields[field].has("default"):
			out[field] = fields[field]["default"]
	return out


func has_record(id: String) -> bool:
	return _records.has(id)


func ids() -> Array:
	var keys := _records.keys()
	keys.sort()
	return keys


func ids_by_type(type: String) -> Array:
	var out := []
	for id in _records:
		if _records[id].get("type", "") == type:
			out.append(id)
	out.sort()
	return out


## Which packs touched a record, in load order. The last entry won.
func sources(id: String) -> Array:
	return _sources.get(id, [])


## Record ids touched by more than one pack — the conflict-inspection view.
func conflicts() -> Array:
	var out := []
	for id in _sources:
		if _sources[id].size() > 1:
			out.append(id)
	out.sort()
	return out


## The schema record describing a record type, or {} if none declared.
func schema_for(type: String) -> Dictionary:
	return _records.get(_schemas.get(type, ""), {})


## Issues with one record, as human-readable strings. Empty means clean
## (or no schema to check against — absence of a schema is not an error).
func validate(id: String) -> Array[String]:
	var issues: Array[String] = []
	var rec: Dictionary = _records.get(id, {})
	var fields: Dictionary = schema_for(rec.get("type", "")).get("fields", {})
	if fields.is_empty():
		return issues
	for key in rec:
		if key in RESERVED_KEYS:
			continue
		if not fields.has(key):
			issues.append("unknown field \"%s\" for type \"%s\"" % [key, rec["type"]])
			continue
		var problem := _check_value(rec[key], fields[key])
		if problem != "":
			issues.append("field \"%s\": %s" % [key, problem])
	return issues


func validate_all() -> Dictionary:
	var out := {}
	for id in _records:
		var issues := validate(id)
		if not issues.is_empty():
			out[id] = issues
	return out


func _check_value(value: Variant, spec: Dictionary) -> String:
	match spec.get("type", "any"):
		"string", "id":
			if typeof(value) != TYPE_STRING:
				return "expected a string"
		"number":
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				return "expected a number"
			if spec.has("min") and value < spec["min"]:
				return "below minimum %s" % spec["min"]
			if spec.has("max") and value > spec["max"]:
				return "above maximum %s" % spec["max"]
		"bool":
			if typeof(value) != TYPE_BOOL:
				return "expected true or false"
		"color":
			if typeof(value) != TYPE_STRING or not Color.html_is_valid(value):
				return "expected a color like \"#rrggbb\""
		"vec2":
			if typeof(value) != TYPE_ARRAY or value.size() != 2:
				return "expected [x, y]"
		"array":
			if typeof(value) != TYPE_ARRAY:
				return "expected an array"
		"dict":
			if typeof(value) != TYPE_DICTIONARY:
				return "expected an object"
	return ""
