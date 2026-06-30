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
@onready var thief_hands = $busScene/ThiefHands
@onready var pause = $HUDlayer/PauseOptions
@onready var audio_manager = $AudioManager

var energy: float
var rest: float
var is_resting: bool
var is_rem: bool
var eyes_are_closed: bool
var level_state := LevelState.WAITING_TO_START
var level_elapsed := 0.0
var next_event_index := 0
var current_encounter := 0
var zipper_hint_shown := false
var current_level_number := 1
var current_level: Dictionary
var can_start_level := false
var start_input_released := false
var next_random_event_time := 0.0

const MAX_ENERGY := 1800.0
const AWAKE_ENERGY_PER_SECOND := -60.0
const REST_ENERGY_PER_SECOND := 90.0
const REST_THRESHOLD := 1.0 # Seconds required before closed eyes count as rest.
const REM_THRESHOLD := 600.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	current_level = _get_level_config(current_level_number)
	_apply_current_level_audio()
	_reset_level_state()
	_on_volume_change()
	eyes_opened.connect(steal_event.player_opened_eyes)
	steal_event.steal_succeeded.connect(_on_steal_succeeded)
	steal_event.steal_prevented.connect(_on_steal_prevented)
	steal_event.response_window_started.connect(_on_response_window_started)
	hud.continue_pressed.connect(_on_continue_pressed)
	hud.retry_pressed.connect(_on_retry_pressed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Freeze gameplay systems after the level reaches a terminal state.
	if level_state == LevelState.WON \
			or level_state == LevelState.LOST_STOLEN \
			or level_state == LevelState.LOST_NOT_RESTED:
		return

	if is_rem and energy > REM_THRESHOLD:
		is_rem = false

	if can_start_level:
		# Prevent held input from the previous screen/announcement from immediately closing the eyes.
		if not start_input_released:
			if Input.is_action_pressed("close"):
				start_input_released = false
			else:
				start_input_released = true

		if start_input_released:
			if !Settings.toggle:
				var should_close_eyes := is_rem or Input.is_action_pressed("close")
				if should_close_eyes != eyes_are_closed:
					set_eyes_closed(should_close_eyes)
			elif Settings.toggle and Input.is_action_just_pressed("close"):
					set_eyes_closed(!eyes_are_closed)

	if level_state != LevelState.RUNNING:
		hud.update_energy(energy, false, is_rem)
		return

	if eyes_are_closed:
		rest = minf(rest + delta, REST_THRESHOLD)
		is_resting = rest >= REST_THRESHOLD
	else:
		rest = 0
		is_resting = false

	energy += AWAKE_ENERGY_PER_SECOND * delta
	if is_resting:
		energy += REST_ENERGY_PER_SECOND * delta
	energy = clampf(energy, 0.0, MAX_ENERGY)
	if energy <= 0.0:
		is_rem = true

	level_elapsed += delta
	_try_start_scheduled_event()
	hud.update_level(level_elapsed, current_level["duration"], current_level["required_rest"], MAX_ENERGY)
	hud.update_energy(energy, is_resting, is_rem)

	if level_elapsed >= current_level["duration"]:
		_finish_level()


func set_eyes_closed(value: bool) -> void:
	if not can_start_level:
		return

	if eyes_are_closed == value:
		return

	eyes_are_closed = value
	if eyes_are_closed:
		hud.close_eyes()
		steal_event.player_closed_eyes()
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

	audio_manager.stop_all()
	level_state = LevelState.LOST_STOLEN
	$HUDlayer/HUD/Pause.disabled = true
	hud.show_result(current_level["stolen_result"], false)


func _on_steal_succeeded() -> void:
	var event_config := _get_current_event_config()
	hud.show_subtitle(event_config["stolen_text"])
	audio_manager.play_thief_voice(event_config["stolen_stream"], "stolen")
	await get_tree().create_timer(2.0).timeout
	lose_from_steal()


func _on_steal_prevented() -> void:
	var event_config := _get_current_event_config()
	hud.show_subtitle(event_config["prevented_text"])
	audio_manager.play_thief_voice(event_config["prevented_stream"], "prevented")


func _on_response_window_started() -> void:
	if not zipper_hint_shown:
		zipper_hint_shown = true
		hud.show_subtitle("Hint: Wake up when you hear the zipper!")


func _start_level() -> void:
	level_state = LevelState.RUNNING
	if !Settings.toggle:
		hud.show_instruction("Hold SPACE to sleep. Release it to wake up.")
	else:
		hud.show_instruction("Press SPACE to sleep. Press it again to wake up.")
	hud.show_subtitle("%s started. Rest, but listen for the zipper!" % current_level["title"])
	audio_manager.play_bus_ambience()


func _try_start_scheduled_event() -> void:
	if not can_start_level:
		return

	if next_event_index >= current_level["max_events"]:
		return
	if level_elapsed >= current_level["duration"] - current_level["event_end_buffer"]:
		return
	if level_elapsed < next_random_event_time:
		return
	if not steal_event.is_available():
		return

	current_encounter = next_event_index + 1
	var event_config := _get_current_event_config()
	hud.show_subtitle(event_config["start_text"])
	audio_manager.play_thief_voice(event_config["start_stream"], "start")
	steal_event.start_event(not eyes_are_closed)
	next_event_index += 1
	_schedule_next_random_event()


func _schedule_next_random_event() -> void:
	var max_events: int = current_level["max_events"]
	if next_event_index >= max_events:
		next_random_event_time = current_level["duration"] + 1.0
		return

	var min_gap: float = current_level["min_event_gap"]
	var max_gap: float = current_level["max_event_gap"]
	var last_allowed_time: float = current_level["duration"] - current_level["event_end_buffer"]
	var events_after_next := max_events - next_event_index - 1

	# Keep enough minimum-gap room for the remaining random events.
	var earliest_time := level_elapsed + min_gap
	var latest_time := minf(level_elapsed + max_gap, last_allowed_time - events_after_next * min_gap)
	if latest_time < earliest_time:
		latest_time = earliest_time
	next_random_event_time = randf_range(earliest_time, latest_time)


func _finish_level() -> void:
	if level_state != LevelState.RUNNING:
		return
	$HUDlayer/HUD/Pause.disabled = true
	audio_manager.stop_all()
	hud.show_subtitle(current_level["arrival_text"])
	audio_manager.play_arrival()

	var player_won: bool = energy >= current_level["required_rest"]
	if player_won:
		level_state = LevelState.WON
	else:
		level_state = LevelState.LOST_NOT_RESTED

	await audio_manager.wait_for_arrival_finished()

	if player_won:
		audio_manager.play_win()
		hud.show_result(current_level["win_result"], true)
	else:
		audio_manager.play_not_rested()
		hud.show_result(current_level["not_rested_result"], false)


func _on_volume_change() -> void:
	if audio_manager == null:
		return
	audio_manager.update_volume()
	_apply_steal_event_audio_volume()


func _on_pause() -> void:
	get_tree().paused = true
	pause.show()


func _get_level_config(level_number: int) -> Dictionary:
	var audio_config: Dictionary = audio_manager.get_level_audio_config(level_number)
	var audio_events: Array = audio_config["events"]

	if level_number == 3:
		return {
			"title": "Level Three",
			"duration": 60.0,
			"starting_energy": MAX_ENERGY * 0.3,
			"required_rest": 1320.0,
			"closed_eye_alpha": 1.0,
			"min_event_gap": 3.5,
			"max_event_gap": 6.5,
			"max_events": 8,
			"event_end_buffer": 3.0,
			"steal_duration": 1.0,
			"response_window": 1.0,
			"audio": audio_config,
			"arrival_text": "",
			"win_result": "Level Three Complete!\nHardcore Mode cleared.",
			"not_rested_result": "Game Over\nYou didn't rest enough.",
			"stolen_result": "Game Over\nYour laptop was stolen.",
			"events": [
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": audio_events[0]["prevented"],
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": audio_events[0]["stolen"],
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": audio_events[1]["prevented"],
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": audio_events[1]["stolen"],
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": audio_events[2]["prevented"],
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": audio_events[2]["stolen"],
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": audio_events[3]["prevented"],
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": audio_events[3]["stolen"],
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": audio_events[4]["prevented"],
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": audio_events[4]["stolen"],
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": audio_events[5]["prevented"],
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": audio_events[5]["stolen"],
				},
			],
		}

	if level_number == 2:
		return {
			"title": "Level Two",
			"duration": 45.0,
			"starting_energy": MAX_ENERGY * 0.4,
			"required_rest": 990.0,
			"closed_eye_alpha": 1.0,
			"min_event_gap": 4.0,
			"max_event_gap": 7.0,
			"max_events": 6,
			"event_end_buffer": 3.0,
			"steal_duration": 2.0,
			"response_window": 1.0,
			"audio": audio_config,
			"arrival_text": "Bus Driver: We are arriving at The Convention Center.",
			"win_result": "Level Two Complete!\nYou protected the laptop and got enough rest.",
			"not_rested_result": "Game Over\nYou didn't rest enough.\n\"Hope you have the energy to win your tournament!\"",
			"stolen_result": "Game Over\nYour laptop was stolen.",
			"events": [
				{
					"start_text": "Thief: Oh, I need a computer for the convention.",
					"start_stream": audio_events[0]["start"],
					"prevented_text": "Thief: Don't you need to sleep?",
					"prevented_stream": audio_events[0]["prevented"],
					"stolen_text": "Thief: Grumble, this is heavy.",
					"stolen_stream": audio_events[0]["stolen"],
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": audio_events[1]["prevented"],
					"stolen_text": "Thief: Cough, nothing suspicious here.",
					"stolen_stream": audio_events[1]["stolen"],
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oop, sorry!",
					"prevented_stream": audio_events[2]["prevented"],
					"stolen_text": "Thief: I'm not stealing your laptop.",
					"stolen_stream": audio_events[2]["stolen"],
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": audio_events[3]["prevented"],
					"stolen_text": "Thief: Laptop? Yes please.",
					"stolen_stream": audio_events[3]["stolen"],
				},
			],
		}

	return {
		"title": "Level One",
		"duration": 30.0,
		"starting_energy": 900.0,
		"required_rest": 660.0,
		"closed_eye_alpha": 0.7,
		"min_event_gap": 4.0,
		"max_event_gap": 7.0,
		"max_events": 4,
		"event_end_buffer": 3.0,
		"steal_duration": 2.0,
		"response_window": 1.5,
		"audio": audio_config,
		"arrival_text": "Bus Driver: We are arriving at The Business District.",
		"win_result": "Level One Complete!\nYou protected the laptop and got enough rest.",
		"not_rested_result": "Game Over\nYou didn't rest enough.\n\"No sleeping on the job!\"",
		"stolen_result": "Game Over\nYour laptop was stolen.\n\"What do you MEAN your\nlaptop was stolen!?\"",
		"events": [
			{
				"start_text": "Thief: Forgot my computer for work. This'll do perfectly.",
				"start_stream": audio_events[0]["start"],
				"prevented_text": "Thief: Rats! That's a loud zipper.",
				"prevented_stream": audio_events[0]["prevented"],
				"stolen_text": "Thief: Oh, I could sell this for thousands!",
				"stolen_stream": audio_events[0]["stolen"],
			},
			{
				"start_text": "Thief: Nothing suspicious here...",
				"start_stream": audio_events[1]["start"],
				"prevented_text": "Thief: Oh man!",
				"prevented_stream": audio_events[1]["prevented"],
				"stolen_text": "Thief: Heh, thanks for the laptop, buddy!",
				"stolen_stream": audio_events[1]["stolen"],
			},
		],
	}


func _apply_current_level_audio() -> void:
	audio_manager.apply_level_audio(current_level["audio"])


func _reset_level_state() -> void:
	audio_manager.stop_all()
	steal_event.reset_event()
	can_start_level = false
	start_input_released = false
	energy = current_level["starting_energy"]
	rest = 0.0
	is_resting = false
	is_rem = false
	eyes_are_closed = false
	level_state = LevelState.RUNNING
	level_elapsed = 0.0
	next_event_index = 0
	next_random_event_time = 0.0
	current_encounter = 0
	zipper_hint_shown = false
	thief_hands.steal_duration = current_level["steal_duration"]
	steal_event.response_window = current_level["response_window"]
	_apply_steal_event_audio_volume()
	$HUDlayer/HUD/Pause.disabled = false
	hud.open_eyes()
	hud.set_closed_eye_alpha(current_level["closed_eye_alpha"])
	hud.show_level_intro(current_level["title"])
	hud.update_level(level_elapsed, current_level["duration"], current_level["required_rest"], MAX_ENERGY)
	hud.update_energy(energy, false, false)
	_schedule_next_random_event()
	audio_manager.play_bus_ambience()
	if audio_manager.has_intro():
		audio_manager.play_intro()
	can_start_level = true
	if !Settings.toggle:
		hud.show_instruction("Hold SPACE to sleep. Release it to wake up.")
	else:
		hud.show_instruction("Press SPACE to sleep. Press it again to wake up.")
	hud.show_subtitle("%s started. Rest, but listen for the zipper!" % current_level["title"])


func _apply_steal_event_audio_volume() -> void:
	$busScene/StealEvent/WarningSound.volume_db = audio_manager.get_zipper_volume_db(current_level_number)
	$busScene/StealEvent/CloseSound.volume_db = audio_manager.get_close_zip_volume_db()


func _get_current_event_config() -> Dictionary:
	var events: Array = current_level["events"]
	var event_index := (current_encounter - 1) % events.size()
	return events[event_index]


func _on_continue_pressed() -> void:
	if current_level_number < 3:
		current_level_number += 1
		current_level = _get_level_config(current_level_number)
		_apply_current_level_audio()
		_reset_level_state()
	else:
		get_tree().change_scene_to_file("res://scenes/credits.tscn")

func _on_retry_pressed() -> void:
	_apply_current_level_audio()
	_reset_level_state()
