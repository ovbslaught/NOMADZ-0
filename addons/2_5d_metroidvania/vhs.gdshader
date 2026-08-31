shader_type canvas_item;

uniform float scanline_count : hint_range(0.0, 1080.0, 1.0) = 288.0; 
uniform float scanline_intensity : hint_range(0.0, 1.0, 0.01) = 0.25;

uniform float luminance_blur : hint_range(0.0, 5.0, 0.1) = 1.2; 
uniform float chroma_bleed : hint_range(0.0, 10.0, 0.1) = 4.0; 
uniform float chroma_shift : hint_range(0.0, 10.0, 0.1) = 2.0; 

uniform float tracking_height : hint_range(0.0, 1.0, 0.01) = 0.4; 
uniform float tracking_distortion : hint_range(0.0, 1.0, 0.01) = 0.01; 
uniform float tracking_noise : hint_range(0.0, 1.0, 0.01) = 0.6; 

uniform float wobble_intensity : hint_range(0.0, 0.1, 0.001) = 0.002;
uniform float wobble_frequency : hint_range(0.0, 100.0, 0.1) = 4.0; 

uniform float tape_noise_intensity : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float tape_noise_color : hint_range(0.0, 1.0, 0.01) = 0.3; 

uniform float chroma_streak_frequency : hint_range(0.0, 1.0, 0.001) = 0.02;
uniform float chroma_streak_intensity : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float chroma_streak_height : hint_range(0.0, 1.0, 0.001) = 0.02;

uniform float dropout_frequency : hint_range(0.0, 1.0, 0.01) = 0.02;
uniform float dropout_intensity : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float dropout_height : hint_range(0.0, 1.0, 0.001) = 0.2;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float smooth_noise(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f); 
    return mix(random(vec2(i, i)), random(vec2(i + 1.0, i + 1.0)), u);
}

void fragment() {
    vec2 pixel_size = TEXTURE_PIXEL_SIZE;
    vec2 time_offset = vec2(random(vec2(TIME, 0.0)), random(vec2(TIME, 1.0)));
    
	// tape wobble
    float wow = smooth_noise(UV.y * wobble_frequency + TIME * 2.0) * 2.0 - 1.0;
    float flutter = smooth_noise(UV.y * wobble_frequency * 3.0 - TIME * 4.0) * 2.0 - 1.0;
    float total_wobble = (wow + flutter * 0.4) * wobble_intensity;

    // tracking distortion
    float bottom_mask = smoothstep(1.0 - tracking_height, 1.0, UV.y);
    float tear_noise = random(vec2(UV.y * 200.0, TIME * 10.0)); 
    float skew = random(vec2(TIME * 2.0, 0.0)) - 0.5; 
    float head_shift = ((tear_noise - 0.5) * 0.5 + skew * 0.5) * tracking_distortion * bottom_mask;
    
    vec2 base_uv = UV + vec2(head_shift + total_wobble, 0.0);
    
    // color bleed
    vec2 blur_step = vec2(luminance_blur * pixel_size.x, 0.0);
    vec2 bleed_step = vec2((luminance_blur + chroma_bleed) * pixel_size.x, 0.0);
    vec2 shift = vec2(chroma_shift * pixel_size.x, 0.0);
    
    vec3 color = vec3(0.0);
    float w0 = 0.4026; // weights (w0 + 2 x w1 + 2 x w2 = 1.0)
	float w1 = 0.2442; 
	float w2 = 0.0545;
    
    color.r += texture(TEXTURE, base_uv + shift).r * w0;
    color.g += texture(TEXTURE, base_uv).g * w0;
    color.b += texture(TEXTURE, base_uv - shift).b * w0;
    
    color.r += texture(TEXTURE, base_uv + bleed_step + shift).r * w1;
    color.g += texture(TEXTURE, base_uv + blur_step).g * w1;
    color.b += texture(TEXTURE, base_uv + bleed_step - shift).b * w1;
    
    color.r += texture(TEXTURE, base_uv - bleed_step + shift).r * w1;
    color.g += texture(TEXTURE, base_uv - blur_step).g * w1;
    color.b += texture(TEXTURE, base_uv - bleed_step - shift).b * w1;
    
    color.r += texture(TEXTURE, base_uv + 2.0 * bleed_step + shift).r * w2;
    color.g += texture(TEXTURE, base_uv + 2.0 * blur_step).g * w2;
    color.b += texture(TEXTURE, base_uv + 2.0 * bleed_step - shift).b * w2;
	
    color.r += texture(TEXTURE, base_uv - 2.0 * bleed_step + shift).r * w2;
    color.g += texture(TEXTURE, base_uv - 2.0 * blur_step).g * w2;
    color.b += texture(TEXTURE, base_uv - 2.0 * bleed_step - shift).b * w2;

    float alpha = texture(TEXTURE, base_uv).a;

    // tracking noise
    float head_static = random(base_uv + time_offset);
    color = mix(color, vec3(head_static), bottom_mask * tracking_noise * tear_noise);
    float fps_time = floor(TIME * 25.0);
    vec2 frame_offset = vec2(random(vec2(fps_time, 0.0)), random(vec2(fps_time, 1.0)));

    // chroma loss streaks
    vec2 chroma_grid = vec2(floor(UV.x * 1.0), floor(UV.y / max(0.0001, chroma_streak_height)));
    float chroma_val = random(chroma_grid + frame_offset * 50.0);
    float is_chroma_streak = step(1.0 - chroma_streak_frequency, chroma_val);
    vec3 shifted_chroma = vec3(color.g, color.b, color.r);
    float color_coin_flip = step(0.5, random(chroma_grid + fps_time));
    shifted_chroma = mix(shifted_chroma, vec3(color.b, color.r, color.g), color_coin_flip);
    color = mix(color, shifted_chroma, is_chroma_streak * chroma_streak_intensity);

    // dropouts
    float dropout_grid = floor(UV.y / max(0.0001, dropout_height));
    float dropout_val = random(vec2(dropout_grid, frame_offset.x));
    float is_dropout = step(1.0 - dropout_frequency, dropout_val);
    float dropout_static = random(UV + frame_offset * 100.0);
    color = mix(color, vec3(dropout_static), is_dropout * dropout_intensity);

    // noise/snow
    vec2 noise_uv = base_uv * vec2(400.0, 300.0); 
    float noise_r = random(noise_uv + time_offset);
    float noise_g = random(noise_uv + time_offset * 1.1);
    float noise_b = random(noise_uv + time_offset * 1.2);
    vec3 luma_noise = vec3(noise_g);
    vec3 chroma_noise = vec3(noise_r, noise_g, noise_b);
    vec3 final_noise = mix(luma_noise, chroma_noise, tape_noise_color);
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    float noise_shift = mix(0.0, 0.5, luminance);
    float noise_volume = mix(tape_noise_intensity * 2.0, tape_noise_intensity, luminance);
    color += (final_noise - noise_shift) * noise_volume;
    color = clamp(color, 0.0, 1.0);

    // scanlines
    float scanline_wave = sin(UV.y * scanline_count * PI * 2.0);
    float scanline_normalized = scanline_wave * 0.5 + 0.5;
    float scanline_multiplier = mix(1.0 - scanline_intensity, 1.0, scanline_normalized);

    COLOR = vec4(color * scanline_multiplier, alpha);
}