extends "res://scripts/weapons/weapon_base.gd"
## 桂冠：每隔 cooldown 秒给玩家 duration 秒的护盾（期间免疫伤害）。
## 护盾出现 / 破裂时播放工作室导出的 pop 曲线。

const MotionPlayer := preload("res://scripts/ui/motion_player.gd")

var _bubble: Node2D
var _on := false
var _pop := 9.0


func setup() -> void:
	_bubble = game.vfx.quad(def.shader, Vector2(28, 28), def.ramp)
	_bubble.visible = false
	game.projectiles.add_child(_bubble)


func update(dt: float) -> void:
	super.update(dt)
	var on: bool = game.player.shield > 0.0
	if on != _on:
		_on = on
		_pop = 0.0
	_pop += dt
	var m := MotionPlayer.sample("motion.fx.pop_in" if _on else "motion.fx.pop_out", _pop)
	_bubble.visible = _on or _pop < MotionPlayer.length_of("motion.fx.pop_out")
	_bubble.scale = Vector2.ONE * float(m.get("sx", 1.0))
	_bubble.modulate.a = float(m.get("alpha", 1.0))
	_bubble.position = (game.player.position + Vector2(0, -9)).round()


func fire() -> void:
	game.player.shield = maxf(game.player.shield, duration())
	play_sfx()


func cleanup() -> void:
	game.vfx.release(_bubble)
