extends PanelContainer
## 相手ごとのパラメータのマトリクス。行 = 見ている側、列 = 見られている側。

const CELL_W := 52
const CELL_H := 24
const HEAD_W := 62

var world = null

var _param_id: String = "affinity"
var _mode: String = "value"  ## "value" | "gap"
var _grid: GridContainer
var _cells := {}             ## "from:to" -> Button
var _detail: VBoxContainer
var _sel_from: int = -1
var _sel_to: int = -1
var _accum := 0.0
var _param_opt: OptionButton


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.BG
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.set_border_width_all(1)
	add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	root.add_child(head)
	head.add_child(UIKit.label("関係マトリクス", 14, Color(0.85, 0.9, 0.98)))

	_param_opt = OptionButton.new()
	_param_opt.add_theme_font_size_override("font_size", 11)
	head.add_child(_param_opt)
	_param_opt.item_selected.connect(_on_param_selected)

	var mode_opt := OptionButton.new()
	mode_opt.add_theme_font_size_override("font_size", 11)
	mode_opt.add_item("値（行→列）")
	mode_opt.add_item("差 |A→B − B→A|")
	head.add_child(mode_opt)
	mode_opt.item_selected.connect(_on_mode_selected)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 2)
	root.add_child(_detail)

	Schema.parameters_changed.connect(_on_schema_changed)
	_refresh_param_options()
	rebuild()


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
	for i in range(ids.size()):
		_param_opt.add_item(Schema.param_label(String(ids[i])), i)
		if String(ids[i]) == _param_id:
			_param_opt.select(i)


func _on_param_selected(i: int) -> void:
	var ids := Schema.ids_in(Schema.SCOPE_PAIR)
	if i < ids.size():
		_param_id = String(ids[i])
	_update_cells()
	_build_detail()


func _on_mode_selected(i: int) -> void:
	_mode = "value" if i == 0 else "gap"
	_update_cells()


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

	var corner := UIKit.label("主体 ↓ ／ 相手 →", 9, UIKit.TEXT_DIM)
	corner.custom_minimum_size = Vector2(HEAD_W, CELL_H)
	_grid.add_child(corner)
	for v in vs:
		var h := UIKit.label(String(v.vname), 10, v.color.lightened(0.3))
		h.custom_minimum_size = Vector2(CELL_W, CELL_H)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grid.add_child(h)

	for a in vs:
		var rh := UIKit.label(String(a.vname), 10, a.color.lightened(0.3))
		rh.custom_minimum_size = Vector2(HEAD_W, CELL_H)
		_grid.add_child(rh)
		for b in vs:
			var btn := Button.new()
			btn.add_theme_font_size_override("font_size", 10)
			btn.custom_minimum_size = Vector2(CELL_W, CELL_H)
			btn.flat = false
			_grid.add_child(btn)
			if a.id == b.id:
				btn.text = "—"
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
			_paint(btn, Color(0.18, 0.19, 0.23))
			continue
		var from_v = world.villager_by_id(fid)
		if from_v == null:
			continue
		var val: float = 0.0
		var known: bool = from_v.knows(tid)
		if known:
			val = from_v.pair_to(tid).get_v(_param_id)

		if _mode == "gap":
			var to_v = world.villager_by_id(tid)
			var back: float = 0.0
			if to_v != null and to_v.knows(fid):
				back = to_v.pair_to(fid).get_v(_param_id)
			var gap: float = absf(val - back)
			btn.text = "%d" % int(gap)
			_paint(btn, Color(0.18, 0.19, 0.23).lerp(Color(0.95, 0.75, 0.25), clampf(gap / maxf(hi - lo, 1.0) * 2.0, 0.0, 1.0)))
			continue

		if not known:
			btn.text = "·"
			_paint(btn, Color(0.16, 0.17, 0.20))
			continue
		btn.text = "%d" % int(val)
		_paint(btn, _value_color(val, lo, hi))


func _value_color(val: float, lo: float, hi: float) -> Color:
	var base := Color(0.18, 0.19, 0.23)
	var col := Schema.param_color(_param_id)
	if lo < 0.0:
		if val >= 0.0:
			return base.lerp(col, clampf(val / maxf(hi, 1.0), 0.0, 1.0) * 0.85)
		return base.lerp(Color(0.85, 0.30, 0.28), clampf(-val / maxf(-lo, 1.0), 0.0, 1.0) * 0.85)
	return base.lerp(col, clampf((val - lo) / maxf(hi - lo, 1.0), 0.0, 1.0) * 0.85)


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
	return 0.0 if f == null else f.pair_to(_sel_to).get_v(key)


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
	_detail.add_child(head)
	head.add_child(UIKit.label("%s → %s" % [f.vname, t.vname], 12, Color(0.9, 0.92, 0.98)))
	var sw := UIKit.button(head, "向きを反転", _swap_pair, 10)
	sw.custom_minimum_size = Vector2(80, 22)

	for d in Schema.pair_params():
		var key := String(d["id"])
		UIKit.bar_row(_detail, String(d["label"]),
			_get_cell(key) - float(d["min"]),
			maxf(float(d["max"]) - float(d["min"]), 1.0), Color(d["color"]))

	var line := ""
	for d2 in Schema.pair_params():
		var back: float = 0.0
		if t.knows(f.id):
			back = t.pair_to(f.id).get_v(String(d2["id"]))
		line += "%s%d  " % [String(d2["label"]), int(back)]
	UIKit.wrapped(_detail, "逆向き（%s → %s）：%s" % [t.vname, f.vname, line], 10, Color(0.66, 0.70, 0.78))
