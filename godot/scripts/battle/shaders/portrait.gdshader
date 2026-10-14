shader_type canvas_item;
// 스토리 초상화 — 웹 css/story.css .st-pt: 말하지 않는 쪽은 어둡게(brightness .38 saturate .6), 아래 28% 는 투명하게 (mask-image),
//  보스(직업 그림)는 붉게 물들임(sepia·saturate·hue-rotate 근사), 환영(ghost)은 보랏빛 반투명
uniform float bright = 1.0;
uniform float sat = 1.0;
uniform float mask_v0 = 2.0;   // 이 v 부터
uniform float mask_v1 = 3.0;   // 이 v 까지 투명해짐
uniform float boss_tint = 0.0;
uniform float ghost = 0.0;
uniform float alpha = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(vec3(l), c.rgb, sat);
	rgb = mix(rgb, vec3(l * 1.35, l * 0.42, l * 0.32), boss_tint * 0.6);
	rgb = mix(rgb, vec3(l * 0.85 + 0.12, l * 0.55 + 0.05, l * 1.15 + 0.15), ghost * 0.7);
	rgb *= bright;
	float m = 1.0 - smoothstep(mask_v0, mask_v1, UV.y);
	COLOR = vec4(rgb, c.a * m * alpha * (1.0 - ghost * 0.22)) * COLOR;
}
