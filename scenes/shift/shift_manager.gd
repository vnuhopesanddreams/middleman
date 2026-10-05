class_name ShiftManager
extends Node

## Runs the workday: decides who arrives next and which table each couple gets, keeps
## the clock and the hearts, and ends the shift when either runs out.

signal points_changed(total: int)
## Someone walked in. `is_date` is true when they're the second half of a couple whose
## first half is already here.
signal guest_arrived(person: Person, is_date: bool)
signal lives_changed(lives: int)
## The shift is over: `survived` is true when time ran out, false when every heart was lost.
signal shift_over(survived: bool)

@export var person_scene: PackedScene
## Where spawned people are added (should have Y Sort enabled).
@export var people: Node2D
## Each Marker2D child of this node is one waiting spot at the entrance.
@export var entrance: Node2D
## Where people walk to when they leave (they fade out there). Must be reachable.
@export var exit: Marker2D
@export var walk_grid: WalkGrid

## Time between arrivals. Each arrival is either a new couple's first person or
## the missing partner of any couple still waiting, picked at random.
@export var arrival_interval_min := 5.0
@export var arrival_interval_max := 9.0
@export var max_couples := 5
## The shift opens empty; the first guest walks in after this many seconds.
@export var first_arrival_delay := 3.0
## How long a shift lasts, in seconds.
@export var shift_length := 180.0
## Hearts at the start. A table that leaves angry costs one; losing them all ends the shift.
@export var max_lives := 3

var tables: Array[Table] = []
var couples: Array[Couple] = []
## Marker2D -> Person standing on it, or null when free.
var spot_occupants := {}
var points := 0
var time_left := 0.0
var lives := 0
var is_over := false

var _arrival_countdown := 0.0


func _ready() -> void:
	set_process(false)
	# Wait a frame so every table in the scene has finished setting up.
	await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("tables"):
		tables.append(node)
	for spot in entrance.get_children():
		if spot is Marker2D:
			spot_occupants[spot] = null

	_arrival_countdown = first_arrival_delay
	set_process(true)
	Music.fade_out()


func _enter_tree() -> void:
	time_left = shift_length
	lives = max_lives


func _process(delta: float) -> void:
	if is_over:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_end_shift(true)
		return
	_arrival_countdown -= delta
	# If nobody can arrive right now (entrance full, nothing to do), retry next frame.
	if _arrival_countdown <= 0.0 and _spawn_random_arrival():
		_reset_arrival_countdown()


## Frees the entrance spot a person was waiting on (once they're seated, or leave).
func release_spot(person: Person) -> void:
	for spot in spot_occupants:
		if spot_occupants[spot] == person:
			spot_occupants[spot] = null


func _spawn_random_arrival() -> bool:
	if _free_spot() == null:
		return false

	var options: Array[Callable] = []
	for couple in couples:
		if not couple.is_complete():
			options.append(_spawn_person.bind(couple))
	if couples.size() < max_couples:
		var table := _random_free_table()
		if table:
			options.append(_start_couple.bind(table))

	if options.is_empty():
		return false
	return options.pick_random().call()


func _start_couple(table: Table) -> bool:
	var couple := Couple.new()
	add_child(couple)
	couples.append(couple)
	table.assign_couple(couple)
	couple.ended.connect(_on_couple_ended.bind(couple))
	return _spawn_person(couple)


func _spawn_person(couple: Couple) -> bool:
	var spot := _free_spot()
	if spot == null:
		return false

	var person: Person = person_scene.instantiate()
	people.add_child(person)
	person.global_position = spot.global_position
	# The spot stays theirs until they sit down (or leave), so a guest who's dropped
	# along the way has somewhere to go back to.
	person.seated.connect(release_spot.bind(person))
	person.leaving.connect(release_spot.bind(person))
	person.dropped.connect(_send_back_to_spot.bind(person))
	spot_occupants[spot] = person
	couple.add_person(person)
	person.appear()
	guest_arrived.emit(person, couple.people.size() > 1)
	return true


func _on_couple_ended(finished: bool, couple: Couple) -> void:
	if finished:
		var earned := roundi(couple.happiness)
		points += earned
		points_changed.emit(points)
		couple.table.celebrate()
		get_tree().call_group("popups", "pop", "+%d" % earned, couple.table.heart_spot())
		get_tree().call_group("camera", "punch", 0.04)
	elif not is_over:
		lives -= 1
		lives_changed.emit(lives)
		get_tree().call_group("camera", "shake", 5.0)
		if lives <= 0:
			_end_shift(false)
	couples.erase(couple)
	couple.table.release()
	for person in couple.people:
		person.leave(walk_grid.find_path(person.feet_position(), exit.global_position), not finished)
	couple.queue_free()


## A guest let go of before their table walks back to their spot at the door.
func _send_back_to_spot(person: Person) -> void:
	for spot in spot_occupants:
		if spot_occupants[spot] == person:
			person.walk_back(walk_grid.find_path(person.feet_position(), spot.global_position + Person.FEET_OFFSET))
			return


func _end_shift(survived: bool) -> void:
	is_over = true
	shift_over.emit(survived)


func _reset_arrival_countdown() -> void:
	_arrival_countdown = randf_range(arrival_interval_min, arrival_interval_max)


func _random_free_table() -> Table:
	var free_tables := tables.filter(func(table: Table) -> bool: return table.is_free())
	if free_tables.is_empty():
		return null
	return free_tables.pick_random()


func _free_spot() -> Marker2D:
	for spot in spot_occupants:
		if spot_occupants[spot] == null:
			return spot
	return null
