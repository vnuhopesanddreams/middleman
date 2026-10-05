extends CharacterBody2D


const SPEED = 250.0
## Speeding up, in pixels per second per second: full speed almost at once.
const ACCELERATION = 3000.0
## Slowing into a stop: about 20 pixels of braking from full speed.
const BRAKING = 1400.0
## Slowest the waiter goes while still on the way somewhere.
const MIN_WALK_SPEED = 30.0
## Roughly how far short of a tapped guest or table the waiter stops (it's used from
## arm's length), so the braking ends there rather than at its middle.
const TARGET_REACH = 12.0
const JUMP_VELOCITY = -400.0
const TRAIL_MAX_POINTS = 64
## Physics layer of the TapArea on guests and tables (layer 3).
const TAP_LAYER = 4
## From the body origin (sprite center) down to the feet, which is what walks the grid.
const FEET_OFFSET = Vector2(0, 8)
const TAP_RIPPLE = preload("res://scenes/ui/tap_ripple.gd")
## Ripple colour for a tap on a guest or table (white otherwise).
const TARGET_TAP_COLOR = Color(1, 0.85, 0.3)
## On-screen buttons in this group (like pause) keep touches on them to themselves: a
## touch reaches both the button and the game, and shouldn't also send the waiter there.
const TOUCH_BLOCKERS = "blocks_touch"
## How far a touch has to move (in screen pixels) before it counts as a drag, not a tap.
const DRAG_START = 30.0
## How far to drag for full speed; less goes slower.
const DRAG_FULL_SPEED = 120.0
## While steering (dragging or keys), the waiter leans into where he's going (at full speed sideways) and
## waddles a little; he swings back upright after.
const DRAG_LEAN = deg_to_rad(14.0)
const DRAG_WADDLE = deg_to_rad(4.0)
const WADDLE_SPEED = 18.0
## How quickly the lean follows (higher is snappier).
const LEAN_SPEED = 12.0
## From the sprite's middle down to the feet, which the lean pivots on.
const SPRITE_FEET = Vector2(0, 8)

@export var sprite_down: Texture2D
@export var sprite_up: Texture2D
@export var sprite_left: Texture2D
@export var sprite_right: Texture2D
## Used to find a way around tables when walking to a tap.
@export var walk_grid: WalkGrid
## Where people being led are kept meanwhile: outside the room, which is drawn again
## either side, so they aren't drawn twice.
@export var followers: Node2D

## What the waiter is carrying or leading (only people for now).
var held: Person
## The date problem being fixed right now. While its action is going, screen input goes
## to it instead of moving the waiter.
var active_problem: DateProblem
## How far apart the copies of a room that repeats sideways are (0 if it doesn't).
## Set by RoomRepeater.
var wrap_width := 0.0
## Recent positions, newest first, so followers can walk the same path.
var _trail: Array[Vector2] = []
## Feet positions still to walk through after a tap; empty when not walking.
var _path := PackedVector2Array()
## What was tapped, used as soon as it is in reach. Null when the floor was tapped.
var _tap_target: Node2D
## Current speed along a tap path.
var _walk_speed := 0.0
## Drag to move: the touch being followed (-1 for none), where it started on screen, and
## how far it has moved from there. Only a drag once it moves past DRAG_START.
var dragging := false
var drag_origin := Vector2.ZERO
var drag_offset := Vector2.ZERO
var _drag_index := -1
## Tapping the person being led lets go of them, but only once the finger lifts without
## dragging: they trail right behind the waiter, where a drag tends to start.
var _drop_on_release := false
var _waddle_time := 0.0

@onready var interact_area: Area2D = $InteractArea
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Pivot on the feet instead of the middle, so leaning tips him over rather than spinning.
	sprite.offset -= SPRITE_FEET
	sprite.position += SPRITE_FEET


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if held:
			_place_held()
		else:
			_interact_with_nearest()
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event is InputEventScreenTouch and event.pressed and _on_button(event.position):
			return
		var point: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if is_instance_valid(active_problem) and active_problem.active:
			if event is InputEventScreenTouch and event.pressed:
				_ripple(point, Color.WHITE)
			var near := _nearest_copy(point, active_problem.global_position)
			if active_problem.handle_input(event, near - active_problem.global_position):
				return
		if event is InputEventScreenTouch:
			if event.pressed:
				_start_touch(event.index, event.position)
				_on_tap(point)
			elif event.index == _drag_index:
				_end_touch()
		elif event.index == _drag_index:
			_move_touch(event.position)


func _on_button(at: Vector2) -> bool:
	for button: Control in get_tree().get_nodes_in_group(TOUCH_BLOCKERS):
		if button.is_visible_in_tree() and button.get_global_rect().has_point(at):
			return true
	return false


func _start_touch(index: int, at: Vector2) -> void:
	_drag_index = index
	drag_origin = at
	drag_offset = Vector2.ZERO
	dragging = false
	_drop_on_release = false


func _move_touch(at: Vector2) -> void:
	drag_offset = at - drag_origin
	if not dragging and drag_offset.length() > DRAG_START:
		# It was a drag after all: forget where the tap was sending the waiter.
		dragging = true
		_drop_on_release = false
		_stop_walking()


func _end_touch() -> void:
	if _drop_on_release and held:
		drop()
	_drop_on_release = false
	dragging = false
	drag_offset = Vector2.ZERO
	_drag_index = -1


## Starts the quick action that fixes a date problem (the guest has to be in reach).
func fix_problem(problem: DateProblem) -> void:
	_stop_walking()
	active_problem = problem
	problem.start()


func can_hold() -> bool:
	return held == null


func hold(person: Person) -> void:
	held = person
	_trail = [global_position, person.global_position]
	person.start_following(self, followers)


func drop() -> void:
	held.stop_following()
	held = null


func feet_position() -> Vector2:
	return global_position + FEET_OFFSET


## Moves the waiter, the path they're on and the trail their follower walks by
## `offset`, for when the room wraps around and they come out the other side.
func shift(offset: Vector2) -> void:
	global_position += offset
	for i in _trail.size():
		_trail[i] += offset
	for i in _path.size():
		_path[i] += offset


## Seats the held person at the nearest table, or drops them if no table is in reach.
func _place_held() -> void:
	var table := _nearest_body(func(body: Node2D) -> bool: return body is Table) as Table
	if table == null:
		drop()
	else:
		_place_held_at(table)


## At the wrong table nothing happens and the waiter keeps holding them.
func _place_held_at(table: Table) -> void:
	if table.try_seat(held):
		held = null


## Tapping a guest or table walks over and uses it, tapping the person being led lets
## go of them, and tapping the floor just walks there.
func _on_tap(point: Vector2) -> void:
	var tapped := _tapped_area(point)
	var target: Node2D = tapped[0].get_parent() if tapped else null
	_ripple(tapped[1] if tapped else point, TARGET_TAP_COLOR if target else Color.WHITE)
	if held and target == held:
		_drop_on_release = true
		_stop_walking()
		return
	_tap_target = target
	_path = walk_grid.find_path(feet_position(), tapped[1] if tapped else point, true)
	# On the floor, stop on the nearest open tile if the exact point is inside something.
	if target == null and not walk_grid.is_open(point) and _path.size() > 1:
		_path.remove_at(_path.size() - 1)


## The copy of `point` (the room repeats sideways) closest to `near`.
func _nearest_copy(point: Vector2, near: Vector2) -> Vector2:
	if wrap_width <= 0.0:
		return point
	return point + Vector2(roundf((near.x - point.x) / wrap_width) * wrap_width, 0)


func _ripple(point: Vector2, color: Color) -> void:
	var ripple := TAP_RIPPLE.new()
	ripple.color = color
	ripple.z_index = 10
	get_parent().add_child(ripple)
	ripple.global_position = point


## The tap area under the point (closest to it if several overlap) and where it was
## seen, as [area, position]. In a room that repeats sideways that can be one of its
## copies, some room-widths away. Empty if nothing was tapped.
func _tapped_area(point: Vector2) -> Array:
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = TAP_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var nearest := []
	var offsets := [0.0]
	if wrap_width > 0.0:
		# The copy the tap landed in, give or take one (things stick out of the room a bit).
		var copy := roundi((point.x - global_position.x) / wrap_width)
		offsets = [(copy - 1) * wrap_width, copy * wrap_width, (copy + 1) * wrap_width]
	for offset in offsets:
		query.position = point - Vector2(offset, 0)
		for hit in get_world_2d().direct_space_state.intersect_point(query):
			var seen_at: Vector2 = hit.collider.global_position + Vector2(offset, 0)
			if nearest.is_empty() or point.distance_to(seen_at) < point.distance_to(nearest[1]):
				nearest = [hit.collider, seen_at]
	return nearest


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
	var nearest_distance := INF
	for body in _bodies_in_reach():
		if not matches.call(body):
			continue
		var distance := global_position.distance_to(_nearest_copy(body.global_position, global_position))
		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance
	return nearest


## Bodies within arm's length. In a room that repeats sideways that includes across the
## seam: right by the edge, something can be next to the waiter on screen while really
## being a room-width away (the waiter is moved across at the edges, it isn't).
func _bodies_in_reach() -> Array[Node2D]:
	var reach: CollisionShape2D = interact_area.get_child(0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = reach.shape
	query.collision_mask = interact_area.collision_mask
	var found: Array[Node2D] = []
	for offset in [0.0, -wrap_width, wrap_width] if wrap_width > 0.0 else [0.0]:
		query.transform = reach.global_transform.translated(Vector2(offset, 0))
		for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
			if hit.collider != self and not found.has(hit.collider):
				found.append(hit.collider)
	return found


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# The keyboard always takes over from a tap.
	if input != Vector2.ZERO and (_tap_target or not _path.is_empty()):
		_stop_walking()

	if _tap_target or not _path.is_empty():
		_follow_path(delta)
	else:
		var wanted := input.normalized() * SPEED
		if dragging:
			wanted = drag_offset.normalized() * SPEED * minf(drag_offset.length() / DRAG_FULL_SPEED, 1.0)
		velocity = velocity.move_toward(wanted, (ACCELERATION if wanted != Vector2.ZERO else BRAKING) * delta)
		_update_facing(velocity)
		move_and_slide()
	_lean(delta, dragging or input != Vector2.ZERO)

	# Someone leaving (e.g. their date stormed out) slips out of the waiter's hands.
	if held and held.state == Person.State.LEAVING:
		held = null
	if held:
		_record_trail()


## Steps along the tap path, using the tapped thing once it is in reach. Like guests,
## this walks the grid directly instead of colliding: the grid already avoids tables,
## and the waiter's body is wider than the gaps it leaves.
func _follow_path(delta: float) -> void:
	if _tap_target and not is_instance_valid(_tap_target):
		_stop_walking()
		return
	if _tap_target and _bodies_in_reach().has(_tap_target):
		_use_tap_target()
		return
	if _path.is_empty():
		# As close as the grid gets, and still out of reach.
		_stop_walking()
		return

	# Off fast, then brake over the last stretch instead of stopping dead.
	var remaining := _path_length()
	if _tap_target:
		remaining = maxf(remaining - TARGET_REACH, 0.0)
	var top_speed := clampf(sqrt(2.0 * BRAKING * remaining), MIN_WALK_SPEED, SPEED)
	_walk_speed = move_toward(_walk_speed, top_speed, ACCELERATION * delta)

	# Corners don't cost a stop: leftover distance carries on to the next point.
	var step := _walk_speed * delta
	while step > 0.0 and not _path.is_empty():
		var next := _path[0] - FEET_OFFSET
		var distance := global_position.distance_to(next)
		if distance <= step:
			global_position = next
			_path.remove_at(0)
			step -= distance
		else:
			_update_facing(next - global_position)
			global_position = global_position.move_toward(next, step)
			step = 0.0


## How far is left to walk along the tap path.
func _path_length() -> float:
	var length := 0.0
	var from := feet_position()
	for point in _path:
		length += from.distance_to(point)
		from = point
	return length


func _use_tap_target() -> void:
	var target := _tap_target
	_stop_walking()
	if held and target is Table:
		_place_held_at(target)
	elif target.has_method("interact"):
		target.interact(self)


func _stop_walking() -> void:
	_path.clear()
	_tap_target = null
	_walk_speed = 0.0
	velocity = Vector2.ZERO


## Leans into the direction of a drag or keyboard move.
func _lean(delta: float, steering: bool) -> void:
	var target := 0.0
	if steering:
		var speed := velocity.length() / SPEED
		_waddle_time += delta * WADDLE_SPEED * speed
		target = velocity.x / SPEED * DRAG_LEAN + sin(_waddle_time) * DRAG_WADDLE * speed
	sprite.rotation = lerp_angle(sprite.rotation, target, 1.0 - exp(-LEAN_SPEED * delta))


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
