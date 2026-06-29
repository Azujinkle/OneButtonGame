extends Node2D

signal reached_backpack
signal finished_retreating

@export var hidden_position := Vector2(1650.0, 410.0)
@export var backpack_position := Vector2(1180.0, 410.0)
@export var hidden_point_path: NodePath = ^"../HandHiddenPoint"
@export var backpack_point_path: NodePath = ^"../HandBackpackPoint"
@export var grab_point_path: NodePath = ^"HandVisual/HandGrabPoint"
@export var steal_duration := 4.0
@export var retreat_duration := 0.4
@export var approach_arc_height := 180.0
@export var retreat_arc_height := 90.0

var movement_tween: Tween
var rest_visual_position := Vector2.ZERO

@onready var hand_visual: Node2D = $HandVisual
@onready var stolen_laptop: CanvasItem = $StolenLaptop


func _ready() -> void:
	# Use the hand image's current editor placement as the start/rest position.
	# The long hand sprite does not need to sit at the ThiefHands origin.
	rest_visual_position = hand_visual.position
	stolen_laptop.visible = false


func move_to_backpack() -> void:
	var start_position := hand_visual.position
	var target_position := _get_visual_position_for_grab_target(backpack_point_path, backpack_position)
	var control_position := _get_arc_control_position(
		start_position,
		target_position,
		approach_arc_height
	)

	_stop_movement()
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_SINE)
	movement_tween.set_ease(Tween.EASE_OUT)
	movement_tween.tween_method(
		_set_parabolic_visual_position.bind(start_position, control_position, target_position),
		0.0,
		1.0,
		steal_duration
	)
	movement_tween.tween_callback(reached_backpack.emit)


func retreat() -> void:
	var start_position := hand_visual.position
	var target_position := rest_visual_position
	var control_position := _get_arc_control_position(
		start_position,
		target_position,
		retreat_arc_height
	)

	_stop_movement()
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_SINE)
	movement_tween.set_ease(Tween.EASE_IN)
	movement_tween.tween_method(
		_set_parabolic_visual_position.bind(start_position, control_position, target_position),
		0.0,
		1.0,
		retreat_duration
	)
	movement_tween.tween_callback(finished_retreating.emit)


func take_laptop() -> void:
	stolen_laptop.visible = true


func reset_position() -> void:
	_stop_movement()
	hand_visual.position = rest_visual_position
	stolen_laptop.visible = false


func _stop_movement() -> void:
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()


func _get_marker_position(marker_path: NodePath, fallback_position: Vector2) -> Vector2:
	var marker := get_node_or_null(marker_path) as Node2D
	if marker == null:
		return fallback_position

	# ThiefHands moves in its parent's local space.
	# If the parent scene ever moves/scales, converting from global keeps the target correct.
	var parent_node := get_parent() as Node2D
	if parent_node == null:
		return marker.global_position

	return parent_node.to_local(marker.global_position)


func _get_visual_position_for_grab_target(target_path: NodePath, fallback_position: Vector2) -> Vector2:
	var target_marker := get_node_or_null(target_path) as Node2D
	var grab_point := get_node_or_null(grab_point_path) as Node2D
	if target_marker == null or grab_point == null:
		return hand_visual.to_local(_get_marker_position(target_path, fallback_position))

	# The hand art is long and intentionally offset from ThiefHands.
	# Move the image itself so its HandGrabPoint reaches the backpack target.
	var grab_offset_from_visual := grab_point.global_position - hand_visual.global_position
	var desired_visual_global_position := target_marker.global_position - grab_offset_from_visual
	return hand_visual.get_parent().to_local(desired_visual_global_position)


func _get_arc_control_position(start_position: Vector2, target_position: Vector2, arc_height: float) -> Vector2:
	# Godot's Y axis points down, so subtracting from Y makes the hand arc upward.
	var midpoint := start_position.lerp(target_position, 0.5)
	return midpoint + Vector2(0.0, -arc_height)


func _set_parabolic_visual_position(progress: float, start_position: Vector2, control_position: Vector2, target_position: Vector2) -> void:
	# Quadratic Bezier curve:
	# start -> control -> target
	# This gives the thief hand a parabolic stealing motion instead of a straight line.
	var first_segment := start_position.lerp(control_position, progress)
	var second_segment := control_position.lerp(target_position, progress)
	hand_visual.position = first_segment.lerp(second_segment, progress)
