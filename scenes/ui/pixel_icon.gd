extends Control

## A chunky pixel icon drawn from a little grid ("X" filled, "." empty), as big as fits
## in this control.

const HEART: PackedStringArray = [
	".X.X.",
	"XXXXX",
	".XXX.",
	"..X..",
]
const STAR: PackedStringArray = [
	"...X...",
	"..XXX..",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	".XX.XX.",
	".X...X.",
]

@export var pattern: PackedStringArray = HEART
@export var color := Color(0.95, 0.4, 0.55)
@export var outline_color := Color(0.1, 0.06, 0.08)
## Outline thickness, in screen pixels.
@export var outline := 5.0


func set_color(value: Color) -> void:
	color = value
	queue_redraw()


func _draw() -> void:
	var columns := pattern[0].length()
	var pixel := floorf(minf(size.x / columns, size.y / pattern.size()))
	var top_left := ((size - Vector2(columns, pattern.size()) * pixel) / 2.0).floor()
	for pass_color in [outline_color, color]:
		var grow := outline if pass_color == outline_color else 0.0
		for y in pattern.size():
			for x in columns:
				if pattern[y][x] == "X":
					draw_rect(Rect2(top_left + Vector2(x, y) * pixel, Vector2(pixel, pixel)).grow(grow), pass_color)
