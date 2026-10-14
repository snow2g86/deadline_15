shader_type canvas_item;
// 맵 오브젝트 테마 색 보정 — 웹 PROP_THEME_FILTER (CSS filter: sepia·saturate·brightness·hue-rotate) 를 3x3 행렬 하나로 합친 것
// (mat3 uniform 이 호환 렌더러에서 제대로 넘어가지 않아 행 셋으로 받음)
uniform vec3 row0 = vec3(1.0, 0.0, 0.0);
uniform vec3 row1 = vec3(0.0, 1.0, 0.0);
uniform vec3 row2 = vec3(0.0, 0.0, 1.0);

// fragment 의 COLOR 는 이미 텍스처 색이 곱해진 값이라, 정점 색(modulate)은 vertex 에서 따로 받아 둠
varying vec4 v_col;

void vertex() {
	v_col = COLOR;
}

void fragment() {
	vec4 mod_col = v_col;
	vec4 c = texture(TEXTURE, UV);
	vec3 o = vec3(dot(row0, c.rgb), dot(row1, c.rgb), dot(row2, c.rgb));
	COLOR = vec4(clamp(o, 0.0, 1.0), c.a) * mod_col;
}
