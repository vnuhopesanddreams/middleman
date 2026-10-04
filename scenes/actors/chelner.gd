extends CharacterBody2D


const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const TRAIL_MAX_POINTS = 64

@export var sprite_down: Texture2D
@export var sprite_up: Texture2D
@export var sprite_left: Texture2D
@export var sprite_right: Texture2D

## What the waiter is carrying or leading (only people for now).
var held: Person
## Recent positions, newest first, so followers can walk the same path.
var _trail: Array[Vector2] = []

@onready var interact_area: Area2D = $InteractArea
@onready var sprite: Sprite2D = $Sprite2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if held:
			_place_held()
		else:
			_interact_with_nearest()


func can_hold() -> bool:
	return held == null


func hold(person: Person) -> void:
	held = person
	_trail = [global_position, person.global_position]
	person.start_following(self)


func drop() -> void:
	held.stop_following()
	held = null


## Seats the held person at the nearest table, or drops them if no table is in reach.
## At the wrong table nothing happens and the waiter keeps holding them.
func _place_held() -> void:
	var table := _nearest_body(func(body: Node2D) -> bool: return body is Table) as Table
	if table == null:
		drop()
	elif table.try_seat(held):
		held = null


## The point `distance` behind the waiter, measured along the path walked.
func trail_point(distance: float) -> Vector2:
	var remaining := distance
	for i in range(1, _trail.size()):
		var segment := _trail[i - 1].distance_to(_trail[i])
		if segment >= remaining:
			return _trail[i - 1].move_toward(_trail[i], remaining)
		remaining -= segment
	return _trail[-1]


func _interact_with_nearest() -> void:
	var nearest := _nearest_body(func(body: Node2D) -> bool: return body.has_method("interact"))
	if nearest:
		nearest.interact(self)


func _nearest_body(matches: Callable) -> Node2D:
	var nearest: Node2D = null
	for body in interact_area.get_overlapping_bodies():
		if not matches.call(body):
			continue
		if nearest == null or global_position.distance_to(body.global_position) < global_position.distance_to(nearest.global_position):
			nearest = body
	return nearest


func _physics_process(delta: float) -> void:
	var vdirection := Input.get_axis("ui_left", "ui_right")
	if vdirection:
		velocity.x = vdirection * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	var hdirection := Input.get_axis("ui_up", "ui_down")
	if hdirection:
		velocity.y = hdirection * SPEED
	else:
		velocity.y = move_toward(velocity.y, 0, SPEED)

	_update_facing(Vector2(vdirection, hdirection))

	move_and_slide()
	# Someone leaving (e.g. their date stormed out) slips out of the waiter's hands.
	if held and held.state == Person.State.LEAVING:
		held = null
	if held:
		_record_trail()


## Swaps to the sprite for the direction being walked; keeps the last one when standing still.
func _update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if absf(direction.x) > absf(direction.y):
		sprite.texture = sprite_right if direction.x > 0 else sprite_left
	else:
		sprite.texture = sprite_down if direction.y > 0 else sprite_up


func _record_trail() -> void:
	if not _trail.is_empty() and global_position.distance_to(_trail[0]) < 1.0:
		return
	_trail.push_front(global_position)
	if _trail.size() > TRAIL_MAX_POINTS:
		_trail.pop_back()
