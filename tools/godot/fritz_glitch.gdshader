shader_type spatial;
// fritz_glitch.gdshader — the living glitch. Assign to Fritz's material.
// tune_amount = 0 idle, crank to 1 during blink.

uniform sampler2D albedo_tex : source_color;
uniform vec4 tint : source_color = vec4(0.2, 0.4, 1.0, 1.0);
uniform float glitch_amount : hint_range(0.0, 1.0) = 0.15;
uniform float band_size : hint_range(2.0, 64.0) = 16.0;
uniform float time_scale = 8.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
    float t = TIME * time_scale;
    // horizontal bands, each band jitters independently
    float band = floor(UV.y * band_size);
    float jitter = (hash(band + floor(t)) - 0.5) * glitch_amount * 0.08;

    // occasional full-row hard tear
    float tear = step(0.97, hash(band * 7.0 + floor(t * 2.0))) * glitch_amount;

    vec2 uv_r = UV + vec2(jitter + tear * 0.15, 0.0);
    vec2 uv_g = UV + vec2(jitter, 0.0);
    vec2 uv_b = UV + vec2(jitter - tear * 0.1, 0.0);

    vec4 c;
    c.r = texture(albedo_tex, uv_r).r;
    c.g = texture(albedo_tex, uv_g).g;
    c.b = texture(albedo_tex, uv_b).b;
    c.a = 1.0;

    // blue glitch tint mixing in with the chrome
    vec3 col = mix(c.rgb, tint.rgb, 0.25 + glitch_amount * 0.35);

    // scanline pulse
    col *= 0.9 + 0.1 * sin(UV.y * 200.0 + t * 3.0);

    ALBEDO = col;
    METALLIC = 0.9;
    ROUGHNESS = 0.15 - glitch_amount * 0.1;
    EMISSION = tint.rgb * glitch_amount * 0.6;
}
