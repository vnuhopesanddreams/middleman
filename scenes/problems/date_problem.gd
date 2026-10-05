class_name DateProblem
extends Node2D

## Something going wrong on a date, stuck to one guest (as their child). The waiter
## fixes it with a quick action: tap the guest to walk over, then the action starts and
## has a few seconds to be done, or it stops and needs another go. Until it's fixed the
## date's happiness drains (see Couple).
##
## Each kind of problem extends this, sets `prompt` and draws itself, and turns screen
## input into progress in `handle_input`.

signal solved

## Every problem in the restaurant, to cap how many go on at once.
const GROUP = "date_problems"

## What to do, shown on screen while the action is going.
var prompt := ""
## How fast the date sours while this goes unsolved.
var drain_per_second := 4.0
## Seconds to do the action once it starts.
var time_limit := 4.0

## Whether the action is going right now.
var active := false
var time_left := 0.0

## Seconds since the problem appeared, for animations.
var _time := 0.0


func _ready() -> void:
	add_to_group(GROUP)


func start() -> void:
	active = true
	time_left = time_limit
	_on_start()


## Input while the action is going. `point` is where it happened, relative to the guest.
## Returns whether it was used.
func handle_input(_event: InputEvent, _point: Vector2) -> bool:
	return false


func _process(delta: float) -> void:
	_time += delta
	if active:
		_tick(delta)
		time_left -= delta
		if time_left <= 0.0:
			active = false
			Sfx.play("qte_fail")
	queue_redraw()


func _succeed() -> void:
	Sfx.play("qte_success")
	active = false
	solved.emit()
	queue_free()


## Called when the action starts (also on another go).
func _on_start() -> void:
	pass


## Called every frame while the action is going.
func _tick(_delta: float) -> void:
	pass
