extends Node
class_name AudioManager

const BASE_AUDIO_DB_OFFSET := -4.0
const THIEF_VOLUME_MULTIPLIER := 1.25

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


func play_bus_ambience() -> void:
	_play_audio(bus_ambience_audio)


func play_arrival() -> void:
	_play_audio(bus_arrive_audio)


func play_win() -> void:
	_play_audio(win_audio)


func play_not_rested() -> void:
	_play_audio(not_rested_audio)


func play_thief_voice(stream: AudioStream) -> void:
	if thief_voice_audio == null or stream == null:
		return
	thief_voice_audio.stop()
	thief_voice_audio.stream = stream
	thief_voice_audio.volume_db = _get_thief_volume_db()
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
	return linear_to_db(Settings.volume / 10.0) + BASE_AUDIO_DB_OFFSET


func _get_thief_volume_db() -> float:
	return linear_to_db(Settings.volume / 10.0 * THIEF_VOLUME_MULTIPLIER) + BASE_AUDIO_DB_OFFSET
