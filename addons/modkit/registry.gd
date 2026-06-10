extends Node
## Record store with load-order override semantics (the ESM/ESP mechanic).
##
## A record is a Dictionary with a stable string id, e.g. "base:player".
## Packs are ingested in load order; a later record with the same id replaces
## the earlier one. A record carrying `"patch": true` is shallow-merged into
## the existing record instead of replacing it, so a mod can change one field
## without restating the whole record.

var _records: Dictionary = {}
var _sources: Dictionary = {}


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
	if not _sources.has(id):
		_sources[id] = []
	_sources[id].append(pack_id)
	if _sources[id].size() > 1:
		print("[Registry] %s overridden by '%s' (chain: %s)" % [id, pack_id, " -> ".join(_sources[id])])
	Events.record_changed.emit(id)


func get_record(id: String) -> Dictionary:
	return _records.get(id, {})


func has_record(id: String) -> bool:
	return _records.has(id)


func ids() -> Array:
	var keys := _records.keys()
	keys.sort()
	return keys


## Which packs touched a record, in load order. The last entry won.
func sources(id: String) -> Array:
	return _sources.get(id, [])
