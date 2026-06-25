extends Node2D

signal reached_backpack
signal finished_retreating

@export var hidden_position := Vector2(1650.0, 410.0)
@export var backpack_position := Vector2(1180.0, 410.0)
@export var steal_duration := 4.0
@export var retreat_duration := 0.4

var movement_tween: Tween

@onready var stolen_laptop: CanvasItem = $StolenLaptop


func _ready() -> void:
	position = hidden_position
	stolen_laptop.visible = false


func move_to_backpack() -> void:
	_stop_movement()
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_SINE)
	movement_tween.set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(
		self,
		"position",
		backpack_position,
		steal_duration
	)
	movement_tween.tween_callback(reached_backpack.emit)


func retreat() -> void:
	_stop_movement()
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_SINE)
	movement_tween.set_ease(Tween.EASE_IN)
	movement_tween.tween_property(
		self,
		"position",
		hidden_position,
		retreat_duration
	)
	movement_tween.tween_callback(finished_retreating.emit)


func take_laptop() -> void:
	stolen_laptop.visible = true


func reset_position() -> void:
	_stop_movement()
	position = hidden_position
	stolen_laptop.visible = false


func _stop_movement() -> void:
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
