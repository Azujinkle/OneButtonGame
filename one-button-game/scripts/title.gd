extends Control

const TITLE_HOLD_SECONDS := 2.0
const TITLE_FADE_SECONDS := 0.75

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$TitleScreenAudio.play()
	if Settings.from_credits:
		Settings.from_credits = false
	else:
		_play_title_intro()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _play_title_intro() -> void:
	$Menu.visible = false
	$MainTitleSplash.visible = true
	$MainTitleSplash.modulate.a = 1.0

	await get_tree().create_timer(TITLE_HOLD_SECONDS).timeout

	$Menu.visible = true
	var tween := create_tween()
	tween.tween_property($MainTitleSplash, "modulate:a", 0.0, TITLE_FADE_SECONDS)
	await tween.finished
	$MainTitleSplash.visible = false


func _on_start_pressed() -> void:
	$TitleScreenAudio.stop()
	get_tree().change_scene_to_file("res://scenes/onboarding.tscn")


func _on_options_pressed() -> void:
	get_tree().paused = true
	$PopupLayer/PauseOptions.show()


func _on_credits_pressed() -> void:
	get_tree().paused = true
	$PopupLayer/Credits.show()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_pause() -> void:
	for button in $Menu.get_children():
		if button.name != "Bus Stop":
			button.disabled = !button.disabled


func _on_volume_change() -> void:
	$TitleScreenAudio.volume_db = linear_to_db(Settings.volume) - 4.0
