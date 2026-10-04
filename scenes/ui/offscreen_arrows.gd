extends Control

## Points from the screen edge toward guests waiting to be picked up who are off screen,
## the shortest way round (the room repeats sideways).

@export var people: Node2D
## Its `wrap_width` says how far apart the room's sideways copies are.
@export var waiter: Node2D
## Gap between the arrows and the screen edge.
@export var margin := 100.0
@export var arrow_size := 64.0
## Same gold as the ring around a guest's table.
@export var color := Color(1, 0.85, 0.3)
@export var outline_color := Color(0.1, 0.06, 0.08)

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.12 * sin(_time * 6.0)
	for arrow in arrows():
		var tip: Vector2 = arrow[0]
		var direction: Vector2 = arrow[1]
		_draw_arrow(tip, direction, arrow_size * pulse)


## One [tip position, direction] per off-screen waiting guest, in screen coordinates.
func arrows() -> Array:
	var to_screen := get_viewport().canvas_transform
	var view := get_viewport_rect()
	var center := view.get_center()
	var half := view.size / 2.0 - Vector2(margin, margin)
	var result := []
	for person in people.get_children():
		if not (person is Person and person.state == Person.State.WAITING):
			continue
		var point := to_screen * _nearest_copy(person.global_position, to_screen.affine_inverse() * center)
		if view.has_point(point):
			continue
		var direction := center.direction_to(point)
		# Where the line from the middle of the screen toward them meets the edge area.
		var reach := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
		result.append([center + direction * reach, direction])
	return result


## The copy of `point` closest to `near` sideways.
func _nearest_copy(point: Vector2, near: Vector2) -> Vector2:
	var width: float = waiter.wrap_width
	if width <= 0.0:
		return point
	return point + Vector2(roundf((near.x - point.x) / width) * width, 0)


## A head and a shaft behind it; a head alone reads like a mouse cursor at some angles.
func _draw_arrow(tip: Vector2, direction: Vector2, length: float) -> void:
	var across := direction.orthogonal()
	var head_base := tip - direction * length * 0.55
	var tail := tip - direction * length * 1.3
	var head := across * length * 0.45
	var shaft := across * length * 0.16
	var points := PackedVector2Array([
		tip, head_base + head, head_base + shaft, tail + shaft,
		tail - shaft, head_base - shaft, head_base - head,
	])
	draw_colored_polygon(points, color)
	points.append(tip)
	draw_polyline(points, outline_color, 5.0, true)
