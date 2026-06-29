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

const MAX_ENERGY := 1800.0
const AWAKE_ENERGY_PER_SECOND := -60.0
const REST_ENERGY_PER_SECOND := 90.0
const REST_THRESHOLD := 0.5 # Seconds required before closed eyes count as rest.
const REM_THRESHOLD := 600.0
const BASE_AUDIO_DB_OFFSET := -4.0
const THIEF_VOLUME_MULTIPLIER := 1.25

const BUS_AMBIENCE_STREAM := preload("res://art/audio/bus ambience 30 sec_LevelOne.mp3")
const BUSINESS_ARRIVE_STREAM := preload("res://art/audio/businessarrive_LevelOne.mp3")
const HAVE_GREAT_DAY_STREAM := preload("res://art/audio/Have a Great day_LevelOne.mp3")
const BOSS_STREAM := preload("res://art/audio/boss_LevelOne.mp3")
const THIEF_EVENT_ONE_START_STREAM := preload("res://art/audio/ForgotMyComputerForWorkThisllDoPerfectly_LevelOne.mp3")
const THIEF_EVENT_TWO_START_STREAM := preload("res://art/audio/NothingSuspiciousHere_LevelOne.mp3")
const THIEF_EVENT_ONE_PREVENTED_STREAM := preload("res://art/audio/RatsThatsALoudZipper_LevelOne.mp3")
const THIEF_EVENT_TWO_PREVENTED_STREAM := preload("res://art/audio/OhMan1_LevelOne.mp3")
const THIEF_EVENT_ONE_STOLEN_STREAM := preload("res://art/audio/OhICouldSellThisForThousands_LevelOne.mp3")
const THIEF_EVENT_TWO_STOLEN_STREAM := preload("res://art/audio/HehThanksForTheLaptopBuddyO_LevelOne.mp3")
const LEVEL_TWO_BUS_AMBIENCE_STREAM := preload("res://art/audio/45 second bus ambience_LevelTwo.mp3")
const LEVEL_TWO_INTRO_STREAM := preload("res://art/audio/level2.mp3")
const LEVEL_TWO_ARRIVE_STREAM := preload("res://art/audio/conventionarrive_LevelTwo.mp3")
const LEVEL_TWO_WIN_STREAM := preload("res://art/audio/Have a great convention_LevelTwo.mp3")
const LEVEL_TWO_NOT_RESTED_STREAM := preload("res://art/audio/tournament_LevelTwo.mp3")
const LEVEL_TWO_EVENT_ONE_START_STREAM := preload("res://art/audio/OhINeedAComputerForTheConvention_LevelTwo.mp3")
const LEVEL_TWO_EVENT_ONE_PREVENTED_STREAM := preload("res://art/audio/DontYouNeedToSleep_LevelTwo.mp3")
const LEVEL_TWO_EVENT_ONE_STOLEN_STREAM := preload("res://art/audio/GrumbleThisIsHeavy_LevelTwo.mp3")
const LEVEL_TWO_EVENT_TWO_PREVENTED_STREAM := preload("res://art/audio/OhMan2_LevelTwo.mp3")
const LEVEL_TWO_EVENT_TWO_STOLEN_STREAM := preload("res://art/audio/CoughNothingSuspiciousHere_LevelTwo.mp3")
const LEVEL_TWO_EVENT_THREE_PREVENTED_STREAM := preload("res://art/audio/OopSorry_LevelTwo.mp3")
const LEVEL_TWO_EVENT_THREE_STOLEN_STREAM := preload("res://art/audio/ImNotStealingYourLaptop_LevelTwo.mp3")
const LEVEL_TWO_EVENT_FOUR_PREVENTED_STREAM := preload("res://art/audio/OhMan3_LevelTwo.mp3")
const LEVEL_TWO_EVENT_FOUR_STOLEN_STREAM := preload("res://art/audio/LaptopYesPlease_LevelTwo.mp3")
const LEVEL_THREE_BUS_AMBIENCE_STREAM := preload("res://art/audio/60 seconds of bus ambience_LevelThree.mp3")
const LEVEL_THREE_PREVENTED_ONE_STREAM := preload("res://art/audio/OhMan4_LevelThree.mp3")
const LEVEL_THREE_PREVENTED_TWO_STREAM := preload("res://art/audio/OhMan5_LevelThree.mp3")
const LEVEL_THREE_PREVENTED_THREE_STREAM := preload("res://art/audio/OhMan6_LevelThree.mp3")
const LEVEL_THREE_STOLEN_STREAM := preload("res://art/audio/OhTheresALaptopInHere1_LevelThree.mp3")

var bus_ambience_audio: AudioStreamPlayer
var bus_arrive_audio: AudioStreamPlayer
var win_audio: AudioStreamPlayer
var not_rested_audio: AudioStreamPlayer
var intro_audio: AudioStreamPlayer
var thief_voice_audio: AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_level_one_audio()
	current_level = _get_level_config(current_level_number)
	_apply_current_level_audio()
	_reset_level_state()
	eyes_opened.connect(steal_event.player_opened_eyes)
	steal_event.steal_succeeded.connect(_on_steal_succeeded)
	steal_event.steal_prevented.connect(_on_steal_prevented)
	steal_event.response_window_started.connect(_on_response_window_started)
	hud.continue_pressed.connect(_on_continue_pressed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Freeze gameplay systems after the level reaches a terminal state.
	if level_state == LevelState.WON \
			or level_state == LevelState.LOST_STOLEN \
			or level_state == LevelState.LOST_NOT_RESTED:
		return

	if is_rem and energy > REM_THRESHOLD:
		is_rem = false
		
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

	_stop_level_audio()
	level_state = LevelState.LOST_STOLEN
	$HUDlayer/HUD/Pause.disabled = true
	hud.show_result(current_level["stolen_result"], false)


func _on_steal_succeeded() -> void:
	var event_config := _get_current_event_config()
	hud.show_subtitle(event_config["stolen_text"])
	_play_thief_voice(event_config["stolen_stream"])
	await get_tree().create_timer(2.0).timeout
	lose_from_steal()


func _on_steal_prevented() -> void:
	var event_config := _get_current_event_config()
	hud.show_subtitle(event_config["prevented_text"])
	_play_thief_voice(event_config["prevented_stream"])


func _on_response_window_started() -> void:
	if not zipper_hint_shown:
		zipper_hint_shown = true
		hud.show_subtitle("Hint: Wake up when you hear the zipper!")


func _start_level() -> void:
	level_state = LevelState.RUNNING
	hud.show_instruction("Hold SPACE to sleep. Release it to wake up.")
	hud.show_subtitle("%s started. Rest, but listen for the zipper!" % current_level["title"])
	_play_audio(bus_ambience_audio)


func _try_start_scheduled_event() -> void:
	var event_times: Array = current_level["event_times"]
	if next_event_index >= event_times.size():
		return
	if level_elapsed < event_times[next_event_index]:
		return
	if not steal_event.is_available():
		return

	current_encounter = next_event_index + 1
	var event_config := _get_current_event_config()
	hud.show_subtitle(event_config["start_text"])
	_play_thief_voice(event_config["start_stream"])
	steal_event.start_event(not eyes_are_closed)
	next_event_index += 1


func _finish_level() -> void:
	if level_state != LevelState.RUNNING:
		return
	$HUDlayer/HUD/Pause.disabled = true
	_stop_level_audio()
	hud.show_subtitle(current_level["arrival_text"])
	_play_audio(bus_arrive_audio)

	var player_won: bool = energy >= current_level["required_rest"]
	if player_won:
		level_state = LevelState.WON
	else:
		level_state = LevelState.LOST_NOT_RESTED

	if bus_arrive_audio.playing:
		await bus_arrive_audio.finished

	if player_won:
		_play_audio(win_audio)
		hud.show_result(current_level["win_result"], true)
	else:
		_play_audio(not_rested_audio)
		hud.show_result(current_level["not_rested_result"], false)


func _on_volume_change() -> void:
	var value = Settings.volume/10.0
	$busScene/StealEvent/WarningSound.volume_db = _get_base_volume_db()
	$busScene/StealEvent/CloseSound.volume_db = _get_base_volume_db()
	for audio_player in [
		bus_ambience_audio,
		bus_arrive_audio,
		win_audio,
		not_rested_audio,
		intro_audio,
	]:
		if audio_player:
			audio_player.volume_db = _get_base_volume_db()
	if thief_voice_audio:
		thief_voice_audio.volume_db = _get_thief_volume_db()


func _on_pause() -> void:
	get_tree().paused = true
	pause.show()


func _setup_level_one_audio() -> void:
	bus_ambience_audio = _create_audio_player(null, "BusAmbienceAudio")
	bus_arrive_audio = _create_audio_player(null, "BusinessArriveAudio")
	win_audio = _create_audio_player(null, "WinAudio")
	not_rested_audio = _create_audio_player(null, "NotRestedAudio")
	intro_audio = _create_audio_player(null, "IntroAudio")
	thief_voice_audio = _create_audio_player(null, "ThiefVoiceAudio")


func _create_audio_player(stream: AudioStream, player_name: String) -> AudioStreamPlayer:
	var audio_player := AudioStreamPlayer.new()
	audio_player.name = player_name
	audio_player.stream = stream
	audio_player.volume_db = _get_base_volume_db()
	add_child(audio_player)
	return audio_player


func _play_audio(audio_player: AudioStreamPlayer) -> void:
	if audio_player == null or audio_player.stream == null:
		return
	audio_player.stop()
	audio_player.play()


func _play_thief_voice(stream: AudioStream) -> void:
	if thief_voice_audio == null or stream == null:
		return
	thief_voice_audio.stop()
	thief_voice_audio.stream = stream
	thief_voice_audio.volume_db = _get_thief_volume_db()
	thief_voice_audio.play()


func _get_base_volume_db() -> float:
	return linear_to_db(Settings.volume / 10.0) + BASE_AUDIO_DB_OFFSET


func _get_thief_volume_db() -> float:
	return linear_to_db(Settings.volume / 10.0 * THIEF_VOLUME_MULTIPLIER) + BASE_AUDIO_DB_OFFSET


func _stop_level_audio() -> void:
	for audio_player in [
		bus_ambience_audio,
		bus_arrive_audio,
		win_audio,
		not_rested_audio,
		intro_audio,
		thief_voice_audio,
	]:
		if audio_player and audio_player.playing:
			audio_player.stop()


func _get_level_config(level_number: int) -> Dictionary:
	if level_number == 3:
		return {
			"title": "Level Three",
			"duration": 60.0,
			"starting_energy": MAX_ENERGY * 0.3,
			"required_rest": 1200.0,
			"event_times": [7.0, 15.0, 23.0, 31.0, 39.0, 47.0],
			"steal_duration": 1.0,
			"intro_stream": null,
			"bus_ambience_stream": LEVEL_THREE_BUS_AMBIENCE_STREAM,
			"arrive_stream": null,
			"win_stream": null,
			"not_rested_stream": null,
			"arrival_text": "",
			"win_result": "Level Three Complete!\nHardcore Mode cleared.",
			"not_rested_result": "Game Over\nYou didn't rest enough.",
			"stolen_result": "Game Over\nYour laptop was stolen.",
			"events": [
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": LEVEL_THREE_PREVENTED_ONE_STREAM,
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": LEVEL_THREE_STOLEN_STREAM,
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": LEVEL_THREE_PREVENTED_TWO_STREAM,
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": LEVEL_THREE_STOLEN_STREAM,
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": LEVEL_THREE_PREVENTED_THREE_STREAM,
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": LEVEL_THREE_STOLEN_STREAM,
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": LEVEL_THREE_PREVENTED_ONE_STREAM,
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": LEVEL_THREE_STOLEN_STREAM,
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": LEVEL_THREE_PREVENTED_TWO_STREAM,
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": LEVEL_THREE_STOLEN_STREAM,
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": LEVEL_THREE_PREVENTED_THREE_STREAM,
					"stolen_text": "Thief: Oh, there's a laptop in here!",
					"stolen_stream": LEVEL_THREE_STOLEN_STREAM,
				},
			],
		}

	if level_number == 2:
		return {
			"title": "Level Two",
			"duration": 45.0,
			"starting_energy": MAX_ENERGY * 0.4,
			"required_rest": 900.0,
			"event_times": [7.0, 16.0, 25.0, 34.0],
			"steal_duration": 2.0,
			"intro_stream": LEVEL_TWO_INTRO_STREAM,
			"bus_ambience_stream": LEVEL_TWO_BUS_AMBIENCE_STREAM,
			"arrive_stream": LEVEL_TWO_ARRIVE_STREAM,
			"win_stream": LEVEL_TWO_WIN_STREAM,
			"not_rested_stream": LEVEL_TWO_NOT_RESTED_STREAM,
			"arrival_text": "Bus Driver: We are arriving at The Convention Center.",
			"win_result": "Level Two Complete!\nYou protected the laptop and got enough rest.",
			"not_rested_result": "Game Over\nYou didn't rest enough.\n\"Hope you have the energy to win your tournament!\"",
			"stolen_result": "Game Over\nYour laptop was stolen.",
			"events": [
				{
					"start_text": "Thief: Oh, I need a computer for the convention.",
					"start_stream": LEVEL_TWO_EVENT_ONE_START_STREAM,
					"prevented_text": "Thief: Don't you need to sleep?",
					"prevented_stream": LEVEL_TWO_EVENT_ONE_PREVENTED_STREAM,
					"stolen_text": "Thief: Grumble, this is heavy.",
					"stolen_stream": LEVEL_TWO_EVENT_ONE_STOLEN_STREAM,
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": LEVEL_TWO_EVENT_TWO_PREVENTED_STREAM,
					"stolen_text": "Thief: Cough, nothing suspicious here.",
					"stolen_stream": LEVEL_TWO_EVENT_TWO_STOLEN_STREAM,
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oop, sorry!",
					"prevented_stream": LEVEL_TWO_EVENT_THREE_PREVENTED_STREAM,
					"stolen_text": "Thief: I'm not stealing your laptop.",
					"stolen_stream": LEVEL_TWO_EVENT_THREE_STOLEN_STREAM,
				},
				{
					"start_text": "",
					"start_stream": null,
					"prevented_text": "Thief: Oh man!",
					"prevented_stream": LEVEL_TWO_EVENT_FOUR_PREVENTED_STREAM,
					"stolen_text": "Thief: Laptop? Yes please.",
					"stolen_stream": LEVEL_TWO_EVENT_FOUR_STOLEN_STREAM,
				},
			],
		}

	return {
		"title": "Level One",
		"duration": 30.0,
		"starting_energy": 900.0,
		"required_rest": 600.0,
		"event_times": [7.0, 17.0],
		"steal_duration": 4.0,
		"intro_stream": null,
		"bus_ambience_stream": BUS_AMBIENCE_STREAM,
		"arrive_stream": BUSINESS_ARRIVE_STREAM,
		"win_stream": HAVE_GREAT_DAY_STREAM,
		"not_rested_stream": BOSS_STREAM,
		"arrival_text": "Bus Driver: We are arriving at The Business District.",
		"win_result": "Level One Complete!\nYou protected the laptop and got enough rest.",
		"not_rested_result": "Game Over\nYou didn't rest enough.\n\"No sleeping on the job!\"",
		"stolen_result": "Game Over\nYour laptop was stolen.\n\"What do you MEAN your\nlaptop was stolen!?\"",
		"events": [
			{
				"start_text": "Thief: Forgot my computer for work. This'll do perfectly.",
				"start_stream": THIEF_EVENT_ONE_START_STREAM,
				"prevented_text": "Thief: Rats! That's a loud zipper.",
				"prevented_stream": THIEF_EVENT_ONE_PREVENTED_STREAM,
				"stolen_text": "Thief: Oh, I could sell this for thousands!",
				"stolen_stream": THIEF_EVENT_ONE_STOLEN_STREAM,
			},
			{
				"start_text": "Thief: Nothing suspicious here...",
				"start_stream": THIEF_EVENT_TWO_START_STREAM,
				"prevented_text": "Thief: Oh man!",
				"prevented_stream": THIEF_EVENT_TWO_PREVENTED_STREAM,
				"stolen_text": "Thief: Heh, thanks for the laptop, buddy!",
				"stolen_stream": THIEF_EVENT_TWO_STOLEN_STREAM,
			},
		],
	}


func _apply_current_level_audio() -> void:
	intro_audio.stream = current_level["intro_stream"]
	bus_ambience_audio.stream = current_level["bus_ambience_stream"]
	bus_arrive_audio.stream = current_level["arrive_stream"]
	win_audio.stream = current_level["win_stream"]
	not_rested_audio.stream = current_level["not_rested_stream"]


func _reset_level_state() -> void:
	_stop_level_audio()
	steal_event.reset_event()
	energy = current_level["starting_energy"]
	rest = 0.0
	is_resting = false
	is_rem = false
	eyes_are_closed = false
	level_state = LevelState.WAITING_TO_START
	level_elapsed = 0.0
	next_event_index = 0
	current_encounter = 0
	zipper_hint_shown = false
	thief_hands.steal_duration = current_level["steal_duration"]
	$HUDlayer/HUD/Pause.disabled = false
	hud.open_eyes()
	hud.show_level_intro(current_level["title"])
	hud.update_level(level_elapsed, current_level["duration"], current_level["required_rest"], MAX_ENERGY)
	hud.update_energy(energy, false, false)
	_play_audio(intro_audio)


func _get_current_event_config() -> Dictionary:
	var events: Array = current_level["events"]
	var event_index := clampi(current_encounter - 1, 0, events.size() - 1)
	return events[event_index]


func _on_continue_pressed() -> void:
	if current_level_number < 3:
		current_level_number += 1
		current_level = _get_level_config(current_level_number)
		_apply_current_level_audio()
		_reset_level_state()
	else:
		get_tree().change_scene_to_file("res://scenes/credits.tscn")
