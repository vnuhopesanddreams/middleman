extends DateProblem

## Green puffs drifting from their mouth. Fixed by tapping fast to spray mint.

const TAPS_NEEDED = 4
const SPRAY_TIME = 0.2

var _taps := 0
var _spray_left := 0.0


func _init() -> void:
	prompt = "TAP FAST!"


func _on_start() -> void:
	_taps = 0


func handle_input(event: InputEvent, _point: Vector2) -> bool:
	if not (event is InputEventScreenTouch and event.pressed):
		return false
	_taps += 1
	_spray_left = SPRAY_TIME
	if _taps >= TAPS_NEEDED:
		_succeed()
	else:
		Sfx.play("action")
	return true


func _tick(delta: float) -> void:
	_spray_left -= delta


func _draw() -> void:
	# Puffs rising from the mouth, each one growing and fading as it goes.
	var puffs := 3 if not active else maxi(3 - _taps / 2, 1)
	for i in puffs:
		var t := fmod(_time * 0.8 + float(i) / puffs, 1.0)
		var at := Vector2(4.0 + t * 5.0 + sin(t * 6.0 + i) * 1.5, -3.0 - t * 12.0)
		draw_circle(at, 1.5 + t * 2.5, Color(0.45, 0.75, 0.2, 0.85 * (1.0 - t)))
	# A burst of mint spray for a moment after each tap.
	if active and _spray_left > 0.0:
		var t := 1.0 - _spray_left / SPRAY_TIME
		for i in 5:
			var angle := -0.6 + i * 0.3
			draw_circle(Vector2(4, -4) + Vector2.from_angle(angle) * (3.0 + t * 7.0), 1.2, Color(0.8, 1.0, 0.95, 1.0 - t))
