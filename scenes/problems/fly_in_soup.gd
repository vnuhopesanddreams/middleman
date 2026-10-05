extends DateProblem

## A fly buzzing around their head. Fixed by tapping the fly.

## How close a tap has to land, in world pixels (finger-sized on a phone).
const HIT_RADIUS = 16.0
## Slows the buzzing down (1 is full speed).
const SPEED = 0.6


func _init() -> void:
	prompt = "SWAT THE FLY!"


func handle_input(event: InputEvent, point: Vector2) -> bool:
	if not (event is InputEventScreenTouch and event.pressed):
		return false
	if point.distance_to(_fly_position()) <= HIT_RADIUS:
		_succeed()
	else:
		Sfx.play("action")
	return true


## Loops around the head, jittering like a fly does.
func _fly_position() -> Vector2:
	var t := _time * SPEED
	return Vector2(
		cos(t * 3.1) * 10.0 + sin(t * 7.3) * 3.0,
		-10.0 + sin(t * 4.7) * 5.0 + cos(t * 11.0) * 2.0)


func _draw() -> void:
	var fly := _fly_position()
	var flap := 1.0 + 0.6 * sin(_time * 60.0)
	var wing := Color(0.9, 0.95, 1.0, 0.8)
	draw_circle(fly + Vector2(-1.2, -1.0 * flap), 1.1, wing)
	draw_circle(fly + Vector2(1.2, -1.0 * flap), 1.1, wing)
	draw_circle(fly, 1.2, Color(0.08, 0.08, 0.1))
