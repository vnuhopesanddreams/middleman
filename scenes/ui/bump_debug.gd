extends CanvasLayer

## Debug menu (loaded at startup as the `BumpDebug` autoload, but only does anything in
## debug builds), mostly for bumping phones: shows what FriendLink and SaveData think is
## going on and lets you fake bumps, flip the "bump to play" lock and reset friends. Can
## also end a shift on the spot. Opens over any screen with F3, or a three-finger tap on
## a phone.

const TOGGLE_KEY = KEY_F3
## Fingers that have to be down at once to open it on a phone.
const TOGGLE_FINGERS = 3
const FONT_SIZE = 30
const MAX_LOG_LINES = 12

var _panel: PanelContainer
var _status: Label
var _log: Label
var _log_lines: PackedStringArray = []
var _force_button: Button
## Last code a bump came in from, to fake meeting them again.
var _last_friend := ""


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.hide()
	FriendLink.linked.connect(_on_linked)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var touch := event as InputEventScreenTouch
	if (key and key.pressed and not key.echo and key.keycode == TOGGLE_KEY) \
			or (touch and touch.pressed and touch.index == TOGGLE_FINGERS - 1):
		get_viewport().set_input_as_handled()
		_panel.visible = not _panel.visible


func _process(_delta: float) -> void:
	if _panel.visible:
		_refresh()


func _refresh() -> void:
	var lines := PackedStringArray([
		"plugin: %s" % _yes_no(FriendLink.has_plugin()),
		"nfc hardware: %s" % _yes_no(FriendLink.has_nfc()),
		"nfc on: %s" % _yes_no(FriendLink.is_nfc_on()),
		"can bump: %s" % _yes_no(FriendLink.can_bump()),
		"can fake bump: %s" % _yes_no(FriendLink.can_fake_bump()),
		"listening: %s" % _yes_no(FriendLink.is_linking),
		"needs bump: %s" % _yes_no(SaveData.needs_bump),
		"my code: %s" % SaveData.friend_code,
		"friends (%d): %s" % [SaveData.friends.size(), ", ".join(SaveData.friends)],
	])
	if not FriendLink.why_cant_bump().is_empty():
		lines.append("why not: %s" % FriendLink.why_cant_bump())
	_status.text = "\n".join(lines)
	_force_button.text = "force fake bumps: %s" % ("ON" if FriendLink.force_fake_bump else "OFF")


func _on_linked(friend_code: String) -> void:
	_last_friend = friend_code
	_add_log("linked %s" % friend_code)


func _add_log(line: String) -> void:
	_log_lines.append("%s  %s" % [Time.get_time_string_from_system(), line])
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.remove_at(0)
	_log.text = "\n".join(_log_lines)


## Ends the shift being played, if there is one.
func _end_shift(survived: bool) -> void:
	var shift: ShiftManager
	for node in get_tree().current_scene.find_children("*", "Node", true, false):
		if node is ShiftManager:
			shift = node
	if shift == null or shift.is_over:
		_add_log("no shift going")
		return
	_panel.hide()
	shift.end_shift(survived)
	_add_log("ended shift (%s)" % ("win" if survived else "lose"))


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = preload("res://scenes/ui/menu_theme.tres")
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.02, 0.04, 0.88)
	background.set_content_margin_all(40)
	_panel.add_theme_stylebox_override("panel", background)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)

	var title := _label("bump debug", 56)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	list.add_child(title)
	_status = _label("", FONT_SIZE)
	list.add_child(_status)

	_force_button = _button(list, "", func() -> void:
		FriendLink.force_fake_bump = not FriendLink.force_fake_bump
		_add_log("force fake bumps %s" % ("on" if FriendLink.force_fake_bump else "off")))
	_button(list, "fake bump: new friend", func() -> void: FriendLink.fake_bump())
	_button(list, "fake bump: same friend again", func() -> void:
		FriendLink.fake_bump(_last_friend if _last_friend else SaveData.friends[-1] if SaveData.friends else ""))
	_button(list, "toggle needs bump", func() -> void:
		SaveData.set_needs_bump(not SaveData.needs_bump)
		_add_log("needs bump %s" % _yes_no(SaveData.needs_bump)))
	_button(list, "start / stop listening", func() -> void:
		if FriendLink.is_linking:
			FriendLink.stop()
		else:
			FriendLink.start()
		_add_log("listening %s" % _yes_no(FriendLink.is_linking)))
	_button(list, "open nfc settings", FriendLink.open_nfc_settings)
	_button(list, "clear friends", func() -> void:
		SaveData.clear_friends()
		_last_friend = ""
		_add_log("friends cleared"))
	_button(list, "new code for me", func() -> void:
		SaveData.reset_friend_code()
		_add_log("my code is now %s" % SaveData.friend_code))
	_button(list, "end shift: win", _end_shift.bind(true))
	_button(list, "end shift: lose", _end_shift.bind(false))
	_button(list, "reload screen", func() -> void:
		_panel.hide()
		get_tree().paused = false
		get_tree().reload_current_scene())
	_button(list, "close", _panel.hide)

	list.add_child(_label("log", 36))
	_log = _label("nothing yet", 26)
	list.add_child(_log)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
