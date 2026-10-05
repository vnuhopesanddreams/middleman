extends Node

## Bumping phones to meet someone (loaded at startup as the `FriendLink` autoload). On
## Android it goes through the NfcFriends plugin: while linking, holding two phones
## together swaps friend codes. Phones without NFC (and iPhones) can't bump; neither can
## a PC, except debug builds, which can fake a bump to test the flow.

signal linked(friend_code: String)

## Debug builds only: lets any device fake bumps (like a phone without NFC), set from
## the bump debug menu.
var force_fake_bump := false
## Whether it's listening for a bump right now.
var is_linking := false

## The Android plugin, when running on a phone that has it.
var _plugin: Object


func _ready() -> void:
	if Engine.has_singleton("NfcFriends"):
		_plugin = Engine.get_singleton("NfcFriends")
		_plugin.friend_linked.connect(_on_linked)
	elif OS.has_feature("android"):
		push_error("NfcFriends plugin missing from this build; reload the editor and export again.")


## Whether this device can bump at all.
func can_bump() -> bool:
	return has_nfc() or can_fake_bump()


## Whether the plugin is here and the phone has NFC hardware.
func has_nfc() -> bool:
	return _plugin != null and _plugin.hasNfc()


func has_plugin() -> bool:
	return _plugin != null


## Why this device can't bump, to tell the player; empty when it can.
func why_cant_bump() -> String:
	if can_bump():
		return ""
	if _plugin:
		return "this phone has no nfc, so no bump needed"
	if OS.has_feature("android"):
		return "this build can't use nfc, so no bump needed"
	return "this device can't bump phones, so no bump needed"


## Debug builds on a PC can pretend a bump happened, to test the flow.
func can_fake_bump() -> bool:
	if not OS.is_debug_build():
		return false
	return force_fake_bump or (_plugin == null and not OS.has_feature("mobile"))


## Whether NFC is switched on (always true where bumping is faked).
func is_nfc_on() -> bool:
	return _plugin.isNfcOn() if _plugin else true


func open_nfc_settings() -> void:
	if _plugin:
		_plugin.openNfcSettings()


## Starts listening for a bump, offering this player's friend code.
func start() -> void:
	is_linking = true
	if _plugin:
		_plugin.startLinking(SaveData.friend_code)


func stop() -> void:
	is_linking = false
	if _plugin:
		_plugin.stopLinking()


func fake_bump(friend_code := "") -> void:
	_on_linked(friend_code if friend_code else SaveData.new_friend_code())


func _on_linked(friend_code: String) -> void:
	linked.emit(friend_code)
