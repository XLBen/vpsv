extends Resource
## 武器单级升级增量。未填写的字段为 0，表示不变。

@export var desc := ""
@export var damage := 0.0
@export var area := 0.0
@export var speed := 0.0
@export var amount := 0
@export var duration := 0.0
@export var pierce := 0
@export var cooldown := 0.0
@export var knockback := 0.0


const FIELDS := ["damage", "area", "speed", "amount", "duration", "pierce", "cooldown", "knockback"]
