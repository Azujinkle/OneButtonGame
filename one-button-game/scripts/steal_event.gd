extends Node

signal warning_started
signal steal_prevented
signal steal_succeeded

enum State {
	IDLE,
	APPROACHING,
	COMPLETE,
}

# Keep the hand visible briefly when the event starts while the player is awake.
@export var awake_retreat_delay := 0.35

@onready var backpack = $"../Backpack"
@onready var thief_hands = $"../ThiefHands"
@onready var warning_sound: AudioStreamPlayer = $WarningSound

var state := State.IDLE
var player_is_awake := true


func _ready() -> void:
	thief_hands.reached_backpack.connect(_on_hand_reached_backpack)


func start_event(player_is_awake: bool) -> void:
	if state != State.IDLE:
		return

	self.player_is_awake = player_is_awake

	# The approach animation itself is the player's response window.
	state = State.APPROACHING
	warning_started.emit()
	if warning_sound.stream:
		warning_sound.play()
	thief_hands.move_to_backpack()

	# An awake player sees the approaching hand, so it retreats after a short beat.
	if player_is_awake:
		_retreat_from_awake_player()


func player_opened_eyes() -> void:
	player_is_awake = true
	if state != State.APPROACHING:
		return

	_prevent_steal()


func player_closed_eyes() -> void:
	player_is_awake = false

	# Restart a completed, prevented event when the player goes back to sleep.
	if state == State.COMPLETE and not backpack.is_open:
		reset_event()

	# Closing the eyes before the tutorial timer expires starts the event now.
	if state == State.IDLE:
		start_event(false)


func _retreat_from_awake_player() -> void:
	await get_tree().create_timer(awake_retreat_delay).timeout
	# If the player fell asleep during this short beat, continue the approach.
	if state == State.APPROACHING and player_is_awake:
		_prevent_steal()


func _prevent_steal() -> void:
	state = State.COMPLETE
	thief_hands.retreat()
	steal_prevented.emit()


func _on_hand_reached_backpack() -> void:
	if state != State.APPROACHING:
		return

	# Reaching the backpack closes the response window and completes the steal.
	backpack.open_zip()
	state = State.COMPLETE
	steal_succeeded.emit()


func reset_event() -> void:
	state = State.IDLE
	backpack.close_zip()
	thief_hands.reset_position()
