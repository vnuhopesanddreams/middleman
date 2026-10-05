extends Control

## Little bits of text that float up from where something happened in the room ("+87",
## "NICE!"), drawn over the game. In the "popups" group, so anything can call `pop` with
## `call_group`.

const GROUP = "popups"
const LIFETIME = 1.1
## How far a popup rises over its life, in screen pixels.
const RISE = 140.0
## They start fading this far through their life.
const FADE_FROM = 0.6

## Its `wrap_width` says how far apart the room's sideways copies are.
@export var waiter: Node2D
@export var font_size := 46
@export var outline_color := Color(0.1, 0.06, 0.08)

## One per popup: text, where it happened (world), colour and age.
var _popups: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(GROUP)


func pop(text: String, world_position: Vector2, color := Color(1, 0.85, 0.3)) -> void:
	_popups.append({"text": text, "at": world_position, "color": color, "age": 0.0})


func _process(delta: float) -> void:
	for popup in _popups:
		popup.age += delta
	_popups = _popups.filter(func(popup: Dictionary) -> bool: return popup.age < LIFETIME)
	queue_redraw()


func _draw() -> void:
	var to_screen := get_viewport().canvas_transform
	var view_center := to_screen.affine_inverse() * get_viewport_rect().get_center()
	var font := get_theme_default_font()
	var width: float = waiter.wrap_width
	for popup in _popups:
		var t: float = popup.age / LIFETIME
		# Over whichever copy of the spot is on screen (the room repeats sideways).
		var spot: Vector2 = popup.at
		if width > 0.0:
			spot.x += roundf((view_center.x - spot.x) / width) * width
		var rise := RISE * (1.0 - pow(1.0 - t, 3.0))
		var alpha := 1.0 if t < FADE_FROM else 1.0 - (t - FADE_FROM) / (1.0 - FADE_FROM)
		var text: String = popup.text
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var at := to_screen * spot - Vector2(size.x / 2.0, rise)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 12, Color(outline_color, alpha))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(popup.color, alpha))
