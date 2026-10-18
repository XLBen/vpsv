extends Resource
## 敌人数据。

@export var id := ""
@export var order := 0                         ## 列表排序（小的在前）
@export var name := ""
@export var sprite := ""                      ## 素材 id，例如 actor.enemy.bat
@export var hp := 10.0
@export var hp_per_level := 0.0               ## 首领：额外生命 × 玩家等级
@export var speed := 30.0                     ## 像素/秒
@export var damage := 5.0
@export var radius := 6.0
@export var xp := 1
@export_range(0.0, 1.0) var knockback_resist := 0.0
@export var freeze_immune := false
@export var boss := false
## chase 追击 · swarm 直线穿越 · wall 包围墙 · boss_charge 首领冲锋 · reaper 死神
@export var behavior := "chase"
@export var chest := false                    ## 死亡掉落宝箱
