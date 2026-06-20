extends Node2D

var energy: int
var rest: int
var is_resting: bool
var is_rem: bool

const STARTING_ENERGY = 1800 # energy at the start of levels
const AWAKE_ENERGY = -2 # energy lost per frame
const REST_ENERGY = 3 # energy gained per frame while resting
const REST_THRESHOLD = 30 # time in frames needed before properly resting
const REM_THRESHOLD = 600 # energy needed to awaken if all energy is depleted

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	energy = STARTING_ENERGY
	rest = 0
	is_resting = false
	is_rem = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_rem:
		close_eyes()
		if energy > REM_THRESHOLD:
			is_rem = false
	else:
		if Input.is_action_pressed("close"): # default controls
			close_eyes()
		else:
			open_eyes()
		# TODO: accessibility controls
	
	energy += AWAKE_ENERGY
	if is_resting:
		energy += REST_ENERGY
	if energy < 0:
		is_rem = true
	$HUD.update_energy(energy, is_resting, is_rem)

# Close the player's eyes, fading out their sights before they recover energy.
func close_eyes() -> void:
	$HUD.close_eyes()
	if rest >= REST_THRESHOLD:
		is_resting = true
	else:
		rest += 1

# Open the player's eyes, resuming energy depletion as they regain their sight.
func open_eyes() -> void:
	$HUD.open_eyes()
	rest -= 1
	if is_resting:
		$HUD.flare_eyes()
	is_resting = false
