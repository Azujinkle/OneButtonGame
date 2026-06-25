extends Node2D

var is_open: bool = false
var contents_stolen: bool = false

@onready var closed_visual: CanvasItem = $ClosedVisual
@onready var open_with_item_visual: CanvasItem = $OpenWithItemVisual
@onready var open_empty_visual: CanvasItem = $OpenEmptyVisual


func _ready() -> void:
	_update_visuals()


func open_with_item() -> void:
	is_open = true
	contents_stolen = false
	closed_visual.visible = false
	open_with_item_visual.visible = true
	open_empty_visual.visible = false


# Remove the laptop while keeping the backpack visibly open.
func remove_contents() -> void:
	is_open = true
	contents_stolen = true
	closed_visual.visible = false
	open_with_item_visual.visible = false
	open_empty_visual.visible = true


# Kept as the generic "open" interface for any future empty-bag state.
func open_zip() -> void:
	remove_contents()


func close_zip() -> void:
	if not is_open:
		return

	is_open = false
	contents_stolen = false
	_update_visuals()


func _update_visuals() -> void:
	closed_visual.visible = true
	open_with_item_visual.visible = false
	open_empty_visual.visible = false
