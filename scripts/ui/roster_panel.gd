extends PanelContainer
## 村人一覧。いま誰が何をしていて、何を持っているかを一望する。
##
## 観察する遊びなので「いま誰が何をしているか」がいちばん見たい情報になる。
## 一人ずつ選んで確かめるのでは追えないため、正面の窓として置く。

signal closed
signal select_requested(v)

## 持ち物の列幅。見出しの絵と行の数字を同じ幅で揃える。
const COL_W := 30

## 持っていないことを示す薄さ。差だけが読めるようにする。
const EMPTY := Color(0.30, 0.22, 0.14, 0.22)

var world = null

var _rows: VBoxContainer
var _head_row: HBoxContainer
var _item_count := -1
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

	# 持ち物の列は、世界にある物の絵を見出しにする。
	# 名前の頭文字だと「木の実」と「木」がどちらも "木" になって読めない。
	_head_row = HBoxContainer.new()
	_head_row.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(_head_row)
	_build_head()
	UIKit.hairline(root)

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


## 村人ごと入れ替わったので、見出しも行も次に開くときに作り直す
func on_world_reset() -> void:
	_item_count = -1


func _process(delta: float) -> void:
	if not visible or world == null:
		return
	_accum += delta
	if _accum < 0.2:
		return
	_accum = 0.0
	# 品目はプレイヤーが「つくりかた」を増やすと変わる。列ごと作り直す。
	var items := Schema.all_items().size()
	if _rows.get_child_count() != world.villagers.size() or items != _item_count:
		_item_count = items
		_build_head()
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

		# 持ち物は品目ごとに列を固定する。羅列だと誰が富んでいるか比べられない。
		var have := HBoxContainer.new()
		have.add_theme_constant_override("separation", UIKit.GAP_S)
		row.add_child(have)
		for item in Schema.all_items():
			var cell := UIKit.label("", 11, UIKit.TEXT_DIM)
			cell.custom_minimum_size = Vector2(COL_W, 0)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.tooltip_text = Schema.item_label(String(item))
			have.add_child(cell)
		# 家は「○」ではなく家の絵。濃い＝あり、薄い＝なし。
		var home := _icon_cell("house", "家")
		row.add_child(home)


func _refresh() -> void:
	var houses := 0
	var built := 0
	for s in world.structures:
		if s.is_house():
			houses += 1
		else:
			built += 1
	_summary.text = "%d人　家 %d軒" % [world.villagers.size(), houses]
	if built > 0:
		# 村のものが建ったら、家とは別に数える（村に何が在るかは家の数では読めない）
		_summary.text += "　村のもの %d" % built

	for i in range(mini(_rows.get_child_count(), world.villagers.size())):
		var v = world.villagers[i]
		var row: HBoxContainer = _rows.get_child(i)
		(row.get_child(1) as Label).text = v.action_label()

		var have: HBoxContainer = row.get_child(2)
		var items := Schema.all_items()
		for k in range(mini(have.get_child_count(), items.size())):
			var n: int = v.item_count(String(items[k]))
			var cell: Label = have.get_child(k)
			# 持っていない品目は「・」。空欄だと列が消えて、行ごとに並びが動いて見える
			cell.text = str(n) if n > 0 else "・"
			cell.add_theme_color_override("font_color",
				UIKit.TEXT if n > 0 else EMPTY)
		var home: Control = row.get_child(3)
		home.modulate = Color(1, 1, 1, 1.0 if v.home != null else 0.18)


## 品目が増減したら見出しも作り直す
func _build_head() -> void:
	for c in _head_row.get_children():
		_head_row.remove_child(c)
		c.queue_free()
	var name_gap := Control.new()
	name_gap.custom_minimum_size = Vector2(54, 0)
	_head_row.add_child(name_gap)
	var doing_gap := Control.new()
	doing_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_row.add_child(doing_gap)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", UIKit.GAP_S)
	_head_row.add_child(icons)
	for item in Schema.all_items():
		icons.add_child(_icon_cell(ItemIcon.art_of(String(item)),
			Schema.item_label(String(item))))
	_head_row.add_child(_icon_cell("house", "家"))


func _icon_cell(art: String, tip: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(COL_W, 18)
	holder.tooltip_text = tip
	var icon := ItemIcon.of_art(art, 18)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -9
	icon.offset_right = 9
	icon.offset_top = -9
	icon.offset_bottom = 9
	holder.add_child(icon)
	return holder


func _jump(vid: int) -> void:
	var v = world.villager_by_id(vid)
	if v != null:
		select_requested.emit(v)
