extends Node

signal warning_started
signal response_window_started
signal steal_prevented
signal steal_succeeded

enum State {
	IDLE,
	APPROACHING,
	RESPONSE_WINDOW,
	COMPLETE,
}

# Keep the hand visible briefly when the event starts while the player is awake.
@export var awake_retreat_delay := 0.35
@export var response_window := 4.0
@export var close_delay := 2.0

@onready var backpack = $"../Backpack"
@onready var thief_hands = $"../ThiefHands"
@onready var warning_sound: AudioStreamPlayer = $WarningSound
@onready var close_sound: AudioStreamPlayer = $CloseSound

var state := State.IDLE
var player_is_awake := true


func _ready() -> void:
	thief_hands.reached_backpack.connect(_on_hand_reached_backpack)


func start_event(player_is_awake: bool) -> void:
	if state != State.IDLE:
		return

	self.player_is_awake = player_is_awake

	# First show the four-second approach; the zipper starts the response window.
	state = State.APPROACHING
	warning_started.emit()
	thief_hands.move_to_backpack()

	# An awake player sees the approaching hand, so it retreats after a short beat.
	if player_is_awake:
		_retreat_from_awake_player()


func player_opened_eyes() -> void:
	player_is_awake = true
	if state != State.APPROACHING and state != State.RESPONSE_WINDOW:
		return

	_prevent_steal()


func player_closed_eyes() -> void:
	player_is_awake = false


func _retreat_from_awake_player() -> void:
	await get_tree().create_timer(awake_retreat_delay).timeout
	# If the player fell asleep during this short beat, continue the approach.
	if state == State.APPROACHING and player_is_awake:
		_prevent_steal()


func _prevent_steal() -> void:
	state = State.COMPLETE
	thief_hands.retreat()
	steal_prevented.emit()
	_close_and_reset_after_delay()


func _close_and_reset_after_delay() -> void:
	await get_tree().create_timer(close_delay).timeout
	if backpack.is_open:
		if close_sound.stream:
			close_sound.play()
		backpack.close_zip()
	thief_hands.reset_position()
	state = State.IDLE


func _on_hand_reached_backpack() -> void:
	if state != State.APPROACHING:
		return

	# Opening the backpack starts a separate four-second response window.
	state = State.RESPONSE_WINDOW
	if warning_sound.stream:
		warning_sound.play()
	backpack.open_with_item()
	response_window_started.emit()

	await get_tree().create_timer(response_window).timeout
	if state != State.RESPONSE_WINDOW:
		return

	# Transfer the laptop to the hand, leave the backpack empty, then escape.
	backpack.remove_contents()
	thief_hands.take_laptop()
	state = State.COMPLETE
	steal_succeeded.emit()
	thief_hands.retreat()


func reset_event() -> void:
	state = State.IDLE
	backpack.close_zip()
	thief_hands.reset_position()


func is_available() -> bool:
	return state == State.IDLE
