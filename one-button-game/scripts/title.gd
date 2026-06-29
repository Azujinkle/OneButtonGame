extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
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
