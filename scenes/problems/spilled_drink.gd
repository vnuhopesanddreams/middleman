extends DateProblem

## A drink spilled down their front. Fixed by swiping back and forth to wipe it off.

## How far to drag in total, in world pixels.
const WIPE_DISTANCE = 55.0

var _wiped := 0.0
var _last_point := Vector2.ZERO


func _init() -> void:
	prompt = "SWIPE TO WIPE!"


func _on_start() -> void:
	_wiped = 0.0


func handle_input(event: InputEvent, point: Vector2) -> bool:
	if event is InputEventScreenTouch:
		_last_point = point
		return true
	if event is InputEventScreenDrag:
		_wiped += point.distance_to(_last_point)
		_last_point = point
		if _wiped >= WIPE_DISTANCE:
			_succeed()
		return true
	return false


func _draw() -> void:
	# The stain shrinks as it's wiped; a drip keeps running off it.
	var left := 1.0 - (_wiped / WIPE_DISTANCE if active else 0.0)
	var stain := Color(0.3, 0.5, 0.95, 0.75)
	draw_circle(Vector2(0, 6), 4.0 * left + 1.0, stain)
	draw_circle(Vector2(2.5, 8), 2.5 * left + 0.5, stain)
	var t := fmod(_time * 1.2, 1.0)
	draw_circle(Vector2(1.5, 9.0 + t * 6.0), 0.9, Color(stain, stain.a * (1.0 - t)))
