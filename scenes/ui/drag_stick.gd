extends Control

## While dragging to move: a faint square where the drag started and a knob under the
## finger, like a joystick that appears wherever the thumb goes down.

@export var waiter: Node2D
@export var color := Color(1, 1, 1, 0.35)
## Half the knob's width.
@export var knob_size := 34.0
@export var outline := 6.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not waiter.dragging or not Settings.show_drag_stick:
		return
	var reach: float = waiter.DRAG_FULL_SPEED
	var offset: Vector2 = waiter.drag_offset.limit_length(reach)
	draw_rect(Rect2(waiter.drag_origin - Vector2.ONE * reach, Vector2.ONE * reach * 2.0), color, false, outline)
	draw_rect(Rect2(waiter.drag_origin + offset - Vector2.ONE * knob_size, Vector2.ONE * knob_size * 2.0), color)
