extends RefCounted
## 그림 아이콘 창구 — 웹 js/common/item-icons.js(itemIcon) · emoji-icons.js(EMOJI_ICON 자동 교체) · js/skills.js(skillIcon) ·
##  render.js portrait(얼굴 원형 크롭) 와 같은 그림을 Godot 텍스처로.
##  디자인 정책: 화면에는 이모지 대신 일러스트 아이콘 시트(image/icon/item-sprite.webp 8×25 칸, skill-sprite.png 8×7 칸)를 쓴다.
##  시트에 그림이 없는 이모지는 지움(rich) — UI 기호(⚑ ⚔ ⚠ ✓ 등 글자)는 글자로 둔다.
##  모든 텍스처는 처음 쓸 때 한 번 만들어 캐시 (AtlasTexture — 시트 한 장을 공유)

const IMG := "res://assets/image/"
const CELL := 64.0

static var _inst: Variant = null

var D: Dictionary
var item_sheet: Texture2D
var skill_sheet: Texture2D
var ITEM_SPRITE: Dictionary = {}
var SKILL_SPRITE: Dictionary = {}
var EMOJI_ICON: Dictionary = {}
var ICON_RARITY: Dictionary = {}
var _cache: Dictionary = {}       # 키 → Texture2D | null
var _emoji_keys: Array = []        # 긴 것부터 (변형 선택자 FE0F 붙은 것 먼저 — 웹 _regex 와 같은 순서)


## 장면마다 새로 만들 필요 없음 — 데이터 사전이 같으면 하나를 같이 씀
static func get_for(p_D: Dictionary) -> Object:
	if _inst == null or not is_same((_inst as Object).get("D"), p_D):
		_inst = new(p_D)
	return _inst


func _init(p_D: Dictionary) -> void:
	D = p_D
	ITEM_SPRITE = D.get("ITEM_SPRITE", {})
	SKILL_SPRITE = D.get("SKILL_SPRITE", {})
	EMOJI_ICON = D.get("EMOJI_ICON", {})
	ICON_RARITY = D.get("ICON_RARITY", {})
	item_sheet = _load(IMG + "icon/item-sprite.webp")
	skill_sheet = _load(IMG + "icon/skill-sprite.png")
	for e: String in EMOJI_ICON.keys():
		if ITEM_SPRITE.has(str(EMOJI_ICON[e])):
			_emoji_keys.append(e)
	_emoji_keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())


static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _atlas(sheet: Texture2D, cell: Array, inset: float = 0.0) -> AtlasTexture:
	if sheet == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(float(cell[0]) * CELL + inset, float(cell[1]) * CELL + inset, CELL - inset * 2.0, CELL - inset * 2.0)
	at.filter_clip = true
	return at


## 아이템·효과 그림 (ITEM_SPRITE 키, 예: chest · potion_heal · e_fire) — 없으면 null
func item(key: String) -> Texture2D:
	var ck := "i:" + key
	if _cache.has(ck):
		return _cache[ck]
	var t: Texture2D = null
	if ITEM_SPRITE.has(key):
		t = _atlas(item_sheet, ITEM_SPRITE[key])
	_cache[ck] = t
	return t


## 등급 테두리 (frame_uncommon·rare·epic·legendary) — common 이나 없으면 null
func rarity_frame(key: String, rarity: String = "") -> Texture2D:
	var r := rarity if rarity != "" else str(ICON_RARITY.get(key, "common"))
	return item("frame_" + r)


## 스킬 그림 (SKILL_SPRITE) — 없으면 null (웹은 스킬 데이터의 이모지로 대신 — 여기서는 그 이모지의 그림, 없으면 null)
func skill(id: String, fallback_emoji: String = "") -> Texture2D:
	var ck := "s:" + id
	if _cache.has(ck):
		return _cache[ck]
	var t: Texture2D = null
	if SKILL_SPRITE.has(id):
		t = _atlas(skill_sheet, SKILL_SPRITE[id])
	elif fallback_emoji != "":
		t = emoji(fallback_emoji)
	_cache[ck] = t
	return t


## 이모지 → 그림 (웹 EmojiIcons: EMOJI_ICON 에 있고 시트에 그림이 있을 때만) — 없으면 null
func emoji(e: String) -> Texture2D:
	if e == "":
		return null
	var key: Variant = EMOJI_ICON.get(e)
	if key == null:
		key = EMOJI_ICON.get(e.replace("️", ""))
	if key == null:
		key = EMOJI_ICON.get(e + "️")
	return item(str(key)) if key != null else null


## 캐릭터 그림 (962×1087, 오른쪽을 봄). 소환수는 도트 그림 (sdb.summon_tex)
func char_tex(cls: String, gender: String, sdb: Object = null) -> Texture2D:
	if cls.begins_with("summon_"):
		return sdb.call("summon_tex", cls, gender) if sdb != null else null
	return _cached_load(IMG + "character/" + cls + ("_02" if gender == "f" else "_01") + ".png")


## 얼굴 크롭 (웹 .ic-portrait: background-size 210%, position 50% 12%) → 원본 그림 안의 사각 영역
##  가로 = 962/2.1 ≈ 458, 왼쪽 = (2.1-1)/2 × 458 ≈ 252, 위 = 0.12 × (1087/962×2.1 - 1) × 458 ≈ 75.6
static func portrait_region(tex: Texture2D) -> Rect2:
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var side := w / 2.1
	var left := (w - side) * 0.5
	var top := (h - side) * 0.12
	return Rect2(left, top, side, side)


func _cached_load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t := _load(path)
	_cache[path] = t
	return t


## 그림 경로 (스토리 초상화 등) — 없으면 null
func image(rel: String) -> Texture2D:
	return _cached_load(IMG + rel)


# ── 글 속 이모지 → 그림 (웹 EmojiIcons.scan 과 같은 일) ──

## 글을 [글, 그림, 글, …] 조각으로 — 시트에 그림이 있는 이모지는 Texture2D, 그림이 없는 이모지(그림 문자)는 지움
func split(text: String) -> Array:
	var out: Array = []
	var buf := ""
	var i := 0
	var n := text.length()
	while i < n:
		var hit := ""
		for e: String in _emoji_keys:
			if e.length() <= n - i and text.substr(i, e.length()) == e:
				hit = e
				break
		if hit != "":
			if buf != "":
				out.append(buf)
				buf = ""
			out.append(emoji(hit))
			i += hit.length()
			continue
		var cp := text.unicode_at(i)
		if is_pictograph(cp):
			i += 1
			# 뒤따르는 변형 선택자·결합 문자도 함께 지움
			while i < n and (text.unicode_at(i) == 0xFE0F or text.unicode_at(i) == 0x200D):
				i += 1
			continue
		buf += text[i]
		i += 1
	if buf != "":
		out.append(buf)
	return out


## 그림 문자(이모지) 판정 — 글자 기호(⚑ ⚔ ⚠ ✓ ★ ▲ 등 U+2000~27BF)는 남김 (변형 선택자가 붙어 이모지로 쓰인 것만 split 의 EMOJI_ICON 이 바꿈)
static func is_pictograph(cp: int) -> bool:
	return (cp >= 0x1F000 and cp <= 0x1FAFF) or cp == 0xFE0F or cp == 0x200D or (cp >= 0x1F1E6 and cp <= 0x1F1FF)


## 이모지를 지운 글 (그림 없이 글만 필요할 때) — 앞뒤 공백 정리
func strip(text: String) -> String:
	var s := ""
	for p: Variant in split(text):
		if typeof(p) == TYPE_STRING:
			s += p
	return s.strip_edges()


## RichTextLabel 에 글+그림 채우기 (그림은 글자 크기에 맞춤 — 웹 .emo-icon 1.2em)
func fill_rich(rt: RichTextLabel, text: String, px: int, color: Variant = null) -> void:
	rt.clear()
	if color != null:
		rt.push_color(color)
	for p: Variant in split(text):
		if typeof(p) == TYPE_STRING:
			rt.add_text(p)
		elif p != null:
			var s := int(round(px * 1.2))
			rt.add_image(p, s, s, Color.WHITE, INLINE_ALIGNMENT_CENTER)
	if color != null:
		rt.pop()
