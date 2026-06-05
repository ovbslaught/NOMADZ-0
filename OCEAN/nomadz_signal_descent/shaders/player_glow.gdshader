// player_glow.gdshader
// NOMADZ: Signal Descent
// NORA's suit glow. Reacts to: fuel level, signal meter, damage state, jetpack.
// Assign to Player's AnimatedSprite2D material.
// VultureCode / Sol / NOMADZ Universe

shader_type canvas_item;

uniform float fuel_level     : hint_range(0.0, 1.0) = 1.0;
uniform float signal_level   : hint_range(0.0, 1.0) = 0.0;
uniform float damage_flash   : hint_range(0.0, 1.0) = 0.0;
uniform float jetpack_active : hint_range(0.0, 1.0) = 0.0;
uniform float corruption     : hint_range(0.0, 1.0) = 0.0;
uniform vec4  suit_base_color: source_color = vec4(0.15, 0.55, 0.85, 1.0);
uniform vec4  fuel_low_color : source_color = vec4(0.9, 0.2, 0.05, 1.0);
uniform vec4  signal_color   : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform vec4  jetpack_color  : source_color = vec4(0.4, 0.9, 1.0, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.01) discard;

    float t = TIME;

    // ── Base suit tint ────────────────────────────────────────────────────────
    vec4 base = tex * suit_base_color;

    // ── Fuel depletion: suit dims and shifts red ──────────────────────────────
    vec4 suit_color = mix(fuel_low_color, suit_base_color, fuel_level);
    base = tex * suit_color;

    // ── Signal meter: edge glow brightens ────────────────────────────────────
    float edge_dist = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
    float edge_glow = (1.0 - smoothstep(0.0, 0.12, edge_dist)) * signal_level;
    base.rgb += signal_color.rgb * edge_glow * 0.8;

    // ── Jetpack thrust: underside bright burst ────────────────────────────────
    if (jetpack_active > 0.5) {
        float underside = smoothstep(0.3, 0.9, UV.y);
        float thrust    = sin(t * 25.0) * 0.5 + 0.5;
        base.rgb += jetpack_color.rgb * underside * thrust * 0.6;
    }

    // ── Damage flash: full white flash ────────────────────────────────────────
    base.rgb = mix(base.rgb, vec3(1.0), damage_flash * 0.9);

    // ── Corruption shimmer: slight distortion at high corruption ──────────────
    if (corruption > 0.4) {
        float shimmer = sin(UV.y * 40.0 + t * 8.0) * (corruption - 0.4) * 0.15;
        base.rgb += vec3(shimmer * 0.5, shimmer * 0.1, shimmer * 0.2);
    }

    // ── Fuel low pulse warning ────────────────────────────────────────────────
    if (fuel_level < 0.15) {
        float warn_pulse = sin(t * 10.0) * 0.5 + 0.5;
        base.rgb = mix(base.rgb, fuel_low_color.rgb, warn_pulse * 0.4);
    }

    COLOR = base;
}
