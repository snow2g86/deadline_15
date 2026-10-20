shader_type canvas_item;
// 머리 조각 색 바꾸기 — mask 의 R: 120 피부 · 240 머리카락(또는 두건)
uniform sampler2D mask : filter_nearest;
uniform vec4 c_hair : source_color = vec4(1.0);
uniform vec4 c_skin : source_color = vec4(1.0);
uniform float k_hair = 0.0;
uniform float k_skin = 0.0;
uniform float ref_hair = 0.5;
uniform float ref_skin = 0.67;

vec3 recolor(vec3 c, vec3 target, float strength, float ref) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float r = l / ref;
	vec3 t = target * r;
	t = mix(t, vec3(1.0), clamp((r - 1.35) * 0.5, 0.0, 0.6));
	return mix(c, clamp(t, 0.0, 1.0), strength);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float m = texture(mask, UV).r * 255.0;
	vec3 col = src.rgb;
	if (abs(m - 240.0) < 20.0) col = recolor(col, c_hair.rgb, k_hair, ref_hair);
	else if (abs(m - 120.0) < 20.0) col = recolor(col, c_skin.rgb, k_skin, ref_skin);
	COLOR = vec4(col, src.a);
}
