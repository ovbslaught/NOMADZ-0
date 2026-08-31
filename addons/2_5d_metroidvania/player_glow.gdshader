shader_type canvas_item;

// Referenced by PlayerShaderController.gd via set_shader_parameter().
// This shader itself was never provided anywhere in the source files —
// written fresh so PlayerShaderController has a real material to drive.

uniform float fuel_level : hint_range(0.0, 1.0) = 1.0;
uniform float signal_level : hint_range(0.0, 1.0) = 0.0;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float jetpack_active : hint_range(0.0, 1.0) = 0.0;
uniform float corruption : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    vec3 signal_tint = vec3(0.4, 0.8, 1.0) * signal_level * 0.6;
    vec3 fuel_warn = vec3(1.0, 0.6, 0.1) * (1.0 - fuel_level) * step(fuel_level, 0.15);
    vec3 corrupt_tint = vec3(0.6, 0.1, 0.3) * corruption;
    vec3 jet_glow = vec3(0.3, 0.6, 1.0) * jetpack_active * 0.3;

    vec3 color = tex.rgb + signal_tint + fuel_warn + corrupt_tint + jet_glow;
    color = mix(color, vec3(1.0), damage_flash * 0.8);

    COLOR = vec4(color, tex.a);
}
