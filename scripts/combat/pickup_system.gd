extends Node2D
## 场上拾取物与光源：经验宝石（三档）、金币、各种道具、宝箱，以及可破坏的光源。

const SheetBatch := preload("res://scripts/render/sheet_batch.gd")

const MAX_GEMS := 400
const PICK_RADIUS := 10.0
const BASE_MAGNET := 30.0


class Item:
	var def: Resource
	var kind := ""                   # 拾取物 id
	var sprite := ""
	var pos := Vector2.ZERO
	var value := 0.0
	var attract := false             # 进入磁力范围后飞向玩家
	var pulled := false
	var sp := 0.0
	var age := 0.0
	var dead := false
	var data := {}                   # 宝箱：{boss: EnemyDef}


class Prop:
	var pos := Vector2.ZERO
	var sprite := ""
	var broken := -1.0
	var dead := false


var game: Node
var items: Array = []
var props: Array = []
var batches := {}
var _gem_count := 0
var _overflow: Item = null
var _prop_t := 0.0


func setup(g: Node) -> void:
	game = g


# ------------------------------------------------------------ 生成

func drop_xp(pos: Vector2, value: float) -> void:
	if _gem_count >= MAX_GEMS:
		# 宝石过多时，多余经验并入一颗大红宝石（与原版一致）
		if _overflow == null or _overflow.dead:
			_overflow = _add("gem", pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)), value)
		else:
			_overflow.value += value
		_overflow.sprite = "pickup.gem.red"
		return
	_add("gem", pos, value)


func drop(kind: String, pos: Vector2, value := -1.0) -> Item:
	return _add(kind, pos, value)


func drop_chest(pos: Vector2, boss_def: Resource) -> void:
	var it := _add("chest", pos, 0.0)
	it.data = {"boss": boss_def}


func _add(kind: String, pos: Vector2, value: float) -> Item:
	var def: Resource = Registry.pickup(kind)
	var it := Item.new()
	it.def = def
	it.kind = kind
	it.pos = pos
	it.value = value if value >= 0.0 else (def.value if def else 0.0)
	it.sprite = def.sprite if def else "pickup.coin"
	it.attract = kind == "gem" or kind == "coin"
	if kind == "gem":
		it.sprite = _gem_sprite(it.value)
		_gem_count += 1
	items.append(it)
	return it


static func _gem_sprite(v: float) -> String:
	if v >= 10.0:
		return "pickup.gem.red"
	if v >= 3.0:
		return "pickup.gem.green"
	return "pickup.gem.blue"


## 光源掉落：按关卡权重表抽取，幸运会提高稀有道具的权重。
func roll_light_drop(pos: Vector2) -> void:
	var table: Dictionary = game.stage.drops
	var luck: float = game.stats.get_stat("luck")
	var total := 0.0
	var pool := []
	for id: String in table:
		var def: Resource = Registry.pickup(id)
		if def == null or game.run.level < def.min_level:
			continue
		var w := float(table[id]) * (luck if def.luck_affected else 1.0)
		pool.append([id, w])
		total += w
	var roll := randf() * total
	for entry in pool:
		roll -= entry[1]
		if roll <= 0.0:
			_add(entry[0], pos, -1.0)
			return


# ------------------------------------------------------------ 更新

func update(dt: float) -> void:
	var ppos: Vector2 = game.player.position
	var magnet: float = BASE_MAGNET * game.stats.get_stat("magnet")
	for it: Item in items:
		if it.dead:
			continue
		it.age += dt
		var to := ppos - it.pos
		var d := to.length()
		if it.attract and not it.pulled and d < magnet:
			it.pulled = true
		if it.pulled:
			it.sp = minf(400.0, it.sp + 700.0 * dt)
			if d > 0.01:
				it.pos += to / d * minf(d, it.sp * dt)
				d = it.pos.distance_to(ppos)
		if d < PICK_RADIUS:
			it.dead = true
			if it.kind == "gem":
				_gem_count -= 1
			game.collect(it)
	_update_props(dt)
	_compact()
	_render(game.view_rect().grow(32.0))


## 吸尘器 / 华美之月：吸取全部宝石。
func vacuum() -> void:
	for it: Item in items:
		if it.kind == "gem":
			it.pulled = true


# ------------------------------------------------------------ 光源

func _update_props(dt: float) -> void:
	var view: Rect2 = game.view_rect()
	for p: Prop in props:
		if p.broken >= 0.0:
			p.broken += dt
			if p.broken > 0.6:
				p.dead = true
		elif not view.grow(view.size.x).has_point(p.pos):
			p.dead = true
	# 维持玩家周围的光源密度：在视野外 1 屏范围内补充
	_prop_t -= dt
	if _prop_t > 0.0:
		return
	_prop_t = 1.0
	var target := int(game.stage.light_density * 9.0)
	var near := 0
	var area := view.grow(view.size.x)
	for p: Prop in props:
		if not p.dead and area.has_point(p.pos):
			near += 1
	for i in maxi(0, target - near):
		var pos := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if view.grow(16.0).has_point(pos) or not game.in_bounds(pos):
			continue
		var p := Prop.new()
		p.pos = pos
		p.sprite = game.stage.light_source
		props.append(p)


## 武器命中范围内的光源被打碎并掉落道具。
func hit_props(pos: Vector2, radius: float) -> void:
	for p: Prop in props:
		if p.broken < 0.0 and not p.dead and p.pos.distance_squared_to(pos) < (radius + 6.0) * (radius + 6.0):
			p.broken = 0.0
			roll_light_drop(p.pos + Vector2(0, -4))
			Audio.play("sfx.prop.break")


func _compact() -> void:
	var j := 0
	for i in items.size():
		if not items[i].dead:
			items[j] = items[i]
			j += 1
	items.resize(j)
	j = 0
	for i in props.size():
		if not props[i].dead:
			props[j] = props[i]
			j += 1
	props.resize(j)


func _batch(sprite: String) -> Node:
	if not batches.has(sprite):
		var b := SheetBatch.new()
		b.setup(sprite)
		add_child(b)
		batches[sprite] = b
	return batches[sprite]


func _render(view: Rect2) -> void:
	for b in batches.values():
		b.begin()
	var t: float = game.run.time
	for p: Prop in props:
		if not view.has_point(p.pos):
			continue
		var b = _batch(p.sprite)
		var clip := "break" if p.broken >= 0.0 else "idle"
		var c: Dictionary = b.info.clip(clip)
		b.add(p.pos, false, b.info.frame_at(clip, p.broken if p.broken >= 0.0 else t + p.pos.x * 0.01), int(c.row))
	for it: Item in items:
		if not view.has_point(it.pos):
			continue
		var b = _batch(it.sprite)
		var c: Dictionary = b.info.clip("idle")
		var bob := Vector2(0, roundf(sin(it.age * 4.0 + it.pos.x) * 1.0)) if it.kind != "gem" else Vector2.ZERO
		b.add(it.pos + bob, false, b.info.frame_at("idle", it.age + it.pos.y * 0.05), int(c.row))
	for b in batches.values():
		b.commit()
