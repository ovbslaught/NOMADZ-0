shader_type canvas_item;

// Godot 4 requires explicit screen texture sampling
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

@export_group("Tri-Render Matrix")
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform float chromatic_aberration : hint_range(0.0, 10.0, 0.1) = 2.0;
uniform float scanline_strength : hint_range(0.0, 1.0, 0.05) = 0.25;
uniform float scanline_speed : hint_range(0.0, 10.0, 0.1) = 2.0;
uniform float vignette_strength : hint_range(0.0, 3.0, 0.1) = 1.2;

void fragment() {
    // 1. Pixel-Perfect Downscaling
    // Snaps the high-res UVs to a chunky, retro grid
    vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 grid_uv = round(SCREEN_UV * res / pixel_size) * pixel_size / res;
    
    // 2. Chromatic Aberration (RGB Separation)
    // Pulls the red and blue channels apart horizontally based on the grid_uv
    vec2 offset = vec2(chromatic_aberration * SCREEN_PIXEL_SIZE.x, 0.0);
    float r = texture(screen_texture, grid_uv - offset).r;
    float g = texture(screen_texture, grid_uv).g;
    float b = texture(screen_texture, grid_uv + offset).b;
    vec3 color = vec3(r, g, b);
    
    // 3. CRT Scanlines & Phosphor Crawl
    // Uses screen space and time to generate scrolling horizontal lines
    float scanline = sin((SCREEN_UV.y - (TIME * scanline_speed * 0.01)) * res.y * 3.14159);
    scanline = (scanline * 0.5 + 0.5) * scanline_strength;
    color -= scanline;
    
    // 4. CRT Vignette (Tube screen curving/shadows)
    vec2 centered_uv = SCREEN_UV - vec2(0.5);
    float vignette = length(centered_uv);
    color *= 1.0 - (vignette * vignette_strength);
    
    COLOR = vec4(color, 1.0);
}
