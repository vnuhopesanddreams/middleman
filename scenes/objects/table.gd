class_name Table
extends StaticBody2D

const RING_PULSE_SPEED = 6.0

var couple: Couple

var _ring_time := 0.0

@onready var happiness_bar: ProgressBar = $HappinessBar
@onready var ring: Sprite2D = $Ring


func _ready() -> void:
	happiness_bar.max_value = Couple.MAX_HAPPINESS
	happiness_bar.hide()
	set_highlighted(false)


func _process(delta: float) -> void:
	_ring_time += delta
	ring.modulate.a = 0.65 + 0.35 * sin(_ring_time * RING_PULSE_SPEED)


func is_free() -> bool:
	return couple == null


## Seats the person only if this is the table their couple was given.
func try_seat(person: Person) -> bool:
	if couple == null or couple != person.couple:
		return false

	var seat := _free_seat()
	if seat == null:
		return false
	seat.occupant = person
	person.sit(seat)
	happiness_bar.value = couple.happiness
	happiness_bar.show()
	return true


## Reserves this table for a couple. Their meter shows once someone sits down.
func assign_couple(new_couple: Couple) -> void:
	couple = new_couple
	couple.table = self
	couple.happiness_changed.connect(_on_couple_happiness_changed)


## Frees the table after the couple has left (or stormed out).
func release() -> void:
	if couple:
		couple.happiness_changed.disconnect(_on_couple_happiness_changed)
	couple = null
	happiness_bar.hide()
	set_highlighted(false)


func set_highlighted(highlighted: bool) -> void:
	ring.visible = highlighted
	set_process(highlighted)


func interact(_waiter: Node2D) -> void:
	if couple:
		couple.cheer_up()


func _free_seat() -> Seat:
	for child in get_children():
		if child is Seat and child.is_free():
			return child
	return null


func _on_couple_happiness_changed(value: float) -> void:
	happiness_bar.value = value
