class_name Couple
extends Node

signal happiness_changed(value: float)
## The date is over. `finished` is true if it ran its course, false if they stormed out.
signal ended(finished: bool)

const MAX_HAPPINESS = 100.0
const PARTY_SIZE = 2

@export var drain_per_second := 2.0
@export var boost_per_visit := 30.0
## How long the date lasts once everyone is seated (stand-in until ordering exists).
@export var date_duration := 30.0

var table: Table
var people: Array[Person] = []
var happiness := MAX_HAPPINESS

var _date_time_left := 0.0
var _has_ended := false


func _ready() -> void:
	_date_time_left = date_duration


func _process(delta: float) -> void:
	if people.is_empty() or _has_ended:
		return
	_set_happiness(happiness - drain_per_second * delta)
	if happiness <= 0.0:
		_end(false)
		return
	if is_seated():
		_date_time_left -= delta
		if _date_time_left <= 0.0:
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


func _end(finished: bool) -> void:
	_has_ended = true
	ended.emit(finished)


func _set_happiness(value: float) -> void:
	value = clampf(value, 0.0, MAX_HAPPINESS)
	if value == happiness:
		return
	happiness = value
	happiness_changed.emit(happiness)
