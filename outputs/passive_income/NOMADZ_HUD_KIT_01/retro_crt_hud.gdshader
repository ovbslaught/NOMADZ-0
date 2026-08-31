shader_type canvas_item;

uniform vec4 scanline_color : source_color = vec4(0.0, 1.0, 0.9, 0.15);
uniform float scanline_count : hint_range(50.0, 800.0) = 240.0;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.005;

void fragment() {
    vec2 uv = UV;
    float r = texture(TEXTURE, uv + vec2(chromatic_aberration, 0.0)).r;
    float g = texture(TEXTURE, uv).g;
    float b = texture(TEXTURE, uv - vec2(chromatic_aberration, 0.0)).b;
    float a = texture(TEXTURE, uv).a;
    vec4 col = vec4(r, g, b, a);
    
    float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
    col = mix(col, scanline_color, scanline * scanline_color.a);
    
    float d = distance(uv, vec2(0.5));
    col.rgb *= smoothstep(0.8, 0.8 - vignette_intensity, d * (0.8 + vignette_intensity));
    
    COLOR = col;
}
