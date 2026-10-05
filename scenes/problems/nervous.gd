extends DateProblem

## Sweat flying off them. Fixed by tapping when a shrinking ring meets the circle around
## them, like taking a deep breath. A miss doesn't restart the ring, so tapping
## early just costs a moment.

const BREATHS_NEEDED = 1
## Seconds for the ring to shrink from its start to past the circle.
const RING_PERIOD = 1.6
const RING_START = 28.0
const RING_END = 4.0
const TARGET_RADIUS = 13.0
## How far off the ring can be from the circle and still count, in world pixels.
const TOLERANCE = 5.0
const FLASH_TIME = 0.25

var _breaths := 0
var _ring_time := 0.0
## Briefly green after a good tap, red after a miss.
var _flash_left := 0.0
var _flash_color := Color.WHITE


func _init() -> void:
	prompt = "TAP WHEN THE RINGS MEET!"
	time_limit = 5.0


func _on_start() -> void:
	_breaths = 0
	_ring_time = 0.0


func handle_input(event: InputEvent, _point: Vector2) -> bool:
	if not (event is InputEventScreenTouch and event.pressed):
		return false
	var hit := absf(_ring_radius() - TARGET_RADIUS) <= TOLERANCE
	_flash_left = FLASH_TIME
	_flash_color = Color(0.4, 1.0, 0.5) if hit else Color(1.0, 0.35, 0.3)
	if not hit:
		Sfx.play("qte_fail")
	else:
		_ring_time = 0.0
		_breaths += 1
		if _breaths >= BREATHS_NEEDED:
			_succeed()
		else:
			Sfx.play("action")
	return true


func _tick(delta: float) -> void:
	_ring_time += delta
	_flash_left -= delta


func _ring_radius() -> float:
	return lerpf(RING_START, RING_END, fmod(_ring_time, RING_PERIOD) / RING_PERIOD)


func _draw() -> void:
	# Drops flicking off both sides of the head.
	for i in 4:
		var t := fmod(_time * 1.6 + i * 0.25, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector2(side * (3.0 + t * 7.0), -10.0 - sin(t * PI) * 5.0 + t * 6.0)
		draw_circle(at, 1.1, Color(0.55, 0.8, 1.0, 1.0 - t))
	if not active:
		return
	# Dark edges so both stand out against the white guests and the floor.
	var dark := Color(0.1, 0.06, 0.08)
	var circle_color := _flash_color if _flash_left > 0.0 else Color(0.45, 0.8, 1.0)
	draw_arc(Vector2.ZERO, TARGET_RADIUS, 0.0, TAU, 48, dark, 3.0)
	draw_arc(Vector2.ZERO, TARGET_RADIUS, 0.0, TAU, 48, circle_color, 1.5)
	draw_arc(Vector2.ZERO, _ring_radius(), 0.0, TAU, 48, dark, 2.5)
	draw_arc(Vector2.ZERO, _ring_radius(), 0.0, TAU, 48, Color(1, 0.85, 0.3), 1.0)
