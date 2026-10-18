extends RefCounted
## --narrative-test：实际实例化对话界面和 CG 画廊，把测试剧本从头播到尾（不接入玩法）。

const DialogueView := preload("res://scripts/narrative/dialogue_view.gd")
const CgGallery := preload("res://scripts/narrative/cg_gallery.gd")


static func run(app: Node) -> bool:
	var v := DialogueView.new()
	app.ui_root.add_child(v)
	if not v.play("_dev_test"):
		return false
	var steps := 0
	while is_instance_valid(v) and v.runner.running and steps < 100:
		steps += 1
		if v.runner.waiting_choice:
			v._pick(0)
		else:
			v._wait_t = 0.0
			v.runner.advance()
	var gallery := CgGallery.new()
	app.ui_root.add_child(gallery)
	var ok := steps < 100 and gallery._cells.size() >= 1
	gallery.queue_free()
	return ok
