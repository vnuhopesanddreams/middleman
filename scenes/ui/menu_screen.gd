class_name MenuScreen
extends Control

## A screen reached from the main menu. Its Back button, the phone's back gesture and
## Esc all lead back there. Opened on top of something else instead (like the pause
## menu), it just closes.

## Going back while opened on top of something else.
signal closed

const MAIN_MENU = "res://scenes/ui/main_menu.tscn"

## Whether going back changes to the main menu, or only emits `closed`.
var returns_to_main_menu := true

@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(go_back)
	# Opened over the game (like settings from the pause menu), the game's sound stays.
	if returns_to_main_menu:
		Music.play_menu_song()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


func go_back() -> void:
	if returns_to_main_menu:
		get_tree().change_scene_to_file(MAIN_MENU)
	else:
		closed.emit()
