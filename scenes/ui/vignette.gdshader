shader_type canvas_item;

// Darkens the edges of the screen, and tints them red by `flash` (0 to 1).

uniform vec4 edge_color : source_color = vec4(0.12, 0.03, 0.07, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 0.12, 0.12, 1.0);
// How dark the very edge gets normally, and with a full flash.
uniform float strength = 0.45;
uniform float flash_strength = 0.55;
// Where the darkening starts (0 middle, 1 corners) and how far it fades in.
uniform float start = 0.45;
uniform float softness = 0.6;
uniform float flash = 0.0;

void fragment() {
	float distance_out = length(UV - 0.5) * 1.414;
	float edge = smoothstep(start, start + softness, distance_out);
	vec3 color = mix(edge_color.rgb, flash_color.rgb, flash);
	COLOR = vec4(color, edge * mix(strength, flash_strength, flash));
}
