extends PanelContainer
## 村人一覧。いま誰が何をしていて、何を持っているかを一望する。
##
## 観察する遊びなので「いま誰が何をしているか」がいちばん見たい情報になる。
## 一人ずつ選んで確かめるのでは追えないため、正面の窓として置く。

signal closed
signal select_requested(v)

var world = null

var _rows: VBoxContainer
var _summary: Label
var _accum := 0.0
var _row_count := -1


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.panel_style())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP_S)
	add_child(root)

	UIKit.window_header(root, "村人", _close)
	_summary = UIKit.label("", 11, UIKit.TEXT_DIM)
	root.add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", UIKit.GAP_S)
	scroll.add_child(_rows)


func _close() -> void:
	closed.emit()


func _process(delta: float) -> void:
	if not visible or world == null:
		return
	_accum += delta
	if _accum < 0.2:
		return
	_accum = 0.0
	if _rows.get_child_count() != world.villagers.size():
		_rebuild()
	_refresh()


func _rebuild() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for v in world.villagers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UIKit.GAP_S)
		_rows.add_child(row)

		var jump := Button.new()
		jump.text = String(v.vname)
		jump.flat = true
		jump.alignment = HORIZONTAL_ALIGNMENT_LEFT
		jump.add_theme_font_size_override("font_size", 12)
		jump.add_theme_color_override("font_color", v.color.darkened(0.42))
		jump.custom_minimum_size = Vector2(54, UIKit.ROW_H)
		jump.tooltip_text = "%s を見る" % v.vname
		row.add_child(jump)
		jump.pressed.connect(_jump.bind(v.id))

		var doing := UIKit.label("", 11, UIKit.TEXT)
		doing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(doing)

		var have := UIKit.label("", 10, UIKit.TEXT_DIM)
		have.custom_minimum_size = Vector2(150, 0)
		have.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(have)


func _refresh() -> void:
	var houses := 0
	for s in world.structures:
		if s.kind == Structure.Kind.HOUSE:
			houses += 1
	_summary.text = "%d人　家 %d軒" % [world.villagers.size(), houses]

	for i in range(mini(_rows.get_child_count(), world.villagers.size())):
		var v = world.villagers[i]
		var row: HBoxContainer = _rows.get_child(i)
		(row.get_child(1) as Label).text = v.action_label()

		var carried := ""
		for item in Schema.all_items():
			var n: int = v.item_count(String(item))
			if n <= 0:
				continue
			if carried != "":
				carried += " "
			carried += "%s%d" % [Schema.item_label(String(item)), n]
		if v.home != null:
			carried += "　家"
		(row.get_child(2) as Label).text = carried


func _jump(vid: int) -> void:
	var v = world.villager_by_id(vid)
	if v != null:
		select_requested.emit(v)
