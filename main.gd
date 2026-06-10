extends Node2D
## Game shell: builds the current room purely from registry records and hosts
## the in-game editor overlay (F1). The world can be torn down and rebuilt at
## any time — that's what makes live record editing and room travel possible.
##
## The world is a graph: rooms are records, and door records declare which
## room they sit in — so a mod can hook a new area into any existing room
## without patching it.

const EditorOverlay := preload("res://addons/modkit/overlay.gd")

const START_ROOM := "base:room_start"

var world: Node2D
var overlay: CanvasLayer
var hud_label: Label
var banner: Label

var current_room_id := START_ROOM
var pending_spawn: Array = []
var coins := 0
var deaths := 0
var won := false
var collected := {}
var player: CharacterBody2D
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var env_room := OS.get_environment("MODKIT_START_ROOM")
	if env_room != "":
		current_room_id = env_room
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	overlay = EditorOverlay.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	_build_hud()
	Events.world_rebuild_requested.connect(rebuild_world)
	Events.player_hit.connect(_on_player_hit)
	Events.play_sound.connect(_play_sound)
	rebuild_world()
	_resolve_pending_mods.call_deferred()


## Script-bearing mods wait for player consent, which needs UI — so the
## loader holds them at boot and we resolve here, once a scene exists.
func _resolve_pending_mods() -> void:
	if await ModLoader.resolve_pending(self):
		rebuild_world()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1 and not won:
		overlay.toggle()
		get_tree().paused = overlay.visible
	elif event.keycode == KEY_R and won:
		_restart()


func _physics_process(_delta: float) -> void:
	if won or get_tree().paused or player == null or not is_instance_valid(player):
		return
	var kill_y: float = Registry.get_record(current_room_id).get("kill_y", 1100)
	if player.position.y > kill_y:
		Events.player_hit.emit("fall")


func rebuild_world() -> void:
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()

	var room := Registry.get_record(current_room_id)
	if room.is_empty():
		push_error("No room record found: " + current_room_id)
		return
	RenderingServer.set_default_clear_color(_safe_color(room.get("background_color"), "#1d2230"))

	for platform in room.get("platforms", []):
		world.add_child(_make_platform(platform))

	for door_id in Registry.ids_by_type("door"):
		var door := Registry.get_record(door_id)
		if door.get("room", "") == current_room_id:
			world.add_child(_make_door(door))

	var index := 0
	for placement in room.get("items", []):
		var key := "%s|%d" % [current_room_id, index]
		index += 1
		if collected.has(key):
			continue
		var item := _make_item(placement, key)
		if item:
			world.add_child(item)

	for placement in room.get("entities", []):
		if typeof(placement) != TYPE_DICTIONARY:
			push_warning("Entity placements are {\"ref\": ..., \"at\": [x, y]} — got: %s" % str(placement))
			continue
		var node := _spawn_entity(placement.get("ref", ""))
		if node:
			node.position = _vec2(placement.get("at", [0, 0]))
			world.add_child(node)

	player = _spawn_entity("base:player") as CharacterBody2D
	if player:
		var spawn: Array = pending_spawn if pending_spawn.size() == 2 else room.get("spawn", [100, 100])
		pending_spawn = []
		player.position = _vec2(spawn)
		world.add_child(player)
	_update_hud()


## platform record entry: [x, y, width, height] in pixels
func _make_platform(p: Array) -> StaticBody2D:
	var body := StaticBody2D.new()
	var size := Vector2(p[2], p[3])
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	visual.color = Color("#3a4256")
	body.position = Vector2(p[0], p[1]) + size / 2.0
	body.add_child(shape)
	body.add_child(visual)
	return body


func _make_door(door: Dictionary) -> Area2D:
	var area := Area2D.new()
	var size := _vec2(door.get("size", [48, 80]))
	area.position = _vec2(door.get("at", [0, 0])) + size / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	visual.color = _safe_color(door.get("color"), "#8a6d3b")
	area.add_child(visual)
	area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			_switch_room.call_deferred(door.get("target_room", ""), door.get("target_spawn", [])))
	return area


func _switch_room(room_id: String, spawn: Array) -> void:
	if won or room_id == "":
		return
	if not Registry.has_record(room_id):
		push_warning("Door leads to unknown room: " + room_id)
		return
	current_room_id = room_id
	pending_spawn = spawn
	Events.room_changed.emit(room_id)
	rebuild_world()


func _make_item(placement: Variant, key: String) -> Area2D:
	if typeof(placement) != TYPE_DICTIONARY:
		push_warning("Item placements are {\"ref\": ..., \"at\": [x, y]} — got: %s" % str(placement))
		return null
	var rec := Registry.get_record(placement.get("ref", ""))
	if rec.is_empty():
		push_warning("Unknown item record: " + str(placement.get("ref", "")))
		return null
	var area := Area2D.new()
	area.position = _vec2(placement.get("at", [0, 0]))
	var size := _vec2(rec.get("size", [20, 20]))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	visual.color = _safe_color(rec.get("color"), "#f2c94c")
	area.add_child(visual)
	area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player") and not collected.has(key):
			collected[key] = true
			area.queue_free()
			_collect_item(rec))
	return area


func _collect_item(rec: Dictionary) -> void:
	coins += int(rec.get("value", 0))
	if rec.has("sound"):
		_play_sound(rec["sound"])
	Events.item_collected.emit(rec.get("id", ""))
	if rec.get("win", false):
		_win()
	_update_hud()


func _spawn_entity(id: String) -> Node2D:
	var record := Registry.get_record(id)
	if record.is_empty():
		push_warning("Unknown entity record: " + id)
		return null
	var script: Variant = load(record.get("script", ""))
	if script == null:
		push_warning("Entity %s has no loadable script" % id)
		return null
	var node: Node2D = script.new()
	if node.has_method("setup"):
		node.setup(record)
	return node


func _on_player_hit(_source_id: String) -> void:
	if won:
		return
	deaths += 1
	var player_record := Registry.get_record("base:player")
	if player_record.has("hurt_sound"):
		_play_sound(player_record["hurt_sound"])
	if player and is_instance_valid(player):
		player.position = _vec2(Registry.get_record(current_room_id).get("spawn", [100, 100]))
		player.velocity = Vector2.ZERO
	_update_hud()


func _win() -> void:
	won = true
	banner.text = "YOU WIN!\n\ncoins %d  ·  deaths %d\n\npress R to play again" % [coins, deaths]
	banner.visible = true
	Events.game_won.emit()
	get_tree().paused = true


func _restart() -> void:
	won = false
	banner.visible = false
	coins = 0
	deaths = 0
	collected = {}
	current_room_id = START_ROOM
	pending_spawn = []
	get_tree().paused = false
	rebuild_world()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	hud_label = Label.new()
	hud_label.position = Vector2(14, 10)
	hud.add_child(hud_label)
	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 44)
	banner.visible = false
	hud.add_child(banner)


func _update_hud() -> void:
	hud_label.text = "coins %d   deaths %d" % [coins, deaths]


func _play_sound(path: String) -> void:
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		if path.begins_with("res://"):
			stream = load(path)
		elif FileAccess.file_exists(path):
			stream = AudioStreamWAV.load_from_file(path)
		if stream == null:
			return
		_streams[path] = stream
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.finished.connect(voice.queue_free)
	add_child(voice)
	voice.play()


## Mods can carry malformed values; bad data degrades to the fallback
## instead of crashing the world build.
func _safe_color(value: Variant, fallback: String) -> Color:
	if typeof(value) == TYPE_STRING and Color.html_is_valid(value):
		return Color(value)
	return Color(fallback)


func _vec2(value: Variant) -> Vector2:
	if typeof(value) == TYPE_ARRAY and value.size() == 2:
		return Vector2(value[0], value[1])
	return Vector2.ZERO
