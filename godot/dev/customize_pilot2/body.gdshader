shader_type canvas_item;
// 시범 2차 — 기사 동작 시트(그대로) 위에서 영역 마스크로 색·무늬·의상을 바꾸고, 머리를 지움
//  mask 시트(같은 크기): R = 영역(40 단위: 1 갑옷·2 천·3 피부·4 가죽·5 윤곽선) · G = 머리 지움 · B = 몸통 덮기
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform vec2 frame_origin = vec2(0.0);     // 시트 안에서 이 칸의 왼쪽 위 (px)
uniform vec4 c_metal : source_color = vec4(1.0);
uniform vec4 c_red : source_color = vec4(1.0);
uniform vec4 c_skin : source_color = vec4(1.0);
uniform vec4 c_leather : source_color = vec4(1.0);
uniform vec4 k_str = vec4(0.0);            // 바꾸는 세기 (갑옷, 천, 피부, 가죽) — 0 이면 원래 색 그대로
uniform vec4 ref_lum = vec4(0.49, 0.23, 0.60, 0.16);   // 영역별 평균 명도 (명도를 보존하며 곱할 때 나눔)
uniform bool head_swap = false;            // 참이면 마스크 G(원래 머리·깃털)를 지움
uniform vec3 torso = vec3(79.5, 104.5, 1.0);  // 몸통 기준점 x, y, 크기 — 무늬·의상이 몸을 따라가게
uniform int pattern = 0;                   // 0 없음 1 줄 2 바둑 3 가장자리 장식 4 가슴 문양
uniform vec4 pat_a : source_color = vec4(0.95, 0.8, 0.3, 1.0);
uniform sampler2D cos_tex : filter_nearest;
uniform bool cos_on = false;
uniform vec2 cos_size = vec2(40.0, 62.0);

vec3 recolor(vec3 c, vec3 target, float strength, float ref) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float r = l / ref;                                  // 이 영역 평균 대비 밝기 (명암 보존)
	vec3 t = target * r;
	t = mix(t, vec3(1.0), clamp((r - 1.35) * 0.5, 0.0, 0.6));   // 가장 밝은 반사는 흰빛으로
	return mix(c, clamp(t, 0.0, 1.0), strength);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec4 m = texture(mask, UV);
	vec3 col = src.rgb;
	float a = src.a;
	int cls = int(floor(m.r * 255.0 / 40.0 + 0.5));
	vec2 sheet_px = vec2(textureSize(TEXTURE, 0));
	vec2 p = UV * sheet_px - frame_origin;           // 이 칸 안 좌표
	vec2 q = (p - torso.xy) / torso.z;                // 몸통 기준 좌표 (원래 크기 단위)
	if (cls == 1) col = recolor(col, c_metal.rgb, k_str.x, ref_lum.x);
	else if (cls == 2) col = recolor(col, c_red.rgb, k_str.y, ref_lum.y);
	else if (cls == 3) col = recolor(col, c_skin.rgb, k_str.z, ref_lum.z);
	else if (cls == 4) col = recolor(col, c_leather.rgb, k_str.w, ref_lum.w);
	// 무늬 — 천 영역(2)과, 몸통 덮기 영역 안의 갑옷(가슴판을 천 조끼로 바꿈)에 얹음. 원래 명암을 곱해서 윤곽·주름 보존
	bool chest = m.b > 0.5 && !cos_on;
	if (pattern > 0 && pattern < 4 && chest && cls == 1) {
		col = recolor(src.rgb, c_red.rgb, 1.0, ref_lum.x);       // 가슴판 → 천 (명암 보존)
		cls = 2;
	}
	if (pattern > 0 && cls >= 1 && cls <= 2) {
		float l = dot(src.rgb, vec3(0.299, 0.587, 0.114));
		float on = 0.0;
		if (pattern == 1 && cls == 2) on = step(0.5, fract((q.x + q.y) / 5.0));
		else if (pattern == 2 && cls == 2) on = abs(step(0.5, fract(q.x / 6.0)) - step(0.5, fract(q.y / 6.0)));
		else if (pattern == 3 && cls == 2) {
			vec2 px = 2.0 / sheet_px;
			float me = m.r + m.b * 0.37;      // 영역 번호 + 덮기 영역 (조끼 가장자리도 잡으려고)
			vec4 n1 = texture(mask, UV + vec2(px.x, 0.0));
			vec4 n2 = texture(mask, UV - vec2(px.x, 0.0));
			vec4 n3 = texture(mask, UV + vec2(0.0, px.y));
			vec4 n4 = texture(mask, UV - vec2(0.0, px.y));
			float d = abs(n1.r + n1.b * 0.37 - me) + abs(n2.r + n2.b * 0.37 - me) + abs(n3.r + n3.b * 0.37 - me) + abs(n4.r + n4.b * 0.37 - me);
			on = float(d > 0.05);
		}
		else if (pattern == 4 && cls == 1) {
			on = float((abs(q.x - 2.0) < 1.8 && abs(q.y + 2.0) < 9.0) || (abs(q.y + 4.0) < 1.8 && abs(q.x - 2.0) < 7.0));
		}
		if (on > 0.5) col = clamp(pat_a.rgb * (l / (cls == 1 ? ref_lum.x : ref_lum.y)), 0.0, 1.0);
	}
	// 의상 조각 (몸통 덮기 영역에서만, 몸통 기준점을 따라감)
	if (cos_on && m.b > 0.5) {
		vec2 cuv = (q + cos_size * 0.5) / cos_size;
		if (cuv.x >= 0.0 && cuv.x <= 1.0 && cuv.y >= 0.0 && cuv.y <= 1.0) {
			vec4 cc = texture(cos_tex, cuv);
			if (cc.a > 0.5) col = cc.rgb;
		}
	}
	if (head_swap && m.g > 0.5) a = 0.0;
	COLOR = vec4(col, a);
}
