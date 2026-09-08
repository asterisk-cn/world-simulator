extends PanelContainer
## 相手ごとのパラメータのマトリクス。行 = 見ている側、列 = 見られている側。
##
## **内訳はここに出さない。** 同じ数を2か所で見せると、どちらが本体か分からなくなる。
## マスは「その人の、その相手についてのところ」への入口で、押すと個人UIへ送る。
## 表は眺めて異変に気づくための面、値を読むのは個人UIの側。

const CELL_W := 60
const CELL_H := 28
const HEAD_W := 76

## マスどうしの隙。表なので余白の段より詰める（1つのまとまりとして読ませる）
const CELL_GAP := 2

var world = null

var _param_id: String = "affinity"
var _grid: GridContainer
var _cells := {}             ## "from:to" -> Button
var _accum := 0.0
var _param_opt: OptionButton
var _scroll: ScrollContainer

signal closed

## 押されたマスの「主体 → 相手」。個人UIのその相手のところへ送る。
signal pair_requested(from_id: int, to_id: int)


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP)
	UIKit.paper_sheet(self).add_child(root)

	var head := UIKit.window_header(root, "間柄", _close, UIKit.HEAD,
		"行が見ている側、列が見られている側。\nA→B と B→A は別の値で、揃わない。\nマスを押すと下に内訳が出る。")
	_param_opt = UIKit.dropdown([], [], "")
	_param_opt.custom_minimum_size = Vector2(130, UIKit.ROW_H)
	head.add_child(_param_opt)
	# 題と「?」の対はひとまとまり。そのあとに、どの言葉で見るかの欄を置く
	head.move_child(_param_opt, 2)
	_param_opt.item_selected.connect(_on_param_selected)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	var scroll := _scroll

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", CELL_GAP)
	_grid.add_theme_constant_override("v_separation", CELL_GAP)
	scroll.add_child(_grid)

	Schema.parameters_changed.connect(_on_schema_changed)
	_refresh_param_options()
	rebuild()


func _close() -> void:
	closed.emit()


func _on_schema_changed() -> void:
	_refresh_param_options()
	rebuild()


func _refresh_param_options() -> void:
	_param_opt.clear()
	var ids := Schema.ids_in(Schema.SCOPE_PAIR)
	if ids.is_empty():
		_param_id = ""
		return
	if not ids.has(_param_id):
		_param_id = String(ids[0])
	var pop := _param_opt.get_popup()
	for i in range(ids.size()):
		_param_opt.add_item(Schema.param_label(String(ids[i])), i)
		pop.set_item_as_radio_checkable(i, false)
		pop.set_item_as_checkable(i, false)
		if String(ids[i]) == _param_id:
			_param_opt.select(i)


func _on_param_selected(i: int) -> void:
	var ids := Schema.ids_in(Schema.SCOPE_PAIR)
	if i < ids.size():
		_param_id = String(ids[i])
	_update_cells()



func on_world_reset() -> void:
	rebuild()


func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < 0.25:
		return
	_accum = 0.0
	# 対角はマスにしないので、あるべき数は n×n から n を引いたぶん
	if world != null and _cells.size() != _cell_count():
		rebuild()
	else:
		_update_cells()


# ---------------------------------------------------------------------------

func rebuild() -> void:
	if world == null or _grid == null:
		return
	_cells.clear()
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()

	var vs: Array = world.villagers
	_grid.columns = vs.size() + 1
	# 人数ぶんの高さを持たせる。増えすぎたら中でスクロールする。
	if _scroll != null:
		_scroll.custom_minimum_size = Vector2(0,
			minf(float(vs.size() + 1) * (CELL_H + CELL_GAP) + UIKit.GAP_S, 420.0))

	# 隅の「主体↓／相手→」は題の横の「?」へ移した。表の中に説明を置くと、
	# いちばん字が小さいマスに、いちばん読ませたいことが載る。
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(HEAD_W, CELL_H)
	_grid.add_child(corner)
	for v in vs:
		var h := UIKit.label(String(v.vname), UIKit.FS_NOTE, v.color.darkened(0.38))
		h.custom_minimum_size = Vector2(CELL_W, CELL_H)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grid.add_child(h)

	for a in vs:
		var rh := UIKit.label(String(a.vname), UIKit.FS_NOTE, a.color.darkened(0.38))
		rh.custom_minimum_size = Vector2(HEAD_W, CELL_H)
		_grid.add_child(rh)
		for b in vs:
			# 対角は自分自身。**間柄が無いのではなく、そういう値が存在しない。**
			# 他のマスと同じ色を敷いていたので「値0」や「まだ会っていない」に見えていた。
			# 表に穴を空けて、読むところではないことを地の色で言う。
			if a.id == b.id:
				var hole := Control.new()
				hole.custom_minimum_size = Vector2(CELL_W, CELL_H)
				_grid.add_child(hole)
				continue
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(CELL_W, CELL_H)
			btn.flat = false
			_grid.add_child(btn)
			btn.pressed.connect(_on_cell_pressed.bind(int(a.id), int(b.id)))
			_cells["%d:%d" % [a.id, b.id]] = btn
	_update_cells()


func _cell_count() -> int:
	var n: int = world.villagers.size()
	return n * (n - 1)


func _update_cells() -> void:
	if world == null or _param_id == "":
		return
	var lo := Schema.param_min(_param_id)
	var hi := Schema.param_max(_param_id)
	for key in _cells:
		var btn: Button = _cells[key]
		if not is_instance_valid(btn):
			continue
		var parts: PackedStringArray = String(key).split(":")
		var fid := int(parts[0])
		var tid := int(parts[1])
		var from_v = world.villager_by_id(fid)
		if from_v == null:
			continue
		var val: float = 0.0
		var known: bool = from_v.knows(tid)
		if known:
			val = from_v.pair_to(tid).get_v(_param_id)

		if not known:
			# まだ会っていない相手は空欄。値0と見分けがつくようにする
			btn.text = ""
			_paint(btn, Color(0.90, 0.86, 0.78))
			continue
		# 数字を並べると表計算になる。眺めて異変に気づく道具にするため、色だけで見せる。
		# 実際の数は、マスを選んだときに内訳側で読む。
		btn.text = ""
		_paint(btn, _value_color(val, lo, hi))


func _value_color(val: float, lo: float, hi: float) -> Color:
	var base := Color(0.84, 0.79, 0.68)
	var col := Schema.param_color(_param_id)
	if lo < 0.0:
		if val >= 0.0:
			return base.lerp(col.darkened(0.10), clampf(val / maxf(hi, 1.0), 0.0, 1.0))
		return base.lerp(Color(0.74, 0.26, 0.22), clampf(-val / maxf(-lo, 1.0), 0.0, 1.0))
	return base.lerp(col.darkened(0.10), clampf((val - lo) / maxf(hi - lo, 1.0), 0.0, 1.0))


func _paint(btn: Button, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	var hov := StyleBoxFlat.new()
	hov.bg_color = col.lightened(0.15)
	hov.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)


# ---------------------------------------------------------------------------

## 押されたマスは、その人の、その相手についてのところへの入口
func _on_cell_pressed(from_id: int, to_id: int) -> void:
	pair_requested.emit(from_id, to_id)
