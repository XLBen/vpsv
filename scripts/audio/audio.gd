extends Node
## 音频（自动加载 Audio）。代码只调用 Audio.play("sfx.xxx")；
## 每个音效的播放规则（最小间隔、音高随机、复音上限、音量）写在 content/audio.json。

const CONFIG := "res://content/audio.json"
const POOL := 24

var rules := {}:
	set(v):
		rules = v
		_rule_cache.clear()
var sfx_volume := 1.0:
	set(v):
		sfx_volume = v
		AudioServer.set_bus_volume_db(_sfx_bus, linear_to_db(maxf(v, 0.0001)))
var music_volume := 0.7:
	set(v):
		music_volume = v
		AudioServer.set_bus_volume_db(_music_bus, linear_to_db(maxf(v, 0.0001)))

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _playing := {}       # id -> 当前同时播放数
var _combo := {}         # id -> [次数, 最后时间]，用于连拾音阶
var _rule_cache := {}    # id -> 合并好的规则（命中音效每帧可能播放几十次，不必每次重新合并）
var _music: AudioStreamPlayer
var _sfx_bus := 0
var _music_bus := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_bus = _ensure_bus("SFX")
	_music_bus = _ensure_bus("Music")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.finished.connect(_on_finished.bind(p))
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	if FileAccess.file_exists(CONFIG):
		var data = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
		if data is Dictionary:
			rules = data


func _ensure_bus(name: String) -> int:
	var i := AudioServer.get_bus_index(name)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	return i


func _rule(id: String) -> Dictionary:
	var cached = _rule_cache.get(id)
	if cached != null:
		return cached
	var r: Dictionary = rules.get("default", {}).duplicate()
	# 支持前缀规则，例如 "sfx.weapon.*"
	for key: String in rules:
		if key.ends_with("*") and id.begins_with(key.trim_suffix("*")):
			r.merge(rules[key], true)
	r.merge(rules.get(id, {}), true)
	_rule_cache[id] = r
	return r


## 播放音效。pitch 为额外音高倍率（例如连拾音阶）。
func play(id: String, pitch := 1.0) -> void:
	var stream := Assets.sound(id)
	if stream == null:
		return
	var r := _rule(id)
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -99.0)) < float(r.get("gap", 0.0)):
		return
	if int(_playing.get(id, 0)) >= int(r.get("poly", 8)):
		return
	_last[id] = now
	var scale := pitch
	if r.has("combo"):
		# 赌场式连拾：窗口期内每次升高一个音阶
		var c: Array = _combo.get(id, [0, -99.0])
		var steps: Array = r.combo.get("steps", [0, 2, 4, 5, 7, 9, 11, 12])
		c[0] = int(c[0]) + 1 if now - float(c[1]) < float(r.combo.get("window", 0.4)) else 0
		c[1] = now
		_combo[id] = c
		scale *= pow(2.0, float(steps[mini(int(c[0]), steps.size() - 1)]) / 12.0)
	var pv := float(r.get("pitch_var", 0.0))
	scale *= 1.0 + randf_range(-pv, pv)
	var p := _players[_next]
	_next = (_next + 1) % POOL
	if p.playing:
		_on_finished(p)
	p.stream = stream
	p.pitch_scale = scale
	p.volume_db = linear_to_db(float(r.get("volume", 1.0)))
	p.set_meta("id", id)
	_playing[id] = int(_playing.get(id, 0)) + 1
	p.play()


func _on_finished(p: AudioStreamPlayer) -> void:
	var id: String = p.get_meta("id", "")
	if id != "":
		_playing[id] = maxi(0, int(_playing.get(id, 1)) - 1)
		p.set_meta("id", "")


func play_music(id: String) -> void:
	var s := Assets.sound(id)
	if s == null or _music.stream == s:
		return
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).data.size() / 2)
	_music.stream = s
	_music.play()


func stop_music() -> void:
	_music.stop()
	_music.stream = null
