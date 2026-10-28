extends RigidBody3D

## The football: a physics body that crosses the goal line and ends the match.

const GOAL_HALF_WIDTH: float = 3.66
const GOAL_TRIGGER_X: float = 50.0

var scored: bool = false

func _physics_process(_delta: float) -> void:
	if scored:
		return
	if global_position.x > GOAL_TRIGGER_X and abs(global_position.z) < GOAL_HALF_WIDTH:
		scored = true
		get_parent().score_home()
	elif global_position.x < -GOAL_TRIGGER_X and abs(global_position.z) < GOAL_HALF_WIDTH:
		scored = true
		get_parent().score_away()
