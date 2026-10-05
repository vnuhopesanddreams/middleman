extends CanvasLayer

## The score in the corner (when it goes up, the number counts up to the new total and
## the panel pops), the hearts under it, the shift clock, and a banner when a guest
## walks in.

## Seconds to count up to a new total.
const COUNT_TIME = 0.6
## How big the panel pops when points come in.
const POP_SCALE = 1.2
## The arrival banner slides down this far while fading in, then stays up a while.
const TOAST_SLIDE = 40.0
const TOAST_FADE_TIME = 0.25
const TOAST_HOLD_TIME = 1.6
## A short buzz on phones when a guest arrives, in milliseconds.
const ARRIVAL_BUZZ_MS = 60
## A longer one when a heart is lost.
const HEART_LOST_BUZZ_MS = 250
const HEART_COLOR = Color(0.95, 0.4, 0.55)
const LOST_HEART_COLOR = Color(0.3, 0.2, 0.25)
## The clock turns red and pulses for the last stretch of the shift.
const HURRY_SECONDS = 30.0
const CLOCK_COLOR = Color(1, 0.85, 0.3)
const HURRY_COLOR = Color(1.0, 0.3, 0.25)

@export var shift_manager: ShiftManager

@onready var points_panel: Control = %PointsPanel
@onready var points_label: Label = %PointsLabel
@onready var toast: Control = %Toast
@onready var toast_label: Label = %ToastLabel
@onready var hearts: Array[Node] = %Lives.get_children()
@onready var timer_label: Label = %TimerLabel
@onready var vignette: ColorRect = %Vignette

var _shown_points := 0.0
var _tween: Tween
var _toast_tween: Tween
## Where the banner rests once it has slid in.
var _toast_y := 0.0


func _ready() -> void:
	shift_manager.points_changed.connect(_on_points_changed)
	shift_manager.guest_arrived.connect(_on_guest_arrived)
	shift_manager.lives_changed.connect(_on_lives_changed)
	_on_lives_changed(shift_manager.lives)
	_show_points(shift_manager.points)
	_toast_y = toast.position.y


func _on_points_changed(total: int) -> void:
	if _tween:
		_tween.kill()
	points_panel.pivot_offset = points_panel.size / 2.0
	points_panel.scale = Vector2.ONE * POP_SCALE
	_tween = create_tween().set_parallel()
	_tween.tween_method(_show_points, _shown_points, float(total), COUNT_TIME)
	_tween.tween_property(points_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	var seconds := ceili(shift_manager.time_left)
	timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	var hurry := shift_manager.time_left <= HURRY_SECONDS
	if hurry and not vignette.hurry:
		Sfx.play("hurry")
	vignette.hurry = hurry
	if vignette.hurry:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.0)
		timer_label.add_theme_color_override("font_color", HURRY_COLOR.lerp(Color.WHITE, pulse * 0.4))
	else:
		timer_label.add_theme_color_override("font_color", CLOCK_COLOR)


func _on_lives_changed(lives: int) -> void:
	for i in hearts.size():
		hearts[i].set_color(HEART_COLOR if i < lives else LOST_HEART_COLOR)
	if lives < hearts.size():
		_shake(%Lives)
		vignette.flash()
		Input.vibrate_handheld(HEART_LOST_BUZZ_MS)


## A quick side-to-side shake, for losing a heart.
func _shake(node: Control) -> void:
	var rest := node.position
	var tween := create_tween()
	for offset in [14.0, -12.0, 8.0, -4.0, 0.0]:
		tween.tween_property(node, "position:x", rest.x + offset, 0.05)


func _on_guest_arrived(_person: Person, is_date: bool) -> void:
	_show_toast("THEIR FRIEND IS HERE!" if is_date else "NEW GUEST!")
	Input.vibrate_handheld(ARRIVAL_BUZZ_MS)


func _show_toast(text: String) -> void:
	if _toast_tween:
		_toast_tween.kill()
	toast_label.text = text
	toast.show()
	toast.modulate.a = 0.0
	toast.position.y = _toast_y - TOAST_SLIDE
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, TOAST_FADE_TIME)
	_toast_tween.parallel().tween_property(toast, "position:y", _toast_y, TOAST_FADE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(TOAST_HOLD_TIME)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, TOAST_FADE_TIME)
	_toast_tween.tween_callback(toast.hide)


func _show_points(value: float) -> void:
	_shown_points = value
	points_label.text = str(roundi(value))
