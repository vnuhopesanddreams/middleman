extends Node

## Background music that keeps playing across scene changes (loaded at startup as the
## `Music` autoload). The menus play the menu song; it fades out when a shift starts.

const MENU_SONG = preload("res://assets/audio/music/BeepBox-Song.mp3")
const FADE_TIME = 0.6
## Quiet enough to count as silent at the end of a fade.
const SILENT_DB = -40.0

var _player := AudioStreamPlayer.new()
var _fade: Tween


func _ready() -> void:
	# Keeps playing while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = "Music"
	add_child(_player)


func _exit_tree() -> void:
	# Let go of the song cleanly when the game closes.
	_player.stop()
	_player.stream = null


## Plays the song, unless it's already playing (then it just carries on).
func play(song: AudioStream) -> void:
	if _fade:
		_fade.kill()
	_player.volume_db = 0.0
	if _player.stream == song and _player.playing:
		return
	_player.stream = song
	_player.play()


func play_menu_song() -> void:
	play(MENU_SONG)


func fade_out() -> void:
	if not _player.playing:
		return
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", SILENT_DB, FADE_TIME)
	_fade.tween_callback(_player.stop)
