extends Control

## While the waiter is fixing a date problem: what to do and the time left, above the guest.

@export var waiter: Node2D
@export var font_size := 34
@export var bar_size := Vector2(200, 16)
@export var color := Color(1, 0.85, 0.3)
@export var outline_color := Color(0.1, 0.06, 0.08)
## Above the guest, in world pixels.
@export var lift := 26.0
## Closest the text gets to the sides of the screen.
@export var edge_margin := 24.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Gone once fixed, so check before using it as a DateProblem.
	if not is_instance_valid(waiter.active_problem) or not waiter.active_problem.active:
		return
	var problem: DateProblem = waiter.active_problem
	var to_screen := get_viewport().canvas_transform
	var view_center := to_screen.affine_inverse() * get_viewport_rect().get_center()
	# Over whichever copy of the guest is on screen (the room repeats sideways).
	var spot := problem.global_position - Vector2(0, lift)
	var width: float = waiter.wrap_width
	if width > 0.0:
		spot.x += roundf((view_center.x - spot.x) / width) * width
	var at := to_screen * spot
	var font := get_theme_default_font()
	var text_width := font.get_string_size(problem.prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_at := at - Vector2(text_width / 2.0, bar_size.y + 8.0)
	# Kept on screen when the guest is near an edge.
	var view := get_viewport_rect()
	text_at.x = clampf(text_at.x, view.position.x + edge_margin, view.end.x - edge_margin - text_width)
	draw_string_outline(font, text_at, problem.prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 10, outline_color)
	draw_string(font, text_at, problem.prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	var bar := Rect2(at - Vector2(bar_size.x / 2.0, 0), bar_size)
	var left := clampf(problem.time_left / problem.time_limit, 0.0, 1.0)
	draw_rect(bar.grow(3), outline_color)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), color.lerp(Color(1, 0.3, 0.25), 1.0 - left))
