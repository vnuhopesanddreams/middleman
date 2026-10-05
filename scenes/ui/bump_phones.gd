extends Control

## Two pixel phones sliding together and bumping, over and over, to show what to do.

const CYCLE = 1.6
## Fraction of the cycle spent sliding in, touching, and sliding back out.
const SLIDE_IN = 0.4
const TOUCH = 0.15

@export var phone_size := Vector2(120, 220)
@export var color := Color(1, 0.85, 0.3)
@export var screen_color := Color(0.45, 0.8, 1.0)
@export var outline_color := Color(0.1, 0.06, 0.08)
@export var spark_color := Color(1, 0.6, 0.75)
@export var outline := 8.0

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var t := fmod(_time, CYCLE) / CYCLE
	# 0 = apart, 1 = touching.
	var closeness := 0.0
	if t < SLIDE_IN:
		closeness = ease(t / SLIDE_IN, 0.4)
	elif t < SLIDE_IN + TOUCH:
		closeness = 1.0
	else:
		closeness = 1.0 - ease((t - SLIDE_IN - TOUCH) / (1.0 - SLIDE_IN - TOUCH), 2.0)
	var gap := lerpf(size.x * 0.3, 0.0, closeness)
	var center := size / 2.0
	_draw_phone(Vector2(center.x - gap / 2.0 - phone_size.x, center.y - phone_size.y / 2.0))
	_draw_phone(Vector2(center.x + gap / 2.0, center.y - phone_size.y / 2.0))
	if closeness >= 1.0:
		for i in 6:
			var direction := Vector2.from_angle(TAU * i / 6.0 + 0.4)
			draw_rect(Rect2(center + direction * 60.0 - Vector2(10, 10), Vector2(20, 20)), spark_color)


func _draw_phone(top_left: Vector2) -> void:
	var body := Rect2(top_left, phone_size)
	draw_rect(body.grow(outline), outline_color)
	draw_rect(body, color)
	draw_rect(Rect2(top_left + Vector2(14, 22), phone_size - Vector2(28, 56)), screen_color)
