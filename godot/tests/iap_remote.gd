extends RefCounted
## check_iap -- --server <주소> 보조: fake_server.gd 와 같은 모양(handle · clock_offset_ms)으로 진짜 로컬 Worker(server/, wrangler dev)를 부름
##  handle(method, path, query, headers, body) → {status:int, body:Dictionary} — 응답 형은 가짜 서버와 같음 (JSON 글을 거쳐 읽음)
##  clock_offset_ms 를 바꾸면 서버의 시험용 시계(/v1/dev/clock, dev 환경 · 로컬 주소에서만)를 밈

const DevRemote := preload("res://scripts/core/billing/dev_remote.gd")

var base := ""
var clock_offset_ms := 0.0:
	set(v):
		clock_offset_ms = v
		DevRemote.request(base, "POST", "/v1/dev/clock", {}, {"offset_ms": v})


## (시험 훅) 다음 n 번의 게임 요청을 429 로 — fake_server.force_429 와 같음 (/v1/dev/force429)
var force_429 := 0:
	set(v):
		force_429 = v
		DevRemote.request(base, "POST", "/v1/dev/force429", {}, {"count": v})


func _init(url: String) -> void:
	base = url


func handle(method: String, path: String, query: Dictionary, headers: Dictionary, body: Dictionary) -> Dictionary:
	var p := path
	if not query.is_empty():
		var parts: Array = []
		for k: String in query.keys():
			parts.append("%s=%s" % [k.uri_encode(), str(query[k]).uri_encode()])
		p += "?" + "&".join(parts)
	return DevRemote.request(base, method, p, headers, body if method == "POST" else null)
