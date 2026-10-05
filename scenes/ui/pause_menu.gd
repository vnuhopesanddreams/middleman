extends CanvasLayer

## Pauses the shift: the button in the corner (or Esc, or the phone's back gesture) stops
## the game and offers to carry on, change the settings, or go back to the main menu. It
## also pauses by itself when the phone switches to another app.

const MAIN_MENU = "res://scenes/ui/main_menu.tscn"
const SETTINGS_MENU = preload("res://scenes/ui/settings_menu.tscn")

@onready var overlay: Control = $Overlay
@onready var pause_button: Button = $PauseButton
@onready var resume_button: Button = %ResumeButton

## The settings screen while it's open on top, or null.
var _settings: MenuScreen


func _ready() -> void:
	# Keeps working while everything else is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(pause)
	resume_button.pressed.connect(resume)
	%SettingsButton.pressed.connect(_open_settings)
	%MainMenuButton.pressed.connect(_to_main_menu)
	overlay.hide()


func pause() -> void:
	get_tree().paused = true
	overlay.show()
	pause_button.hide()
	resume_button.grab_focus()


func resume() -> void:
	get_tree().paused = false
	overlay.hide()
	pause_button.show()


func _toggle() -> void:
	if get_tree().paused:
		resume()
	else:
		pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# With settings open, the back gesture is theirs (it closes them).
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _settings == null:
		_toggle()
	elif what == NOTIFICATION_APPLICATION_PAUSED and not get_tree().paused:
		pause()


func _open_settings() -> void:
	_settings = SETTINGS_MENU.instantiate()
	_settings.returns_to_main_menu = false
	_settings.closed.connect(_close_settings)
	add_child(_settings)


func _close_settings() -> void:
	_settings.queue_free()
	_settings = null
	resume_button.grab_focus()


func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
