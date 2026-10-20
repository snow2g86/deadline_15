shader_type spatial;
// 도트풍 셀 셰이딩 — 빛은 화면(카메라) 기준으로 고정, 명암은 단계로 나눔
// 채널(COLOR.r*16): 0 피부 1 머리카락 2 옷1 3 옷2 4 금속 5 가죽 6 나무 7 눈(어두움) 8 흰색 9 볼터치
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 c_skin : source_color = vec3(0.93, 0.72, 0.58);
uniform vec3 c_hair : source_color = vec3(0.35, 0.22, 0.12);
uniform vec3 c_cloth1 : source_color = vec3(0.7, 0.2, 0.2);
uniform vec3 c_cloth2 : source_color = vec3(0.25, 0.2, 0.18);
uniform vec3 c_metal : source_color = vec3(0.65, 0.68, 0.72);
uniform vec3 c_leather : source_color = vec3(0.4, 0.26, 0.15);
uniform vec3 c_wood : source_color = vec3(0.5, 0.35, 0.2);
uniform vec3 c_eye : source_color = vec3(0.1, 0.07, 0.07);
uniform vec3 c_white : source_color = vec3(0.92, 0.92, 0.9);
uniform vec3 c_blush : source_color = vec3(0.9, 0.45, 0.4);

uniform vec3 light_dir = vec3(-0.45, 0.8, 0.55);   // 화면 기준 (왼쪽 위 앞)
uniform int steps : hint_range(2, 5) = 3;           // 명암 단계 수
uniform float t1 = 0.30;                            // 밝음 경계 (N·L)
uniform float t2 = -0.15;                           // 어둠 경계
uniform float t3 = -0.60;
uniform float lit_mul = 1.18;
uniform float mid_mul = 0.9;
uniform float dark_mul = 0.68;
uniform float deep_mul = 0.5;
uniform vec3 shadow_tint : source_color = vec3(0.45, 0.4, 0.6);   // 그림자에 섞는 차가운 색
uniform float tint_amt = 0.22;
uniform float dither = 0.0;                         // 0~1 경계 점묘(도트 디더)

varying float ch;

vec3 pick(float id) {
	int i = int(id + 0.5);
	if (i == 0) return c_skin;
	if (i == 1) return c_hair;
	if (i == 2) return c_cloth1;
	if (i == 3) return c_cloth2;
	if (i == 4) return c_metal;
	if (i == 5) return c_leather;
	if (i == 6) return c_wood;
	if (i == 7) return c_eye;
	if (i == 8) return c_white;
	return c_blush;
}

float bayer(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int idx = q.x + q.y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0 - 0.5;
}

void vertex() {
	ch = COLOR.r * 16.0;
}

void fragment() {
	vec3 base = pick(ch);
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
	}
	vec3 col = base * m;
	float sh = clamp((1.0 - m) * 1.4, 0.0, 1.0);
	col = mix(col, col * shadow_tint * 1.6, sh * tint_amt);
	ALBEDO = col;
}
