shader_type spatial;
// 뒤집은 메시 외곽선 — TANGENT.xyz 에 "부드러운 바깥 방향"을 넣어 둠 (스키닝도 같이 따라감)
render_mode unshaded, cull_front;
uniform float width = 0.0147;                 // 월드 단위 (1 도트 = 1/ppu)
uniform vec3 line_color : source_color = vec3(0.11, 0.085, 0.078);
void vertex() {
	VERTEX += normalize(TANGENT) * width * COLOR.g;   // COLOR.g = 0 이면 외곽선 없음 (눈·볼 같은 작은 것)
}
void fragment() {
	ALBEDO = line_color;
}
