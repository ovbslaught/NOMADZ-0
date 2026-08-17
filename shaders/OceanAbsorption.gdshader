shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

@export_group("Beer-Lambert Absorption")
// Red is absorbed fastest, leaving blue/green for that terrifying deep ocean look
uniform vec3 absorption_color = vec3(0.85, 0.25, 0.05); 
uniform float density : hint_range(0.0, 5.0) = 1.5;

@export_group("Fluid Wobble")
uniform float wave_speed : hint_range(0.0, 5.0) = 2.0;
uniform float wave_strength : hint_range(0.0, 0.1) = 0.01;

void fragment() {
    // 1. Hydrodynamic Wobble (Screen distortion)
    vec2 uv = SCREEN_UV;
    uv.x += sin(TIME * wave_speed + uv.y * 10.0) * wave_strength;
    uv.y += cos(TIME * wave_speed + uv.x * 10.0) * wave_strength;
    
    vec3 color = texture(screen_texture, uv).rgb;
    
    // 2. Depth Calculation (How far away is the object we are looking at?)
    float raw_depth = texture(depth_texture, uv).x;
    // Convert to linear depth
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float linear_depth = -view.z;
    
    // 3. Beer-Lambert Law Application (Exponential decay based on depth and density)
    // Formula: Transmittance = e^(-absorption_coefficient * distance)
    vec3 transmittance = exp(-absorption_color * density * linear_depth * 0.1);
    
    // Mix the original color with the deep ocean tint based on distance
    vec3 ocean_base = vec3(0.01, 0.05, 0.15); // The crushing dark blue at infinity
    color = mix(ocean_base, color * transmittance, transmittance);
    
    COLOR = vec4(color, 1.0);
}
