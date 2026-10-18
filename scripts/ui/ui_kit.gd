extends RefCounted
## 界面工具：主题（像素字体 + 工作室导出的九宫格边框）、常用控件工厂。
## 所有边框都是素材 id，美术替换图即可改变整体界面风格。

const MotionPlayer := preload("res://scripts/ui/motion_player.gd")
const IconRect := preload("res://scripts/ui/icon_rect.gd")

const FONT_S := 12
const FONT_L := 24

static var _theme: Theme


static func color(key: String) -> Color:
	return Assets.color(key)


## 九宫格边框：边距写在素材 tags 的 "margin:N" 中。
static func frame(id: String, clip := "normal", content_margin := -1) -> StyleBox:
	if not Assets.has(id):
		var sb := StyleBoxFlat.new()
		sb.bg_color = color("night")
		sb.border_color = color("clay")
		sb.set_border_width_all(2)
		sb.set_content_margin_all(6)
		return sb
	var info = Assets.sheet(id)
	var margin := 6
	for tag: String in Assets.entry(id).get("tags", []):
		if tag.begins_with("margin:"):
			margin = int(tag.get_slice(":", 1))
	var at := AtlasTexture.new()
	at.atlas = info.texture
	var c: Dictionary = info.clip(clip)
	at.region = Rect2(Vector2(0, int(c.row) * info.size.y), Vector2(info.size))
	var sb := StyleBoxTexture.new()
	sb.texture = at
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content_margin if content_margin >= 0 else margin)
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = Assets.font
	t.default_font_size = FONT_S
	t.set_color("font_color", "Label", color("paper"))
	t.set_color("font_outline_color", "Label", color("ink"))
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 1)
	t.set_stylebox("panel", "PanelContainer", frame("ui.frame.panel"))
	t.set_stylebox("panel", "Panel", frame("ui.frame.panel"))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var clip := state if state != "focus" else "hover"
		t.set_stylebox(state, "Button", frame("ui.frame.button", clip, 4))
	t.set_color("font_color", "Button", color("cream"))
	t.set_color("font_hover_color", "Button", color("white"))
	t.set_color("font_pressed_color", "Button", color("tan"))
	t.set_color("font_disabled_color", "Button", color("dusk"))
	t.set_color("font_focus_color", "Button", color("white"))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func label(text: String, color_key := "paper", size := FONT_S, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", color(color_key))
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 按钮：悬停 / 按下时播放导出的动效，并播放界面音效。
static func button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 20)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Audio.play("sfx.ui.confirm")
		MotionPlayer.play(b, "motion.ui.button_press")
		cb.call())
	b.mouse_entered.connect(func():
		Audio.play("sfx.ui.hover")
		MotionPlayer.play(b, "motion.ui.button_hover"))
	b.focus_entered.connect(func(): MotionPlayer.play(b, "motion.ui.button_hover"))
	b.mouse_exited.connect(func(): MotionPlayer.stop(b, true))
	return b


static func icon(asset_id: String, scale := 2) -> Control:
	var i := IconRect.new()
	i.set_icon(asset_id, scale)
	return i


## 图标槽：小边框 + 图标 + 右下角等级。
static func slot(asset_id: String, level := 0, max_level := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame("ui.frame.slot", "normal", 1))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := icon(asset_id, 1)
	p.add_child(i)
	if level > 0:
		var l := label("M" if level >= max_level else str(level), "gold" if level >= max_level else "paper")
		l.add_theme_font_size_override("font_size", FONT_S)
		l.position = Vector2(10, 6)
		i.add_child(l)
	return p


## 全屏半透明遮罩。
static func dim(alpha := 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(color("ink"), alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


static func fmt_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]


static func fmt_num(v: float) -> String:
	var n := int(v)
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%.1fK" % (n / 1000.0)
	return str(n)
