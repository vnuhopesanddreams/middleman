extends Control

## "Bump phones!": hold your phone against a friend's to meet them (swapping friend codes
## over NFC, see FriendLink), which lets you play again. Opened over the win screen or
## the main menu; `bumped` once it has worked and the player taps PLAY, `closed` on Back.

signal bumped(friend_code: String)
signal closed

## A long buzz when a bump goes through.
const BUMPED_BUZZ_MS = 200

var _friend := ""


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and %Waiting.visible:
		get_viewport().set_input_as_handled()
		closed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and %Waiting.visible:
		closed.emit()


func _on_linked(friend_code: String) -> void:
	_friend = friend_code
	var is_new := SaveData.add_friend(friend_code)
	SaveData.set_needs_bump(false)
	%FriendCode.text = friend_code
	%FriendNote.text = "new friend!" if is_new else "good to see you again!"
	%FriendCount.text = "friends met: %d" % SaveData.friends.size()
	%Waiting.hide()
	%Met.show()
	%PlayButton.grab_focus()
	Input.vibrate_handheld(BUMPED_BUZZ_MS)
