extends Node2D
## 投射物、持续伤害区域与近战判定。武器脚本创建它们，这里负责移动、碰撞、寿命和表现节点同步。
## 投射物和近战判定对怪物的身体中心（Enemy.center()）判定；贴地的区域对脚底判定。

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
	var fade := 0.0                    # 寿命末尾的消散时长（表现节点的着色器 dissolve 参数）
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


## 近战判定（皮鞭等）：跟随 follow 的矩形，只在 [start, start + window] 内生效，
## 窗口内每个敌人最多命中一次。命中交给 weapon.hit()，因此武器自己的命中效果（如血泪回血）照常生效。
class Strike:
	var weapon: Object
	var follow: Node2D
	var offset := Vector2.ZERO         # 矩形中心相对 follow 的偏移
	var size := Vector2(16, 16)
	var start := 0.0
	var window := 0.1
	var age := 0.0
	var kdir := Vector2.ZERO
	var damage := -1.0                 # < 0：用武器当前伤害
	var dead := false
	var hits := {}

	func rect() -> Rect2:
		var c := follow.position + offset
		return Rect2(c - size * 0.5, size)

	func active() -> bool:
		return age >= start and age <= start + window


var game: Node
var projs: Array = []
var zones: Array = []
var strikes: Array = []


func setup(g: Node) -> void:
	game = g


func add_proj(p: Proj) -> Proj:
	projs.append(p)
	if p.node:
		add_child(p.node)
		p.node.position = p.pos.round()
	return p


func add_strike(s: Strike) -> Strike:
	strikes.append(s)
	return s


## parent：表现节点挂在哪个节点下（贴地的火池挂到 game.ground_fx，在怪物之下）。
func add_zone(z: Zone, parent: Node = null) -> Zone:
	zones.append(z)
	if z.node:
		(parent if parent else self).add_child(z.node)
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
			if p.fade > 0.0 and p.life < p.fade and p.node.material is ShaderMaterial:
				(p.node.material as ShaderMaterial).set_shader_parameter("dissolve", 1.0 - p.life / p.fade)
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
		for e in game.enemies.query(z.pos, z.radius + 32.0):
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
	for s: Strike in strikes:
		if s.dead:
			continue
		var was := s.age
		s.age += dt
		# 帧时间较长时也保证窗口至少判定一次
		if s.age >= s.start and was <= s.start + s.window:
			_strike(s)
		if s.age > s.start + s.window:
			s.dead = true
	_cleanup()


func _strike(s: Strike) -> void:
	var r := s.rect()
	game.debug.rect(r)
	var c := r.get_center()
	for e in game.enemies.query(c, maxf(r.size.x, r.size.y) * 0.5 + 16.0):
		if e.alive() and not s.hits.has(e) and r.grow(e.radius).has_point(e.center()):
			s.hits[e] = true
			s.weapon.hit(e, s.damage, s.kdir)
	game.pickups.hit_props(c, maxf(r.size.x, r.size.y) * 0.5)


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
		if e.center().distance_squared_to(p.pos) >= rr * rr:
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
	strikes = strikes.filter(func(s): return not s.dead)


func clear_all() -> void:
	for p: Proj in projs:
		p.dead = true
	for z: Zone in zones:
		z.dead = true
	for s: Strike in strikes:
		s.dead = true
	_cleanup()
