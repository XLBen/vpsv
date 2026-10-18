extends Control
## galgame 对话界面：背景、CG、左中右立绘、文本框与名牌、逐字显示、
## 自动播放、只跳过已读、历史记录、隐藏界面、选项。
## 操作：点击 / 确认键 前进 · A 自动 · Ctrl 按住跳过已读 · L 历史 · H 隐藏界面
##
## 用法（目前没有接入任何玩法）：
##   var v := DialogueView.new(); parent.add_child(v); v.play("_dev_test")

const Runner := preload("res://scripts/narrative/dialogue_runner.gd")
const CgRegistry := preload("res://scripts/narrative/cg_registry.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

const CHARS_PER_SEC := 30.0
const AUTO_DELAY := 1.2
const SLOT_X := {"left": 0.22, "center": 0.5, "right": 0.78}

signal closed

var runner := Runner.new()
var auto := false
var _bg: TextureRect
var _cg: TextureRect
var _portraits := {}        # who -> TextureRect
var _ui: Control
var _box: PanelContainer
var _name: Label
var _text: Label
var _choices: VBoxContainer
var _log: PanelContainer
var _hint: Label
var _shown := 0.0
var _full := 0
var _read := false
var _auto_t := 0.0
var _wait_t := 0.0
var _cg_id := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = _image_layer()
	var portraits_layer := Control.new()
	portraits_layer.name = "Portraits"
	portraits_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portraits_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portraits_layer)
	_cg = _image_layer()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_box = PanelContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_top = -86
	_box.offset_left = 12
	_box.offset_right = -12
	_box.offset_bottom = -8
	_ui.add_child(_box)
	var vb := VBoxContainer.new()
	_box.add_child(vb)
	_name = UiKit.label("", "gold")
	vb.add_child(_name)
	_text = UiKit.label("", "paper")
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_text)
	_hint = UiKit.label("", "dusk", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_RIGHT)
	vb.add_child(_hint)
	_choices = VBoxContainer.new()
	_choices.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_choices.add_theme_constant_override("separation", 4)
	_ui.add_child(_choices)
	_log = PanelContainer.new()
	_log.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log.offset_left = 30
	_log.offset_right = -30
	_log.offset_top = 20
	_log.offset_bottom = -20
	_log.visible = false
	add_child(_log)

	runner.said.connect(_on_said)
	runner.choices_shown.connect(_on_choices)
	runner.background_changed.connect(func(id): _set_image(_bg, id))
	runner.cg_changed.connect(_on_cg)
	runner.portrait_shown.connect(_on_show)
	runner.portrait_hidden.connect(_on_hide)
	runner.sound_requested.connect(func(kind, id):
		if kind == "sfx":
			Audio.play(id)
		elif id == "stop":
			Audio.stop_music()
		else:
			Audio.play_music(id))
	runner.wait_requested.connect(func(t): _wait_t = t)
	runner.finished.connect(func():
		closed.emit()
		queue_free())


func _image_layer() -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func play(script_id: String, label := "") -> bool:
	if not runner.load_script(script_id):
		return false
	runner.start(label)
	return true


func _set_image(rect: TextureRect, id: String) -> void:
	rect.texture = null if id in ["none", "off", ""] else Assets.frame_texture(id, "idle", 0)


# ------------------------------------------------------------ 运行器回调

func _speaker_name(who: String) -> String:
	var ch: Resource = Registry.character(who)
	return ch.name if ch else who


func _on_said(speaker: String, text: String, read: bool) -> void:
	_name.text = _speaker_name(speaker)
	_name.visible = speaker != ""
	_text.text = text
	_full = text.length()
	_shown = 0.0
	_text.visible_characters = 0
	_read = read
	_auto_t = 0.0
	_update_hint()


func _on_choices(options: Array) -> void:
	for c in _choices.get_children():
		c.queue_free()
	for i in options.size():
		var o: Dictionary = options[i]
		var b := UiKit.button(o.text, func(): _pick(o.index), 220)
		_choices.add_child(b)
		MotionPlayer.play(b, "motion.ui.card_in", 0.06 * i)
		if i == 0:
			b.grab_focus.call_deferred()


func _pick(i: int) -> void:
	for c in _choices.get_children():
		c.queue_free()
	runner.choose(i)


func _on_cg(id: String, variant: int) -> void:
	_cg_id = id
	_set_image(_cg, "off" if id == "off" else CgRegistry.image(id, variant))


func _on_show(who: String, pos: String, expr: String) -> void:
	var layer: Control = get_node("Portraits")
	var t: TextureRect = _portraits.get(who)
	var first := t == null
	if first:
		t = TextureRect.new()
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.add_child(t)
		_portraits[who] = t
	var asset := "portrait." + who
	t.texture = Assets.frame_texture(asset, expr, 0)
	var info = Assets.sheet(asset)
	t.size = Vector2(info.size) * 2.0
	t.position = Vector2(size.x * SLOT_X.get(pos, 0.5) - t.size.x * 0.5, size.y - t.size.y - 6).round()
	MotionPlayer.reset_rest(t)
	if first:
		MotionPlayer.play(t, "motion.ui.toast_in")


func _on_hide(who: String) -> void:
	var keys: Array = _portraits.keys() if who == "all" else [who]
	for k in keys:
		if _portraits.has(k):
			_portraits[k].queue_free()
			_portraits.erase(k)


# ------------------------------------------------------------ 推进与模式

func _process(dt: float) -> void:
	if _wait_t > 0.0:
		_wait_t -= dt
		if _wait_t <= 0.0:
			runner.advance()
		return
	if _text.visible_characters < _full:
		_shown += dt * CHARS_PER_SEC
		_text.visible_characters = mini(_full, int(_shown))
		return
	var skipping := Input.is_key_pressed(KEY_CTRL) and _read
	if skipping or (auto and runner.running and not runner.waiting_choice):
		_auto_t += dt
		if skipping or _auto_t >= AUTO_DELAY:
			runner.advance()


func _advance() -> void:
	if _log.visible:
		_log.visible = false
		return
	if not _ui.visible:
		_ui.visible = true
		return
	if runner.waiting_choice or _wait_t > 0.0:
		return
	if _text.visible_characters < _full:
		_text.visible_characters = _full
		_shown = _full
		return
	runner.advance()


func _update_hint() -> void:
	_hint.text = ("自动 " if auto else "") + ("已读" if _read else "")


func toggle_log() -> void:
	_log.visible = not _log.visible
	for c in _log.get_children():
		c.queue_free()
	if not _log.visible:
		return
	var scroll := ScrollContainer.new()
	var vb := VBoxContainer.new()
	scroll.add_child(vb)
	_log.add_child(scroll)
	for entry in runner.backlog:
		var l := UiKit.label(("%s：%s" % [_speaker_name(entry[0]), entry[1]]) if entry[0] != "" else entry[1], "fog")
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size.x = size.x - 90
		vb.add_child(l)
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		toggle_log()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		if ev.is_action_pressed("ui_accept"):
			_advance()
		return
	match ev.physical_keycode:
		KEY_ENTER, KEY_SPACE, KEY_KP_ENTER:
			_advance()
		KEY_A:
			auto = not auto
			_update_hint()
		KEY_L:
			toggle_log()
		KEY_H:
			_ui.visible = not _ui.visible
		_:
			return
	get_viewport().set_input_as_handled()
