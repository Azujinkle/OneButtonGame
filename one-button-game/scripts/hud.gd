extends Control

var threshold: float
var closed_eye_alpha := 0.7
signal pause
signal continue_pressed

const RESTED_COLOR = Color("e96a0e")
const TIRED_COLOR = Color("a92a0e")
const MAX_ENERGY_VALUE = 1800.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Fader.custom_minimum_size = get_viewport_rect().size
	$Fader.size = get_viewport_rect().size
	$ResultOverlay.visible = false
	threshold = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

# Darken the screen to simulate closed eyes.
func close_eyes() -> void:
	var tween: Tween = create_tween()
	tween.tween_property($Fader, "modulate:a", closed_eye_alpha, 0.2)

# Reveal the screen to simulate opened eyes.
func open_eyes() -> void:
	var tween: Tween = create_tween()
	tween.tween_property($Fader, "modulate:a", 0.0, 0.2)

# Causes a light flare.
func flare_eyes() -> void:
	var tween: Tween = create_tween()
	tween.tween_property($Flare, "modulate:a", 1.0, 0.2)
	tween.tween_property($Flare, "modulate:a", 0.0, 0.2)

# Updates energy bar and status.
func update_energy(value: float, is_resting: bool, is_rem: bool) -> void:
	$Energy/Bar.value = value / 18.0
	$Energy/Percent.text = "%d%%" % roundi(value / MAX_ENERGY_VALUE * 100.0)
	var percent_x: float = $Energy/Bar.position.x + $Energy/Bar.size.x * value / MAX_ENERGY_VALUE
	$Energy/Percent.position.x = percent_x - $Energy/Percent.size.x / 2.0
	if is_rem:
		$Energy/Status.text = "Tired..."
	elif is_resting:
		$Energy/Status.text = "Resting"
	else:
		$Energy/Status.text = "Awake"
	var stylebox = $Energy/Bar.get_theme_stylebox("fill").duplicate()
	if value >= threshold: 
		stylebox.bg_color = RESTED_COLOR
	else:
		stylebox.bg_color = TIRED_COLOR
	$Energy/Bar.add_theme_stylebox_override("fill", stylebox)


# Display the level prompt before its timer begins.
func show_level_intro(level_name := "Level One") -> void:
	$ResultOverlay.visible = false
	$LevelInfo/Instruction.text = "Hold SPACE to sleep and start %s" % level_name
	$LevelInfo/Subtitle.text = "Protect your laptop and get enough rest."


func show_instruction(message: String) -> void:
	$LevelInfo/Instruction.text = message


func set_closed_eye_alpha(value: float) -> void:
	closed_eye_alpha = clampf(value, 0.0, 1.0)


func update_level(elapsed: float, duration: float, required: float, maximum: float) -> void:
	var time_left := maxf(duration - elapsed, 0.0)
	$LevelInfo/Timer.text = "Bus ride: %.1f s" % time_left
	threshold = required
	var rested_x: float = $Energy/Bar.position.x + $Energy/Bar.size.x * required / maximum
	$Energy/RestedLine.position.x = rested_x - $Energy/RestedLine.size.x / 2.0
	$Energy/RestedLabel.position.x = rested_x - $Energy/RestedLabel.size.x / 2.0

func show_subtitle(message: String) -> void:
	$LevelInfo/Subtitle.text = message


func show_result(message: String, success: bool) -> void:
	$ResultOverlay/Message.text = message
	if success:
		$ResultOverlay/Message.modulate = Color(0.75, 1.0, 0.78)
		$ResultOverlay/AngryMan.visible = false
		$ResultOverlay/Retry.visible = false
		$ResultOverlay/Continue.visible = true
	else:
		$ResultOverlay/Message.modulate = Color(1.0, 0.75, 0.75)
		$ResultOverlay/AngryMan.visible = true
		$ResultOverlay/Retry.visible = true
		$ResultOverlay/Continue.visible = false
	$ResultOverlay.visible = true


func _on_pause_pressed() -> void:
	pause.emit()


func _on_retry_pressed() -> void:
	# TODO: change to properly reload current level
	$ResultOverlay.visible = false
	get_tree().reload_current_scene()


func _on_continue_pressed() -> void:
	continue_pressed.emit()
