shader_type canvas_item;

uniform float mask_density : hint_range(10.0, 1000.0, 1.0) = 400.0;
uniform float mask_intensity : hint_range(0.0, 1.0, 0.01) = 0.2;

uniform float convergence_intensity : hint_range(0.0, 0.1, 0.001) = 0.02;

uniform float halation_intensity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float halation_radius : hint_range(0.0, 5.0, 0.1) = 2.0;

uniform float tv_brightness : hint_range(-1.0, 1.0, 0.01) = -0.1;
uniform float tv_contrast : hint_range(0.0, 3.0, 0.01) = 1.25;
uniform float tv_saturation : hint_range(0.0, 3.0, 0.01) = 0.75;

uniform float vignette_intensity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float vignette_smoothness : hint_range(0.0, 2.0, 0.01) = 0.5;

uniform float corner_radius : hint_range(0.0, 0.5, 0.01) = 0.01;
uniform float border_thickness_horizontal : hint_range(0.0, 0.5, 0.001) = 0.006;
uniform float border_thickness_vertical : hint_range(0.0, 0.5, 0.001) = 0.008;
uniform float border_smoothness : hint_range(0.0, 0.1, 0.001) = 0.002;

void fragment() {
    vec2 base_uv = UV;
    vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	
    vec2 center_uv = base_uv - vec2(0.5);
    float dist_sq = dot(center_uv, center_uv); 
    
    // edge convergence
    vec2 convergence_offset = center_uv * dist_sq * convergence_intensity;
    float r = texture(TEXTURE, base_uv + convergence_offset).r;
    float g = texture(TEXTURE, base_uv).g;
    float b = texture(TEXTURE, base_uv - convergence_offset).b;
    vec3 base_color = vec3(r, g, b);
    float alpha = texture(TEXTURE, base_uv).a;

    // halation
    vec2 blur_step = pixel_size * halation_radius;
    vec3 bloom = base_color * 0.382928;
    bloom += texture(TEXTURE, base_uv + vec2(blur_step.x, 0.0)).rgb * 0.241732;
    bloom += texture(TEXTURE, base_uv - vec2(blur_step.x, 0.0)).rgb * 0.241732;
    bloom += texture(TEXTURE, base_uv + vec2(0.0, blur_step.y)).rgb * 0.060598;
    bloom += texture(TEXTURE, base_uv - vec2(0.0, blur_step.y)).rgb * 0.060598;
    
    vec3 final_color = base_color + (bloom * halation_intensity);

    // virtual tv settings
    final_color += tv_brightness;
    final_color = (final_color - vec3(0.5)) * tv_contrast + vec3(0.5);
    float luminance = dot(final_color, vec3(0.299, 0.587, 0.114)); // 601 luma values
    final_color = mix(vec3(luminance), final_color, tv_saturation);
    final_color = clamp(final_color, 0.0, 1.0);

    // mask
    float phase = base_uv.x * mask_density * PI * 2.0;
    vec3 mask = vec3(
        clamp(sin(phase) * 2.0, 0.0, 1.0),
        clamp(sin(phase - 2.09439) * 2.0, 0.0, 1.0), // radian offsets
        clamp(sin(phase - 4.18879) * 2.0, 0.0, 1.0)
    );
    vec3 mask_overlay = mix(vec3(1.0), mask, mask_intensity);
    final_color *= mask_overlay;

    // vignette
    float dist = length(center_uv);
    float vig = 1.0 - smoothstep(1.0 - vignette_smoothness, 1.0, dist * 1.414);
    final_color = mix(final_color, final_color * vig, vignette_intensity);

    // black glass tube border
    vec2 aspect = vec2(pixel_size.y / pixel_size.x, 1.0);
    vec2 aspect_uv = center_uv * aspect;
    vec2 border_thickness = vec2(border_thickness_horizontal, border_thickness_vertical);
    vec2 box_size = (vec2(0.5) - border_thickness) * aspect;
    vec2 q = abs(aspect_uv) - box_size + vec2(corner_radius);
    float box_dist = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - corner_radius;
    float border_mask = 1.0 - smoothstep(0.0, border_smoothness, box_dist);
    final_color *= border_mask;

    COLOR = vec4(final_color, alpha);
}