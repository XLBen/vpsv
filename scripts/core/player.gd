extends Node2D
## 玩家：移动、朝向、受伤、无敌、回复、复活、护盾。外观来自角色的序列帧素材。

const BASE_SPEED := 70.0
const INVULN := 0.4
const HURT_SHADER := preload("res://shaders/player.gdshader")
const Layers := preload("res://scripts/render/layers.gd")

var game: Node
var radius := 5.0
var hp := 100.0
var move_dir := Vector2.RIGHT     # 最近一次移动方向（飞刀等）
var face := 1.0
var moving := false
var invuln := 0.0
var shield := 0.0                 # 桂冠护盾剩余时间
var hurt_flash := 0.0
var input_override := Vector2.ZERO   # 触屏摇杆
var _sprite: AnimatedSprite2D
var _mat: ShaderMaterial

signal hurt_taken(amount: float)
signal died


func setup(g: Node, sprite_id: String) -> void:
	game = g
	Layers.put(self, Layers.PLAYER)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Assets.sprite_frames(sprite_id)
	var info = Assets.sheet(sprite_id)
	_sprite.centered = false
	_sprite.offset = -Vector2(info.pivot) - Vector2(0, 1)
	_mat = ShaderMaterial.new()
	_mat.shader = HURT_SHADER
	_sprite.material = _mat
	add_child(_sprite)
	_sprite.play("idle")
	hp = game.stats.max_hp()


func update(dt: float) -> void:
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_override.length() > 0.15:
		mv = input_override.limit_length(1.0)
	moving = mv.length() > 0.1
	if moving:
		position += mv * BASE_SPEED * game.stats.get_stat("move_speed") * dt
		move_dir = mv.normalized()
		if absf(mv.x) > 0.15:
			face = signf(mv.x)
	position = game.clamp_to_bounds(position)
	invuln = maxf(0.0, invuln - dt)
	shield = maxf(0.0, shield - dt)
	hurt_flash = maxf(0.0, hurt_flash - dt)
	hp = minf(game.stats.max_hp(), hp + game.stats.get_stat("recovery") * dt)

	var anim := "walk" if moving else "idle"
	if hurt_flash > 0.25:
		anim = "hurt"
	if _sprite.animation != anim:
		_sprite.play(anim)
	_sprite.flip_h = face < 0.0
	_mat.set_shader_parameter("flash", hurt_flash / 0.35)
	_mat.set_shader_parameter("invuln", 1.0 if invuln > 0.0 else 0.0)
	_mat.set_shader_parameter("shield", shield)


func hurt(amount: float, _source: Object = null) -> void:
	if invuln > 0.0 or game.paused or amount <= 0.0:
		return
	if shield > 0.0:
		return
	var dmg := maxf(1.0, amount - game.stats.get_stat("armor"))
	hp -= dmg
	invuln = INVULN
	hurt_flash = 0.35
	game.camera_shake(3.0)
	game.vfx.float_text(position + Vector2(0, -22), str(int(dmg)), Assets.color("red"))
	Audio.play("sfx.player.hurt")
	hurt_taken.emit(dmg)
	if hp <= 0.0:
		hp = 0.0
		died.emit()


func heal(amount: float) -> void:
	hp = minf(game.stats.max_hp(), hp + amount)
	game.vfx.float_text(position + Vector2(0, -22), "+%d" % int(amount), Assets.color("lime"))


func revive() -> void:
	hp = game.stats.max_hp() * 0.5
	invuln = 2.0
	_sprite.play("idle")
