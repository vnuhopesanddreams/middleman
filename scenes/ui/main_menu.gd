extends Control

## The first screen: the game's name, a button to start a shift, and the way to the
## settings and credits. After a won shift, starting the next takes bumping phones with
## someone first (see BumpScreen), if this phone can.

const SHIFT_SCENE = "res://scenes/shift/restaurant.tscn"
const SETTINGS_SCENE = "res://scenes/ui/settings_menu.tscn"
const CREDITS_SCENE = "res://scenes/ui/credits_menu.tscn"
const BUMP_SCREEN = preload("res://scenes/ui/bump_screen.tscn")
## "BUMP TO PLAY" is longer than "PLAY", so it's set smaller to fit the button.
const LOCKED_PLAY_FONT_SIZE = 56

@onready var play_button: Button = %PlayButton


func _ready() -> void:
	play_button.pressed.connect(_play)
	%SettingsButton.pressed.connect(_open.bind(SETTINGS_SCENE))
	%CreditsButton.pressed.connect(_open.bind(CREDITS_SCENE))
	if SaveData.best_score > 0:
		%Best.text = "best %d" % SaveData.best_score
		%Best.show()
	if not SaveData.friends.is_empty():
		%Friends.text = "friends met: %d" % SaveData.friends.size()
		%Friends.show()
	if _needs_bump():
		play_button.text = "BUMP TO PLAY"
		play_button.add_theme_font_size_override("font_size", LOCKED_PLAY_FONT_SIZE)
	play_button.grab_focus()
	Music.play_menu_song()


func _needs_bump() -> bool:
	return SaveData.needs_bump and FriendLink.can_bump()


func _play() -> void:
	if not _needs_bump():
		_open(SHIFT_SCENE)
		return
	var bump_screen: Control = BUMP_SCREEN.instantiate()
	bump_screen.bumped.connect(func(_friend: String) -> void: _open(SHIFT_SCENE))
	bump_screen.closed.connect(func() -> void:
		bump_screen.queue_free()
		play_button.grab_focus())
	add_child(bump_screen)


func _open(scene: String) -> void:
	get_tree().change_scene_to_file(scene)
