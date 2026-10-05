extends CanvasLayer

## Shown when the shift ends: time's up (you made it) or every heart is gone (game
## over). Stops the game and shows the score and the best one (flashing when it's a new
## best), with a way to play again or leave. After a win, playing again takes bumping
## phones with someone (see BumpScreen), if this phone can.

const MAIN_MENU = "res://scenes/ui/main_menu.tscn"
const BUMP_SCREEN = preload("res://scenes/ui/bump_screen.tscn")
const NEW_BEST_COLOR = Color(1, 0.85, 0.3)
const NEW_BEST_FLASH = Color(1, 0.6, 0.75)

@export var shift_manager: ShiftManager
## Turned off once the shift is over, so it can't unpause the game underneath.
@export var pause_menu: CanvasLayer

@onready var overlay: Control = $Overlay
@onready var title: Label = %Title
@onready var reason: Label = %Reason
@onready var score: Label = %Score
@onready var best: Label = %Best

var _flash_tween: Tween
var _bump_screen: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.hide()
	shift_manager.shift_over.connect(_on_shift_over)
	%PlayAgainButton.pressed.connect(_play_again)
	%MainMenuButton.pressed.connect(_to_main_menu)


func _on_shift_over(survived: bool) -> void:
	pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	pause_menu.hide()
	get_tree().paused = true
	title.text = "TIME'S UP!" if survived else "GAME OVER"
	reason.text = "nice shift!" if survived else "too many angry tables"
	if survived and FriendLink.can_bump():
		SaveData.set_needs_bump(true)
	%NoBump.text = FriendLink.why_cant_bump()
	%NoBump.visible = survived and not %NoBump.text.is_empty()
	%PlayAgainButton.text = "BUMP TO PLAY AGAIN" if _needs_bump() else "PLAY AGAIN"
	score.text = str(shift_manager.points)
	if survived:
		Sfx.play("shift_win")
	if SaveData.record_score(shift_manager.points):
		Sfx.play("new_best")
		best.text = "NEW BEST!"
		_flash(best)
	else:
		best.text = "best %d" % SaveData.best_score
	overlay.show()
	%PlayAgainButton.grab_focus()


func _flash(label: Label) -> void:
	_flash_tween = create_tween().set_loops()
	_flash_tween.tween_property(label, "theme_override_colors/font_color", NEW_BEST_FLASH, 0.3)
	_flash_tween.tween_property(label, "theme_override_colors/font_color", NEW_BEST_COLOR, 0.3)


func _needs_bump() -> bool:
	return SaveData.needs_bump and FriendLink.can_bump()


func _play_again() -> void:
	if _needs_bump():
		_open_bump_screen()
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


func _open_bump_screen() -> void:
	_bump_screen = BUMP_SCREEN.instantiate()
	_bump_screen.bumped.connect(func(_friend: String) -> void: _play_again())
	_bump_screen.closed.connect(_close_bump_screen)
	add_child(_bump_screen)


func _close_bump_screen() -> void:
	_bump_screen.queue_free()
	_bump_screen = null
	%PlayAgainButton.grab_focus()


func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
