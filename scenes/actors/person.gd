class_name Person
extends CharacterBody2D

signal picked_up
## Let go of before reaching their table (see `walk_back`).
signal dropped
signal seated
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
## Worn while the waiter is leading them (same gold as the ring around their table).
const HELD_COLOR = Color(1.0, 0.85, 0.3)
## Worn while waiting at the door to be seated.
const UNSEATED_COLOR = Color(0.62, 0.62, 0.66)
## Worn leaving after a date that went well (same pink as the hearts).
const HAPPY_COLOR = Color(1.0, 0.72, 0.82)
## Pulsed toward while something is going wrong for them that the waiter hasn't
## started fixing yet.
const PROBLEM_COLOR = Color(1.0, 0.5, 0.05)
## Pulsed toward while their date is troubled and close to falling apart, and worn when
## they storm out.
const ANGRY_COLOR = Color(1.0, 0.25, 0.2)
## Below this much happiness (out of 100) a troubled date counts as close to falling apart.
const DANGER_HAPPINESS = 30.0
const PULSE_SPEED = 8.0
## Dark edge around the "!" over someone with a problem.
const MARK_OUTLINE = Color(0.1, 0.06, 0.08)
## Waiting (at the door, or alone at the table for their date): they start sweating
## after a while, more and more until full at SWEAT_FULL (when a lonely guest's meter
## starts draining).
const SWEAT_AFTER = 3.0
const SWEAT_FULL = 10.0
const MAX_SWEAT_DROPS = 6
const SWEAT_COLOR = Color(0.55, 0.8, 1.0)
## Left waiting at the door this long (not counting while being led), they give up and
## storm out with their whole party, which costs a heart like any angry table. They
## pulse red as a warning from DOOR_ANGRY_AFTER.
const DOOR_PATIENCE = 25.0
const DOOR_ANGRY_AFTER = 17.0
## Walking in: how long the fade-in takes, and how small they start.
const APPEAR_TIME = 0.4
const APPEAR_SCALE = 0.5

var couple: Couple
var state := State.WAITING
var leader: Node2D
var seat: Seat
## Where they were before being led, to go back to when that ends.
var _home: Node
## Left because the date went wrong.
var _stormed_out := false

var _facing := Vector2.DOWN
var _moving := false
var _animation_time := 0.0
var _path := PackedVector2Array()
## How long they've been kept waiting this time.
var _wait_time := 0.0
## How long they've spent waiting at the door in all (see DOOR_PATIENCE).
var _door_time := 0.0
## How bad things are for them, to sound it when it gets worse (see `_mood_level`).
var _mood := 0
## Draws the sweat, over the sprite (this node's own drawing goes under it).
var _sweat := Node2D.new()

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_child(_sweat)
	_sweat.draw.connect(_draw_sweat)


## Waiting: the waiter takes them. Seated: the waiter fixes what's wrong with them, or
## if nothing is, it's the same as visiting their table.
func interact(waiter: Node2D) -> void:
	if state == State.WAITING and waiter.can_hold():
		waiter.hold(self)
	elif state == State.SEATED and couple:
		var problem := current_problem()
		if problem:
			waiter.fix_problem(problem)
		else:
			couple.cheer_up()


## What's going wrong for them on their date right now, if anything.
func current_problem() -> DateProblem:
	for child in get_children():
		if child is DateProblem and not child.is_queued_for_deletion():
			return child
	return null


## `holder` is where they are kept while following (see the waiter's `followers`).
func start_following(new_leader: Node2D, holder: Node) -> void:
	leader = new_leader
	state = State.FOLLOWING
	_path.clear()
	_home = get_parent()
	reparent(holder)
	_set_table_highlighted(true)
	picked_up.emit()


func stop_following() -> void:
	Sfx.play("drop")
	_stop(State.WAITING)
	dropped.emit()


## Walks the given path (feet positions) while still waiting, e.g. back to their spot at
## the door after being dropped.
func walk_back(path: PackedVector2Array) -> void:
	_path = path


func sit(new_seat: Seat) -> void:
	_stop(State.SEATED)
	seat = new_seat
	Sfx.play("seat")
	global_position = seat.global_position
	_facing = seat.facing
	seated.emit()


func feet_position() -> Vector2:
	return global_position + FEET_OFFSET


## Walks the given path (feet positions) and disappears at the end of it.
## Works from any state (waiting, held or seated). `stormed_out` turns them red.
func leave(path: PackedVector2Array, stormed_out := false) -> void:
	_stop(State.LEAVING)
	_stormed_out = stormed_out
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
	if _home:
		reparent(_home)
		_home = null
	_moving = false


## Shows the ring around this person's table, once their couple has one.
func _set_table_highlighted(highlighted: bool) -> void:
	if couple and couple.table:
		couple.table.set_highlighted(highlighted)


func _physics_process(delta: float) -> void:
	match state:
		State.FOLLOWING:
			_move_to(leader.trail_point(FOLLOW_DISTANCE))
		State.WAITING:
			if not _path.is_empty():
				_walk_path(delta)
		State.LEAVING:
			_walk_path(delta)


## Walks point to point along _path. Someone leaving fades out at the end of it.
func _walk_path(delta: float) -> void:
	if _path.is_empty():
		_moving = false
		if state == State.LEAVING:
			set_physics_process(false)
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
	_wait_time = _wait_time + delta if is_waiting() else 0.0
	if state == State.WAITING:
		_door_time += delta
		if _door_time >= DOOR_PATIENCE and couple:
			get_tree().call_group("popups", "pop", "HMPH!", global_position - Vector2(0, 18), ANGRY_COLOR)
			couple.storm_out()
	_sweat.queue_redraw()
	var row := WALK_ROW if _moving else IDLE_ROW
	var column: int = FACING_COLUMN[Vector2.RIGHT if _facing == Vector2.LEFT else _facing]
	column += int(_animation_time * ANIMATION_FPS) % FRAMES_PER_STRIP
	sprite.frame = row * SHEET_COLUMNS + column
	sprite.flip_h = _facing == Vector2.LEFT
	sprite.modulate = _tint()
	queue_redraw()
	var mood := _mood_level()
	if mood > _mood:
		Sfx.play("worse")
	_mood = mood


## 0 fine, 1 a problem on their date, 2 close to storming out (the same cues as
## `_tint`). Sweating while waiting doesn't count: it comes on too often to sound.
func _mood_level() -> int:
	if state == State.LEAVING:
		return 0
	if (couple and couple.troubled and couple.happiness < DANGER_HAPPINESS) \
			or (state == State.WAITING and _door_time > DOOR_ANGRY_AFTER):
		return 2
	if current_problem():
		return 1
	return 0


## Colour cues, most important first: red storming out, gold being led, red pulsing
## close to storming out (a troubled date, or fed up at the door), orange with a problem to fix, pink leaving happy, gray waiting
## at the door.
func _tint() -> Color:
	var pulse := 0.5 + 0.5 * sin(_animation_time * PULSE_SPEED)
	if _stormed_out:
		return ANGRY_COLOR
	if state == State.FOLLOWING:
		return HELD_COLOR
	if (couple and couple.troubled and couple.happiness < DANGER_HAPPINESS) \
			or (state == State.WAITING and _door_time > DOOR_ANGRY_AFTER):
		return Color.WHITE.lerp(ANGRY_COLOR, 0.4 + 0.6 * pulse)
	var problem := current_problem()
	if problem and not problem.active:
		return Color.WHITE.lerp(PROBLEM_COLOR, 0.55 + 0.45 * pulse)
	if state == State.LEAVING:
		return HAPPY_COLOR
	if state != State.SEATED:
		return UNSEATED_COLOR
	return Color.WHITE


## Fades in and pops up to full size, for walking in the door.
func appear() -> void:
	modulate.a = 0.0
	sprite.scale = Vector2.ONE * APPEAR_SCALE
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, APPEAR_TIME)
	tween.tween_property(sprite, "scale", Vector2.ONE, APPEAR_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## At the door to be seated, or seated with their date not there yet.
func is_waiting() -> bool:
	if state == State.WAITING:
		return true
	return state == State.SEATED and couple != null and not couple.is_seated()


## Drops flicking off both sides of the head, more the longer they've waited.
func _draw_sweat() -> void:
	var amount := clampf((_wait_time - SWEAT_AFTER) / (SWEAT_FULL - SWEAT_AFTER), 0.0, 1.0)
	if amount <= 0.0:
		return
	var drops := ceili(amount * MAX_SWEAT_DROPS)
	var speed := 1.0 + amount
	for i in drops:
		var t := fmod(_animation_time * speed + float(i) / drops, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		# From the side of the head, arcing out and falling.
		var at := Vector2(side * (4.0 + t * 8.0), -8.0 - sin(t * PI) * 4.0 + t * 7.0)
		var fade := 1.0 - t * t
		_sweat.draw_circle(at, 1.9, Color(MARK_OUTLINE, fade))
		_sweat.draw_circle(at, 1.3, Color(SWEAT_COLOR, fade))


## A bouncing "!" over someone with a problem nobody's fixing yet.
func _draw() -> void:
	var problem := current_problem()
	if problem == null or problem.active:
		return
	var top := Vector2(0, -24 - absf(sin(_animation_time * 5.0)) * 3.0)
	for pass_color in [MARK_OUTLINE, PROBLEM_COLOR]:
		var grow := 1.0 if pass_color == MARK_OUTLINE else 0.0
		draw_rect(Rect2(top + Vector2(-1, 0), Vector2(2, 5)).grow(grow), pass_color)
		draw_rect(Rect2(top + Vector2(-1, 6), Vector2(2, 2)).grow(grow), pass_color)


func _direction_of(step: Vector2) -> Vector2:
	if absf(step.x) > absf(step.y):
		return Vector2.RIGHT if step.x > 0 else Vector2.LEFT
	return Vector2.DOWN if step.y > 0 else Vector2.UP
