extends RefCounted
## (디버그 빌드 · dev 가게 전용) 로컬 결제 확인 서버(server/ 의 wrangler dev)에 바로 묻는 작은 동기 HTTP — 결제층 B
##  가짜 가게 장부(fake_files.gd STORE_FILE)를 서버의 /v1/dev/ledger 로 비추고, 시험이 서버 상태(/v1/dev/state · clock · reset)를 다룰 때 씀.
##  게임의 결제 요청 자체(verify · consume · refunds)는 여기가 아니라 verifier.gd 의 HTTPRequest 로 감 (진짜 길 그대로).
##  가짜 가게 도구는 서버가 ENV=dev · DEV_STORE=1 · 로컬 주소일 때만 답함 (prod 에는 없음).

const TIMEOUT_MS := 5000


## 요청 하나 → {status:int, body:Dictionary} (연결 실패면 status 0)
static func request(base: String, method: String, path: String, headers: Dictionary = {}, body: Variant = null) -> Dictionary:
	var u := base.trim_suffix("/")
	var tls := u.begins_with("https://")
	var hostport := u.substr(u.find("://") + 3) if u.contains("://") else u
	var host := hostport
	var port := 443 if tls else 80
	var c := hostport.rfind(":")
	if c > 0:
		host = hostport.substr(0, c)
		port = int(hostport.substr(c + 1))
	var hc := HTTPClient.new()
	if hc.connect_to_host(host, port, TLSOptions.client() if tls else null) != OK:
		return {"status": 0, "body": {}}
	var t0 := Time.get_ticks_msec()
	while hc.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		hc.poll()
		OS.delay_usec(300)
		if Time.get_ticks_msec() - t0 > TIMEOUT_MS:
			return {"status": 0, "body": {}}
	if hc.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"status": 0, "body": {}}
	var hl := PackedStringArray()
	var payload := ""
	if body != null:
		payload = JSON.stringify(body)
		hl.append("Content-Type: application/json")
	for k: String in headers.keys():
		if k.to_lower() != "content-type":
			hl.append("%s: %s" % [k, str(headers[k])])
	var m := {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "PUT": HTTPClient.METHOD_PUT}.get(method, HTTPClient.METHOD_GET) as int
	if hc.request(m, path, hl, payload) != OK:
		return {"status": 0, "body": {}}
	while hc.get_status() == HTTPClient.STATUS_REQUESTING:
		hc.poll()
		OS.delay_usec(300)
		if Time.get_ticks_msec() - t0 > TIMEOUT_MS:
			return {"status": 0, "body": {}}
	if not hc.has_response():
		return {"status": 0, "body": {}}
	var code := hc.get_response_code()
	var bytes := PackedByteArray()
	while hc.get_status() == HTTPClient.STATUS_BODY:
		hc.poll()
		var chunk := hc.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_usec(300)
		else:
			bytes.append_array(chunk)
		if Time.get_ticks_msec() - t0 > TIMEOUT_MS:
			break
	hc.close()
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return {"status": code, "body": parsed if parsed is Dictionary else {}}
