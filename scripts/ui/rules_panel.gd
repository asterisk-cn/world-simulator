extends PanelContainer
## 設定。この世界に何が存在し、どんな物理で動くかを神が決める。
##
## 編集できるのは開始前だけ。始まったあとは同じ画面が閲覧専用になる。

signal started
signal closed

var world = null
var editable := true

var _tabs: TabContainer
var _param_box: VBoxContainer
var _action_box: VBoxContainer
var _recipe_box: VBoxContainer
var _world_box: VBoxContainer
var _title: Label
var _start_btn: Button
var _reset_btn: Button
var _delete_btn: Button
var _close_btn: Button
var _start_note: Label
var _lead: Label
var _mode_label: Label
var _delete_mode := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.panel_style())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP)
	add_child(root)

	# 題は舞台の名前。設定ダイアログではなく、世界に言葉を与える場に見せる。
	_title = UIKit.label("この世界の言葉", 22, UIKit.HEAD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)
	_lead = UIKit.label("", 11, UIKit.TEXT_DIM)
	_lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_lead)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(head)
	_mode_label = UIKit.label("", 11, Color(0.72, 0.30, 0.20))
	head.add_child(_mode_label)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)

	_reset_btn = UIKit.button(head, "はじめに戻す", _reset_all, 10)
	_reset_btn.custom_minimum_size = Vector2(84, UIKit.ROW_H - 3)

	_delete_btn = UIKit.trash_toggle(head, "消すものを選ぶ")
	_delete_btn.toggled.connect(_on_delete_toggled)

	_close_btn = UIKit.icon_button(head, "✕", "閉じる", _close, 26, UIKit.ROW_H - 3, 13)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_tabs.tab_changed.connect(_on_tab_changed)

	_param_box = _make_tab("ことば")
	_action_box = _make_tab("ふるまい")
	_recipe_box = _make_tab("つくりかた")
	_world_box = _make_tab("世界")

	_start_note = UIKit.label("始めると、ここで決めたことは変えられない。", 10, UIKit.TEXT_DIM)
	_start_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_start_note)
	_start_btn = UIKit.accent_button(root, "この世界を始める", _on_start, 14)
	_start_btn.custom_minimum_size = Vector2(0, 38)

	Schema.parameters_changed.connect(_rebuild_params)
	Schema.actions_changed.connect(_rebuild_actions)
	Schema.recipes_changed.connect(_rebuild_recipes)
	_rebuild_params()
	_rebuild_actions()
	_rebuild_recipes()
	_rebuild_world()


func set_editable(on: bool) -> void:
	editable = on
	_lead.text = ("村人が使える言葉と、できることを決める。" if on
		else "始まった世界の言葉は、もう変えられない。")
	_start_btn.visible = on
	_start_note.visible = on
	_reset_btn.visible = on
	_close_btn.visible = not on
	if not on:
		_delete_mode = false
		_delete_btn.set_pressed_no_signal(false)
		_mode_label.text = ""
	_update_delete_btn()
	_rebuild_params()
	_rebuild_actions()
	_rebuild_recipes()
	_rebuild_world()


func _on_start() -> void:
	started.emit()


func _close() -> void:
	closed.emit()


func _on_delete_toggled(on: bool) -> void:
	_delete_mode = on
	_delete_btn.modulate = Color(1.0, 0.55, 0.5) if on else Color.WHITE
	_mode_label.text = "消すものを選んでいる" if on else ""
	_rebuild_params()
	_rebuild_actions()
	_rebuild_recipes()


func _on_tab_changed(_i: int) -> void:
	_update_delete_btn()


## 世界タブには消せるものが無い。隠すと右上のボタンの位置が動いてしまうので、
## 置いたまま効かなくする。
func _update_delete_btn() -> void:
	if _delete_btn == null or _tabs == null:
		return
	_delete_btn.visible = editable
	var usable := _tabs.current_tab != 3
	_delete_btn.disabled = not usable
	_delete_btn.modulate = (Color(1.0, 0.55, 0.5) if _delete_mode
		else Color(1, 1, 1, 1.0 if usable else 0.30))
	if not usable and _delete_mode:
		_delete_btn.set_pressed_no_signal(false)
		_on_delete_toggled(false)


func _can_delete() -> bool:
	return editable and _delete_mode


func _make_tab(title: String) -> VBoxContainer:
	var holder := MarginContainer.new()
	holder.name = title
	holder.add_theme_constant_override("margin_top", 2)
	_tabs.add_child(holder)
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", UIKit.page_style())
	holder.add_child(page)
	return UIKit.scroll_body(page)


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
	if editable:
		UIKit.wrapped(_param_box, "村人が自分と他人について語れる言葉。", 11, UIKit.TEXT_DIM)

	for scope in [Schema.SCOPE_SELF, Schema.SCOPE_PAIR]:
		var sc := String(scope)
		# 束（カテゴリ）より一段上の区分。素のラベルだと注記に見えるので、
		# 上に間を空けて罫を添え、見出しとして読ませる。
		UIKit.spacer(_param_box, UIKit.GAP_S)
		var sh := HBoxContainer.new()
		sh.add_theme_constant_override("separation", UIKit.GAP_S)
		_param_box.add_child(sh)
		sh.add_child(UIKit.label(String(Schema.SCOPE_LABEL[sc]), 15, UIKit.HEAD))
		var rule := HSeparator.new()
		rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sh.add_child(rule)
		UIKit.spacer(_param_box, 2)

		for cat in Schema.categories_in(sc):
			_build_category(sc, String(cat))

		if editable:
			UIKit.add_button(_param_box, "＋ 束を増やす", _add_category.bind(sc))
		UIKit.spacer(_param_box, 10)


func _build_category(scope: String, cat: String) -> void:
	var col := Schema.category_color(cat)
	var card := UIKit.card()
	_param_box.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.GAP_S)
	card.add_child(box)

	# 見出し
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	head.add_child(UIKit.label("■", 14, col.darkened(0.28)))
	if editable:
		head.add_child(_flat_edit(cat, col, scope))
	else:
		head.add_child(UIKit.label(cat, 13, col.darkened(0.28)))
	if _can_delete():
		UIKit.icon_button(head, "✕", "%s を消す" % cat, _del_category.bind(scope, cat), 26, UIKit.ROW_H, 13)

	box.add_child(HSeparator.new())

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	box.add_child(inner)

	var first := true
	for d in Schema.params_in(scope):
		if String(d["category"]) != cat:
			continue
		if not first:
			UIKit.hairline(inner)
		first = false
		_build_param(inner, d)

	if editable:
		UIKit.spacer(inner, 2)
		UIKit.add_button(inner, "＋ ことばを増やす", _add_param.bind(scope, cat))


## 見出し用の、枠を消した入力欄
func _flat_edit(cat: String, col: Color, scope: String) -> LineEdit:
	var le := LineEdit.new()
	le.text = cat
	le.add_theme_font_size_override("font_size", 13)
	le.add_theme_color_override("font_color", col.darkened(0.28))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(80, UIKit.ROW_H + 2)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_left = 2
	le.add_theme_stylebox_override("normal", flat)
	var focused := StyleBoxFlat.new()
	focused.bg_color = Color(1, 1, 1, 0.06)
	focused.set_corner_radius_all(3)
	focused.content_margin_left = 2
	le.add_theme_stylebox_override("focus", focused)
	le.text_submitted.connect(_rename_category.bind(scope, cat))
	le.focus_exited.connect(func() -> void: _rename_category(le.text, scope, cat))
	return le


func _build_param(box: Node, def: Dictionary) -> void:
	var pid := String(def["id"])
	var col := Schema.param_color(pid)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 3)
	pad.add_theme_constant_override("margin_bottom", 3)
	box.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.GAP_S)
	pad.add_child(row)
	row.add_child(UIKit.label("●", 12, col.darkened(0.25)))

	if not editable:
		row.add_child(UIKit.label(String(def["label"]), 12, UIKit.TEXT))
		row.add_child(UIKit.label("  %d〜%d" % [int(def["min"]), int(def["max"])],
			10, UIKit.TEXT_DIM))
		return

	var le := LineEdit.new()
	le.text = String(def["label"])
	le.add_theme_font_size_override("font_size", 11)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(96, UIKit.ROW_H)
	row.add_child(le)
	le.text_changed.connect(_set_label.bind(def))

	UIKit.range_row(row, "", -100.0, 100.0, float(def["min"]), float(def["max"]), 1.0,
		_set_range.bind(def), col, 0, "0〜100")

	if _can_delete():
		UIKit.icon_button(row, "✕", "%s を消す" % String(def["label"]),
			_del_param.bind(pid), 26, UIKit.ROW_H, 13)


func _add_category(scope: String) -> void:
	Schema.add_category(scope)


func _del_category(scope: String, cat: String) -> void:
	Schema.remove_category(scope, cat)


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
	if editable:
		UIKit.wrapped(_action_box, "村人にできること。型と、その相手や道具の組み合わせ。", 11, UIKit.TEXT_DIM)

	var kinds: Array = Schema.BEHAVIORS.keys()

	# 型で束ねる。パラメータの束と同じ文法にして、画面をまたいで読み方を揃える。
	for k in kinds:
		var kind := String(k)
		var mine: Array = []
		for a in Schema.actions:
			if String(a["kind"]) == kind:
				mine.append(a)
		if mine.is_empty() and not editable:
			continue

		var card := UIKit.card()
		_action_box.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", UIKit.GAP_S)
		card.add_child(box)
		box.add_child(UIKit.label(Schema.behavior_label(kind), 13, UIKit.HEAD))
		box.add_child(HSeparator.new())

		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 0)
		box.add_child(rows)

		var first := true
		for a2 in mine:
			var act: Dictionary = a2
			var aid := String(act["id"])
			if not first:
				UIKit.hairline(rows)
			first = false

			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_top", 3)
			pad.add_theme_constant_override("margin_bottom", 3)
			rows.add_child(pad)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", UIKit.GAP_S)
			pad.add_child(row)

			if not editable:
				var nm := UIKit.label(String(act["label"]), 12, UIKit.TEXT)
				nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(nm)
				row.add_child(UIKit.label(
					Schema.target_label(kind, String(act["target"])), 10, UIKit.TEXT_DIM))
				continue

			var le := LineEdit.new()
			le.text = String(act["label"])
			le.add_theme_font_size_override("font_size", 11)
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.custom_minimum_size = Vector2(96, UIKit.ROW_H)
			row.add_child(le)
			le.text_changed.connect(_set_a_label.bind(act))

			var tkeys: Array = Schema.targets_of(kind).keys()
			if tkeys.is_empty():
				var none := UIKit.label("相手がない", 10, Color(0.72, 0.36, 0.18))
				none.custom_minimum_size = Vector2(136, 0)
				row.add_child(none)
			else:
				var tlabels: Array = []
				for t in tkeys:
					tlabels.append(Schema.target_label(kind, String(t)))
				var t_opt := UIKit.dropdown(tkeys, tlabels, String(act["target"]))
				t_opt.custom_minimum_size = Vector2(136, UIKit.ROW_H)
				row.add_child(t_opt)
				t_opt.item_selected.connect(func(i: int) -> void:
					_set_target(String(tkeys[i]), act))

			if _can_delete():
				UIKit.icon_button(row, "✕", "%s を消す" % String(act["label"]),
					_del_action.bind(aid), 26, UIKit.ROW_H, 13)

		if editable:
			UIKit.spacer(rows, 2)
			UIKit.add_button(rows, "＋ %sを増やす" % Schema.behavior_label(kind),
				_add_action_of.bind(kind))

	UIKit.spacer(_action_box, 10)


func _add_action_of(kind: String) -> void:
	var a := Schema.add_action()
	a["kind"] = kind
	a["target"] = Schema.first_target(kind)
	a["label"] = Schema.behavior_label(kind)
	Schema.actions_changed.emit()


func _del_action(aid: String) -> void:
	Schema.remove_action(aid)


func _set_a_label(text: String, act: Dictionary) -> void:
	act["label"] = text


func _set_target(key: String, act: Dictionary) -> void:
	act["target"] = key
	Schema.actions_changed.emit()



# ---------------------------------------------------------------------------
# 世界（物理と時間）
# ---------------------------------------------------------------------------

func _rebuild_world() -> void:
	if _world_box == null:
		return
	_clear(_world_box)
	if editable:
		UIKit.wrapped(_world_box, "世界そのものの流れかた。", 11, UIKit.TEXT_DIM)

	# 他のタブと同じく1枚の紙にまとめる。ここだけ素の行が並ぶと設定画面に戻ってしまう。
	var card := UIKit.card()
	_world_box.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	card.add_child(rows)

	var first := true
	for k in SimConfig.PARAM_DEF:
		var key := String(k)
		var d: Array = SimConfig.PARAM_DEF[key]
		if not first:
			UIKit.hairline(rows)
		first = false
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_top", 3)
		pad.add_theme_constant_override("margin_bottom", 3)
		rows.add_child(pad)

		if editable:
			UIKit.slider_row(pad, String(d[3]), SimConfig.p(key),
				float(d[1]), float(d[2]), _step_for(float(d[1]), float(d[2])),
				_set_world.bind(key), UIKit.WOOD, 150, _world_text.bind(key))
		else:
			var row := HBoxContainer.new()
			pad.add_child(row)
			var nm := UIKit.label(String(d[3]), 11, UIKit.TEXT)
			nm.custom_minimum_size = Vector2(150, 0)
			row.add_child(nm)
			row.add_child(UIKit.label(_world_text(SimConfig.p(key), key), 11, UIKit.TEXT_DIM))

	UIKit.spacer(_world_box, 10)


## 数字だけだと何の単位か分からない。世界の側の言い方で見せる。
func _world_text(v: float, key: String) -> String:
	match key:
		"day_length_sec":
			return "%d秒" % int(v)
		"night_starts_at":
			return "%02d:%02d" % [int(v), int(fmod(v * 60.0, 60.0))]
		"decision_interval":
			return "%.1f秒" % v
		"move_speed":
			return "%.1fマス/秒" % v
		"summaries_kept":
			return "%d日" % int(v)
	return UIKit._fmt(v, 1.0)


func _set_world(x: float, key: String) -> void:
	SimConfig.set_param(key, x)


func _step_for(vmin: float, vmax: float) -> float:
	var span := vmax - vmin
	if span <= 2.0:
		return 0.01
	if span <= 20.0:
		return 0.1
	return 1.0


# ---------------------------------------------------------------------------
# レシピ
# ---------------------------------------------------------------------------

func _rebuild_recipes() -> void:
	if _recipe_box == null:
		return
	_clear(_recipe_box)
	if editable:
		UIKit.wrapped(_recipe_box, "材料を組み合わせて作れるもの。", 11, UIKit.TEXT_DIM)

	for r in Schema.recipes:
		var rec: Dictionary = r
		var rid := String(rec["id"])
		var card := UIKit.card()
		_recipe_box.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", UIKit.GAP_S)
		card.add_child(box)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		box.add_child(head)
		head.add_child(UIKit.label("◆", 13, Color(0.55, 0.40, 0.20)))
		if editable:
			var le := LineEdit.new()
			le.text = String(rec["label"])
			le.add_theme_font_size_override("font_size", 12)
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.custom_minimum_size = Vector2(80, UIKit.ROW_H)
			head.add_child(le)
			le.text_changed.connect(_rename_recipe.bind(rid))
		else:
			head.add_child(UIKit.label(String(rec["label"]), 12, UIKit.TEXT))
		if _can_delete():
			UIKit.icon_button(head, "✕", "%s を消す" % String(rec["label"]),
				_del_recipe.bind(rid), 26, UIKit.ROW_H, 13)

		# 材料の増減だけだと在庫表に見える。何が何になるのかを1行の式で見せる
		var formula := ""
		for item in rec["inputs"]:
			var n := int(rec["inputs"][item])
			if n <= 0:
				continue
			if formula != "":
				formula += "  ＋  "
			formula += "%s×%d" % [Schema.item_label(String(item)), n]
		formula = ("材料なし" if formula == "" else formula)
		formula += "  →  " + String(rec["label"])
		box.add_child(UIKit.label(formula, 11, UIKit.TEXT_DIM))

		box.add_child(HSeparator.new())

		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", UIKit.PAD)
		box.add_child(indent)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", UIKit.GAP_S)
		indent.add_child(inner)

		if editable:
			inner.add_child(UIKit.label("材料", 10, UIKit.TEXT_DIM))
			for item in Schema.all_items():
				var iid := String(item)
				if iid == rid:
					continue  # 自分自身は材料にできない
				# 使っていない材料は0のまま並ぶ。薄くして、実際の材料だけが読めるようにする
				var n := int(rec["inputs"].get(iid, 0))
				var srow := UIKit.stepper_row(inner, Schema.item_label(iid),
					n, 9, _set_input.bind(rid, iid), 70)
				srow.modulate = Color(1, 1, 1, 1.0 if n > 0 else 0.45)
		else:
			var mats := ""
			for item in rec["inputs"]:
				if mats != "":
					mats += " ＋ "
				mats += "%s×%d" % [Schema.item_label(String(item)), int(rec["inputs"][item])]
			inner.add_child(UIKit.label(mats if mats != "" else "材料なし", 11, UIKit.TEXT_DIM))

	if editable:
		UIKit.spacer(_recipe_box, 4)
		UIKit.add_button(_recipe_box, "＋ つくりかたを増やす", _add_recipe)
	UIKit.spacer(_recipe_box, 10)


func _add_recipe() -> void:
	Schema.add_recipe()


func _del_recipe(rid: String) -> void:
	Schema.remove_recipe(rid)


func _rename_recipe(text: String, rid: String) -> void:
	Schema.rename_recipe(rid, text)


func _set_input(n: int, rid: String, item: String) -> void:
	Schema.set_recipe_input(rid, item, n)
