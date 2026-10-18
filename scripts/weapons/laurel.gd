extends "res://scripts/weapons/weapon_base.gd"
## 桂冠：每隔 cooldown 秒给玩家 duration 秒的护盾（期间免疫伤害）。


var _bubble: Node2D


func setup() -> void:
	_bubble = game.vfx.quad(def.shader, Vector2(28, 28), def.ramp)
	_bubble.visible = false
	game.projectiles.add_child(_bubble)


func update(dt: float) -> void:
	super.update(dt)
	_bubble.visible = game.player.shield > 0.0
	_bubble.position = (game.player.position + Vector2(0, -9)).round()


func fire() -> void:
	game.player.shield = maxf(game.player.shield, duration())
	play_sfx()


func cleanup() -> void:
	game.vfx.release(_bubble)
