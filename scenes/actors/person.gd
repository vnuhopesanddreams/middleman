class_name Person
extends CharacterBody2D

signal picked_up
signal leaving

enum State { WAITING, FOLLOWING, SEATED, LEAVING }

const SHEET_COLUMNS = 35
const IDLE_ROW = 1
const WALK_ROW = 2
## First column of each facing's 4-frame strip. Left reuses RIGHT, flipped.
const FACING_COLUMN = { Vector2.DOWN: 0, Vector2.RIGHT: 8, Vector2.UP: 16 }
const FRAMES_PER_STRIP = 4
const ANIMATION_FPS = 8.0
## How far behind the waiter (along their path) a follower walks.
const FOLLOW_DISTANCE = 14.0
const LEAVE_SPEED = 40.0
## From the body origin (sprite center) down to the feet, which is what walks the grid.
const FEET_OFFSET = Vector2(0, 10)

var couple: Couple
var state := State.WAITING
var leader: Node2D
var seat: Seat

var _facing := Vector2.DOWN
var _moving := false
var _animation_time := 0.0
var _path := PackedVector2Array()

@onready var sprite: Sprite2D = $Sprite2D


func interact(waiter: Node2D) -> void:
	if state == State.WAITING and waiter.can_hold():
		waiter.hold(self)


func start_following(new_leader: Node2D) -> void:
	leader = new_leader
	state = State.FOLLOWING
	_set_table_highlighted(true)
	picked_up.emit()


func stop_following() -> void:
	_stop(State.WAITING)


func sit(new_seat: Seat) -> void:
	_stop(State.SEATED)
	seat = new_seat
	global_position = seat.global_position
	_facing = seat.facing


func feet_position() -> Vector2:
	return global_position + FEET_OFFSET


## Walks the given path (feet positions) and disappears at the end of it.
## Works from any state (waiting, held or seated).
func leave(path: PackedVector2Array) -> void:
	_stop(State.LEAVING)
	if seat:
		seat.occupant = null
		seat = null
	couple = null
	_path = path
	leaving.emit()


func _stop(new_state: State) -> void:
	_set_table_highlighted(false)
	leader = null
	state = new_state
	_moving = false


## Shows the ring around this person's table, once their couple has one.
func _set_table_highlighted(highlighted: bool) -> void:
	if couple and couple.table:
		couple.table.set_highlighted(highlighted)


func _physics_process(delta: float) -> void:
	match state:
		State.FOLLOWING:
			_move_to(leader.trail_point(FOLLOW_DISTANCE))
		State.LEAVING:
			_walk_path(delta)


## Walks point to point along _path, then fades out.
func _walk_path(delta: float) -> void:
	if _path.is_empty():
		set_physics_process(false)
		_moving = false
		create_tween().tween_property(self, "modulate:a", 0.0, 0.3).finished.connect(queue_free)
		return
	var target := _path[0] - FEET_OFFSET
	_move_to(global_position.move_toward(target, LEAVE_SPEED * delta))
	if global_position == target:
		_path.remove_at(0)


func _move_to(target: Vector2) -> void:
	var step := target - global_position
	_moving = step.length() > 0.1
	if _moving:
		_facing = _direction_of(step)
	global_position = target


func _process(delta: float) -> void:
	_animation_time += delta
	var row := WALK_ROW if _moving else IDLE_ROW
	var column: int = FACING_COLUMN[Vector2.RIGHT if _facing == Vector2.LEFT else _facing]
	column += int(_animation_time * ANIMATION_FPS) % FRAMES_PER_STRIP
	sprite.frame = row * SHEET_COLUMNS + column
	sprite.flip_h = _facing == Vector2.LEFT


func _direction_of(step: Vector2) -> Vector2:
	if absf(step.x) > absf(step.y):
		return Vector2.RIGHT if step.x > 0 else Vector2.LEFT
	return Vector2.DOWN if step.y > 0 else Vector2.UP
