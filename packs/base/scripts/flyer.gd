extends Area2D
## Hovering enemy: drifts in a figure-eight around its spawn point.
## Hurts the player on touch.

var record: Dictionary = {}
var speed := 1.4
var fly_range := Vector2(130, 70)
var origin := Vector2.ZERO
var t := 0.0


func setup(rec: Dictionary) -> void:
	record = rec
	speed = rec.get("speed", speed)
	var raw_range: Array = rec.get("fly_range", [130, 70])
	fly_range = Vector2(raw_range[0], raw_range[1])

	var raw_size: Array = rec.get("size", [36, 28])
	var size := Vector2(raw_size[0], raw_size[1])
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	var color: Variant = rec.get("color", "#4ad9c4")
	visual.color = Color(color) if typeof(color) == TYPE_STRING and Color.html_is_valid(color) else Color("#4ad9c4")
	add_child(visual)
	body_entered.connect(_on_body_entered)


func _ready() -> void:
	origin = position


func _physics_process(delta: float) -> void:
	t += delta
	position = origin + Vector2(sin(t * speed) * fly_range.x, sin(t * speed * 2.0) * fly_range.y)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		Events.player_hit.emit(record.get("id", ""))
