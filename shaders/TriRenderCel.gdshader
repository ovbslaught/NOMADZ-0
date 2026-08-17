shader_type spatial;
// Disable Godot's default lighting so we can draw our own hard shadows
render_mode diffuse_toon, specular_toon;

@export_group("Base Properties")
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;

@export_group("Cel Shading")
// The "Tri" in Tri-Render - snaps lighting into 3 distinct hard bands
uniform int color_bands : hint_range(1, 10) = 3; 
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.2; // How dark the darkest shadow gets

@export_group("Atomic Rim Light")
uniform float rim_thickness : hint_range(0.0, 1.0) = 0.2;
// Defaulting to a neon cyan to fit the retro-cyberpunk vibe
uniform vec4 rim_color : source_color = vec4(0.0, 1.0, 1.0, 1.0); 

void fragment() {
    ALBEDO = albedo.rgb;
    METALLIC = metallic;
    ROUGHNESS = roughness;
}

void light() {
    // 1. Calculate standard directional light hitting the surface
    float NdotL = dot(NORMAL, LIGHT);
    float diffuse_light = clamp(NdotL, 0.0, 1.0);
    
    // 2. Snap the light into hard color bands (The Cel-Shade effect)
    float banded_diffuse = floor(diffuse_light * float(color_bands)) / float(color_bands);
    
    // 3. Ensure shadows don't go pitch black
    banded_diffuse = max(banded_diffuse, shadow_floor);
    
    // 4. Calculate Synthwave Rim Lighting (edges catching light)
    float VdotN = clamp(dot(VIEW, NORMAL), 0.0, 1.0);
    float rim_math = 1.0 - VdotN;
    // Only show rim light on the side where the light source is actually hitting
    float rim_intensity = smoothstep(1.0 - rim_thickness, 1.0, rim_math) * clamp(NdotL, 0.0, 1.0);
    vec3 final_rim = rim_color.rgb * rim_intensity;

    // Output final lit color
    DIFFUSE_LIGHT += clamp((banded_diffuse * ALBEDO * LIGHT_COLOR) + final_rim, 0.0, 1.0);
}
