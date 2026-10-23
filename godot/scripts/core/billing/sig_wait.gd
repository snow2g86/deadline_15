extends RefCounted
## 신호를 시간 제한을 두고 기다리는 작은 도구 (6b) — 결제·광고 SDK 는 요청마다 신호 하나로 답하고 요청 번호가 없으므로
##  '먼저 기다릴 준비(arm) → 요청 → 기다림(join)' 순서로 쓴다. 응답이 영영 안 오는 경우(플러그인 오류 · 네트워크)에도 제한 시간 뒤 돌아온다.
##
##   var w := SigWait.arm(self, [client.connected, client.connect_error], 15.0)
##   client.start_connection()
##   var r: Dictionary = await w.join()      # {i: 먼저 온 신호의 번호 (제한 시간이면 -1), args: [인자…]}
##
##  accept(i, args) -> bool 을 주면 false 인 응답은 무시하고 계속 기다림 (예: 소모 응답의 token 이 내 것인지).

signal done

var finished := false
var value: Dictionary = {"i": -1, "args": []}
var _links: Array = []   # [[Signal, Callable]]


## 기다릴 준비 — 신호들을 지금 연결하고 제한 시간 타이머를 시작
static func arm(host: Node, sigs: Array, secs: float, accept: Callable = Callable()) -> RefCounted:
	var w: RefCounted = (load("res://scripts/core/billing/sig_wait.gd") as GDScript).new()
	for idx: int in sigs.size():
		var sg: Signal = sigs[idx]
		var i := idx
		var h := func(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
			var args := [a, b, c, d]   # 신호가 주는 인자 수만큼만 뜻이 있음 (나머지는 null)
			if accept.is_valid() and not bool(accept.call(i, args)):
				return
			w.fire(i, args)
		sg.connect(h)
		w._links.append([sg, h])
	if host != null and host.is_inside_tree():
		host.get_tree().create_timer(maxf(0.01, secs)).timeout.connect(func() -> void: w.fire(-1, []))
	return w


func fire(i: int, args: Array) -> void:
	if finished:
		return
	finished = true
	value = {"i": i, "args": args}
	_unlink()
	done.emit()


## 기다림을 그만둠 (요청이 시작도 못 했을 때)
func cancel() -> void:
	if not finished:
		finished = true
		_unlink()
		done.emit()


func join() -> Dictionary:
	if not finished:
		await done
	return value


func _unlink() -> void:
	for l: Array in _links:
		var sg: Signal = l[0]
		if sg.is_connected(l[1]):
			sg.disconnect(l[1])
	_links.clear()

