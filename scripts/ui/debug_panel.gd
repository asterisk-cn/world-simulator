extends PanelContainer
## デバッグ用の一覧。村人が何を持っていて、いま何をしていて、家が建ったかを一望する。

var world = null

var _rows: VBoxContainer
var _summary: Label
var _accum := 0.0


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.BG
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.set_border_width_all(1)
	add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	root.add_child(head)
	head.add_child(UIKit.label("デバッグ", 14, Color(0.85, 0.9, 0.98)))
	var b1 := UIKit.button(head, "材料を配る", _give_materials, 10)
	b1.custom_minimum_size = Vector2(88, 22)
	var b2 := UIKit.button(head, "全員に家", _give_houses, 10)
	b2.custom_minimum_size = Vector2(76, 22)

	_summary = UIKit.label("", 11, Color(0.8, 0.85, 0.92))
	root.add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 1)
	scroll.add_child(_rows)


func _process(delta: float) -> void:
	if not visible or world == null:
		return
	_accum += delta
	if _accum < 0.2:
		return
	_accum = 0.0
	_refresh()


func _refresh() -> void:
	var houses := 0
	for s in world.structures:
		if s.kind == Structure.Kind.HOUSE:
			houses += 1
	_summary.text = "家 %d / %d　建築コスト 木%d 石%d" % [
		houses, world.villagers.size(), Rules.BUILD_WOOD, Rules.BUILD_STONE]

	while _rows.get_child_count() < world.villagers.size():
		var l := UIKit.label("", 11, Color(0.75, 0.79, 0.86))
		_rows.add_child(l)

	for i in range(world.villagers.size()):
		var v = world.villagers[i]
		var l: Label = _rows.get_child(i)
		var inv: Dictionary = v.inventory
		l.text = "%-4s 木%2d 石%2d 実%2d  %s  %s" % [
			v.vname, inv["wood"], inv["stone"], inv["food"],
			"家○" if v.home != null else "家×",
			v.action_label(),
		]
		l.add_theme_color_override("font_color",
			Color(0.6, 0.85, 0.65) if v.home != null else Color(0.75, 0.79, 0.86))


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
