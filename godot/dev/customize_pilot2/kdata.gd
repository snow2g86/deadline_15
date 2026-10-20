extends RefCounted
## 시범 2차 자료 불러오기 (기준점 표·마스크·머리·의상 그림) — 한 번만 읽고 보관
const DIR := "res://assets/pilot/knight2/"
static var anchors: Dictionary = {}
static var parts: Dictionary = {}
static var _tex: Dictionary = {}


static func load_all() -> void:
	if not anchors.is_empty():
		return
	anchors = JSON.parse_string(FileAccess.get_file_as_string(DIR + "anchors.json"))
	parts = JSON.parse_string(FileAccess.get_file_as_string(DIR + "parts.json"))


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		# 가져오기(import) 없이 바로 읽음 — 개발용 에셋이라 .import 파일을 만들지 않으려고
		var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + name))
		_tex[name] = ImageTexture.create_from_image(img) if img != null else null
	return _tex[name]
