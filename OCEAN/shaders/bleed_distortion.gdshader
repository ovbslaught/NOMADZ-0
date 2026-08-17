// bleed_distortion.gdshader
// NOMADZ: Signal Descent
// Full-screen post-process: Signalverse bleed distortion.
// CRT scanlines + chromatic aberration + noise glitch.
// Attach to a full-screen ColorRect with CanvasLayer.
// VultureCode / Sol / NOMADZ Universe

shader_type canvas_item;

// ─── UNIFORMS ────────────────────────────────────────────────────────────────
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_intensity  : hint_range(0.0, 1.0) = 0.15;
uniform float aberration_amount   : hint_range(0.0, 0.02) = 0.003;
uniform float noise_scale         : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_strength   : hint_range(0.0, 1.0) = 0.35;
uniform float time_offset         : hint_range(0.0, 100.0) = 0.0;
uniform vec4  tint_color          : source_color = vec4(0.02, 0.02, 0.05, 1.0);
uniform float corruption          : hint_range(0.0, 1.0) = 0.0;

// ─── NOISE ────────────────────────────────────────────────────────────────────
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// ─── FRAGMENT ─────────────────────────────────────────────────────────────────
void fragment() {
    vec2 uv = UV;
    float t = TIME + time_offset;

    // ── Signalverse glitch displacement ──────────────────────────────────────
    if (distortion_strength > 0.001) {
        float glitch_band = step(0.97, sin(uv.y * 80.0 + t * 12.0));
        float glitch_t    = noise(vec2(t * 5.0, floor(uv.y * 40.0)));
        float disp_x      = (glitch_t - 0.5) * distortion_strength * 0.06 * glitch_band;
        uv.x += disp_x;

        // Vertical tear
        float tear_band = step(0.995, sin(t * 3.0 + uv.x * 20.0));
        uv.y += (rand(vec2(t, uv.x)) - 0.5) * 0.008 * distortion_strength * tear_band;
    }

    // ── Corruption warping ────────────────────────────────────────────────────
    if (corruption > 0.01) {
        float warp = sin(uv.y * 30.0 + t * 2.0) * corruption * 0.004;
        uv.x += warp;
        float warp2 = cos(uv.x * 25.0 + t * 1.5) * corruption * 0.003;
        uv.y += warp2;
    }

    // Clamp UV to prevent wrap artifacts
    uv = clamp(uv, vec2(0.0), vec2(1.0));

    // ── Chromatic aberration ──────────────────────────────────────────────────
    float ab = aberration_amount + corruption * 0.005;
    vec4 col_r = texture(TEXTURE, uv + vec2( ab, 0.0));
    vec4 col_g = texture(TEXTURE, uv);
    vec4 col_b = texture(TEXTURE, uv + vec2(-ab, 0.0));
    vec4 col   = vec4(col_r.r, col_g.g, col_b.b, col_g.a);

    // ── CRT Scanlines ─────────────────────────────────────────────────────────
    float scanline = sin(uv.y * 600.0) * 0.5 + 0.5;
    col.rgb -= scanline * scanline_intensity;

    // ── Screen noise ─────────────────────────────────────────────────────────
    if (noise_scale > 0.001) {
        float n = rand(uv + vec2(t * 0.1)) * noise_scale;
        col.rgb += vec3(n - noise_scale * 0.5);
    }

    // ── Vignette ──────────────────────────────────────────────────────────────
    vec2 vig_uv = uv * (1.0 - uv.yx);
    float vig   = vig_uv.x * vig_uv.y * 15.0;
    vig         = pow(vig, 0.3 + corruption * 0.4);
    vig         = clamp(vig, 0.0, 1.0);
    col.rgb     *= mix(1.0 - vignette_strength, 1.0, vig);

    // ── Corruption tint ───────────────────────────────────────────────────────
    col.rgb = mix(col.rgb, tint_color.rgb, corruption * 0.25);

    // ── Edge darken during heavy bleed ────────────────────────────────────────
    if (distortion_strength > 0.5) {
        float edge = 1.0 - smoothstep(0.0, 0.1, min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y)));
        col.rgb *= 1.0 - edge * distortion_strength * 0.5;
    }

    COLOR = col;
}
