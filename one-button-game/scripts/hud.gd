extends Control

# A partially transparent test value lets us inspect events while "asleep".
# Change this to 1.0 once the steal flow and audio cues are finalized.
const CLOSED_EYE_ALPHA = 0.7

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Fader.custom_minimum_size = get_viewport_rect().size
	$Fader.size = get_viewport_rect().size

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
func update_energy(value: int, is_resting: bool, is_rem: bool) -> void:
	@warning_ignore("integer_division") # keep the percentage simple
	$Energy/Bar.value = value/18
	if is_rem:
		$Energy/Status.text = "Tired..."
	elif is_resting:
		$Energy/Status.text = "Resting"
	else:
		$Energy/Status.text = "Awake"


# Display a terminal overlay after the player discovers the stolen backpack.
func show_lose_message(message: String) -> void:
	$ResultOverlay/Message.text = message
	$ResultOverlay.visible = true
