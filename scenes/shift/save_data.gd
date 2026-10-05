extends Node

## Progress kept between sessions (loaded at startup as the `SaveData` autoload), in a
## file on the device: the best score, this player's friend code and the friends met by
## bumping phones, and whether a bump is needed before playing again.

const PATH = "user://save.cfg"
## Friend codes use letters and digits that are hard to mix up (no O/0, I/1).
const CODE_CHARACTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH = 6

var best_score := 0
## This player's own code, made up the first time the game runs.
var friend_code := ""
## Codes of everyone met by bumping phones, oldest first.
var friends: PackedStringArray = []
## Set after a won shift: the next one can't start until phones are bumped.
var needs_bump := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		best_score = config.get_value("scores", "best", best_score)
		friend_code = config.get_value("friends", "code", friend_code)
		friends = config.get_value("friends", "met", friends)
		needs_bump = config.get_value("friends", "needs_bump", needs_bump)
	if friend_code.is_empty():
		friend_code = new_friend_code()
		_save()


## Records a shift's score. Returns whether it beat the best (which is then saved).
func record_score(score: int) -> bool:
	if score <= best_score:
		return false
	best_score = score
	_save()
	return true


## Records meeting someone. Returns whether they're a new friend.
func add_friend(code: String) -> bool:
	var is_new := not friends.has(code)
	if is_new:
		friends.append(code)
	_save()
	return is_new


func set_needs_bump(value: bool) -> void:
	needs_bump = value
	_save()


## Debug: forgets everyone met.
func clear_friends() -> void:
	friends.clear()
	_save()


## Debug: gives this player a fresh code.
func reset_friend_code() -> void:
	friend_code = new_friend_code()
	_save()


func new_friend_code() -> String:
	var code := ""
	for i in CODE_LENGTH:
		code += CODE_CHARACTERS[randi() % CODE_CHARACTERS.length()]
	return code


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "best", best_score)
	config.set_value("friends", "code", friend_code)
	config.set_value("friends", "met", friends)
	config.set_value("friends", "needs_bump", needs_bump)
	config.save(PATH)
