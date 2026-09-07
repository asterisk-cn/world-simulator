extends PanelContainer
## 相手ごとのパラメータのマトリクス。行 = 見ている側、列 = 見られている側。

const CELL_W := 52
const CELL_H := 24
const HEAD_W := 62

var world = null

var _param_id: String = "affinity"
var _grid: GridContainer
var _cells := {}             ## "from:to" -> Button
var _detail: VBoxContainer
var _sel_from: int = -1
var _sel_to: int = -1
var _accum := 0.0
var _param_opt: OptionButton
var _scroll: ScrollContainer

signal closed


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.panel_style())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP)
	add_child(root)

	var head := UIKit.window_header(root, "間柄", _close)
	_param_opt = UIKit.dropdown([], [], "")
	_param_opt.custom_minimum_size = Vector2(110, UIKit.ROW_H)
	head.add_child(_param_opt)
	head.move_child(_param_opt, 1)
	_param_opt.item_selected.connect(_on_param_selected)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	var scroll := _scroll

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(_detail)

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
	_build_detail()



## 前の村で選んでいたマスは、次の村では別人どうしの組になってしまう
func on_world_reset() -> void:
	_sel_from = -1
	_sel_to = -1
	rebuild()


func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < 0.25:
		return
	_accum = 0.0
	if world != null and _cells.size() != world.villagers.size() * world.villagers.size():
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
			minf(float(vs.size() + 1) * (CELL_H + 2.0) + 6.0, 420.0))

	var corner := UIKit.label("主体 ↓ ／ 相手 →", 9, UIKit.TEXT_DIM)
	corner.custom_minimum_size = Vector2(HEAD_W, CELL_H)
	_grid.add_child(corner)
	for v in vs:
		var h := UIKit.label(String(v.vname), 10, v.color.darkened(0.38))
		h.custom_minimum_size = Vector2(CELL_W, CELL_H)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grid.add_child(h)

	for a in vs:
		var rh := UIKit.label(String(a.vname), 10, a.color.darkened(0.38))
		rh.custom_minimum_size = Vector2(HEAD_W, CELL_H)
		_grid.add_child(rh)
		for b in vs:
			var btn := Button.new()
			btn.add_theme_font_size_override("font_size", 10)
			btn.custom_minimum_size = Vector2(CELL_W, CELL_H)
			btn.flat = false
			_grid.add_child(btn)
			if a.id == b.id:
				btn.text = ""
				btn.disabled = true
			else:
				btn.pressed.connect(_on_cell_pressed.bind(int(a.id), int(b.id)))
			_cells["%d:%d" % [a.id, b.id]] = btn
	_update_cells()
	_build_detail()


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
		if fid == tid:
			_paint(btn, Color(0.84, 0.79, 0.68))
			continue
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

func _on_cell_pressed(from_id: int, to_id: int) -> void:
	_sel_from = from_id
	_sel_to = to_id
	_build_detail()


func _get_cell(key: String) -> float:
	var f = world.villager_by_id(_sel_from)
	if f == null:
		return 0.0
	var pp = f.pair_peek(_sel_to)
	return 0.0 if pp == null else pp.get_v(key)


func _swap_pair() -> void:
	var t := _sel_from
	_sel_from = _sel_to
	_sel_to = t
	_build_detail()


func _build_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	if world == null or _sel_from < 0:
		_detail.add_child(UIKit.label("マスを選ぶと内訳が出る", 10, UIKit.TEXT_DIM))
		return
	var f = world.villager_by_id(_sel_from)
	var t = world.villager_by_id(_sel_to)
	if f == null or t == null:
		return

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.GAP)
	_detail.add_child(head)
	head.add_child(UIKit.label("%s → %s" % [f.vname, t.vname], 12, UIKit.TEXT))
	if f.pair_peek(_sel_to) == null:
		head.add_child(UIKit.label("まだ会っていない", 10, UIKit.TEXT_DIM))
	var sw := SwapButton.new()
	head.add_child(sw)
	sw.pressed.connect(_swap_pair)

	for d in Schema.pair_params():
		var key := String(d["id"])
		UIKit.bar_row(_detail, String(d["label"]), _get_cell(key),
			float(d["min"]), float(d["max"]), Schema.param_color(String(d["id"])))

