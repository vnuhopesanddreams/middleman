class_name Couple
extends Node

signal happiness_changed(value: float)
## Something bad started or stopped happening to this date (see `troubled`).
signal troubled_changed(troubled: bool)
## The date is over. `finished` is true if it ran its course, false if they stormed out.
signal ended(finished: bool)

const MAX_HAPPINESS = 100.0
const PARTY_SIZE = 2
## Problems a date can have going at once (one per guest at most).
const MAX_PROBLEMS = 2
## Problems going at once in the whole restaurant. New ones wait until one is fixed.
const MAX_PROBLEMS_EVERYWHERE = 3
## Kinds of things that can go wrong during a date, picked at random.
const PROBLEMS: Array[Script] = [
	preload("res://scenes/problems/bad_breath.gd"),
	preload("res://scenes/problems/nervous.gd"),
	preload("res://scenes/problems/spilled_drink.gd"),
	preload("res://scenes/problems/fly_in_soup.gd"),
]

## How fast happiness drops while someone sits alone too long. Each problem adds its own
## drain on top. Happiness doesn't drop otherwise.
@export var drain_per_second := 0.75
@export var boost_per_visit := 30.0
## How long someone can sit alone waiting for their date before it starts to hurt.
@export var lonely_grace := 10.0
## Time between problems, once both guests are seated.
@export var problem_interval_min := 3.0
@export var problem_interval_max := 6.0
## Happiness for fixing a problem.
@export var solve_bonus := 10.0
## How long the date lasts once everyone is seated (stand-in until ordering exists).
@export var date_duration := 30.0

var table: Table
var people: Array[Person] = []
var happiness := MAX_HAPPINESS
## Whether something bad is happening to the date right now. Happiness only drains (and
## the table only shows the meter) while it is.
var troubled := false
## What's going wrong right now. Each sits on one of the guests.
var problems: Array[DateProblem] = []

var _date_time_left := 0.0
var _alone_time := 0.0
var _next_problem_in := 0.0
var _has_ended := false


func _ready() -> void:
	_date_time_left = date_duration
	_next_problem_in = randf_range(problem_interval_min, problem_interval_max)


func _process(delta: float) -> void:
	if people.is_empty() or _has_ended:
		return
	var drain := _drain_rate(delta)
	_set_troubled(drain > 0.0)
	if troubled:
		_set_happiness(happiness - drain * delta)
		if happiness <= 0.0:
			_end(false)
			return
	_count_down_to_problem(delta)
	if is_seated():
		_date_time_left -= delta
		# Doesn't end on a problem: once their time is up, they leave as soon as it's fixed.
		if _date_time_left <= 0.0 and problems.is_empty():
			_end(true)


func add_person(person: Person) -> void:
	people.append(person)
	person.couple = self


func is_complete() -> bool:
	return people.size() >= PARTY_SIZE


func is_seated() -> bool:
	return is_complete() and people.all(func(person: Person) -> bool: return person.state == Person.State.SEATED)


func cheer_up() -> void:
	_set_happiness(happiness + boost_per_visit)


## Ends the date angrily right away (e.g. someone got fed up waiting at the door).
func storm_out() -> void:
	if not _has_ended:
		_end(false)


## How fast happiness is dropping, from everything going wrong right now.
func _drain_rate(delta: float) -> float:
	var rate := 0.0
	_alone_time = _alone_time + delta if _is_waiting_alone() else 0.0
	if _alone_time > lonely_grace:
		rate += drain_per_second
	for problem in problems:
		rate += problem.drain_per_second
	return rate


func _set_troubled(value: bool) -> void:
	if value != troubled:
		troubled = value
		troubled_changed.emit(troubled)


## Problems only come up on an actual date: both guests seated. They hit a guest who
## doesn't have one already.
func _count_down_to_problem(delta: float) -> void:
	# No new problems once their time is up; they're only waiting on the current ones.
	if not is_seated() or _date_time_left <= 0.0:
		return
	var free_guests := people.filter(func(person: Person) -> bool: return person.current_problem() == null)
	if free_guests.is_empty() or problems.size() >= MAX_PROBLEMS:
		return
	if get_tree().get_nodes_in_group(DateProblem.GROUP).size() >= MAX_PROBLEMS_EVERYWHERE:
		return
	_next_problem_in -= delta
	if _next_problem_in <= 0.0:
		_next_problem_in = randf_range(problem_interval_min, problem_interval_max)
		_start_problem(free_guests.pick_random())


func _start_problem(person: Person) -> void:
	var problem: DateProblem = PROBLEMS.pick_random().new()
	person.add_child(problem)
	problems.append(problem)
	problem.solved.connect(_on_problem_solved.bind(problem))


func _on_problem_solved(problem: DateProblem) -> void:
	problems.erase(problem)
	_set_happiness(happiness + solve_bonus)
	get_tree().call_group("popups", "pop", "NICE!", problem.global_position - Vector2(0, 18), Color(0.55, 1.0, 0.6))
	get_tree().call_group("camera", "punch", 0.05)


## Someone is at the table but their date hasn't sat down yet.
func _is_waiting_alone() -> bool:
	var seated := people.filter(func(person: Person) -> bool: return person.state == Person.State.SEATED)
	return not seated.is_empty() and not is_seated()


func _end(finished: bool) -> void:
	_has_ended = true
	for problem in problems:
		problem.queue_free()
	problems.clear()
	ended.emit(finished)


func _set_happiness(value: float) -> void:
	value = clampf(value, 0.0, MAX_HAPPINESS)
	if value == happiness:
		return
	happiness = value
	happiness_changed.emit(happiness)
