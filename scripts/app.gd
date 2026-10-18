extends Node
## 应用入口：界面导航（标题 / 选角 / 选关 / 强化 / 图鉴 / 设置）、像素转场、开局与结算。

const Game := preload("res://scripts/core/game.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const Unlocks := preload("res://scripts/core/unlocks.gd")
const Backdrop := preload("res://scripts/ui/menu_backdrop.gd")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const SelectScreen := preload("res://scripts/ui/select_screen.gd")
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")
const SettingsScreen := preload("res://scripts/ui/settings_screen.gd")
const CollectionScreen := preload("res://scripts/ui/collection_screen.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const LevelUpPanel := preload("res://scripts/ui/level_up_panel.gd")
const ChestPanel := preload("res://scripts/ui/chest_panel.gd")
const PausePanel := preload("res://scripts/ui/pause_panel.gd")
const ResultsPanel := preload("res://scripts/ui/results_panel.gd")
const TRANSITION := preload("res://shaders/ui/transition.gdshader")

var ui_root: Control
var screen: Control
var backdrop: Node2D
var game: Node2D
var run_ui: Array[Control] = []
var _history: Array[Callable] = []
var _pick_character := ""
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	SettingsScreen.apply(Save.settings())
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui_root = Control.new()
	ui_root.theme = UiKit.theme()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	var top := CanvasLayer.new()
	top.layer = 100
	add_child(top)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = TRANSITION
	m.set_shader_parameter("pattern", Assets.texture("ui.pattern.diamond"))
	m.set_shader_parameter("color", Assets.color("ink"))
	_fade.material = m
	top.add_child(_fade)
	_set_fade(0.0)
	_show_backdrop()
	show_title()


# ------------------------------------------------------------ 转场与导航

func _set_fade(v: float) -> void:
	_fade.material.set_shader_parameter("progress", v)
	_fade.visible = v > 0.0


## 像素菱形转场：盖住 → 执行 change → 揭开。
func transition(change: Callable) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, 0.25)
	await tw.finished
	change.call()
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_method(_set_fade, 1.0, 0.0, 0.3)
	await tw2.finished
	_busy = false


func _set_screen(s: Control) -> void:
	if game != null and not game.finished:
		# 开局后不再显示菜单（转场回调可能晚于开局到达）
		s.queue_free()
		return
	if screen:
		screen.queue_free()
	screen = s
	ui_root.add_child(s)


func _open(builder: Callable, remember := true) -> void:
	if remember:
		_history.append(builder)
	transition(func(): _set_screen(builder.call()))


func back() -> void:
	if _history.size() > 1:
		_history.pop_back()
		var prev: Callable = _history.back()
		transition(func(): _set_screen(prev.call()))


func show_title() -> void:
	_history.clear()
	_open(func():
		var s := TitleScreen.new()
		s.setup(self)
		return s)


func show_character_select() -> void:
	_open(func():
		var s := SelectScreen.new()
		s.setup(self, "characters", func(id: String):
			_pick_character = id
			show_stage_select())
		return s)


func show_stage_select() -> void:
	_open(func():
		var s := SelectScreen.new()
		s.setup(self, "stages", func(id: String): start_run(_pick_character, id))
		return s)


func show_shop() -> void:
	_open(func():
		var s := ShopScreen.new()
		s.setup(self)
		return s)


func show_settings() -> void:
	_open(func():
		var s := SettingsScreen.new()
		s.setup(self)
		return s)


func show_collection() -> void:
	_open(func():
		var s := CollectionScreen.new()
		s.setup(self)
		return s)


func _show_backdrop() -> void:
	if backdrop == null:
		backdrop = Backdrop.new()
		add_child(backdrop)


# ------------------------------------------------------------ 开局与结算

func start_run(character_id: String, stage_id: String, instant := false) -> void:
	var begin := func():
		if screen:
			screen.queue_free()
			screen = null
		if backdrop:
			backdrop.queue_free()
			backdrop = null
		game = Game.new()
		add_child(game)
		game.setup(character_id, stage_id)
		game.run_finished.connect(_on_run_finished)
		var hud := Hud.new()
		var lvl := LevelUpPanel.new()
		var chest := ChestPanel.new()
		var pause := PausePanel.new()
		for c: Control in [hud, lvl, chest, pause]:
			ui_root.add_child(c)
			c.setup(game)
			run_ui.append(c)
	if instant:
		begin.call()
	else:
		transition(begin)


func _on_run_finished(result: Dictionary) -> void:
	var news := Unlocks.apply_result(result)
	var panel := ResultsPanel.new()
	ui_root.add_child(panel)
	run_ui.append(panel)
	panel.on_done = func(): end_run()
	panel.show_result(result)
	for n: String in news:
		game.toast(n)


func end_run() -> void:
	transition(func():
		for c in run_ui:
			c.queue_free()
		run_ui.clear()
		if game:
			game.queue_free()
			game = null
		Audio.stop_music()
		_show_backdrop()
		_history.clear()
		var s := TitleScreen.new()
		s.setup(self)
		_history.append(func():
			var t := TitleScreen.new()
			t.setup(self)
			return t)
		_set_screen(s))
