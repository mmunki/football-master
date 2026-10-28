extends Node3D

## Football Master - quick match controller.
##
## A compact football scene: two goal frames on a regulation pitch, one player
## character (the striker) and one physics ball.

@export var match_duration: float = 90.0

@onready var player: CharacterBody3D = $Player
@onready var ball: RigidBody3D = $Ball
@onready var camera: Camera3D = $Camera3D

var time_left: float = 0.0
var time_running: bool = false
var home_score: int = 0
var away_score: int = 0

func _ready() -> void:
	_reset_match()

func _process(delta: float) -> void:
	if not time_running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		time_running = false
		_end_match()

func start_match() -> void:
	_reset_match()
	time_left = match_duration
	time_running = true

func _reset_match() -> void:
	player.global_position = Vector3(0.0, 0.7, 0.0)
	player.velocity = Vector3.ZERO
	player.facing = Vector3(0, 0, 1)
	player.last_move_dir = Vector3(0, 0, 1)
	ball.global_position = Vector3(0.0, 0.12, 0.0)
	_reset_ball()
	time_left = match_duration
	time_running = true
	home_score = 0
	away_score = 0

func _end_match() -> void:
	time_running = false
	print("football master: match ended, score %d - %d" % [home_score, away_score])

func score_home() -> void:
	home_score += 1
	_reset_ball()

func score_away() -> void:
	away_score += 1
	_reset_ball()

func _reset_ball() -> void:
	ball.global_position = Vector3(0.0, 0.12, 0.0)
	ball.linear_velocity = Vector3.ZERO
	if ball.sleeping:
		ball.wake_up()
