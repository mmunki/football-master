extends Control

## On-screen controls for the Android build: a left thumb stick for movement
## and a KICK button under the right thumb.  Two touches work at the same time,
## so the striker can run and kick without lifting a finger.
##
## The control draws itself and feeds the player directly; it stays hidden on
## platforms without a touch screen so the desktop build is unchanged.

@export var player_path: NodePath = ^"../../Player"
@export var margin: float = 28.0
@export var sprint_threshold: float = 0.85

var _player: Node = null
var _stick_radius: float = 110.0
var _knob_radius: float = 48.0
var _button_radius: float = 70.0
var _stick_center: Vector2 = Vector2.ZERO
var _button_center: Vector2 = Vector2.ZERO
var _stick_touch: int = -1
var _button_touch: int = -1
var _stick_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	_player = get_node_or_null(player_path)
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_stick_radius = clampf(size.y * 0.17, 64.0, 150.0)
	_knob_radius = _stick_radius * 0.44
	_button_radius = _stick_radius * 0.62
	_stick_center = Vector2(margin + _stick_radius, size.y - margin - _stick_radius)
	_button_center = Vector2(size.x - margin - _button_radius, size.y - margin - _button_radius)
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var base := Color(0.04, 0.06, 0.11, 0.45)
	var rim := Color(0.85, 0.9, 1.0, 0.35)
	var accent := Color(1.0, 0.48, 0.18, 0.6)

	draw_circle(_stick_center, _stick_radius, base)
	draw_arc(_stick_center, _stick_radius, 0.0, TAU, 64, rim, 3.0, true)
	draw_circle(_stick_center + _stick_vector * _stick_radius, _knob_radius, accent)

	draw_circle(_button_center, _button_radius, base)
	draw_arc(_button_center, _button_radius, 0.0, TAU, 64, rim, 3.0, true)

	var font := ThemeDB.fallback_font
	var font_size := int(_button_radius * 0.42)
	var text_size := font.get_string_size("KICK", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, _button_center + Vector2(-text_size.x * 0.5, font_size * 0.35),
		"KICK", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.9))

func _input(event: InputEvent) -> void:
	if not visible or _player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _button_touch == -1 and event.position.distance_to(_button_center) <= _button_radius * 1.2:
				_button_touch = event.index
				_player.touch_kick()
				queue_redraw()
			elif _stick_touch == -1 and event.position.x < size.x * 0.55:
				_stick_touch = event.index
				_update_stick(event.position)
		else:
			if event.index == _button_touch:
				_button_touch = -1
				queue_redraw()
			elif event.index == _stick_touch:
				_release_stick()
	elif event is InputEventScreenDrag and event.index == _stick_touch:
		_update_stick(event.position)

func _update_stick(position: Vector2) -> void:
	var offset := position - _stick_center
	_stick_vector = offset / maxf(_stick_radius, 1.0)
	if _stick_vector.length() > 1.0:
		_stick_vector = _stick_vector.normalized()
	_player.touch_move = _stick_vector
	_player.touch_sprint = _stick_vector.length() >= sprint_threshold
	queue_redraw()

func _release_stick() -> void:
	_stick_touch = -1
	_stick_vector = Vector2.ZERO
	if _player != null:
		_player.touch_move = Vector2.ZERO
		_player.touch_sprint = false
	queue_redraw()
