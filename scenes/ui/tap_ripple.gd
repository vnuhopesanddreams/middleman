extends Node2D

## A ring spreading out where the screen was tapped, so every tap gets an answer.

const LIFETIME = 0.3

var color := Color.WHITE

var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	draw_arc(Vector2.ZERO, 3.0 + t * 7.0, 0.0, TAU, 24, Color(color, 1.0 - t), 1.0)
