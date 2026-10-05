extends Node

## The player's settings (loaded at startup as the `Settings` autoload). They're kept
## between sessions in a file on the device and applied as soon as they change.

const PATH = "user://settings.cfg"

## Volume per audio bus, from 0 (off) to 1 (full).
var volumes := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}
## Whether dragging to move shows the joystick under the finger.
var show_drag_stick := true


func _ready() -> void:
	_load()
	for bus in volumes:
		_apply_volume(bus)


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = value
	_apply_volume(bus)


func save() -> void:
	var config := ConfigFile.new()
	for bus in volumes:
		config.set_value("volume", bus, volumes[bus])
	config.set_value("controls", "show_drag_stick", show_drag_stick)
	config.save(PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for bus in volumes:
		volumes[bus] = config.get_value("volume", bus, volumes[bus])
	show_drag_stick = config.get_value("controls", "show_drag_stick", show_drag_stick)


func _apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(volumes[bus]))
	AudioServer.set_bus_mute(index, volumes[bus] <= 0.0)
