extends Node

var active: bool
signal steal

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

# Initiates a steal event that must be cleared within the given time in frames.
func initiate(time: int) -> void:
	$Zipper.play()
	$Interval.wait_time = time
	$Interval.start()
	active = true

# Stops the current steal event.
func stop_steal() -> void:
	$Interval.stop()
	active = false

# Player has failed to open their eyes within the steal interval.
func _on_interval_timeout() -> void:
	steal.emit()
	active = false
