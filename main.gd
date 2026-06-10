extends Node2D
## Boot scene: builds the world purely from registry records, and hosts the
## in-game editor overlay (F1). The world can be torn down and rebuilt at any
## time, which is what makes live record editing possible.

const EditorOverlay := preload("res://addons/modkit/overlay.gd")

const ROOM_ID := "base:room_start"

var world: Node2D
var overlay: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	overlay = EditorOverlay.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	Events.world_rebuild_requested.connect(rebuild_world)
	rebuild_world()
	_resolve_pending_mods.call_deferred()


## Script-bearing mods wait for player consent, which needs UI — so the
## loader holds them at boot and we resolve here, once a scene exists.
func _resolve_pending_mods() -> void:
	if await ModLoader.resolve_pending(self):
		rebuild_world()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		overlay.toggle()
		get_tree().paused = overlay.visible


func rebuild_world() -> void:
	for child in world.get_children():
		child.queue_free()

	var room := Registry.get_record(ROOM_ID)
	if room.is_empty():
		push_error("No room record found: " + ROOM_ID)
		return
	RenderingServer.set_default_clear_color(_safe_color(room.get("background_color"), "#1d2230"))

	for platform in room.get("platforms", []):
		world.add_child(_make_platform(platform))

	var spawn: Array = room.get("spawn", [100, 100])
	for entity_id in room.get("entities", []):
		var node := _spawn_entity(entity_id)
		if node:
			node.position = Vector2(spawn[0], spawn[1])
			world.add_child(node)


## Mods can carry malformed values; bad data degrades to the fallback
## instead of crashing the world build.
func _safe_color(value: Variant, fallback: String) -> Color:
	if typeof(value) == TYPE_STRING and Color.html_is_valid(value):
		return Color(value)
	return Color(fallback)


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


func _spawn_entity(id: String) -> Node:
	var record := Registry.get_record(id)
	if record.is_empty():
		push_warning("Unknown entity record: " + id)
		return null
	var script: Variant = load(record.get("script", ""))
	if script == null:
		push_warning("Entity %s has no loadable script" % id)
		return null
	var node: Node = script.new()
	if node.has_method("setup"):
		node.setup(record)
	return node
