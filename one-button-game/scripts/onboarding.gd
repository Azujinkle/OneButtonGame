extends Control

const GAME_SCENE := "res://scenes/game.tscn"

@onready var alarm_clock: TextureRect = $Visuals/AlarmClock
@onready var bus_background: TextureRect = $Visuals/BusBackground
@onready var backpack: TextureRect = $Visuals/Backpack
@onready var text_label: Label = $DialoguePanel/Text
@onready var alarm_audio: AudioStreamPlayer = $Audio/AlarmAudio
@onready var zipper_audio: AudioStreamPlayer = $Audio/ZipperAudio
@onready var bus_audio: AudioStreamPlayer = $Audio/BusOnboardingAudio


func _ready() -> void:
	_run_onboarding()


func _run_onboarding() -> void:
	# The onboarding is automatic so the game still only uses one gameplay button.
	# It establishes: the player is tired, the laptop is in the backpack, and thieves matter.
	_show_alarm_intro()
	await _show_line("6:00 AM. I barely got any sleep last night...", 3.0)
	await _show_line("I still need to get to work, so I should sleep on the bus.", 3.0)
	await _show_line("I just need to make sure nobody steals my laptop.", 3.0)

	_show_packing_moment()
	await _show_line("Laptop packed.", 1.5)

	_show_bus_intro()
	await _show_line("Bus Driver: Attention passengers. ", 3.0)
	await _show_line("Bus Driver: Next stop, The Business District.", 3.0)
	await _show_line("Bus Driver: Just to let you know, we are not liable for any theft on this bus. But,\nthe bus thieves only steal when you're asleep.", 9.0)
	await _show_line("Bus Driver: Sleep at your own discretion.", 2.5)

	# Do not switch scenes until the bus onboarding voice line finishes.
	# Changing scenes destroys this AudioStreamPlayer, which would cut the audio off.
	if bus_audio.playing:
		await bus_audio.finished

	get_tree().change_scene_to_file(GAME_SCENE)


func _show_alarm_intro() -> void:
	alarm_clock.visible = true
	bus_background.visible = false
	backpack.visible = false
	alarm_audio.volume_db = linear_to_db(Settings.volume)
	alarm_audio.play()


func _show_packing_moment() -> void:
	alarm_clock.visible = false
	bus_background.visible = true
	backpack.visible = true
	zipper_audio.volume_db = linear_to_db(Settings.volume)
	zipper_audio.play()


func _show_bus_intro() -> void:
	alarm_clock.visible = false
	bus_background.visible = true
	backpack.visible = true
	bus_audio.volume_db = linear_to_db(Settings.volume)
	bus_audio.play()


func _show_line(message: String, duration: float) -> void:
	text_label.text = message
	await get_tree().create_timer(duration).timeout
