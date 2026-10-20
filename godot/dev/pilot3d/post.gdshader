shader_type canvas_item;
// 3D 를 그린 질감 뒤처리 — 색 수 줄이기(포스터라이즈 / 팔레트 맞추기), 바깥 외곽선
uniform sampler2D pal_tex : filter_nearest, repeat_disable;
uniform int pal_n = 32;
uniform int mode = 0;               // 0 끔, 1 포스터라이즈, 2 팔레트
uniform float levels = 6.0;
uniform bool outline_on = false;
uniform vec4 outline_color : source_color = vec4(0.11, 0.085, 0.078, 1.0);

vec3 snap_pal(vec3 c) {
	vec3 best = c;
	float bd = 1e9;
	for (int i = 0; i < 48; i++) {
		if (i >= pal_n) break;
		vec3 p = texelFetch(pal_tex, ivec2(i, 0), 0).rgb;
		vec3 d = (p - c);
		float dd = dot(d * vec3(0.9, 1.0, 1.1), d * vec3(0.9, 1.0, 1.1));
		if (dd < bd) { bd = dd; best = p; }
	}
	return best;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float edge = 0.0;
	if (c.a < 0.5 && outline_on) {
		edge = step(0.5, texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	}
	vec3 rgb = c.rgb;
	if (mode == 1) {
		// 색상·채도·밝기를 각각 단계로 끊음 (RGB 채널별로 끊으면 회색이 푸르게 틀어짐)
		vec3 h = rgb2hsv(rgb);
		float sat_lv = max(3.0, levels - 2.0);
		h.z = floor(h.z * levels + 0.5) / levels;
		h.y = floor(h.y * sat_lv + 0.5) / sat_lv;
		h.x = floor(h.x * 24.0 + 0.5) / 24.0;
		rgb = hsv2rgb(h);
	} else if (mode == 2) {
		rgb = snap_pal(rgb);
	}
	float a = step(0.5, c.a);
	rgb = mix(rgb, outline_color.rgb, edge);
	COLOR = vec4(rgb, max(a, edge));
}
