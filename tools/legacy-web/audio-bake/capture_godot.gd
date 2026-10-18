extends SceneTree
## Godot 출력 녹음 (Master 버스에 AudioEffectRecord) — 기본 음량(bgmVol 0.5, sfxVol 0.7)
var OUT := ""
func _initialize() -> void:
	OUT = OS.get_cmdline_user_args()[0]
	_main.call_deferred()
func _rec(name: String, secs: float, fn: Callable) -> void:
	var rec := AudioEffectRecord.new()
	rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, rec)
	rec.set_recording_active(true)
	fn.call()
	await create_timer(secs).timeout
	rec.set_recording_active(false)
	var w := rec.get_recording()
	w.save_to_wav(OUT + "/" + name)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	print("rec ", name, " ", w.get_length(), " ", w.mix_rate, " stereo=", w.stereo)
func _main() -> void:
	var st := root.get_node("Store")
	st.call("use_path", "user://capture_tmp.json")
	st.call("clear")
	var snd := root.get_node("Sound")
	snd.call("reload_settings")
	await create_timer(0.5).timeout
	await _rec("godot_bgm_12s.wav", 12.0, func() -> void: snd.call("play_bgm", "battle"))
	snd.call("stop_bgm", false)
	await create_timer(0.5).timeout
	for s in ["atk_mage", "atk_knight", "victory", "heal", "kill"]:
		await _rec("godot_sfx_%s.wav" % s, 1.3, func() -> void: snd.call("sfx", s))
	st.call("clear"); st.call("flush")
	quit()
