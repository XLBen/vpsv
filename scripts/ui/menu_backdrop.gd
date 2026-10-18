extends Node2D
## 菜单背景：缓慢平移的地面，加几只来回游荡的怪物占位。

const Ground := preload("res://scripts/render/ground.gd")

var _cam: Camera2D
var _t := 0.0
var _walkers: Array = []   # [sprite, speed]
var _ground: Node2D


func view_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(_cam.position - vs * 0.5, vs)


func _ready() -> void:
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_ground = Ground.new()
	add_child(_ground)
	_ground.setup(self, "tile.forest", 0.0)
	var ids := ["actor.enemy.bat", "actor.enemy.zombie", "actor.enemy.skeleton", "actor.enemy.ghost", "actor.enemy.mudman", "actor.hero.whip"]
	for i in 10:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = Assets.sprite_frames(ids[i % ids.size()])
		s.play("walk")
		s.position = Vector2(randf_range(-320, 320), randf_range(-170, 170))
		var sp := randf_range(10.0, 26.0) * (1.0 if randf() < 0.5 else -1.0)
		s.flip_h = sp < 0.0
		s.modulate = Color(1, 1, 1, 0.55)
		add_child(s)
		_walkers.append([s, sp])


func _process(dt: float) -> void:
	_t += dt
	_cam.position = Vector2(_t * 12.0, sin(_t * 0.2) * 20.0).round()
	_ground.refresh(view_rect())
	for w in _walkers:
		var s: AnimatedSprite2D = w[0]
		s.position.x += w[1] * dt
		var rel := s.position.x - _cam.position.x
		if absf(rel) > 360.0:
			s.position.x = _cam.position.x - signf(rel) * 340.0
