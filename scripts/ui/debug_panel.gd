extends PanelContainer

signal closed
## 検証用の近道だけ。見て楽しむ一覧は roster_panel.gd に移した。

var world = null

var _summary: Label
var _accum := 0.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.panel_style())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP_S)
	add_child(root)

	UIKit.window_header(root, "デバッグ", _close)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	root.add_child(head)
	var b1 := UIKit.button(head, "材料を配る", _give_materials, 10)
	b1.custom_minimum_size = Vector2(88, UIKit.ROW_H)
	var b2 := UIKit.button(head, "全員に家", _give_houses, 10)
	b2.custom_minimum_size = Vector2(76, UIKit.ROW_H)

	_summary = UIKit.label("", 11, UIKit.TEXT_DIM)
	root.add_child(_summary)


func _process(delta: float) -> void:
	if not visible or world == null:
		return
	_accum += delta
	if _accum < 0.3:
		return
	_accum = 0.0
	var houses := 0
	for st in world.structures:
		if st.kind == Structure.Kind.HOUSE:
			houses += 1
	_summary.text = "家 %d / %d　建築コスト 木%d 石%d" % [
		houses, world.villagers.size(), Rules.BUILD_WOOD, Rules.BUILD_STONE]


## 建築の検証用。全員に家1軒ぶんの材料を渡す。
func _give_materials() -> void:
	for v in world.villagers:
		v.add_item("wood", Rules.BUILD_WOOD)
		v.add_item("stone", Rules.BUILD_STONE)
	EventLog.notable("神が全員に建築材料を配った")


## 家が建った状態をすぐ見るための近道。
func _give_houses() -> void:
	for v in world.villagers:
		if v.home != null:
			continue
		var c: Vector2i = world.find_build_cell(v.cell)
		if c.x < 0:
			continue
		v.home = world.add_structure(Structure.Kind.HOUSE, c, v.id, v.color)
	EventLog.notable("神が家を建てた")


func _close() -> void:
	closed.emit()
