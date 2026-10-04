class_name FollowCamera
extends Camera2D

## Trails a little behind `target`, like position smoothing, but can be jumped along
## with it (see `shift`) when the room wraps around.

@export var target: Node2D
## Higher catches up faster.
@export var follow_speed := 8.0


func _ready() -> void:
	top_level = true
	global_position = target.global_position


func _process(delta: float) -> void:
	global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))


func shift(offset: Vector2) -> void:
	global_position += offset
