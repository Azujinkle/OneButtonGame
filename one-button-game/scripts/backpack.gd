extends Node2D

var is_open: bool = false

@onready var closed_visual: CanvasItem = $ClosedVisual
@onready var open_visual: CanvasItem = $OpenVisual


func _ready() -> void:
	_update_visuals()


func open_zip() -> void:
	if is_open:
		return

	is_open = true
	_update_visuals()


func close_zip() -> void:
	if not is_open:
		return

	is_open = false
	_update_visuals()


func _update_visuals() -> void:
	closed_visual.visible = not is_open
	open_visual.visible = is_open
