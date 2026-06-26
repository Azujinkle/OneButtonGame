extends Control

var threshold: float
signal pause

# A partially transparent test value lets us inspect events while "asleep".
# Change this to 1.0 once the steal flow and audio cues are finalized.
const CLOSED_EYE_ALPHA = 0.7
const RESTED_COLOR = Color("e96a0e")
const TIRED_COLOR = Color("a92a0e")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Fader.custom_minimum_size = get_viewport_rect().size
	$Fader.size = get_viewport_rect().size
	threshold = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

# Darken the screen to simulate closed eyes.
func close_eyes() -> void:
	var tween: Tween = create_tween()
	tween.tween_property($Fader, "modulate:a", CLOSED_EYE_ALPHA, 0.2)

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


# Display the Level One prompt before its timer begins.
func show_level_intro() -> void:
	$LevelInfo/Instruction.text = "Hold SPACE to sleep and start Level One"
	$LevelInfo/Subtitle.text = "Protect your laptop and get enough rest."


func show_instruction(message: String) -> void:
	$LevelInfo/Instruction.text = message


func update_level(elapsed: float, duration: float, required: float, maximum: float) -> void:
	var time_left := maxf(duration - elapsed, 0.0)
	$LevelInfo/Timer.text = "Bus ride: %.1f s" % time_left
	threshold = required
	var displacement = $Energy/Bar.size.x * required / maximum - $Energy/Marker.size.x / 2.0
	$Energy/Marker.position = Vector2($Energy/Bar.position.x + displacement, -7)

func show_subtitle(message: String) -> void:
	$LevelInfo/Subtitle.text = message


func show_result(message: String, success: bool) -> void:
	$ResultOverlay/Message.text = message
	if success:
		$ResultOverlay/Message.modulate = Color(0.75, 1.0, 0.78)
	else:
		$ResultOverlay/Message.modulate = Color(1.0, 0.75, 0.75)
	$ResultOverlay.visible = true


func _on_pause_pressed() -> void:
	pause.emit()
