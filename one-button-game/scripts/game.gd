extends Node2D

signal eyes_opened

enum LevelState {
	WAITING_TO_START,
	RUNNING,
	WON,
	LOST_STOLEN,
	LOST_NOT_RESTED,
}

@onready var hud = $HUDlayer/HUD
@onready var steal_event = $busScene/StealEvent
@onready var backpack = $busScene/Backpack

var energy: float
var rest: float
var is_resting: bool
var is_rem: bool
var eyes_are_closed: bool
var level_state := LevelState.WAITING_TO_START
var level_elapsed := 0.0
var rested_time := 0.0
var next_event_index := 0
var current_encounter := 0
var zipper_hint_shown := false

const MAX_ENERGY := 1800.0
const STARTING_ENERGY := 900.0 # Level One starts with the energy bar half full.
const AWAKE_ENERGY_PER_SECOND := -60.0
const REST_ENERGY_PER_SECOND := 90.0
const REST_THRESHOLD := 0.5 # Seconds required before closed eyes count as rest.
const REM_THRESHOLD := 600.0
const LEVEL_DURATION := 30.0
const REQUIRED_REST_TIME := 12.0
const STEAL_EVENT_TIMES := [7.0, 17.0]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	energy = STARTING_ENERGY
	rest = 0
	is_resting = false
	is_rem = false
	eyes_are_closed = false
	eyes_opened.connect(steal_event.player_opened_eyes)
	steal_event.steal_succeeded.connect(_on_steal_succeeded)
	steal_event.steal_prevented.connect(_on_steal_prevented)
	steal_event.response_window_started.connect(_on_response_window_started)
	hud.show_level_intro()
	hud.update_level(level_elapsed, LEVEL_DURATION, rested_time, REQUIRED_REST_TIME)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Freeze gameplay systems after the level reaches a terminal state.
	if level_state == LevelState.WON \
			or level_state == LevelState.LOST_STOLEN \
			or level_state == LevelState.LOST_NOT_RESTED:
		return

	if is_rem and energy > REM_THRESHOLD:
		is_rem = false

	var should_close_eyes := is_rem or Input.is_action_pressed("close")
	if should_close_eyes != eyes_are_closed:
		set_eyes_closed(should_close_eyes)

	if level_state != LevelState.RUNNING:
		hud.update_energy(energy, false, is_rem)
		return

	if eyes_are_closed:
		rest = minf(rest + delta, REST_THRESHOLD)
		is_resting = rest >= REST_THRESHOLD
	else:
		rest = maxf(rest - delta, 0.0)
		is_resting = false

	energy += AWAKE_ENERGY_PER_SECOND * delta
	if is_resting:
		energy += REST_ENERGY_PER_SECOND * delta
		# Forced REM restores energy but does not satisfy the level's rest goal.
		if not is_rem and Input.is_action_pressed("close"):
			rested_time += delta
	energy = clampf(energy, 0.0, MAX_ENERGY)
	if energy <= 0.0:
		is_rem = true

	level_elapsed += delta
	_try_start_scheduled_event()
	hud.update_level(level_elapsed, LEVEL_DURATION, rested_time, REQUIRED_REST_TIME)
	hud.update_energy(energy, is_resting, is_rem)

	if level_elapsed >= LEVEL_DURATION:
		_finish_level()


func set_eyes_closed(value: bool) -> void:
	if eyes_are_closed == value:
		return

	eyes_are_closed = value
	if eyes_are_closed:
		hud.close_eyes()
		steal_event.player_closed_eyes()
		if level_state == LevelState.WAITING_TO_START:
			_start_level()
	else:
		hud.open_eyes()
		if is_resting:
			hud.flare_eyes()
		eyes_opened.emit()
		_check_open_eyes_result()


# Discovering an empty backpack means the steal has succeeded.
func _check_open_eyes_result() -> void:
	if backpack.contents_stolen:
		lose_from_steal()


func lose_from_steal() -> void:
	# Guard against showing the same result more than once.
	if level_state != LevelState.RUNNING:
		return

	level_state = LevelState.LOST_STOLEN
	hud.show_result("Game Over\nYour laptop was stolen.", false)


func _on_steal_succeeded() -> void:
	hud.show_subtitle("Thief: Thanks for the laptop, buddy!")
	await get_tree().create_timer(2.0).timeout
	lose_from_steal()


func _on_steal_prevented() -> void:
	hud.show_subtitle("Thief: Oh man! I almost had it.")


func _on_response_window_started() -> void:
	if not zipper_hint_shown:
		zipper_hint_shown = true
		hud.show_subtitle("Hint: Wake up when you hear the zipper!")


func _start_level() -> void:
	level_state = LevelState.RUNNING
	hud.show_instruction("Hold SPACE to sleep. Release it to wake up.")
	hud.show_subtitle("Level One started. Rest, but listen for the zipper!")


func _try_start_scheduled_event() -> void:
	if next_event_index >= STEAL_EVENT_TIMES.size():
		return
	if level_elapsed < STEAL_EVENT_TIMES[next_event_index]:
		return
	if not steal_event.is_available():
		return

	current_encounter = next_event_index + 1
	if current_encounter == 1:
		hud.show_subtitle("Thief: Oh, there's a laptop in here...")
	else:
		hud.show_subtitle("Thief: Nothing suspicious here...")
	steal_event.start_event(not eyes_are_closed)
	next_event_index += 1


func _finish_level() -> void:
	if level_state != LevelState.RUNNING:
		return

	hud.show_subtitle("Bus Driver: We are arriving at The Business District.")
	if rested_time >= REQUIRED_REST_TIME:
		level_state = LevelState.WON
		hud.show_result("Level One Complete!\nYou protected the laptop and got enough rest.", true)
	else:
		level_state = LevelState.LOST_NOT_RESTED
		hud.show_result("Game Over\nYou didn't rest enough.", false)
