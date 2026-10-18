extends SceneTree
## 데이터 원본 도구 (웹 export-godot-data.js · battle-sim.js --check · outer-*-expect.js --check 를 대신함)
##
##  Godot --headless --path godot --script res://tools/data_tool.gd                 점검만 (= --check, 커밋 전)
##  Godot --headless --path godot --script res://tools/data_tool.gd -- --write      godot/data 모양 맞춤 + manifest.json 다시 만듦
##  Godot --headless --path godot --script res://tools/data_tool.gd -- --relock "이유"   기준(golden·fixtures·baseline/data) 잠금 다시 씀 (검토 뒤에만)
##  Godot --headless --path godot --script res://tools/data_tool.gd -- --rebase "이유"   기준 데이터를 지금 데이터로 옮김:
##     godot/data → tests/baseline/data 복사 → replay_golden --record (황금 기록 다시 씀) → --relock. 기록이 실패하면 둘 다 되돌림.
##     그 뒤 사람이 git diff 를 검토하고 check_outer_* 를 돌려 웹 정답 항목을 정리 (README '기준을 다시 만들 때')
##
##  점검 내용:
##   1) godot/data/**/*.json 이 정해진 모양(tools/data_format.gd)이고 manifest.json 이 최신 (아니면 바뀔 파일 목록 + 종료 코드 1)
##   2) 기준 데이터 tests/baseline/data 도 모양·manifest 가 맞음 (기준 데이터는 고치지 않음 — --write 도 건드리지 않음)
##   3) tests/baseline/LOCK.json 의 sha1 = golden · fixtures · baseline/data 지금 파일 (기준이 몰래 바뀌지 않았는지)
##  웹 data/*.js · js/* 는 읽지 않는다 (2026-10-18 이후 원본은 godot/data).
##  끝 줄: DATA_TOOL: OK / DATA_TOOL: FAIL

const DF := preload("res://tools/data_format.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var write := args.has("--write")
	var relock := args.has("--relock")
	var fails: Array = []
	# 1) 지금 데이터
	var r := DF.run(DF.DATA_DIR, write)
	for e: String in r["errors"]:
		fails.append("data: " + e)
	if write:
		print("[data_tool] godot/data: 파일 %d개, 고쳐 씀 %d개%s" % [r["files"], (r["changed"] as Array).size(), "" if (r["changed"] as Array).is_empty() else " — " + ", ".join(r["changed"])])
	else:
		if (r["changed"] as Array).is_empty():
			print("[data_tool] godot/data: 파일 %d개 모양·manifest 최신" % r["files"])
		else:
			fails.append("data: 모양이 다르거나 manifest 가 오래됨 → -- --write 로 맞추세요: " + ", ".join(r["changed"]))
	# 2) 기준 데이터 (읽기만)
	var rb := DF.run(DF.BASELINE_DIR, false)
	for e2: String in rb["errors"]:
		fails.append("baseline: " + e2)
	if not (rb["changed"] as Array).is_empty():
		fails.append("baseline: 기준 데이터 모양·manifest 가 다름 — 기준 데이터는 손으로 고치지 않음 (git 으로 되돌리거나, 기준을 지금 데이터로 옮기려면 -- --rebase \"이유\", README '기준을 다시 만들 때'): " + ", ".join(rb["changed"]))
	else:
		print("[data_tool] tests/baseline/data: 파일 %d개 모양·manifest 맞음" % rb["files"])
	# (선택) 기준 옮기기
	if args.has("--rebase"):
		var j := args.find("--rebase")
		var why := args[j + 1] if j + 1 < args.size() and not args[j + 1].begins_with("--") else ""
		if why == "":
			fails.append("--rebase 에는 이유를 붙이세요 (예: -- --rebase \"전사 공격력 25→31 반영\")")
		elif not fails.is_empty() or not (r["changed"] as Array).is_empty():
			fails.append("--rebase: godot/data 가 먼저 정해진 모양이어야 합니다 (-- --write 먼저, 오류 0)")
		else:
			var e := _rebase(why)
			if e != "":
				fails.append("--rebase: " + e)
			else:
				relock = false
	# 3) 잠금
	if relock:
		var i := args.find("--relock")
		var reason := args[i + 1] if i + 1 < args.size() and not args[i + 1].begins_with("--") else ""
		if reason == "":
			fails.append("--relock 에는 이유를 붙이세요 (예: -- --relock \"전투 규칙 고침: 화상 피해 반올림\")")
		else:
			DF.lock_write(reason)
			print("[data_tool] LOCK.json 다시 씀 (%d개): %s" % [DF.lock_scan().size(), reason])
	var lk := DF.lock_check()
	for e3: String in lk["errors"]:
		fails.append("lock: " + e3)
	if lk["ok"]:
		print("[data_tool] 기준 잠금 맞음 (%d개 파일)" % DF.lock_scan().size())
	else:
		fails.append("lock: 기준은 몰래 바뀌면 안 됨 — 실수면 git checkout 으로 되돌리고, 일부러 바꿨다면 git diff 검토 뒤 -- --relock \"이유\" (README '기준을 다시 만들 때')")
	for f: String in fails:
		print("  ! " + f)
	print("DATA_TOOL: " + ("OK" if fails.is_empty() else "FAIL (%d)" % fails.size()))
	quit(0 if fails.is_empty() else 1)



## 기준 데이터 = 지금 데이터 → 황금 기록 다시 쓰기 → 잠금. 실패하면 기준 데이터·황금 기록을 그대로 되돌림 → 오류 글 (성공 "")
func _rebase(why: String) -> String:
	var keep := {}   # res 경로 → 바이트 (되돌리기용)
	for sub: String in ["tests/baseline/data/", "tests/golden/"]:
		_backup("res://" + sub, keep)
	# 기준 데이터 비우고 복사
	for path: String in keep.keys():
		if path.begins_with(DF.BASELINE_DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var n := _copy_dir(DF.DATA_DIR, DF.BASELINE_DIR)
	print("[data_tool] --rebase: godot/data → tests/baseline/data (%d개 파일)" % n)
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/replay_golden.gd", "--", "--record"], out, true)
	var text := str(out[0]) if not out.is_empty() else ""
	for ln: String in text.split("\n"):
		if ln.contains("같음") or ln.contains("바뀜") or ln.contains("쓰지 않음") or ln.begins_with("RESULT"):
			print("  " + ln.strip_edges())
	if code != 0:
		for path2: String in keep.keys():
			var f := FileAccess.open(path2, FileAccess.WRITE)
			f.store_buffer(keep[path2])
			f.close()
		for extra: String in _list_files(DF.BASELINE_DIR):
			if not keep.has(extra):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(extra))
		return "황금 기록을 다시 쓰지 못해 기준 데이터·황금 기록을 되돌림 (종료 코드 %d) — 기록된 명령이 맞지 않는 시나리오는 새로 짜야 함" % code
	DF.lock_write("rebase: " + why)
	print("[data_tool] --rebase 끝 — LOCK.json 다시 씀. 다음: git diff --stat godot/tests 검토 → check_outer_4a/4b1/4b2 를 돌려 바뀐 웹 정답 항목을 정리 → 시험 전부 → 커밋")
	return ""


func _list_files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		out.append(dir + f)
	for sub: String in d.get_directories():
		out.append_array(_list_files(dir + sub + "/"))
	return out


func _backup(dir: String, keep: Dictionary) -> void:
	for p: String in _list_files(dir):
		keep[p] = FileAccess.get_file_as_bytes(p)


func _copy_dir(src: String, dst: String) -> int:
	var n := 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst))
	var d := DirAccess.open(src)
	for f: String in d.get_files():
		if f.get_extension() != "json":
			continue
		var w := FileAccess.open(dst + f, FileAccess.WRITE)
		w.store_buffer(FileAccess.get_file_as_bytes(src + f))
		w.close()
		n += 1
	for sub: String in d.get_directories():
		n += _copy_dir(src + sub + "/", dst + sub + "/")
	return n
