shader_type canvas_item;
// 물·용암 윗면 반짝임 — 웹 .iso-tile-bg.t-water::after (115° 띠가 300% 폭 배경 위를 4초(용암 2.6초)마다 지나감)
// UV 에는 타일 그림 좌표(px)를 넣어 둠 (가로 0~96, 세로 0~50)
uniform vec4 band : source_color = vec4(0.706, 0.863, 1.0, 0.16);
uniform float period = 4.0;
uniform float half_w = 0.15;      // 띠 반폭 (그라디언트 길이 비율: 물 35~65% → .15, 용암 30~70% → .2)

void fragment() {
	float W = 96.0;
	float H = 50.0;
	float t = fract(TIME / period);
	// 배경 위치 150% → -150%: 띠 가운데 x = -1.5W → 4.5W
	float cx = mix(-1.5 * W, 4.5 * W, t);
	vec2 d = vec2(0.906, 0.423);                 // 115deg
	float L = 3.0 * W * 0.906 + H * 0.423;       // 그라디언트 선 길이 (300% 배경)
	float s = dot(UV - vec2(cx, H * 0.5), d) / L;
	float a = clamp(1.0 - abs(s) / half_w, 0.0, 1.0);
	COLOR = vec4(band.rgb, band.a * a);
}
