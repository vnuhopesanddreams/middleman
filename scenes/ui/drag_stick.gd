extends Control

## While dragging to move: a faint ring where the drag started and a knob under the
## finger, like a joystick that appears wherever the thumb goes down.

@export var waiter: Node2D
@export var color := Color(1, 1, 1, 0.35)
@export var knob_radius := 34.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not waiter.dragging:
		return
	var reach: float = waiter.DRAG_FULL_SPEED
	var offset: Vector2 = waiter.drag_offset.limit_length(reach)
	draw_arc(waiter.drag_origin, reach, 0.0, TAU, 48, color, 6.0, true)
	draw_circle(waiter.drag_origin + offset, knob_radius, color)
