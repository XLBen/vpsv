extends "res://scripts/weapons/weapon_base.gd"
## 雷电指环 / 雷霆回路：随机雷击屏幕内的敌人。雷霆回路每道闪电 repeat 次。

var _pending: Array = []   # [剩余时间, 位置]


func update(dt: float) -> void:
	super.update(dt)
	for q in _pending:
		q[0] -= dt
		if q[0] <= 0.0:
			_strike(q[1])
	_pending = _pending.filter(func(q): return q[0] > 0.0)


func fire() -> void:
	var cands: Array = game.enemies.in_view()
	if cands.is_empty():
		timer = 0.3
		return
	cands.shuffle()
	var rep := int(param("repeat", 1))
	for i in mini(amount(), cands.size()):
		var at: Vector2 = cands[i].pos
		_strike(at)
		for k in range(1, rep):
			_pending.append([0.25 * k, at])
	play_sfx()


func _strike(at: Vector2) -> void:
	var r := float(param("radius", 16)) * area()
	hit_circle(at, r)
	var h: float = game.view_rect().size.y * 0.7
	var q: Node2D = game.vfx.quad(def.shader, Vector2(r * 2.0 + 8.0, h), def.ramp)
	game.vfx.one_shot(q, at - Vector2(0, h * 0.5), 0.25)
	if q.material:
		q.material.set_shader_parameter("seed", randf() * 100.0)
	var flash: Node2D = game.vfx.quad("res://shaders/weapons/explosion.gdshader", Vector2.ONE * r * 2.0, def.ramp)
	game.vfx.one_shot(flash, at, 0.25)
