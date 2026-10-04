class_name Seat
extends Marker2D

## Which way someone sitting here looks (toward the table).
@export var facing := Vector2.RIGHT

var occupant: Person


func is_free() -> bool:
	return occupant == null
