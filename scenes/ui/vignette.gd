extends ColorRect

## Darkens the screen's edges a little, flashes them red (`flash`), and pulses red while
## `hurry` is on (the last stretch of the shift).

const FLASH_TIME = 0.7
## How strong the hurry pulse gets (a full flash is 1).
const HURRY_PULSE = 0.35

var hurry := false

var _flash := 0.0


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta / FLASH_TIME)
	var pulse := 0.0
	if hurry:
		pulse = (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU)) * HURRY_PULSE
	material.set_shader_parameter("flash", maxf(_flash, pulse))
