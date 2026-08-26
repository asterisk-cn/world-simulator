extends PanelContainer
## 設定。この世界に何が存在し、どんな物理で動くかを神が決める。
##
## 編集できるのは開始前だけ。始まったあとは同じ画面が閲覧専用になる。

signal started

var world = null
var editable := true

var _tabs: TabContainer
var _param_box: VBoxContainer
var _action_box: VBoxContainer
var _world_box: VBoxContainer
var _title: Label
var _start_btn: Button
var _reset_btn: Button


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
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	_title = UIKit.label("設定", 14, Color(0.85, 0.9, 0.98))
	head.add_child(_title)
	_reset_btn = UIKit.button(head, "既定に戻す", _reset_all, 10)
	_reset_btn.custom_minimum_size = Vector2(90, 22)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)

	_param_box = _make_tab("パラメータ")
	_action_box = _make_tab("アクション")
	_world_box = _make_tab("世界")

	_start_btn = UIKit.button(root, "この世界を始める", _on_start, 13)
	_start_btn.custom_minimum_size = Vector2(0, 32)

	Schema.parameters_changed.connect(_rebuild_params)
	Schema.actions_changed.connect(_rebuild_actions)
	_rebuild_params()
	_rebuild_actions()
	_rebuild_world()


func set_editable(on: bool) -> void:
	editable = on
	_title.text = "設定" if on else "設定（開始後は変更できない）"
	_start_btn.visible = on
	_reset_btn.visible = on
	_rebuild_params()
	_rebuild_actions()
	_rebuild_world()


func _on_start() -> void:
	started.emit()


func _make_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)
	return box


func _reset_all() -> void:
	Schema.reset_all()
	SimConfig.reset_params()
	_rebuild_world()


func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# ---------------------------------------------------------------------------
# パラメータ
# ---------------------------------------------------------------------------

func _rebuild_params() -> void:
	if _param_box == null:
		return
	_clear(_param_box)

	for scope in [Schema.SCOPE_SELF, Schema.SCOPE_PAIR]:
		var sc := String(scope)
		_param_box.add_child(UIKit.label(
			String(Schema.SCOPE_LABEL[sc]), 13, Color(0.82, 0.87, 0.95)))

		for cat in Schema.categories_in(sc):
			_build_category(sc, String(cat))

		if editable:
			UIKit.button(_param_box, "＋ カテゴリを追加", _add_category.bind(sc), 10)
		UIKit.spacer(_param_box, 10)


func _build_category(scope: String, cat: String) -> void:
	var col := Schema.category_color(cat)
	var card := UIKit.panel(UIKit.BG_SOFT, 6)
	_param_box.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	head.add_child(UIKit.label("■", 13, col))
	if editable:
		var le := LineEdit.new()
		le.text = cat
		le.add_theme_font_size_override("font_size", 12)
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.custom_minimum_size = Vector2(80, 22)
		head.add_child(le)
		le.text_submitted.connect(_rename_category.bind(scope, cat))
		le.focus_exited.connect(func() -> void: _rename_category(le.text, scope, cat))
	else:
		head.add_child(UIKit.label(cat, 12, Color(0.9, 0.92, 0.98)))

	for d in Schema.params_in(scope):
		if String(d["category"]) != cat:
			continue
		_build_param(box, d)

	if editable:
		UIKit.button(box, "＋ パラメータ", _add_param.bind(scope, cat), 10)


func _build_param(box: VBoxContainer, def: Dictionary) -> void:
	var pid := String(def["id"])
	var col := Schema.param_color(pid)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	row.add_child(UIKit.label("●", 12, col))

	if not editable:
		row.add_child(UIKit.label(String(def["label"]), 12, Color(0.9, 0.92, 0.98)))
		row.add_child(UIKit.label("  %d〜%d" % [int(def["min"]), int(def["max"])],
			10, UIKit.TEXT_DIM))
		return

	var le := LineEdit.new()
	le.text = String(def["label"])
	le.add_theme_font_size_override("font_size", 11)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(70, 22)
	row.add_child(le)
	le.text_changed.connect(_set_label.bind(def))

	UIKit.range_row(row, "", -100.0, 100.0, float(def["min"]), float(def["max"]), 1.0,
		_set_range.bind(def), col, 0)

	var del := UIKit.button(row, "×", _del_param.bind(pid), 11)
	del.custom_minimum_size = Vector2(26, 22)


func _add_category(scope: String) -> void:
	Schema.add_category(scope)


func _rename_category(new_name: String, scope: String, old_name: String) -> void:
	if new_name != old_name:
		Schema.rename_category(scope, old_name, new_name)


func _add_param(scope: String, cat: String) -> void:
	Schema.add_param(scope, cat)


func _del_param(pid: String) -> void:
	Schema.remove_param(pid)


func _set_label(text: String, def: Dictionary) -> void:
	def["label"] = text


func _set_range(lo: float, hi: float, def: Dictionary) -> void:
	def["min"] = lo
	def["max"] = hi


# ---------------------------------------------------------------------------
# アクション
# ---------------------------------------------------------------------------

func _rebuild_actions() -> void:
	if _action_box == null:
		return
	_clear(_action_box)

	var kinds: Array = Schema.BEHAVIORS.keys()
	var kind_labels: Array = []
	for k in kinds:
		kind_labels.append(Schema.behavior_label(String(k)))

	for a in Schema.actions:
		var act: Dictionary = a
		var aid := String(act["id"])
		var kind := String(act["kind"])
		var card := UIKit.panel(UIKit.BG_SOFT, 6)
		_action_box.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)

		var head := HBoxContainer.new()
		box.add_child(head)
		head.add_child(UIKit.label(String(act["label"]), 13, Color(0.9, 0.92, 0.98)))
		head.add_child(UIKit.label("  %s ／ %s"
			% [Schema.behavior_label(kind), Schema.target_label(kind, String(act["target"]))],
			10, UIKit.TEXT_DIM))
		if not editable:
			if not bool(act["enabled"]):
				head.add_child(UIKit.label("  無効", 10, Color(0.85, 0.5, 0.45)))
			continue

		UIKit.check_row(head, "有効", bool(act["enabled"]), _set_enabled.bind(act))
		var del := UIKit.button(head, "削除", _del_action.bind(aid), 10)
		del.custom_minimum_size = Vector2(46, 22)

		UIKit.line_edit_row(box, "名前", String(act["label"]), _set_a_label.bind(act))
		UIKit.option_row(box, "型", kinds, kind_labels, kind, _set_kind.bind(act))

		var tkeys: Array = Schema.targets_of(kind).keys()
		if tkeys.is_empty():
			box.add_child(UIKit.label("　この型にはまだ対象がない", 10, Color(0.85, 0.6, 0.45)))
		else:
			var tlabels: Array = []
			for t in tkeys:
				tlabels.append(Schema.target_label(kind, String(t)))
			UIKit.option_row(box, "対象", tkeys, tlabels, String(act["target"]),
				_set_target.bind(act))

	if editable:
		UIKit.spacer(_action_box, 4)
		UIKit.button(_action_box, "＋ アクションを追加", _add_action)
	UIKit.spacer(_action_box, 10)


func _add_action() -> void:
	Schema.add_action()


func _del_action(aid: String) -> void:
	Schema.remove_action(aid)


func _set_a_label(text: String, act: Dictionary) -> void:
	act["label"] = text


func _set_kind(key: String, act: Dictionary) -> void:
	act["kind"] = key
	act["target"] = Schema.first_target(key)
	Schema.actions_changed.emit()


func _set_target(key: String, act: Dictionary) -> void:
	act["target"] = key
	Schema.actions_changed.emit()


func _set_enabled(on: bool, act: Dictionary) -> void:
	act["enabled"] = on


# ---------------------------------------------------------------------------
# 世界（物理と時間）
# ---------------------------------------------------------------------------

func _rebuild_world() -> void:
	if _world_box == null:
		return
	_clear(_world_box)

	for k in SimConfig.PARAM_DEF:
		var key := String(k)
		var d: Array = SimConfig.PARAM_DEF[key]
		if editable:
			UIKit.slider_row(_world_box, String(d[3]), SimConfig.p(key),
				float(d[1]), float(d[2]), _step_for(float(d[1]), float(d[2])),
				_set_world.bind(key), Color(0.55, 0.75, 0.95), 150)
		else:
			var row := HBoxContainer.new()
			_world_box.add_child(row)
			var nm := UIKit.label(String(d[3]), 11, UIKit.TEXT)
			nm.custom_minimum_size = Vector2(150, 0)
			row.add_child(nm)
			row.add_child(UIKit.label(UIKit._fmt(SimConfig.p(key),
				_step_for(float(d[1]), float(d[2]))), 11, UIKit.TEXT_DIM))

	UIKit.spacer(_world_box, 10)


func _set_world(x: float, key: String) -> void:
	SimConfig.set_param(key, x)


func _step_for(vmin: float, vmax: float) -> float:
	var span := vmax - vmin
	if span <= 2.0:
		return 0.01
	if span <= 20.0:
		return 0.1
	return 1.0
