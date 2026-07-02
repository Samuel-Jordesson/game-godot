shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.05, 0.3, 0.4, 0.75);
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;

uniform sampler2D normal_map_1 : hint_normal;
uniform sampler2D normal_map_2 : hint_normal;

uniform vec2 wave_dir_1 = vec2(0.2, 0.1);
uniform vec2 wave_dir_2 = vec2(-0.1, 0.2);
uniform float time_scale = 0.05;
uniform float normal_scale = 1.0;

// Refração e Profundidade
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

uniform float edge_fade : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	// Movimentação das ondas usando o tempo
	vec2 time1 = TIME * time_scale * wave_dir_1;
	vec2 time2 = TIME * time_scale * wave_dir_2;
	
	// Mistura de dois mapas normais para um efeito de onda caótico
	vec3 n1 = texture(normal_map_1, UV * 4.0 + time1).rgb;
	vec3 n2 = texture(normal_map_2, UV * 4.0 + time2).rgb;
	vec3 normal_blend = mix(n1, n2, 0.5);
	
	// Cálculo de profundidade para suavizar as bordas (Proximity Fade)
	float depth_tex = textureLod(DEPTH_TEXTURE, SCREEN_UV, 0.0).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
	world_pos.xyz /= world_pos.w;
	float depth_blend = clamp((VERTEX.z - world_pos.z) / max(edge_fade, 0.001), 0.0, 1.0);
	
	// Refração distorcendo o fundo
	vec2 ref_ofs = SCREEN_UV - normal_blend.xy * 0.02;
	vec3 ref_color = textureLod(SCREEN_TEXTURE, ref_ofs, 0.0).rgb;
	
	// Mistura a cor da água com a refração do fundo e aplica o fade na borda
	vec3 final_color = mix(ref_color, water_color.rgb, water_color.a);
	
	ALBEDO = final_color;
	ALPHA = depth_blend;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL_MAP = normal_blend;
	NORMAL_MAP_DEPTH = normal_scale;
}
