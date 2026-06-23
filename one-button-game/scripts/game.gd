extends Node2D

signal eyes_opened

enum LevelState {
	RUNNING,
	LOST_STOLEN,
}

@onready var hud = $HUDlayer/HUD
@onready var steal_event = $busScene/StealEvent
@onready var backpack = $busScene/Backpack

var energy: int
var rest: int
var is_resting: bool
var is_rem: bool
var eyes_are_closed: bool
var level_state := LevelState.RUNNING

const STARTING_ENERGY = 1800 # energy at the start of levels
const AWAKE_ENERGY = -2 # energy lost per frame
const REST_ENERGY = 3 # energy gained per frame while resting
const REST_THRESHOLD = 30 # time in frames needed before properly resting
const REM_THRESHOLD = 600 # energy needed to awaken if all energy is depleted
const FIRST_STEAL_DELAY = 0.5 # short pause before the automatic tutorial steal

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	energy = STARTING_ENERGY
	rest = 0
	is_resting = false
	is_rem = false
	eyes_are_closed = false
	eyes_opened.connect(steal_event.player_opened_eyes)
	steal_event.steal_succeeded.connect(_on_steal_succeeded)
	_run_first_steal_event()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Freeze gameplay systems after the level reaches a terminal state.
	if level_state != LevelState.RUNNING:
		return

	if is_rem and energy > REM_THRESHOLD:
		is_rem = false

	var should_close_eyes := is_rem or Input.is_action_pressed("close")
	if should_close_eyes != eyes_are_closed:
		set_eyes_closed(should_close_eyes)

	if eyes_are_closed:
		rest = mini(rest + 1, REST_THRESHOLD)
		is_resting = rest >= REST_THRESHOLD
	else:
		rest = maxi(rest - 1, 0)
		is_resting = false
	
	energy += AWAKE_ENERGY
	if is_resting:
		energy += REST_ENERGY
	if energy < 0:
		is_rem = true
	hud.update_energy(energy, is_resting, is_rem)


func set_eyes_closed(value: bool) -> void:
	if eyes_are_closed == value:
		return

	eyes_are_closed = value
	if eyes_are_closed:
		hud.close_eyes()
		steal_event.player_closed_eyes()
	else:
		hud.open_eyes()
		if is_resting:
			hud.flare_eyes()
		eyes_opened.emit()
		_check_open_eyes_result()


# Discovering an already-open backpack means the steal has succeeded.
func _check_open_eyes_result() -> void:
	if backpack.is_open:
		lose_from_steal()


func lose_from_steal() -> void:
	# Guard against showing the same result more than once.
	if level_state != LevelState.RUNNING:
		return

	level_state = LevelState.LOST_STOLEN
	hud.show_lose_message("Your backpack was stolen!")


# If the response window already expired while the player was waking up,
# resolve the loss as soon as the hand finishes opening the backpack.
func _on_steal_succeeded() -> void:
	if not eyes_are_closed:
		lose_from_steal()


func _run_first_steal_event() -> void:
	await get_tree().create_timer(FIRST_STEAL_DELAY).timeout
	if level_state != LevelState.RUNNING:
		return

	# The first event always plays. Awake players see the hand enter and retreat;
	# sleeping players must release Space before the hand reaches the backpack.
	steal_event.start_event(not eyes_are_closed)
