extends Node

## Sound effects (loaded at startup as the `Sfx` autoload), on the SFX bus. Everything
## that happens in the game plays one of the EVENTS below by name. Each event has one or
## more takes; `play` picks one at random (never the same twice in a row) at a slightly
## random pitch, so repeats don't grate, except for `exact` events (the bump screen's),
## which always sound as recorded. Every button in the game clicks when pressed.
##
## Events marked "stand-in" borrow another event's sound at a different pitch until
## they get their own: swap in the new file here and nothing else needs to change.

const BUTTON_CLICK = preload("res://assets/audio/sfx/buttonclick.wav")
const ACTION_CLICK = preload("res://assets/audio/sfx/actionclick.wav")
const ACTION_NEEDED = preload("res://assets/audio/sfx/actionneeded.wav")
const HOLD = preload("res://assets/audio/sfx/hold.wav")
const BUMP1 = preload("res://assets/audio/sfx/bump1.wav")
const BUMP2 = preload("res://assets/audio/sfx/bump2.wav")

## Event -> {takes, and optionally volume (dB), pitch, exact}.
const EVENTS := {
	# Moving about.
	"walk": {"takes": [
		preload("res://assets/audio/sfx/walk1.wav"),
		preload("res://assets/audio/sfx/walk2.wav"),
		preload("res://assets/audio/sfx/walk3.wav"),
	], "volume": -8.0},
	# Doing something that has no sound of its own: starting a quick-time action, a
	# quick-time tap that doesn't finish or miss it, or visiting a table to cheer it up.
	# Not walking.
	"action": {"takes": [ACTION_CLICK]},
	"button_click": {"takes": [BUTTON_CLICK]},

	# Guests.
	"hold": {"takes": [HOLD]},
	"seat": {"takes": [HOLD], "pitch": 0.8}, # stand-in
	"drop": {"takes": [HOLD], "pitch": 0.6}, # stand-in
	"guest_arrived": {"takes": [ACTION_NEEDED], "pitch": 1.3}, # stand-in
	# A guest got worse: got a problem, or is close to storming out.
	"worse": {"takes": [ACTION_NEEDED]},

	# Quick-time events.
	"qte_success": {"takes": [BUMP1]},
	# Missed, or ran out of time.
	"qte_fail": {"takes": [ACTION_NEEDED], "pitch": 0.7}, # stand-in
	"wipe": {"takes": [ACTION_CLICK], "volume": -6.0, "pitch": 1.4}, # stand-in

	# Tables and the shift.
	"date_done": {"takes": [BUMP1]},
	"heart_lost": {"takes": [ACTION_NEEDED], "pitch": 0.5}, # stand-in
	# The clock turning red for the last stretch.
	"hurry": {"takes": [ACTION_NEEDED], "pitch": 0.85}, # stand-in
	"shift_win": {"takes": [BUMP2], "pitch": 0.85}, # stand-in
	"new_best": {"takes": [BUMP1], "pitch": 1.3}, # stand-in

	# The bump screen, in order.
	"bump_hit": {"takes": [BUMP1], "exact": true},
	# Each letter of their code locking in (pitched up letter by letter by the caller).
	"bump_letter": {"takes": [ACTION_CLICK], "exact": true},
	"bump_land": {"takes": [BUMP2], "exact": true},
	"bump_stamp": {"takes": [HOLD], "pitch": 0.75, "exact": true}, # stand-in
	"bump_count": {"takes": [ACTION_CLICK], "pitch": 1.3, "exact": true}, # stand-in
}
## How far a random pitch may shift either way.
const PITCH_SPREAD = 0.08
## Sounds that can play at once; past this the oldest is cut off.
const MAX_PLAYERS = 12

## Event -> the take it played last, so `play` doesn't repeat it.
var _last_take := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	# Menus over a paused game still click.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play.bind("button_click"))


## Plays `event`. `pitch` scales its pitch further (e.g. to climb over a run of them).
func play(event: String, pitch := 1.0) -> void:
	var sound: Dictionary = EVENTS[event]
	var takes: Array = sound.takes
	var take := randi() % takes.size()
	if takes.size() > 1 and take == _last_take.get(event, -1):
		take = (take + 1 + randi() % (takes.size() - 1)) % takes.size()
	_last_take[event] = take
	pitch *= sound.get("pitch", 1.0)
	if not sound.get("exact", false):
		pitch *= 1.0 + randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	var player := _free_player()
	player.stream = takes[take]
	player.volume_db = sound.get("volume", 0.0)
	player.pitch_scale = pitch
	player.play()


func _free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	if _players.size() < MAX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
		return player
	# All busy: reuse the one that's been going longest.
	var oldest := _players[0]
	for player in _players:
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	return oldest
