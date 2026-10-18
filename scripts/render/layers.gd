extends RefCounted
## 世界内的绘制层级（z_index，均为绝对值）。所有节点统一从这里取值，避免互相遮挡：
## 地面类特效（圣水、大蒜）必须在怪物之下，否则怪物走进去就“隐形”了。

const GROUND := -100
const GROUND_FX := -20      # 圣水火池、大蒜光环等贴地特效
const PICKUPS := -10        # 宝石、金币、光源
const ENEMIES := 0
const PLAYER := 5
const PROJECTILES := 10     # 投射物、环绕物、鸟
const VFX := 20             # 一次性特效、命中火花
const SCREEN_FX := 40       # 全屏闪光（五芒星）
const NUMBERS := 50         # 伤害数字、粒子
const DEBUG := 60           # 判定框调试层


## 把节点放到指定层（绝对 z，不受父节点影响）。
static func put(node: CanvasItem, layer: int) -> void:
	node.z_as_relative = false
	node.z_index = layer


## 节点最终生效的 z（测试用）。
static func effective_z(node: Node) -> int:
	var z := 0
	var n := node
	while n != null:
		if n is CanvasItem:
			z += (n as CanvasItem).z_index
			if not (n as CanvasItem).z_as_relative:
				break
		n = n.get_parent()
	return z
