shader_type canvas_item;

// Screen finish for the title: faint scanlines, a slow phosphor sweep and edge darkening.
// Draw it on a full-screen ColorRect that ignores the mouse.

uniform float line_alpha : hint_range(0.0, 0.3) = 0.07;
uniform float line_pitch = 3.0;
uniform float sweep_speed = 0.045;
uniform float sweep_strength : hint_range(0.0, 0.2) = 0.022;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 sweep_color : source_color = vec4(0.78, 1.0, 0.21, 1.0);
uniform vec4 shade_color : source_color = vec4(0.02, 0.03, 0.10, 1.0);

void fragment() {
	// Scanlines
	float row = mod(FRAGCOORD.y, line_pitch);
	float line = step(line_pitch * 0.5, row) * line_alpha;

	// Sweep band moving down the screen
	float p = fract(TIME * sweep_speed);
	float band = smoothstep(0.035, 0.0, abs(UV.y - p)) * sweep_strength;

	// Edge darkening
	vec2 c = (UV - 0.5) * vec2(1.15, 1.0);
	float vig = smoothstep(0.38, 0.95, length(c)) * vignette_strength;

	float shade_a = clamp(line + vig, 0.0, 1.0);
	float alpha = clamp(shade_a + band, 0.0, 1.0);
	vec3 col = (shade_color.rgb * shade_a + sweep_color.rgb * band) / max(shade_a + band, 0.0001);
	COLOR = vec4(col, alpha);
}
