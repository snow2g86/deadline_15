shader_type canvas_item;
// 유닛 그림: 웹 .u-icon 의 CSS filter 를 흉내 — 바닥 그림자 drop-shadow(0 2px 4px rgba(0,0,0,.8)) +
// 테두리 빛(적 붉은빛·현재 차례 금빛) + 회색(기절) + 흰 번쩍임(피격·쓰러짐)
// 스프라이트 시트에서 한 칸(region)만 쓰므로 그 밖의 픽셀은 투명으로 본다 (빛이 옆 칸 그림을 줍지 않게)
// (TEXTURE 를 함수 인자로 넘기면 Godot 4.5 셰이더 변환기가 오류를 내서 표본 반복을 fragment 안에 둠)

uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);   // 쓰는 칸 (UV: x0, y0, x1, y1)
uniform vec4 glow_color : source_color = vec4(0.0);
uniform float glow_px = 5.0;      // 빛 반경 (텍스처 픽셀)
uniform float shadow_px = 4.0;    // 그림자 흐림 반경 (텍스처 픽셀)
uniform float shadow_dy = 2.0;    // 그림자 아래로 (텍스처 픽셀)
uniform float gray = 0.0;
uniform float flash = 0.0;
uniform float body_alpha = 1.0;   // 그림만 반투명 (숲 안)

float inside(vec2 uv) {
	return (uv.x < region.x || uv.y < region.y || uv.x > region.z || uv.y > region.w) ? 0.0 : 1.0;
}

// fragment 의 COLOR 는 이미 텍스처 색이 곱해진 값이라, 정점 색(modulate)은 vertex 에서 따로 받아 둠
varying vec4 v_col;

void vertex() {
	v_col = COLOR;
}

void fragment() {
	vec4 mod_col = v_col;
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV) * inside(UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(c.rgb, vec3(lum), gray);
	rgb = mix(rgb, vec3(1.0), flash);
	float ba = c.a * body_alpha;
	// 그림자·빛: 둘레 8방향 × 2겹 표본의 평균 알파
	vec2 su = UV - vec2(0.0, shadow_dy) * px;
	vec2 sr = px * shadow_px;
	vec2 gr = px * glow_px;
	float sa = 0.0;
	float ga = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		vec2 d = vec2(cos(ang), sin(ang));
		vec2 p1 = su + d * sr;
		vec2 p2 = su + d * sr * 0.5;
		sa += texture(TEXTURE, p1).a * inside(p1) + texture(TEXTURE, p2).a * inside(p2);
		vec2 q1 = UV + d * gr;
		vec2 q2 = UV + d * gr * 0.5;
		ga += texture(TEXTURE, q1).a * inside(q1) + texture(TEXTURE, q2).a * inside(q2);
	}
	sa = clamp(sa / 16.0 * 1.6, 0.0, 1.0) * 0.8 * body_alpha;
	ga = clamp(ga / 16.0 * 1.3, 0.0, 1.0) * glow_color.a;
	// 아래부터 차례로 겹치기 (premultiplied)
	vec4 acc = vec4(0.0, 0.0, 0.0, sa);
	acc = vec4(glow_color.rgb * ga, ga) + acc * (1.0 - ga);
	acc = vec4(rgb * ba, ba) + acc * (1.0 - ba);
	COLOR = vec4(acc.rgb / max(acc.a, 0.0001), acc.a) * mod_col;
}
