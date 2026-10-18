extends Node2D
## 投射物与持续伤害区域。武器脚本创建它们，这里负责移动、碰撞、寿命和表现节点同步。

class Proj:
	var weapon: Object                 # WeaponBase
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 1.0
	var age := 0.0
	var radius := 4.0
	var damage := 10.0
	var pierce := 1
	var knockback := 1.0
	var hit_delay := 0.0               # 0：每个敌人只命中一次；>0：间隔后可再次命中
	var gravity := 0.0
	var spin := 0.0
	var rot := 0.0
	var face_velocity := true
	var mode := ""                     # "" 直线 · boomerang 回旋 · bounce 屏幕反弹 · spiral 螺旋外扩
	var data := {}
	var node: Node2D
	var dead := false
	var hits := {}
	var on_hit: Callable               # func(p, enemy)
	var on_expire: Callable            # func(p)
	var on_bounce: Callable            # func(p)


class Zone:
	var weapon: Object
	var pos := Vector2.ZERO
	var radius := 16.0
	var life := 1.0
	var age := 0.0
	var damage := 10.0
	var knockback := 0.0
	var hit_delay := 0.5
	var grow := 0.0                    # 每秒半径增长比例
	var follow := 0.0                  # >0：以该速度向玩家移动
	var node: Node2D
	var dead := false
	var on_hit: Callable


var game: Node
var projs: Array = []
var zones: Array = []


func setup(g: Node) -> void:
	game = g


func add_proj(p: Proj) -> Proj:
	projs.append(p)
	if p.node:
		add_child(p.node)
		p.node.position = p.pos.round()
	return p


func add_zone(z: Zone) -> Zone:
	zones.append(z)
	if z.node:
		add_child(z.node)
		z.node.position = z.pos.round()
	return z


func count_for(weapon: Object) -> int:
	var n := 0
	for p: Proj in projs:
		if p.weapon == weapon and not p.dead:
			n += 1
	return n


func update(dt: float) -> void:
	var view: Rect2 = game.view_rect()
	for p: Proj in projs:
		if p.dead:
			continue
		p.age += dt
		p.life -= dt
		if p.life <= 0.0:
			_expire(p)
			continue
		_move(p, dt, view)
		_collide(p)
		if p.node:
			p.node.position = p.pos.round()
			if p.face_velocity and p.vel.length_squared() > 1.0:
				p.node.rotation = p.vel.angle()
			else:
				p.node.rotation = p.rot
	for z: Zone in zones:
		if z.dead:
			continue
		z.age += dt
		z.life -= dt
		if z.life <= 0.0:
			z.dead = true
			continue
		z.radius *= 1.0 + z.grow * dt
		if z.follow > 0.0:
			z.pos = z.pos.move_toward(game.player.position, z.follow * dt)
		for e in game.enemies.query(z.pos, z.radius + 16.0):
			if e.alive() and e.pos.distance_to(z.pos) < z.radius + e.radius and game.enemies.can_hit(e, z, z.hit_delay):
				if z.on_hit.is_valid():
					z.on_hit.call(z, e)
				else:
					game.enemies.damage(e, z.damage, (e.pos - z.pos).normalized(), z.knockback, z.weapon)
		game.pickups.hit_props(z.pos, z.radius)
		if z.node:
			z.node.position = z.pos.round()
			if z.node.has_method("set_radius"):
				z.node.set_radius(z.radius, 1.0 - z.life / maxf(z.life + z.age, 0.001))
	_cleanup()


func _move(p: Proj, dt: float, view: Rect2) -> void:
	match p.mode:
		"boomerang":
			# 先减速，再加速飞回玩家
			var back: Vector2 = (game.player.position - p.pos).normalized()
			p.vel += back * float(p.data.get("accel", 380.0)) * dt
		"bounce":
			var r := view.grow(-4.0)
			if (p.pos.x < r.position.x and p.vel.x < 0.0) or (p.pos.x > r.end.x and p.vel.x > 0.0):
				p.vel.x = -p.vel.x
				_bounced(p)
			if (p.pos.y < r.position.y and p.vel.y < 0.0) or (p.pos.y > r.end.y and p.vel.y > 0.0):
				p.vel.y = -p.vel.y
				_bounced(p)
		"spiral":
			p.vel = p.vel.rotated(float(p.data.get("turn", 1.5)) * dt)
	p.vel.y += p.gravity * dt
	p.pos += p.vel * dt
	p.rot += p.spin * dt


func _bounced(p: Proj) -> void:
	if p.on_bounce.is_valid():
		p.on_bounce.call(p)


func _collide(p: Proj) -> void:
	for e in game.enemies.query(p.pos, p.radius + 16.0):
		if not e.alive():
			continue
		var rr: float = e.radius + p.radius
		if e.pos.distance_squared_to(p.pos) >= rr * rr:
			continue
		var t: float = game.run.time
		if p.hits.has(e) and (p.hit_delay <= 0.0 or t < float(p.hits[e])):
			continue
		p.hits[e] = t + p.hit_delay
		if p.on_hit.is_valid():
			p.on_hit.call(p, e)
		else:
			game.enemies.damage(e, p.damage, p.vel.normalized(), p.knockback, p.weapon)
		p.pierce -= 1
		if p.pierce <= 0:
			_expire(p)
			return
	game.pickups.hit_props(p.pos, p.radius)


func _expire(p: Proj) -> void:
	if p.dead:
		return
	p.dead = true
	if p.on_expire.is_valid():
		p.on_expire.call(p)


func _cleanup() -> void:
	var j := 0
	for i in projs.size():
		var p: Proj = projs[i]
		if p.dead:
			if p.node:
				game.vfx.release(p.node)
		else:
			projs[j] = p
			j += 1
	projs.resize(j)
	j = 0
	for i in zones.size():
		var z: Zone = zones[i]
		if z.dead:
			if z.node:
				game.vfx.release(z.node)
		else:
			zones[j] = z
			j += 1
	zones.resize(j)


func clear_all() -> void:
	for p: Proj in projs:
		p.dead = true
	for z: Zone in zones:
		z.dead = true
	_cleanup()
