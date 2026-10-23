extends RefCounted
## 그림 창구 — 웹 js/battle/rig.js (Rig.key·fit·sheet·_sheetEl) 의 위치 계산과 그림 불러오기
##  캐릭터 그림: res://assets/image/character/<직업>_<01|02>.webp (손실 WebP q85, 원본 PNG 는 art_src) (962x1087, 오른쪽을 봄)
##  동작 시트: SPRITE_SHEETS[키][idle|combat|hit|attack] (가로로 frames 칸, 칸 크기 w×h)
##  몸 높이 맞춤 (CHAR_FIG·FIG_H·FIG_FOOT): 화면에서 무기를 뺀 몸이 FIG_H(50px) 가 되게, 발끝을 같은 선에
##  뒷모습(<키>_b 시트·정지 그림)은 웹도 꺼 둠 (Rig.BACK_VIEW = false) — 화면은 쓰지 않음. 그림 파일은 3D 교체를 위해 2026-10-23 삭제(git 기록에서 복구).
##  sheet()/still() 의 back 인자는 '뒷모습을 읽는 자리' — 파일이 없으면 앞모습으로 대신 (UnitView.facing_back, godot/README.md '뒷모습')

const IMG := "res://assets/image/"
## 웹 UI (캐릭터 아이콘 기본 폭) — CHAR_FIG 가 없는 그림(소환수)
const UI_SIZE := 52.0

var SHEETS: Dictionary = {}
var FIG: Dictionary = {}
var FIG_H := 50.0
var FIG_FOOT := 3.0
var CHAR_SPRITES: Dictionary = {}

var _tex: Dictionary = {}      # 경로 → Texture2D (없으면 null 기록)


func _init(sprites: Dictionary) -> void:
	SHEETS = sprites.get("SPRITE_SHEETS", {})
	FIG = sprites.get("CHAR_FIG", {})
	FIG_H = float(sprites.get("FIG_H", 50))
	FIG_FOOT = float(sprites.get("FIG_FOOT", 3))
	CHAR_SPRITES = sprites.get("CHAR_SPRITES", {})


## Rig.key — 직업 + 성별 (01 남 / 02 여)
static func key_of(cls: String, gender: String) -> String:
	return cls + ("_02" if gender == "f" else "_01")


func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex[path] = t
	return t


## 동작 시트 (없으면 null). back = true 면 뒷모습 시트(<키>_b)를 찾고, 데이터에 없거나 그림 파일이 없으면 앞모습 시트로 대신
func sheet(cls: String, gender: String, kind: String, back: bool = false) -> Variant:
	if back:
		var b: Variant = SHEETS.get(key_of(cls, gender) + "_b")
		if typeof(b) == TYPE_DICTIONARY and (b as Dictionary).has(kind):
			var bs: Variant = b[kind]
			if typeof(bs) == TYPE_DICTIONARY and ResourceLoader.exists(IMG + str(bs["src"]).trim_prefix("image/")):
				return bs
	var a: Variant = SHEETS.get(key_of(cls, gender))
	if typeof(a) != TYPE_DICTIONARY:
		return null
	if (a as Dictionary).has(kind):
		return a[kind]
	return null


func sheet_tex(sh: Dictionary) -> Texture2D:
	return tex(IMG + str(sh["src"]).trim_prefix("image/"))


## 몸 높이 맞춤 (Rig.fit): { s: 원본 → 화면 배율, size: 아이콘 폭(px), mb: 아래 여백 } — 측정값이 없으면 null
func fit(cls: String, gender: String) -> Variant:
	var f: Variant = FIG.get(key_of(cls, gender))
	if typeof(f) != TYPE_ARRAY:
		return null
	var s := FIG_H / (float(f[1]) - float(f[0]))
	return {"s": s, "size": roundf(962.0 * s), "mb": roundf(FIG_FOOT - (1087.0 - float(f[1])) * s), "f1": float(f[1])}


## 시트 한 칸을 발 위치(0,0) 기준으로 놓을 자리 (Rig._sheetEl): { pos: 왼쪽 위, scale: z, w, h }
##  웹: left = icx*s - cx*z (아이콘 안), 몸 아랫선(body[1]) = 발 — 아이콘 왼쪽 = -size/2
func sheet_place(cls: String, gender: String, sh: Dictionary) -> Variant:
	var ft: Variant = fit(cls, gender)
	if ft == null:
		return null
	var body: Array = sh["body"]
	var z := FIG_H / (float(body[1]) - float(body[0]))
	var left := -float(ft["size"]) / 2.0 + float(sh["icx"]) * float(ft["s"]) - float(sh["cx"]) * z
	return {"pos": Vector2(left, -float(body[1]) * z), "scale": z, "w": float(sh["w"]), "h": float(sh["h"])}


## 정지 그림 (시트가 없을 때): { tex, rect(발 기준) }. back = true 면 character/<키>_b.webp (삭제됨 — 3D 교체 전 임시), 없으면 앞모습
func still(cls: String, gender: String, back: bool = false) -> Variant:
	if cls.begins_with("summon_"):
		var t := summon_tex(cls, gender)
		if t == null:
			return null
		var w := UI_SIZE
		var h := roundf(UI_SIZE * float(t.get_height()) / float(t.get_width()))
		# 아이콘 아래 = 타일 가운데 = 발 + 3
		return {"tex": t, "rect": Rect2(-w / 2.0, 3.0 - h, w, h)}
	var t2: Texture2D = null
	if back:
		t2 = tex(IMG + "character/" + key_of(cls, gender) + "_b.webp")
	if t2 == null:
		t2 = tex(IMG + "character/" + key_of(cls, gender) + ".webp")
	if t2 == null:
		return null
	var ft: Variant = fit(cls, gender)
	var size := UI_SIZE if ft == null else float(ft["size"])
	var mb := 0.0 if ft == null else float(ft["mb"])
	var hh := size * 1087.0 / 962.0
	return {"tex": t2, "rect": Rect2(-size / 2.0, 3.0 - mb - hh, size, hh)}


## 소환수 도트 그림 (웹 sprites.js _svgSprite: CHAR_SPRITES[cls_m|f] 의 팔레트 p · 줄 r) → 텍스처
func summon_tex(cls: String, gender: String) -> Texture2D:
	var k := cls + ("_f" if gender == "f" else "_m")
	var path := "summon:" + k
	if _tex.has(path):
		return _tex[path]
	var def: Variant = CHAR_SPRITES.get(k, CHAR_SPRITES.get(cls + "_m"))
	var t: Texture2D = null
	if typeof(def) == TYPE_DICTIONARY:
		var rows: Array = def["r"]
		var pal: Dictionary = def["p"]
		var w: int = str(rows[0]).length()
		var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in rows.size():
			var row := str(rows[y])
			for x in mini(w, row.length()):
				var ch := row[x]
				if ch != "." and pal.has(ch):
					img.set_pixel(x, y, Color(str(pal[ch])))
		t = ImageTexture.create_from_image(img)
	_tex[path] = t
	return t


## CSS filter 문자열 (PROP_THEME_FILTER) → 3x3 색 행렬 (sepia·saturate·brightness·hue-rotate 순서대로 곱함)
static func css_filter_matrix(s: String) -> Basis:
	var m := Basis.IDENTITY
	var re := RegEx.new()
	re.compile("([a-z-]+)\\(([-0-9.]+)(deg)?\\)")
	for r: RegExMatch in re.search_all(s):
		var fn := r.get_string(1)
		var v := float(r.get_string(2))
		var f := Basis.IDENTITY
		match fn:
			"sepia":
				var a := 1.0 - minf(v, 1.0)
				f = _rows(Vector3(0.393 + 0.607 * a, 0.769 - 0.769 * a, 0.189 - 0.189 * a),
					Vector3(0.349 - 0.349 * a, 0.686 + 0.314 * a, 0.168 - 0.168 * a),
					Vector3(0.272 - 0.272 * a, 0.534 - 0.534 * a, 0.131 + 0.869 * a))
			"saturate":
				f = _rows(Vector3(0.213 + 0.787 * v, 0.715 - 0.715 * v, 0.072 - 0.072 * v),
					Vector3(0.213 - 0.213 * v, 0.715 + 0.285 * v, 0.072 - 0.072 * v),
					Vector3(0.213 - 0.213 * v, 0.715 - 0.715 * v, 0.072 + 0.928 * v))
			"brightness":
				f = Basis.IDENTITY.scaled(Vector3(v, v, v))
			"hue-rotate":
				var a2 := deg_to_rad(v)
				var cs := cos(a2)
				var sn := sin(a2)
				f = _rows(Vector3(0.213 + cs * 0.787 - sn * 0.213, 0.715 - cs * 0.715 - sn * 0.715, 0.072 - cs * 0.072 + sn * 0.928),
					Vector3(0.213 - cs * 0.213 + sn * 0.143, 0.715 + cs * 0.285 + sn * 0.140, 0.072 - cs * 0.072 - sn * 0.283),
					Vector3(0.213 - cs * 0.213 - sn * 0.787, 0.715 - cs * 0.715 + sn * 0.715, 0.072 + cs * 0.928 + sn * 0.072))
		m = f * m
	return m


## 행(row) 셋으로 Basis 만들기 (셰이더 mat3 * vec3 는 열 기준이라 전치해서 넘김 — battle_map 참고)
static func _rows(r0: Vector3, r1: Vector3, r2: Vector3) -> Basis:
	# Basis(x, y, z) 는 열 벡터 — 행렬 M 의 행 r0..r2 를 넣으려면 열 = (r0.x, r1.x, r2.x) …
	return Basis(Vector3(r0.x, r1.x, r2.x), Vector3(r0.y, r1.y, r2.y), Vector3(r0.z, r1.z, r2.z))
