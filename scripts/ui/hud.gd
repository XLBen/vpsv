extends Control
## 局内 HUD（640×360 像素画面）：经验条、等级、计时、击杀、金币、背包图标、
## 玩家血条、首领血条、提示条、触屏摇杆。大部分直接绘制，提示条用动效曲线。

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

const VIGNETTE := preload("res://shaders/screen/vignette.gdshader")

var game: Node
var _vignette: ColorRect
var _toasts: Array[Control] = []
var _bar_frame: StyleBox
var _slot_frame: StyleBox
var _t := 0.0
var _last_kills := 0
var _last_gold := 0
var _kills_label: Label
var _gold_label: Label
var touch_active := false
var touch_origin := Vector2.ZERO
var touch_vec := Vector2.ZERO
var _touch_idx := -1
var _xp_shown := 0.0          # 经验条显示值（缓动追赶实际值）
var _xp_level := 1
var _xp_glow := 0.0           # 获得经验时整条发亮，随后衰减
var _hp_chip := 1.0           # 受伤后慢慢退去的浅色残血段
var _levels := {}             # 背包格 → 上次看到的等级（升级时闪一下）
var _slot_flash := {}


func setup(g: Node) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = VIGNETTE
	_vignette.material = vm
	add_child(_vignette)
	_bar_frame = UiKit.frame("ui.frame.bar", "normal", 0)
	_slot_frame = UiKit.frame("ui.frame.slot", "normal", 0)
	game.toast_requested.connect(toast)
	# 击杀、金币用 Label，数值变化时播放“跳动”动效
	_kills_label = _corner_label()
	_gold_label = _corner_label()
	resized.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
	_kills_label.position = Vector2(size.x - 102, 15)
	_gold_label.position = Vector2(size.x - 102, 29)
	MotionPlayer.reset_rest(_kills_label)
	MotionPlayer.reset_rest(_gold_label)


func _corner_label() -> Label:
	var l := UiKit.label("0", "paper", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_RIGHT)
	l.add_theme_constant_override("outline_size", 4)
	l.size = Vector2(80, 14)
	add_child(l)
	return l


func _process(dt: float) -> void:
	_t += dt
	var hp_ratio: float = game.player.hp / game.stats.max_hp()
	var m: ShaderMaterial = _vignette.material
	m.set_shader_parameter("hurt", 0.0 if Save.settings().get("reduce_flashing", false) else game.player.hurt_flash / 0.35)
	m.set_shader_parameter("low_hp", clampf((0.3 - hp_ratio) / 0.3, 0.0, 1.0))
	m.set_shader_parameter("freeze", 1.0 if game.enemies.freeze_all > 0.0 else 0.0)
	# 死神降临后黑雾在 3 秒内渐入
	m.set_shader_parameter("reaper", clampf((game.run.time - game.stage.duration) / 3.0, 0.0, 1.0))
	if game.run.kills != _last_kills:
		_last_kills = game.run.kills
		_kills_label.text = UiKit.fmt_num(_last_kills)
		if not _kills_label.has_meta("motion_player"):
			MotionPlayer.play(_kills_label, "motion.ui.number_pop")
	_update_bars(dt)
	if int(game.run.gold) != _last_gold:
		_last_gold = int(game.run.gold)
		_gold_label.text = UiKit.fmt_num(_last_gold)
		MotionPlayer.play(_gold_label, "motion.ui.number_pop")
	queue_redraw()


func _update_bars(dt: float) -> void:
	var run = game.run
	var target: float = clampf(run.xp / run.xp_to_next(run.level), 0.0, 1.0)
	if run.level != _xp_level:
		_xp_level = run.level
		_xp_shown = 0.0
		_xp_glow = 1.0
	if target > _xp_shown + 0.0001:
		_xp_glow = maxf(_xp_glow, 0.6)
		_xp_shown = move_toward(_xp_shown, target, dt * maxf(0.5, (target - _xp_shown) * 10.0))
	else:
		_xp_shown = target
	_xp_glow = maxf(0.0, _xp_glow - dt * 3.0)
	var hp: float = clampf(game.player.hp / game.stats.max_hp(), 0.0, 1.0)
	_hp_chip = move_toward(_hp_chip, hp, dt * 0.5) if hp < _hp_chip else hp
	for k in _slot_flash.keys():
		_slot_flash[k] -= dt
		if _slot_flash[k] <= 0.0:
			_slot_flash.erase(k)


## 背包格等级变化时闪一下（新获得也算）。
func _slot_changed(key: String, level: int) -> float:
	if _levels.get(key, 0) != level:
		if _levels.has(key) or game.run.time > 1.0:
			_slot_flash[key] = 0.45
		_levels[key] = level
	return _slot_flash.get(key, 0.0) / 0.45


## 右对齐时 pos.x 为右边缘；居中时为中心（width 为文本框宽）。
func _text(s: String, pos: Vector2, font_size := UiKit.FONT_S, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f: Font = Assets.font
	var p := pos.round()
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		width = 200.0 if width < 0.0 else width
		p.x -= width if align == HORIZONTAL_ALIGNMENT_RIGHT else width * 0.5
	draw_string_outline(f, p, s, align, width, font_size, 4, UiKit.color("ink"))
	draw_string(f, p, s, align, width, font_size, col)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var run = game.run
	# 经验条
	draw_style_box(_bar_frame, Rect2(0, 0, w, 12))
	var fw := floorf((w - 4) * _xp_shown)
	draw_rect(Rect2(2, 2, fw, 8), UiKit.color("sky"))
	draw_rect(Rect2(2, 2, fw, 2), UiKit.color("ice"))
	if _xp_glow > 0.0:
		draw_rect(Rect2(2, 2, fw, 8), Color(1, 1, 1, 0.45 * _xp_glow))
	if fw > 2.0:
		draw_rect(Rect2(2 + fw - 2, 2, 2, 8), UiKit.color("white"))   # 填充头部的亮边
	_text("LV %d" % run.level, Vector2(w - 5, 10), UiKit.FONT_S, UiKit.color("white"), HORIZONTAL_ALIGNMENT_RIGHT)
	# 计时
	_text(UiKit.fmt_time(run.time), Vector2(w * 0.5, 38), UiKit.FONT_L, UiKit.color("white"), HORIZONTAL_ALIGNMENT_CENTER)
	# 击杀 / 金币图标
	_icon_frame("icon.passive.skull_omaniac", "idle", Vector2(w - 12, 22), 1.0)
	_icon_frame("pickup.coin", "idle", Vector2(w - 12, 36), 1.0)
	# 背包
	var x := 4.0
	for wpn in game.weapons:
		_slot(Vector2(x, 15), wpn.def.icon, wpn.level, wpn.def.max_level, _slot_changed("w:" + wpn.def.id, wpn.level))
		x += 19.0
	x = 4.0
	for id: String in game.passive_order:
		var d: Resource = Registry.passive(id)
		_slot(Vector2(x, 34), d.icon, game.passives[id], d.max_level, _slot_changed("p:" + id, game.passives[id]))
		x += 19.0
	_player_bar()
	_boss_bar(w, h)
	if game.flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, game.flash))
	if touch_active:
		draw_arc(touch_origin, 26.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 1.0)
		draw_circle(touch_origin + touch_vec * 26.0, 9.0, Color(1, 1, 1, 0.3))


func _icon_frame(id: String, clip: String, pos: Vector2, scale: float) -> void:
	var info = Assets.sheet(id)
	var c: Dictionary = info.clip(clip)
	var src := Rect2(Vector2(0, int(c.row) * info.size.y), Vector2(info.size))
	var ds := (Vector2(info.size) * scale).round()
	draw_texture_rect_region(info.texture, Rect2((pos - ds * 0.5).round(), ds), src)


func _slot(pos: Vector2, icon: String, level: int, max_level: int, flash := 0.0) -> void:
	# 升级时整格向上跳 1px 并闪白
	if flash > 0.0:
		pos.y -= 1.0 if flash > 0.5 else 0.0
	draw_style_box(_slot_frame, Rect2(pos, Vector2(18, 18)))
	var info = Assets.sheet(icon)
	var f: int = info.frame_at("idle", _t + pos.x * 0.03)
	var c: Dictionary = info.clip("idle")
	var src := Rect2(Vector2(f * info.size.x, int(c.row) * info.size.y), Vector2(info.size))
	draw_texture_rect_region(info.texture, Rect2(pos + Vector2(1, 1), Vector2(16, 16)), src)
	if level >= max_level:
		draw_rect(Rect2(pos + Vector2(13, 13), Vector2(3, 3)), UiKit.color("gold"))
	if flash > 0.0:
		draw_rect(Rect2(pos, Vector2(18, 18)), Color(1, 1, 1, 0.6 * flash))


func _player_bar() -> void:
	var p: Node2D = game.player
	var sp: Vector2 = p.get_global_transform_with_canvas().origin
	var hp: float = p.hp / game.stats.max_hp()
	var r := Rect2((sp + Vector2(-9, 3)).round(), Vector2(18, 3))
	draw_rect(r.grow(1), UiKit.color("ink"))
	draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * _hp_chip), r.size.y)), UiKit.color("cream"))
	draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * hp), r.size.y)), UiKit.color("red"))


func _boss_bar(w: float, h: float) -> void:
	var boss = null
	for e in game.enemies.list:
		if e.boss and e.alive() and e.behavior != "reaper":
			boss = e
			break
	if boss == null:
		return
	var bw := minf(300.0, w - 40.0)
	var r := Rect2(((w - bw) * 0.5), h - 16, bw, 8)
	draw_style_box(_bar_frame, r)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(floorf((bw - 4) * boss.hp / boss.max_hp), 4)), UiKit.color("blood"))
	_text(boss.def.name, Vector2(w * 0.5, h - 20), UiKit.FONT_S, UiKit.color("pink"), HORIZONTAL_ALIGNMENT_CENTER)


## 屏幕上方的提示条：Motion 弹簧入场，停留后淡出。
func toast(text: String) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.frame("ui.frame.card", "hover", 4))
	pc.add_child(UiKit.label(text, "lemon", UiKit.FONT_S, HORIZONTAL_ALIGNMENT_CENTER))
	holder.add_child(pc)
	holder.modulate.a = 0.0   # 布局完成前不可见
	add_child(holder)
	await get_tree().process_frame
	holder.size = pc.get_combined_minimum_size()
	holder.position = Vector2(roundf((size.x - holder.size.x) * 0.5), 48 + _toasts.size() * 22)
	_toasts.append(holder)
	MotionPlayer.play(holder, "motion.ui.toast_in")
	await get_tree().create_timer(2.2, false).timeout
	MotionPlayer.play(holder, "motion.ui.toast_out", 0.0, func():
		_toasts.erase(holder)
		holder.queue_free())


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed and not touch_active and not game.paused:
			touch_active = true
			_touch_idx = ev.index
			touch_origin = ev.position
		elif not ev.pressed and ev.index == _touch_idx:
			touch_active = false
			touch_vec = Vector2.ZERO
	elif ev is InputEventScreenDrag and touch_active and ev.index == _touch_idx:
		touch_vec = ((ev.position - touch_origin) / 26.0).limit_length(1.0)
	game.player.input_override = touch_vec
