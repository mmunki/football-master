extends CharacterBody3D

## The striker: movement, sprint and the kick that feeds the physics ball.

@export var walk_speed: float = 3.4
@export var sprint_speed: float = 7.5
@export var kick_speed: float = 15.0
@export var kick_cooldown: float = 0.25

var facing: Vector3 = Vector3(0, 0, 1)
var last_move_dir: Vector3 = Vector3(0, 0, 1)
var kick_cooldown_left: float = 0.0

func _physics_process(delta: float) -> void:
	if kick_cooldown_left > 0.0:
		kick_cooldown_left -= delta

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1

	var move_dir := Vector3(input_dir.x, 0.0, input_dir.y)
	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()

	var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	velocity.y -= 9.8 * get_physics_process_delta_time()

	move_and_slide()

	if move_dir != Vector3.ZERO:
		facing = move_dir.normalized()
		last_move_dir = facing
		rotation.y = atan2(facing.x, facing.z)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_perform_kick()

func _perform_kick() -> void:
	if kick_cooldown_left > 0.0:
		return
	kick_cooldown_left = kick_cooldown
	var kick_dir := last_move_dir if last_move_dir != Vector3.ZERO else facing
	var ball := get_parent().get_node_or_null("Ball") as RigidBody3D
	if ball == null:
		return
	ball.linear_velocity = kick_dir * kick_speed
	if ball.sleeping:
		ball.wake_up()
