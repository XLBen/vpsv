extends Control
## 宝箱开启演出（老虎机式）：
##   宝箱抖动蓄力（转轮滴答声越来越快） → 弹开，光柱旋转（着色器）
##   → 物品依次弹出（GSAP 交错曲线）→ 金币滚动计数 → 按件数播放 A/B/C 结尾音乐。
## 任何时候点击 / 确认键都会跳到结尾。

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")
const BEAMS := preload("res://shaders/ui/chest_beams.gdshader")

var game: Node
var _stage: Control           # 演出舞台（不用容器，便于自由摆放和做位移动画）
var _chest: TextureRect
var _beams: ColorRect
var _items: Array[Control] = []
var _gold_label: Label
var _jackpot: Label
var _continue: Button
var _result := {}
var _gold_shown := 0.0
var _phase := 0               # 0 蓄力 · 1 弹出 · 2 计数 · 3 完成
var _t := 0.0
var _tick_t := 0.0


func setup(g: Node) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_child(UiKit.dim(0.7))
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_beams = ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = BEAMS
	m.set_shader_parameter("ramp", Assets.ramp("ramp.gold"))
	_beams.material = m
	_beams.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_beams)
	_chest = TextureRect.new()
	_chest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chest.stretch_mode = TextureRect.STRETCH_SCALE
	_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_chest)
	_gold_label = UiKit.label("", "gold", UiKit.FONT_L, HORIZONTAL_ALIGNMENT_CENTER)
	_stage.add_child(_gold_label)
	_jackpot = UiKit.label("大奖！", "lemon", UiKit.FONT_L, HORIZONTAL_ALIGNMENT_CENTER)
	_stage.add_child(_jackpot)
	_continue = UiKit.button("继续", _close, 90)
	_stage.add_child(_continue)
	game.chest_opened.connect(play)


func play(result: Dictionary) -> void:
	_result = result
	visible = true
	_phase = 0
	_t = 0.0
	_gold_shown = 0.0
	for it in _items:
		it.queue_free()
	_items.clear()
	var c := size * 0.5
	_beams.size = Vector2(220, 220)
	_beams.position = (c - _beams.size * 0.5 - Vector2(0, 20)).round()
	_beams.material.set_shader_parameter("progress", 0.0)
	_beams.material.set_shader_parameter("rays", 6.0 + 2.0 * result.count)
	_chest.texture = Assets.frame_texture("prop.chest", "idle", 0)
	_chest.size = Vector2(64, 64)
	_chest.position = (c - Vector2(32, 52)).round()
	MotionPlayer.reset_rest(_chest)
	MotionPlayer.play(_chest, "motion.chest.shake")
	_gold_label.text = ""
	_gold_label.size = Vector2(200, 30)
	_gold_label.position = (c + Vector2(-100, 70)).round()
	_jackpot.visible = false
	_jackpot.size = Vector2(200, 30)
	_jackpot.position = (c + Vector2(-100, -160)).round()
	_continue.visible = false
	_continue.size = Vector2(90, 20)
	_continue.position = (c + Vector2(-45, 110)).round()
	Audio.play("sfx.chest.found")


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	match _phase:
		0:
			# 转轮滴答：间隔越来越短
			_tick_t -= dt
			if _tick_t <= 0.0:
				_tick_t = lerpf(0.16, 0.04, clampf(_t / 1.3, 0.0, 1.0))
				Audio.play("sfx.chest.tick")
			if _t >= 1.4:
				_open()
		1:
			_beams.material.set_shader_parameter("progress", clampf((_t - 1.4) / 0.4, 0.0, 1.0))
			if _t >= 1.4 + 0.25 * _result.rewards.size() + 0.6:
				_phase = 2
		2:
			var target := float(_result.gold)
			var prev := int(_gold_shown)
			_gold_shown = minf(target, _gold_shown + maxf(target * dt * 1.2, 40.0 * dt))
			if int(_gold_shown) != prev and int(_gold_shown) % 7 == 0:
				Audio.play("sfx.ui.coin_tick")
			_gold_label.text = "+%d 金币" % int(_gold_shown)
			if _gold_shown >= target:
				_finish()
	_beams.material.set_shader_parameter("time_offset", _t)


func _open() -> void:
	_phase = 1
	_chest.texture = Assets.frame_texture("prop.chest", "open", 5)
	Audio.play("sfx.chest.open")
	var n: int = _result.rewards.size()
	var c := size * 0.5
	for i in n:
		var r: Dictionary = _result.rewards[i]
		var info: Dictionary = game.choice_info(r)
		var item := VBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := UiKit.icon(info.icon, 2)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		item.add_child(ic)
		item.add_child(UiKit.label(info.name, "gold" if r.get("evolved", false) else "paper", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_CENTER))
		item.add_child(UiKit.label(info.tag, "ice", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_CENTER))
		_stage.add_child(item)
		item.size = Vector2(80, 60)
		# 一排摆在宝箱上方，件数多时收紧间距
		var spread := minf(100.0, (size.x - 80.0) / maxf(1.0, n))
		var ox := (i - (n - 1) * 0.5) * spread
		var oy := -95.0 - (8.0 if i % 2 == 1 else 0.0)
		item.position = (c + Vector2(ox - 40.0, oy - 30.0)).round()
		MotionPlayer.reset_rest(item)
		item.modulate.a = 0.0
		MotionPlayer.play(item, "motion.chest.item_pop", 0.25 * i, func(): Audio.play("sfx.chest.item"))
		_items.append(item)
	if _result.count >= 5:
		_jackpot.visible = true
		MotionPlayer.reset_rest(_jackpot)
		MotionPlayer.play(_jackpot, "motion.chest.jackpot")


func _finish() -> void:
	if _phase == 3:
		return
	_phase = 3
	_gold_label.text = "+%d 金币" % int(_result.gold)
	Audio.play(["sfx.chest.end_a", "sfx.chest.end_b", "sfx.chest.end_c"][[1, 3, 5].find(int(_result.count))])
	_continue.visible = true
	_continue.grab_focus()


## 跳过演出：直接到结尾。
func _skip() -> void:
	if _phase == 0:
		_open()
	for it in _items:
		MotionPlayer.stop(it, true)
		it.modulate.a = 1.0
	_beams.material.set_shader_parameter("progress", 1.0)
	_gold_shown = float(_result.gold)
	_finish()


func _close() -> void:
	visible = false
	game.close_chest()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and _phase < 3:
		_skip()


func _unhandled_input(ev: InputEvent) -> void:
	if visible and _phase < 3 and ev.is_action_pressed("ui_accept"):
		_skip()
		get_viewport().set_input_as_handled()
