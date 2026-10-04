extends Node2D

## Little pixel hearts floating up and fading, for a date that went well. Frees itself
## once they're gone.

const HEART: Array[String] = [
	".X.X.",
	"XXXXX",
	".XXX.",
	"..X..",
]
const COUNT = 10
const COLORS: Array[Color] = [Color(0.95, 0.4, 0.55), Color(1.0, 0.62, 0.72), Color(0.88, 0.25, 0.42)]
## Hearts start fading this far through their life.
const FADE_FROM = 0.6

## One per heart: where it starts, how fast it rises, how it sways, when it starts and
## how long it lasts, its colour and its pixel size.
var _hearts: Array[Dictionary] = []
var _age := 0.0
var _duration := 0.0


func _ready() -> void:
	for i in COUNT:
		var heart := {
			"start": Vector2(randf_range(-16.0, 16.0), randf_range(-4.0, 4.0)),
			"speed": randf_range(14.0, 26.0),
			"sway": randf_range(2.0, 5.0),
			"phase": randf() * TAU,
			"delay": randf_range(0.0, 0.5),
			"life": randf_range(1.0, 1.6),
			"color": COLORS.pick_random(),
			"size": 2.0 if randf() < 0.3 else 1.0,
		}
		_hearts.append(heart)
		_duration = maxf(_duration, heart.delay + heart.life)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	for heart in _hearts:
		var alive: float = _age - heart.delay
		var t: float = alive / heart.life
		if t < 0.0 or t > 1.0:
			continue
		var sway: float = sin(t * TAU + heart.phase) * heart.sway
		var at: Vector2 = heart.start + Vector2(sway, -heart.speed * alive)
		var alpha := 1.0 if t < FADE_FROM else 1.0 - (t - FADE_FROM) / (1.0 - FADE_FROM)
		_draw_heart(at.round(), heart.size, Color(heart.color, alpha))


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	var top_left := center - Vector2(2.5, 2.0) * size
	for y in HEART.size():
		for x in HEART[y].length():
			if HEART[y][x] == "X":
				draw_rect(Rect2(top_left + Vector2(x, y) * size, Vector2(size, size)), color)
