extends PanelContainer
## 村人一覧。いま誰が何をしていて、何を持っているかを一望する。
##
## 観察する遊びなので「いま誰が何をしているか」がいちばん見たい情報になる。
## 一人ずつ選んで確かめるのでは追えないため、正面の窓として置く。

signal closed
signal select_requested(v)

## 持ち物の列幅。見出しの絵と名前、行の数字を同じ幅で揃える。
## 名前が入るぶんだけ広い。絵だけの見出しでは、神がつけた名前の物が何なのか読めない。
const COL_W := 54

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
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP_S)
	UIKit.paper_sheet(self).add_child(root)

	UIKit.window_header(root, "村人", _close, UIKit.HEAD,
		"いま誰が何をしていて、何を持っているか。\n名前を押すと世界の側でもその人へ寄る。")
	_summary = UIKit.label("", UIKit.FS_NOTE, UIKit.TEXT_DIM)
	root.add_child(_summary)

	# 持ち物の列の見出しは、絵の下に名前。絵だけでは神がつけた物の名前が読めず、
	# 名前だけだと「木の実」と「木」が並んだときに見分けづらい。
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
		jump.add_theme_color_override("font_color", v.color.darkened(0.42))
		jump.custom_minimum_size = Vector2(66, UIKit.ROW_H)
		jump.tooltip_text = "%s を見る" % v.vname
		row.add_child(jump)
		jump.pressed.connect(_jump.bind(v.id))

		var doing := UIKit.label("", UIKit.FS_BODY, UIKit.TEXT)
		doing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(doing)

		# 持ち物は品目ごとに列を固定する。羅列だと誰が富んでいるか比べられない。
		var have := HBoxContainer.new()
		have.add_theme_constant_override("separation", UIKit.GAP_S)
		row.add_child(have)
		for item in Schema.all_items():
			var cell := UIKit.label("", UIKit.FS_BODY, UIKit.TEXT_DIM)
			cell.custom_minimum_size = Vector2(COL_W, 0)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.tooltip_text = Schema.item_label(String(item))
			have.add_child(cell)


func _refresh() -> void:
	# 建物は誰のものでもないので「一人に一軒」の数え方はしない。
	# 何がいくつ建ったかを、建てるものの名前ごとに数える。
	var built := {}
	for s in world.structures:
		var name_text: String = s.label()
		built[name_text] = int(built.get(name_text, 0)) + 1
	_summary.text = "%d人" % world.villagers.size()
	if not built.is_empty():
		var parts: Array = []
		for k in built:
			parts.append("%s %d" % [String(k), int(built[k])])
		_summary.text += "　" + "・".join(parts)

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


## 品目が増減したら見出しも作り直す
func _build_head() -> void:
	for c in _head_row.get_children():
		_head_row.remove_child(c)
		c.queue_free()
	var name_gap := Control.new()
	name_gap.custom_minimum_size = Vector2(66, 0)
	_head_row.add_child(name_gap)
	var doing_gap := Control.new()
	doing_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_row.add_child(doing_gap)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", UIKit.GAP_S)
	_head_row.add_child(icons)
	for item in Schema.all_items():
		icons.add_child(_col_head(String(item)))


## 1列ぶんの見出し。絵の下に名前。名前は列幅で切って、全体はツールチップで読ませる。
func _col_head(item: String) -> Control:
	var label_text := Schema.item_label(item)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(COL_W, 0)
	col.add_theme_constant_override("separation", UIKit.HAIR)
	col.tooltip_text = label_text
	col.mouse_filter = Control.MOUSE_FILTER_PASS

	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(icon_row)
	icon_row.add_child(ItemIcon.of_item(item, 18))

	var nm := UIKit.label(label_text, UIKit.FS_NOTE, UIKit.TEXT_DIM)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(COL_W, 0)
	col.add_child(nm)
	return col


func _jump(vid: int) -> void:
	var v = world.villager_by_id(vid)
	if v != null:
		select_requested.emit(v)
