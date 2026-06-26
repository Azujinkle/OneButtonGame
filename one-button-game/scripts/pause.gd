extends Control

@onready var volume_range = $Menu/Slider
@onready var windowed_mode = $Menu/DisplayOption/Windowed
@onready var fullscreen_mode = $Menu/DisplayOption/Fullscreen
@onready var hold_mode = $Menu/ControlOption/Hold
@onready var toggle_mode = $Menu/ControlOption/Toggle

signal volume_change


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	check_settings()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_pause_button() -> void:
	check_settings()
	show()

# Ensure menus reflect current settings
func check_settings() -> void:
	volume_range.value = Settings.volume
	
	windowed_mode.button_pressed = !Settings.fullscreen
	fullscreen_mode.button_pressed = Settings.fullscreen
	if Settings.fullscreen:
		fullscreen_mode.button_mask = 0
	else:
		windowed_mode.button_mask = 0
	
	hold_mode.button_pressed = !Settings.toggle
	toggle_mode.button_pressed = Settings.toggle
	if Settings.toggle:
		toggle_mode.button_mask = 0
	else:
		hold_mode.button_mask = 0

func _on_slider_value_changed(value: float) -> void:
	Settings.volume = volume_range.value
	volume_change.emit()

func _on_windowed_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Settings.fullscreen = false
		windowed_mode.button_mask = 0
		fullscreen_mode.button_pressed = false
		fullscreen_mode.button_mask = 1
		get_window().set_mode(Window.MODE_WINDOWED)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Settings.fullscreen = true
		windowed_mode.button_mask = 1
		windowed_mode.button_pressed = false
		fullscreen_mode.button_mask = 0
		get_window().set_mode(Window.MODE_FULLSCREEN)

func _on_hold_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Settings.toggle = false
		toggle_mode.button_mask = 1
		toggle_mode.button_pressed = false
		hold_mode.button_mask = 0

func _on_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Settings.toggle = true
		toggle_mode.button_mask = 0
		hold_mode.button_pressed = false
		hold_mode.button_mask = 1

func _on_return_pressed() -> void:
	get_tree().paused = false
	hide()
