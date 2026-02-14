// here's the template shader with simple wind wave effect

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv1_scale = vec2(1.0);
uniform vec2 uv1_offset;

group_uniforms wind;
uniform vec3 wind_direction = vec3(0.0, 0.0, 1.0); // you can provide this vector from shader globals
uniform float wind_freq = 1.0;
uniform float wind_strength = 0.25;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	
	float pos_offset = fract(
		NODE_POSITION_WORLD.x * 1229.0 + // multiplied by large prime numbers to keep components unique
		NODE_POSITION_WORLD.y * 2053.0 + 
		NODE_POSITION_WORLD.z * 3907.0
	);
	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float two_pi = 2.0 * PI;
	float quarter_pi = 0.25 * PI;
	vec3 wind_offset = wind_direction * sin(
		TIME * two_pi * wind_freq  // actual wave
		+ COLOR.g * two_pi // segment/mesh based offset to break unison movement
		+ pos_offset * quarter_pi // node position based offset to further break unison movement
	) * wind_strength * COLOR.r;
	
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_vertex + wind_offset, 1.0)).xyz;
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
}
