// bioluminescent_glow.gdshader
// NOMADZ: Signal Descent
// Animated bioluminescent glow for floor/wall organisms.
// Reacts to player proximity and signal pulse events.
// Attach to TileMap or Sprite2D layers.
// VultureCode / Sol / NOMADZ Universe

shader_type canvas_item;

uniform float pulse_speed     : hint_range(0.1, 5.0) = 0.8;
uniform float pulse_amplitude : hint_range(0.0, 1.0) = 0.3;
uniform float glow_intensity  : hint_range(0.0, 3.0) = 1.2;
uniform vec4  base_color      : source_color = vec4(0.1, 0.6, 0.4, 1.0);
uniform vec4  alert_color     : source_color = vec4(0.8, 0.1, 0.05, 1.0);
uniform float alert_level     : hint_range(0.0, 1.0) = 0.0;
uniform float player_distance : hint_range(0.0, 300.0) = 300.0;
uniform float proximity_radius: hint_range(50.0, 300.0) = 120.0;
uniform float corruption      : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.01) discard;

    float t = TIME;

    // ── Base pulse (4-second rhythm matching lore) ───────────────────────────
    float pulse_phase = sin(t * pulse_speed * TAU / 4.0);
    float pulse       = 1.0 + pulse_phase * pulse_amplitude;

    // ── Proximity response ────────────────────────────────────────────────────
    float proximity = 1.0 - clamp(player_distance / proximity_radius, 0.0, 1.0);
    float reaction  = proximity * 0.4;

    // ── Alert state (triggered by fast player movement or signal pulse) ───────
    vec4 current_color = mix(base_color, alert_color, alert_level);

    // ── Corruption darkens the glow, makes it flicker ────────────────────────
    float flicker = 1.0;
    if (corruption > 0.3) {
        float f = sin(t * 15.0 + UV.x * 30.0) * corruption * 0.3;
        flicker = 1.0 - f;
    }

    // ── Compose ───────────────────────────────────────────────────────────────
    vec4 result = tex * current_color;
    result.rgb *= glow_intensity * pulse * (1.0 + reaction) * flicker;

    // ── Edge glow ─────────────────────────────────────────────────────────────
    float edge_dist = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
    float edge_glow = 1.0 - smoothstep(0.0, 0.15, edge_dist);
    result.rgb += current_color.rgb * edge_glow * 0.6 * pulse;

    COLOR = result;
}
