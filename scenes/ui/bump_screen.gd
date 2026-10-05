extends Control

## "Bump phones!": hold your phone against a friend's to meet them (swapping friend codes
## over NFC, see FriendLink), which lets you play again. Once you've met, it gives you
## both the same question to ask each other (see BumpQuestions). Opened over the win
## screen or the main menu; `bumped` once it has worked and the player taps PLAY, `closed`
## on Back. A bump going through gets a big celebration (see `_celebrate`); a tap skips
## to the end of it.

signal bumped(friend_code: String)
signal closed

## A long buzz when a bump goes through.
const BUMPED_BUZZ_MS = 200
## A tick as each letter of their code locks in, and a thump when it lands.
const LETTER_BUZZ_MS = 15
const LANDED_BUZZ_MS = 60
## How long their code spins before every letter has locked in.
const SCRAMBLE_TIME = 0.7
## How much each letter locking in kicks the code's size.
const LETTER_KICK = 0.15
## How much higher each locked letter's tick is than the last.
const LETTER_PITCH_STEP = 0.08
## The PLAY button gently grows and shrinks this much once it's in, to be pressed.
const BREATHE_SCALE = 1.06
const BREATHE_TIME = 0.6

var _friend := ""
## The celebration playing after a bump, while it is.
var _sequence: Tween
## Letters of their code locked in so far, while it spins.
var _locked := 0


func _ready() -> void:
	%Code.text = SaveData.friend_code
	%BackButton.pressed.connect(closed.emit)
	%NfcButton.pressed.connect(FriendLink.open_nfc_settings)
	%FakeBumpButton.visible = FriendLink.can_fake_bump()
	%FakeBumpButton.pressed.connect(FriendLink.fake_bump)
	%PlayButton.pressed.connect(func() -> void: bumped.emit(_friend))
	FriendLink.linked.connect(_on_linked)
	FriendLink.start()
	%Waiting.show()
	%Met.hide()


func _exit_tree() -> void:
	FriendLink.stop()


func _process(_delta: float) -> void:
	%NfcOff.visible = %Waiting.visible and not FriendLink.is_nfc_on()


func _input(event: InputEvent) -> void:
	# A tap during the celebration jumps to the end of it (and doesn't press anything).
	var tap := (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed()
	if tap and _sequence and _sequence.is_running():
		get_viewport().set_input_as_handled()
		_sequence.custom_step(60.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and %Waiting.visible:
		get_viewport().set_input_as_handled()
		closed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and %Waiting.visible:
		closed.emit()


func _on_linked(friend_code: String) -> void:
	# One bump per visit; phones held together a while longer can link again.
	if %Met.visible:
		return
	_friend = friend_code
	var is_new := SaveData.add_friend(friend_code)
	SaveData.set_needs_bump(false)
	var count := SaveData.friends.size()
	%FriendNote.text = "new friend!" if is_new else "good to see you again!"
	# A new friend's count ticks up during the celebration.
	%FriendCount.text = "friends met: %d" % (count - 1 if is_new else count)
	%Question.text = BumpQuestions.for_pair(SaveData.friend_code, friend_code)
	%Waiting.hide()
	for child: Control in %Met.get_children():
		child.modulate.a = 0.0
	%Met.show()
	%PlayButton.grab_focus()
	Input.vibrate_handheld(BUMPED_BUZZ_MS)
	Sfx.play("bump_hit")
	# Wait for the layout, so everything's size (to grow it from its middle) is known.
	await get_tree().process_frame
	_celebrate(is_new, count)


## Flash and burst, their code spinning like a slot machine and locking in letter by
## letter, then the note, count, question and PLAY popping in one after another.
func _celebrate(is_new: bool, count: int) -> void:
	for child: Control in %Met.get_children():
		child.pivot_offset = child.size / 2.0
	%Celebration.celebrate(_middle_of(%FriendCode))
	_locked = 0
	_sequence = create_tween()
	_sequence.tween_property(%YouMet, "modulate:a", 1.0, 0.2)
	_sequence.tween_property(%FriendCode, "modulate:a", 1.0, 0.0)
	_sequence.tween_method(_spin_code, 0.0, 1.0, SCRAMBLE_TIME)
	_sequence.tween_callback(_land_code)
	_sequence.tween_property(%FriendCode, "scale", Vector2.ONE, 0.35).from(Vector2.ONE * 1.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_sequence.tween_callback(Sfx.play.bind("bump_stamp"))
	_sequence.tween_property(%FriendNote, "modulate:a", 1.0, 0.08)
	_sequence.parallel().tween_property(%FriendNote, "scale", Vector2.ONE, 0.3).from(Vector2.ONE * 2.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_new:
		_sequence.tween_callback(func() -> void: %Celebration.burst(_middle_of(%FriendNote), 25))

	_sequence.tween_property(%FriendCount, "modulate:a", 1.0, 0.15)
	if is_new:
		_sequence.tween_callback(func() -> void:
			%FriendCount.text = "friends met: %d" % count
			Sfx.play("bump_count"))
		_sequence.tween_property(%FriendCount, "scale", Vector2.ONE, 0.3).from(Vector2.ONE * 1.5) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_sequence.tween_interval(0.15)
	_sequence.tween_property(%AskEachOther, "modulate:a", 1.0, 0.25)
	_sequence.tween_property(%Question, "modulate:a", 1.0, 0.3)
	_sequence.parallel().tween_property(%Question, "scale", Vector2.ONE, 0.4).from(Vector2.ONE * 0.8) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_sequence.tween_property(%PlayButton, "modulate:a", 1.0, 0.05)
	_sequence.parallel().tween_property(%PlayButton, "scale", Vector2.ONE, 0.5).from(Vector2.ZERO) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_sequence.tween_callback(_breathe_play_button)


## Their code mid-spin: `progress` 0 to 1, letters locking in left to right.
func _spin_code(progress: float) -> void:
	var length := _friend.length()
	var spun := progress * length
	var locked := mini(floori(spun), length)
	var text := _friend.left(locked)
	for i in length - locked:
		text += SaveData.CODE_CHARACTERS[randi() % SaveData.CODE_CHARACTERS.length()]
	%FriendCode.text = text
	if locked > _locked:
		_locked = locked
		Input.vibrate_handheld(LETTER_BUZZ_MS)
		# Climbs a little with each letter.
		Sfx.play("bump_letter", 1.0 + LETTER_PITCH_STEP * locked)
	%FriendCode.scale = Vector2.ONE * (1.0 + LETTER_KICK * (1.0 - (spun - floorf(spun))))


func _land_code() -> void:
	%FriendCode.text = _friend
	%Celebration.burst(_middle_of(%FriendCode), 40)
	Input.vibrate_handheld(LANDED_BUZZ_MS)
	Sfx.play("bump_land")


func _breathe_play_button() -> void:
	var breathe := create_tween().set_loops()
	breathe.tween_property(%PlayButton, "scale", Vector2.ONE * BREATHE_SCALE, BREATHE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(%PlayButton, "scale", Vector2.ONE, BREATHE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The middle of a control, where the celebration layer can draw.
func _middle_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center() - %Celebration.global_position
