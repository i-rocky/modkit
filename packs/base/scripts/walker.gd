extends CharacterBody2D
## Ground patroller: walks until it hits a wall or a platform edge, then
## turns around. Hurts the player on touch.

var record: Dictionary = {}
var speed := 90.0
var gravity := 1600.0
var dir := -1.0
var half_width := 20.0
var edge_ray: RayCast2D


func setup(rec: Dictionary) -> void:
	record = rec
	speed = rec.get("speed", speed)

	var raw_size: Array = rec.get("size", [40, 40])
	var size := Vector2(raw_size[0], raw_size[1])
	half_width = size.x / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	var color: Variant = rec.get("color", "#b04ad9")
	visual.color = Color(color) if typeof(color) == TYPE_STRING and Color.html_is_valid(color) else Color("#b04ad9")
	add_child(visual)

	var hitbox := Area2D.new()
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = size + Vector2(6, 6)
	hit_shape.shape = hit_rect
	hitbox.add_child(hit_shape)
	hitbox.body_entered.connect(_on_body_entered)
	add_child(hitbox)

	edge_ray = RayCast2D.new()
	edge_ray.position = Vector2(-(half_width + 6), 0)
	edge_ray.target_position = Vector2(0, size.y)
	add_child(edge_ray)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = dir * speed
	move_and_slide()
	if is_on_wall():
		dir *= -1.0
	elif is_on_floor() and edge_ray and not edge_ray.is_colliding():
		dir *= -1.0
	if edge_ray:
		edge_ray.position.x = dir * (half_width + 6)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		Events.player_hit.emit(record.get("id", ""))
