extends Control

## The fireworks behind the bump screen once a bump goes through: a white flash, a ring
## shooting out, a burst of pixel hearts and stars that fall away, and then hearts
## drifting up the screen for as long as it's showing. Doesn't take any touches.

const HEART: PackedStringArray = [
	".X.X.",
	"XXXXX",
	".XXX.",
	"..X..",
]
const STAR: PackedStringArray = [
	"..X..",
	".XXX.",
	"XXXXX",
	".X.X.",
]
const SQUARE: PackedStringArray = ["XX", "XX"]
const SHAPES: Array[PackedStringArray] = [HEART, HEART, STAR, SQUARE]
const COLORS: Array[Color] = [
	Color(1, 0.85, 0.3),
	Color(0.95, 0.4, 0.55),
	Color(1.0, 0.62, 0.72),
	Color(0.45, 0.8, 1.0),
	Color(1, 1, 1),
]
const OUTLINE_COLOR = Color(0.1, 0.06, 0.08)

const FLASH_TIME = 0.35
const RING_TIME = 0.55
const RING_RADIUS = 900.0
const RING_COLOR = Color(1, 0.85, 0.3)
const GRAVITY = 1600.0
## Pieces of a burst: how many, how fast they fly out, how long they last.
const BURST_SPEED_MIN = 500.0
const BURST_SPEED_MAX = 1500.0
const BURST_LIFE_MIN = 0.9
const BURST_LIFE_MAX = 1.6
## Hearts drifting up afterwards: one every this many seconds.
const DRIFT_EVERY = 0.22
const DRIFT_SPEED_MIN = 120.0
const DRIFT_SPEED_MAX = 240.0
const DRIFT_ALPHA = 0.45

## One per flying piece: where it is, its velocity, shape, colour, pixel size, age and
## lifetime, and whether gravity pulls it (drifting hearts float up instead).
var _pieces: Array[Dictionary] = []
var _flash := 0.0
## Rings shooting out: centre and age.
var _rings: Array[Dictionary] = []
var _drifting := false
var _drift_countdown := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## The big moment: flash, ring and burst from `at` (in this control's coordinates).
func celebrate(at: Vector2) -> void:
	_flash = 1.0
	burst(at, 70)
	_drifting = true


## A spray of pieces and a ring from `at`.
func burst(at: Vector2, count: int) -> void:
	_rings.append({"at": at, "age": 0.0})
	for i in count:
		var direction := Vector2.from_angle(randf() * TAU)
		# Mostly upward, so they arc out before falling.
		direction.y -= 0.6
		_pieces.append({
			"at": at,
			"velocity": direction.normalized() * randf_range(BURST_SPEED_MIN, BURST_SPEED_MAX),
			"shape": SHAPES.pick_random(),
			"color": COLORS.pick_random(),
			"pixel": randf_range(7.0, 13.0),
			"age": 0.0,
			"life": randf_range(BURST_LIFE_MIN, BURST_LIFE_MAX),
			"falls": true,
		})


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	for ring in _rings:
		ring.age += delta
	_rings = _rings.filter(func(ring: Dictionary) -> bool: return ring.age < RING_TIME)
	for piece in _pieces:
		piece.age += delta
		if piece.falls:
			piece.velocity.y += GRAVITY * delta
		piece.at += piece.velocity * delta
	_pieces = _pieces.filter(func(piece: Dictionary) -> bool: return piece.age < piece.life)
	if _drifting:
		_drift_countdown -= delta
		if _drift_countdown <= 0.0:
			_drift_countdown = DRIFT_EVERY
			_add_drifting_heart()
	queue_redraw()


func _add_drifting_heart() -> void:
	var speed := randf_range(DRIFT_SPEED_MIN, DRIFT_SPEED_MAX)
	_pieces.append({
		"at": Vector2(randf() * size.x, size.y + 40.0),
		"velocity": Vector2(randf_range(-30.0, 30.0), -speed),
		"shape": HEART,
		"color": Color(COLORS[1 + randi() % 2], DRIFT_ALPHA),
		"pixel": randf_range(6.0, 10.0),
		"age": 0.0,
		"life": (size.y + 80.0) / speed,
		"falls": false,
	})


func _draw() -> void:
	for ring in _rings:
		var t: float = ring.age / RING_TIME
		var radius := RING_RADIUS * ease(t, 0.3)
		draw_arc(ring.at, radius, 0.0, TAU, 64, Color(RING_COLOR, 1.0 - t), lerpf(40.0, 4.0, t))
	for piece in _pieces:
		var t: float = piece.age / piece.life
		# Burst pieces fade out over their last third; drifting ones keep their alpha.
		var alpha := 1.0 if not piece.falls or t < 0.66 else (1.0 - t) / 0.34
		_draw_shape(piece.shape, piece.at, piece.pixel, piece.color, alpha)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash * 0.85))


func _draw_shape(shape: PackedStringArray, center: Vector2, pixel: float, color: Color, alpha: float) -> void:
	var top_left := (center - Vector2(shape[0].length(), shape.size()) * pixel / 2.0).round()
	for is_outline in [true, false]:
		var pass_color := Color(OUTLINE_COLOR if is_outline else color, color.a * alpha)
		var grow := 3.0 if is_outline else 0.0
		for y in shape.size():
			for x in shape[y].length():
				if shape[y][x] == "X":
					draw_rect(Rect2(top_left + Vector2(x, y) * pixel, Vector2(pixel, pixel)).grow(grow), pass_color)
