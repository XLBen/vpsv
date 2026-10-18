extends Node2D
## 判定框调试层（F3 切换，自动试玩 --hitbox 打开）：
##   绿 玩家 · 黄 怪物受击圈（身体中心）· 青 投射物 · 橙 持续区域 · 品红 近战判定 · 红 本次范围伤害形状。
## 用来核对“看到的”和“打到的”是否一致。

const Layers := preload("res://scripts/render/layers.gd")

var game: Node
var on := false
var _shapes: Array = []      # [kind, a, b, life]


func setup(g: Node) -> void:
	game = g
	Layers.put(self, Layers.DEBUG)
	visible = false


func toggle(v := not on) -> void:
	on = v
	visible = v
	_shapes.clear()


func rect(r: Rect2, life := 0.15) -> void:
	if on:
		_shapes.append(["rect", r, 0.0, life])


func circle(c: Vector2, r: float, life := 0.15) -> void:
	if on:
		_shapes.append(["circle", c, r, life])


func update(dt: float) -> void:
	if not on:
		return
	for s in _shapes:
		s[3] -= dt
	_shapes = _shapes.filter(func(s): return s[3] > 0.0)
	queue_redraw()


func _ring(c: Vector2, r: float, col: Color) -> void:
	draw_arc(c.round(), maxf(1.0, r), 0.0, TAU, maxi(8, int(r * 1.5)), col, 1.0, false)


func _draw() -> void:
	if not on:
		return
	var view: Rect2 = game.view_rect().grow(16.0)
	var p: Node2D = game.player
	_ring(p.position, p.radius, Color(0.3, 1.0, 0.4))
	draw_rect(Rect2(p.position.round() - Vector2(1, 1), Vector2(2, 2)), Color(0.3, 1.0, 0.4))
	for e in game.enemies.list:
		if e.alive() and view.has_point(e.pos):
			_ring(e.center(), e.radius, Color(1.0, 0.9, 0.2, 0.8))
	for pr in game.projectiles.projs:
		if not pr.dead:
			_ring(pr.pos, pr.radius, Color(0.3, 0.95, 1.0))
	for z in game.projectiles.zones:
		if not z.dead:
			_ring(z.pos, z.radius, Color(1.0, 0.6, 0.2))
	for s in game.projectiles.strikes:
		if not s.dead:
			draw_rect(s.rect(), Color(1.0, 0.3, 1.0, 0.9 if s.active() else 0.35), false, 1.0)
	for s in _shapes:
		if s[0] == "rect":
			draw_rect(s[1], Color(1.0, 0.25, 0.2), false, 1.0)
		else:
			_ring(s[1], s[2], Color(1.0, 0.25, 0.2))


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).physical_keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()
