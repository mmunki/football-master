extends Control

@onready var kick_off_button: Button = $VBox/KickOffButton

func _ready() -> void:
	kick_off_button.pressed.connect(_on_kick_off)

func _on_kick_off() -> void:
	get_tree().change_scene_to_file("res://scenes/match.tscn")
