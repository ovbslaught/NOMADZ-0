shader_type spatial;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform float color_depth : hint_range(1.0, 32.0) = 8.0;
uniform float dither_size : hint_range(1.0, 8.0) = 2.0;

const mat4 DITHER_MATRIX = mat4(
    vec4(0.0, 0.5, 0.125, 0.625),
    vec4(0.75, 0.25, 0.875, 0.375),
    vec4(0.1875, 0.6875, 0.0625, 0.5625),
    vec4(0.9375, 0.4375, 0.8125, 0.3125)
);

void fragment() {
    vec2 screen_uv = SCREEN_UV;
    vec3 screen_color = texture(SCREEN_TEXTURE, screen_uv).rgb;
    
    ivec2 dither_coord = ivec2(mod(FRAGCOORD.xy / dither_size, 4.0));
    float dither_val = DITHER_MATRIX[dither_coord.x][dither_coord.y];
    
    screen_color += (dither_val - 0.5) / color_depth;
    screen_color = floor(screen_color * color_depth) / color_depth;
    
    ALBEDO = screen_color;
}
