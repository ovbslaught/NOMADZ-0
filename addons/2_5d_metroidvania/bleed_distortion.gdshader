shader_type canvas_item;

// Referenced by BleedDistortionController.gd's doc comment
// ("Attach to a full-screen ColorRect with bleed_distortion.gdshader
// assigned") but the shader file itself was never provided. Written
// fresh, matching every uniform name the controller script sets.

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale : hint_range(0.0, 1.0) = 0.0;
uniform float corruption : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.05, 0.02, 0.02, 1.0);

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    float warp = sin(uv.y * 40.0 + time_offset * 6.0) * distortion_strength * 0.01;
    uv.x += warp;

    vec4 tex = texture(TEXTURE, uv);

    float n = rand(uv * 500.0 + time_offset);
    tex.rgb = mix(tex.rgb, vec3(n), noise_scale * 0.3);

    float scan = sin(uv.y * 400.0) * 0.5 + 0.5;
    tex.rgb *= mix(1.0 - scanline_intensity, 1.0, scan);

    vec2 centered = uv - vec2(0.5);
    float vig = 1.0 - smoothstep(0.3, 0.9, length(centered));
    tex.rgb = mix(tex.rgb * (1.0 - vignette_strength), tex.rgb, vig);

    tex.rgb = mix(tex.rgb, tint_color.rgb, corruption * 0.5);

    COLOR = tex;
}
