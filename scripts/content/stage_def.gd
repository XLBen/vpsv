extends Resource
## 关卡数据。

@export var id := ""
@export var order := 0                         ## 列表排序（小的在前）
@export var name := ""
@export_multiline var desc := ""
@export var tileset := ""                     ## 地面图块素材 id
@export var light_source := ""                ## 光源素材 id
@export var bounded_height := 0.0             ## 0 = 无限地图；>0 = 纵向边界高度（像素）
@export var duration := 1800.0                ## 秒；到时出现死神
@export var light_density := 0.6              ## 每屏光源数量
@export var max_enemies := 400
@export var bgm := ""
@export var unlock := ""
@export var unlock_desc := ""
## 每分钟波次：[{enemies: [id...], min: 15, interval: 1.0, boss: "id"}]，下标即分钟。
@export var waves: Array[Dictionary] = []
## 事件：[{at: 秒, type: "bat_swarm"/"ghost_swarm"/"flower_wall", ...参数}]
@export var events: Array[Dictionary] = []
## 光源掉落权重：{pickup_id: weight}
@export var drops := {}
