extends Node
class_name AudioManager

@export var base_audio_db_offset := -4.0
@export var thief_voice_db_boost := 2.0
@export var thief_start_db_boost := 0.0
@export var thief_prevented_db_boost := 6.0
@export var thief_stolen_db_boost := 6.0
@export var level_one_warning_zipper_db_boost := 0.0
@export var level_two_warning_zipper_db_boost := 2.0
@export var level_three_warning_zipper_db_boost := 4.0
@export var close_backpack_zip_db_boost := 0.0

const LEVEL_ONE_AUDIO := {
	"bus_ambience": preload("res://art/audio/bus ambience 30 sec_LevelOne.mp3"),
	"arrive": preload("res://art/audio/businessarrive_LevelOne.mp3"),
	"win": preload("res://art/audio/Have a Great day_LevelOne.mp3"),
	"not_rested": preload("res://art/audio/boss_LevelOne.mp3"),
	"events": [
		{
			"start": preload("res://art/audio/ForgotMyComputerForWorkThisllDoPerfectly_LevelOne.mp3"),
			"prevented": preload("res://art/audio/RatsThatsALoudZipper_LevelOne.mp3"),
			"stolen": preload("res://art/audio/OhICouldSellThisForThousands_LevelOne.mp3"),
		},
		{
			"start": preload("res://art/audio/NothingSuspiciousHere_LevelOne.mp3"),
			"prevented": preload("res://art/audio/OhMan1_LevelOne.mp3"),
			"stolen": preload("res://art/audio/HehThanksForTheLaptopBuddyO_LevelOne.mp3"),
		},
	],
}

const LEVEL_TWO_AUDIO := {
	"intro": preload("res://art/audio/level2.mp3"),
	"bus_ambience": preload("res://art/audio/45 second bus ambience_LevelTwo.mp3"),
	"arrive": preload("res://art/audio/conventionarrive_LevelTwo.mp3"),
	"win": preload("res://art/audio/Have a great convention_LevelTwo.mp3"),
	"not_rested": preload("res://art/audio/tournament_LevelTwo.mp3"),
	"events": [
		{
			"start": preload("res://art/audio/OhINeedAComputerForTheConvention_LevelTwo.mp3"),
			"prevented": preload("res://art/audio/DontYouNeedToSleep_LevelTwo.mp3"),
			"stolen": preload("res://art/audio/GrumbleThisIsHeavy_LevelTwo.mp3"),
		},
		{
			"prevented": preload("res://art/audio/OhMan2_LevelTwo.mp3"),
			"stolen": preload("res://art/audio/CoughNothingSuspiciousHere_LevelTwo.mp3"),
		},
		{
			"prevented": preload("res://art/audio/OopSorry_LevelTwo.mp3"),
			"stolen": preload("res://art/audio/ImNotStealingYourLaptop_LevelTwo.mp3"),
		},
		{
			"prevented": preload("res://art/audio/OhMan3_LevelTwo.mp3"),
			"stolen": preload("res://art/audio/LaptopYesPlease_LevelTwo.mp3"),
		},
	],
}

const LEVEL_THREE_AUDIO := {
	"bus_ambience": preload("res://art/audio/60 seconds of bus ambience_LevelThree.mp3"),
	"events": [
		{
			"prevented": preload("res://art/audio/OhMan4_LevelThree.mp3"),
			"stolen": preload("res://art/audio/OhTheresALaptopInHere1_LevelThree.mp3"),
		},
		{
			"prevented": preload("res://art/audio/OhMan5_LevelThree.mp3"),
			"stolen": preload("res://art/audio/OhTheresALaptopInHere1_LevelThree.mp3"),
		},
		{
			"prevented": preload("res://art/audio/OhMan6_LevelThree.mp3"),
			"stolen": preload("res://art/audio/OhTheresALaptopInHere1_LevelThree.mp3"),
		},
		{
			"prevented": preload("res://art/audio/OhMan4_LevelThree.mp3"),
			"stolen": preload("res://art/audio/OhTheresALaptopInHere1_LevelThree.mp3"),
		},
		{
			"prevented": preload("res://art/audio/OhMan5_LevelThree.mp3"),
			"stolen": preload("res://art/audio/OhTheresALaptopInHere1_LevelThree.mp3"),
		},
		{
			"prevented": preload("res://art/audio/OhMan6_LevelThree.mp3"),
			"stolen": preload("res://art/audio/OhTheresALaptopInHere1_LevelThree.mp3"),
		},
	],
}

var intro_audio: AudioStreamPlayer
var bus_ambience_audio: AudioStreamPlayer
var bus_arrive_audio: AudioStreamPlayer
var win_audio: AudioStreamPlayer
var not_rested_audio: AudioStreamPlayer
var thief_voice_audio: AudioStreamPlayer


func _ready() -> void:
	intro_audio = _create_audio_player("IntroAudio")
	bus_ambience_audio = _create_audio_player("BusAmbienceAudio")
	bus_arrive_audio = _create_audio_player("BusArriveAudio")
	win_audio = _create_audio_player("WinAudio")
	not_rested_audio = _create_audio_player("NotRestedAudio")
	thief_voice_audio = _create_audio_player("ThiefVoiceAudio")


func get_level_audio_config(level_number: int) -> Dictionary:
	if level_number == 3:
		return LEVEL_THREE_AUDIO
	if level_number == 2:
		return LEVEL_TWO_AUDIO
	return LEVEL_ONE_AUDIO


func apply_level_audio(audio_config: Dictionary) -> void:
	intro_audio.stream = audio_config.get("intro", null)
	bus_ambience_audio.stream = audio_config.get("bus_ambience", null)
	bus_arrive_audio.stream = audio_config.get("arrive", null)
	win_audio.stream = audio_config.get("win", null)
	not_rested_audio.stream = audio_config.get("not_rested", null)


func update_volume() -> void:
	for audio_player in [
		intro_audio,
		bus_ambience_audio,
		bus_arrive_audio,
		win_audio,
		not_rested_audio,
	]:
		if audio_player:
			audio_player.volume_db = get_base_volume_db()
	if thief_voice_audio:
		thief_voice_audio.volume_db = _get_thief_volume_db()


func play_intro() -> void:
	_play_audio(intro_audio)


func has_intro() -> bool:
	return intro_audio != null and intro_audio.stream != null


func is_intro_playing() -> bool:
	return intro_audio != null and intro_audio.playing


func wait_for_intro_finished() -> void:
	if is_intro_playing():
		await intro_audio.finished


func play_bus_ambience() -> void:
	_play_audio(bus_ambience_audio)


func play_arrival() -> void:
	_play_audio(bus_arrive_audio)


func play_win() -> void:
	_play_audio(win_audio)


func play_not_rested() -> void:
	_play_audio(not_rested_audio)


func play_thief_voice(stream: AudioStream, voice_type := "default") -> void:
	if thief_voice_audio == null or stream == null:
		return
	thief_voice_audio.stop()
	thief_voice_audio.stream = stream
	thief_voice_audio.volume_db = _get_thief_volume_db(voice_type)
	thief_voice_audio.play()


func wait_for_arrival_finished() -> void:
	if bus_arrive_audio and bus_arrive_audio.playing:
		await bus_arrive_audio.finished


func stop_all() -> void:
	for audio_player in [
		intro_audio,
		bus_ambience_audio,
		bus_arrive_audio,
		win_audio,
		not_rested_audio,
		thief_voice_audio,
	]:
		if audio_player and audio_player.playing:
			audio_player.stop()


func _create_audio_player(player_name: String) -> AudioStreamPlayer:
	var audio_player := AudioStreamPlayer.new()
	audio_player.name = player_name
	audio_player.volume_db = get_base_volume_db()
	add_child(audio_player)
	return audio_player


func _play_audio(audio_player: AudioStreamPlayer) -> void:
	if audio_player == null or audio_player.stream == null:
		return
	audio_player.stop()
	audio_player.play()


func get_base_volume_db() -> float:
	return linear_to_db(Settings.volume / 10.0) + base_audio_db_offset


func get_zipper_volume_db(level_number: int) -> float:
	return get_base_volume_db() + _get_level_zipper_db_boost(level_number)


func get_close_zip_volume_db() -> float:
	return get_base_volume_db() + close_backpack_zip_db_boost


func _get_thief_volume_db(voice_type := "default") -> float:
	return get_base_volume_db() + thief_voice_db_boost + _get_thief_type_db_boost(voice_type)


func _get_thief_type_db_boost(voice_type: String) -> float:
	if voice_type == "start":
		return thief_start_db_boost
	if voice_type == "prevented":
		return thief_prevented_db_boost
	if voice_type == "stolen":
		return thief_stolen_db_boost
	return 0.0


func _get_level_zipper_db_boost(level_number: int) -> float:
	if level_number == 3:
		return level_three_warning_zipper_db_boost
	if level_number == 2:
		return level_two_warning_zipper_db_boost
	return level_one_warning_zipper_db_boost
