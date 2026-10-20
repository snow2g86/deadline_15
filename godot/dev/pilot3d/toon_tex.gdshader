shader_type spatial;
// 텍스처가 있는 모델(KayKit)용 셀 셰이딩 — 팔레트 아틀라스(가로 8 × 세로 4 칸, 칸 안은 세로 그라데이션)를 읽어
//  (1) 칸 단위 색 바꾸기(역할: 피부·머리카락·옷1·옷2)  (2) 칸 안 그라데이션을 N단으로 끊기  (3) 명암을 단계로 나눔
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform int tex_levels = 0;                    // 0 = 원본 그라데이션, N = 칸 안을 N단으로 끊음 (1 = 칸마다 한 색)
uniform float cell_role[32];                   // 칸 → 역할 번호 (-1 없음, 0 피부, 1 머리카락, 2 옷1, 3 옷2)
uniform float cell_lum[32];                    // 칸 평균 밝기 (그라데이션 비율 계산용)
uniform vec4 role_col[5] : source_color;
uniform bool use_roles = false;

uniform vec3 light_dir = vec3(-0.45, 0.8, 0.55);
uniform int steps : hint_range(1, 5) = 4;
uniform float t1 = 0.30;
uniform float t2 = -0.15;
uniform float t3 = -0.60;
uniform float lit_mul = 1.12;
uniform float mid_mul = 0.9;
uniform float dark_mul = 0.7;
uniform float deep_mul = 0.52;
uniform vec3 shadow_tint : source_color = vec3(0.45, 0.4, 0.6);
uniform float tint_amt = 0.2;
uniform float dither = 0.0;
uniform float brightness = 1.0;

float bayer(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int idx = q.x + q.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0 - 0.5;
}

void fragment() {
	vec2 g = vec2(UV.x * 8.0, UV.y * 4.0);
	vec2 cell = floor(g);
	vec2 loc = clamp(g - cell, 0.04, 0.96);
	vec2 uv2 = UV;
	if (tex_levels > 0) {
		float n = float(tex_levels);
		float q = (floor(loc.y * n) + 0.5) / n;
		uv2 = vec2((cell.x + 0.5) / 8.0, (cell.y + q) / 4.0);
	} else {
		uv2 = vec2((cell.x + loc.x) / 8.0, (cell.y + loc.y) / 4.0);
	}
	vec3 base = texture(albedo_tex, uv2).rgb;
	if (use_roles) {
		int ci = int(clamp(cell.x, 0.0, 7.0)) + int(clamp(cell.y, 0.0, 3.0)) * 8;
		int role = int(cell_role[ci] + 0.5);
		if (cell_role[ci] > -0.5) {
			float l = dot(base, vec3(0.3, 0.59, 0.11));
			float ratio = clamp(l / max(cell_lum[ci], 0.03), 0.35, 1.45);
			base = clamp(role_col[role].rgb * ratio, 0.0, 1.0);
		}
	}
	float nl = dot(normalize(NORMAL), normalize(light_dir));
	nl += dither * 0.18 * bayer(FRAGCOORD.xy);
	float m = mid_mul;
	if (nl > t1) {
		m = lit_mul;
	} else if (steps >= 3 && nl <= t2) {
		m = dark_mul;
		if (steps >= 4 && nl <= t3) m = deep_mul;
	} else if (steps == 2 && nl <= t2) {
		m = dark_mul;
	} else if (steps == 1) {
		m = 1.0;
	}
	vec3 col = base * m * brightness;
	float sh = clamp((1.0 - m) * 1.4, 0.0, 1.0);
	col = mix(col, col * shadow_tint * 1.6, sh * tint_amt);
	ALBEDO = col;
}
