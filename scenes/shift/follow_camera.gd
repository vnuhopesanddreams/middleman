class_name FollowCamera
extends Camera2D

## Trails a little behind `target`, like position smoothing, but can be jumped along
## with it (see `shift`) when the room wraps around. Looks a bit ahead in the direction
## the target is moving, and can shake (`shake`) or bump its zoom (`punch`) for effect.
## In the "camera" group, so anything can call those with `call_group`.

const GROUP = "camera"
## Moving faster than this counts as full speed for looking ahead.
const LEAD_FULL_SPEED = 250.0
## How fast a shake dies down, in pixels of strength per second.
const SHAKE_DECAY = 14.0
const PUNCH_TIME = 0.3

@export var target: Node2D
## Higher catches up faster.
@export var follow_speed := 8.0
## How far ahead of the target the camera looks while it moves, in world pixels.
@export var look_ahead := 44.0
## Higher swings the look-ahead round faster.
@export var look_ahead_speed := 3.0

var _lead := Vector2.ZERO
var _last_target := Vector2.ZERO
var _shake := 0.0
var _base_zoom := Vector2.ONE
var _punch: Tween


func _ready() -> void:
	top_level = true
	add_to_group(GROUP)
	global_position = target.global_position
	_last_target = target.global_position
	_base_zoom = zoom


## Measures how the target moves on physics steps, which is when it moves; rendered
## frames can come more often (high refresh screens) and would mostly see it still.
func _physics_process(delta: float) -> void:
	var motion := (target.global_position - _last_target) / delta
	_last_target = target.global_position
	var wanted_lead := motion.limit_length(LEAD_FULL_SPEED) / LEAD_FULL_SPEED * look_ahead
	_lead = _lead.lerp(wanted_lead, 1.0 - exp(-look_ahead_speed * delta))


func _process(delta: float) -> void:
	global_position = global_position.lerp(target.global_position + _lead, 1.0 - exp(-follow_speed * delta))

	if _shake > 0.0:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = move_toward(_shake, 0.0, SHAKE_DECAY * delta)
	else:
		offset = Vector2.ZERO


func shift(by: Vector2) -> void:
	global_position += by
	_last_target += by


## Shakes the view, `strength` world pixels at first, settling quickly.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## Zooms in a touch and springs back.
func punch(amount := 0.06) -> void:
	if _punch:
		_punch.kill()
	zoom = _base_zoom * (1.0 + amount)
	_punch = create_tween()
	_punch.tween_property(self, "zoom", _base_zoom, PUNCH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
