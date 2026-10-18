extends Resource
## 武器数据。行为由 behavior 脚本实现（继承 scripts/weapons/weapon_base.gd），
## 数值、升级表、进化关系、素材 id 都在这里，可在 Godot 检查器中直接编辑。

@export var id := ""
@export var order := 0                         ## 列表排序（小的在前）
@export var name := ""
@export_multiline var desc := ""
@export var icon := ""                       ## 素材 id，例如 icon.weapon.whip
@export var behavior: Script                 ## 行为脚本
@export_range(1, 100) var rarity := 100      ## 升级选项抽取权重
@export_range(1, 8) var max_level := 8
@export var is_evolution := false
@export var hidden := false                  ## 只能通过进化获得，不进升级池

@export_group("基础数值")
@export var damage := 10.0
@export var area := 1.0
@export var speed := 1.0                     ## 投射物速度倍率
@export var amount := 1
@export var duration := 0.0                  ## 秒
@export var pierce := 1
@export var cooldown := 1.0                  ## 秒
@export var interval := 0.1                  ## 同一轮多发之间的间隔
@export var hit_delay := 0.5                 ## 同一目标再次受击的间隔（持续型）
@export var knockback := 1.0
@export var pool_limit := 0                  ## 同时存在的投射物上限，0 表示不限
@export var params := {}                     ## 行为脚本专用参数

@export_group("升级表")
## levels[i] 是升到 i+2 级时的增量（第 1 级为基础数值）。
@export var levels: Array[Resource] = []

@export_group("进化")
@export var evolve_passive := ""             ## 需要的被动
@export var evolve_passive_max := false      ## 被动是否需要满级
@export var evolve_weapon := ""              ## 合体：需要的另一把武器（满级）
@export var evolve_into := ""

@export_group("表现")
@export var vfx := {}                        ## 角色 → 素材 id，例如 {"projectile": "vfx.wand.bolt"}
@export var shader := ""                     ## 特效着色器路径
@export var ramp := ""                       ## 色带素材 id
@export var sfx := ""                        ## 出手音效 id
