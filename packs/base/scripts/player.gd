extends CharacterBody2D
## Player behavior, shipped inside the base pack like any mod script would be.
## All tunables come from the record, so a one-line JSON patch can change
## how the game feels without touching this file.

var record: Dictionary = {}
var move_speed := 320.0
var jump_velocity := -680.0
var gravity := 1600.0


func setup(rec: Dictionary) -> void:
	record = rec
	move_speed = rec.get("move_speed", move_speed)
	jump_velocity = rec.get("jump_velocity", jump_velocity)
	gravity = rec.get("gravity", gravity)

	var raw_size: Array = rec.get("size", [48, 48])
	var size := Vector2(raw_size[0], raw_size[1])
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	var color: Variant = rec.get("color", "#e8554d")
	visual.color = Color(color) if typeof(color) == TYPE_STRING and Color.html_is_valid(color) else Color("#e8554d")
	add_child(visual)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity
	velocity.x = Input.get_axis("ui_left", "ui_right") * move_speed
	move_and_slide()
