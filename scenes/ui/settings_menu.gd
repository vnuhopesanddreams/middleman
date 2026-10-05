extends MenuScreen

## Volume sliders and control options. Changes apply right away and are saved on the
## way out.

## Slider -> audio bus it sets.
@onready var sliders := {
	%MasterSlider: "Master",
	%MusicSlider: "Music",
	%SoundSlider: "SFX",
}
@onready var drag_stick_toggle: Button = %DragStickToggle


func _ready() -> void:
	super()
	for slider: HSlider in sliders:
		var bus: String = sliders[slider]
		slider.value = Settings.volumes[bus]
		slider.value_changed.connect(func(value: float) -> void: Settings.set_volume(bus, value))
	drag_stick_toggle.button_pressed = Settings.show_drag_stick
	_show_toggle(Settings.show_drag_stick)
	drag_stick_toggle.toggled.connect(_on_drag_stick_toggled)


func _on_drag_stick_toggled(on: bool) -> void:
	Settings.show_drag_stick = on
	_show_toggle(on)


func _show_toggle(on: bool) -> void:
	drag_stick_toggle.text = "ON" if on else "OFF"


func go_back() -> void:
	Settings.save()
	super()
