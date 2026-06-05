// NOMADZ-0 :: PyramidNeon.gdshader
// Iridescent cyan veins — φ-pulse, metallic neon
// Palette: #00FFFF cyan veins on dark substrate
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float pulse_speed: hint_range(0.1, 2.0) = 0.618;
uniform vec4 vein_color: source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float vein_width: hint_range(0.01, 0.5) = 0.05;
uniform sampler2D noise_tex: hint_default_white;

void fragment() {
	float pulse = sin(TIME * pulse_speed + VERTEX.y) * 0.5 + 0.5;
	float noise = texture(noise_tex, UV * 4.0).r;
	float vein_mask = step(1.0 - vein_width, noise);

	ALBEDO = vein_color.rgb * vein_mask;
	EMISSION = vein_color.rgb * pulse * vein_mask * 2.0;
	ROUGHNESS = 0.1;
	METALLIC = 0.9;
	ALPHA = max(vein_mask, 0.1);
}
