extends PanelContainer
## 設定。この世界に何が存在し、どんな物理で動くかを神が決める。
##
## 編集できるのは開始前だけ。始まったあとは同じ画面が閲覧専用になる。

signal started
signal closed
signal ended

var world = null
var editable := true

var _tabs: TabContainer
var _people_box: VBoxContainer
var _head_row: HBoxContainer
var _param_box: VBoxContainer
var _recipe_box: VBoxContainer
var _world_box: VBoxContainer
var _title: Label
var _start_btn: Button
var _reset_btn: Button
var _delete_btn: Button
var _close_btn: Button
var _start_note: Label
var _end_btn: Button
var _end_note: Label
var _lead: Label
var _mode_label: Label
var _delete_mode := false
var _end_armed := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.panel_style())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP)
	add_child(root)

	# 題は舞台の名前。設定ダイアログではなく、世界に言葉を与える場に見せる。
	# 閉じるは題と同じ行の右端。副題の下に置くと、行き場のない印として浮く。
	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var lead_gap := Control.new()
	lead_gap.custom_minimum_size = Vector2(26, 0)
	title_row.add_child(lead_gap)
	_title = UIKit.label("この世界の言葉", 22, UIKit.HEAD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title)
	_close_btn = UIKit.icon_button(title_row, "✕", "閉じる", _close, 26, UIKit.ROW_H - 3, 13)
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lead = UIKit.label("", 11, UIKit.TEXT_DIM)
	_lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_lead)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(head)
	_head_row = head
	_mode_label = UIKit.label("", 11, Color(0.72, 0.30, 0.20))
	head.add_child(_mode_label)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)

	_reset_btn = UIKit.button(head, "はじめに戻す", _reset_all, 10)
	_reset_btn.custom_minimum_size = Vector2(84, UIKit.ROW_H - 3)

	_delete_btn = UIKit.trash_toggle(head, "消すものを選ぶ")
	_delete_btn.toggled.connect(_on_delete_toggled)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_tabs.tab_changed.connect(_on_tab_changed)

	_param_box = _make_tab("ことば")
	_recipe_box = _make_tab("つくりかた")
	_world_box = _make_tab("世界")
	_people_box = _make_tab("村人")

	# 大事なことほど、注記の書式で書かない
	_start_note = UIKit.label("これがこの世界の、最初で最後の言葉になる。", 12, UIKit.HEAD)
	_start_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_start_note)
	_start_btn = UIKit.accent_button(root, "この世界を始める", _on_start, 14)
	_start_btn.custom_minimum_size = Vector2(0, 38)

	# 始まった世界にできることは、見ることと、終えること。
	# 終えれば言葉のところへ戻る（この紙が、そのままこの遊びのメニュー）。
	# 始めるボタンと同じ場所に置く。出口を別の隅へ隠すと、探すものになってしまう。
	_end_note = UIKit.label("", 12, UIKit.HEAD)
	_end_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_note.visible = false
	root.add_child(_end_note)
	_end_btn = UIKit.button(root, "この世界を終える", _on_end, 12)
	_end_btn.custom_minimum_size = Vector2(0, 32)
	_end_btn.visible = false

	# 窓を閉じたら、押しかけていた手も戻す
	visibility_changed.connect(func() -> void:
		if not visible:
			_disarm_end())

	Schema.parameters_changed.connect(_rebuild_params)
	Schema.recipes_changed.connect(_rebuild_recipes)
	Schema.buildings_changed.connect(_rebuild_recipes)
	Schema.villagers_changed.connect(_rebuild_people)
	_rebuild_params()
	_rebuild_recipes()
	_rebuild_world()
	_rebuild_people()


func set_editable(on: bool) -> void:
	editable = on
	_lead.text = ("村人が使える言葉と、この世界にある物を決める。" if on
		else "始まった世界の言葉は、もう変えられない。")
	_start_btn.visible = on
	_start_note.visible = on
	_reset_btn.visible = on
	_close_btn.visible = not on
	_head_row.visible = on
	_end_btn.visible = not on
	_disarm_end()
	if not on:
		_delete_mode = false
		_delete_btn.set_pressed_no_signal(false)
		_mode_label.text = ""
	_update_delete_btn()
	_rebuild_params()
	_rebuild_recipes()
	_rebuild_world()
	_rebuild_people()


func _on_start() -> void:
	started.emit()


func _close() -> void:
	closed.emit()


## 一度目の押しで「終わる」と名乗り、二度目で本当に終える。
## 確認のダイアログを出さないのは始めるときと同じで、
## 出したいのは間違いの話ではなく、この村がここで終わるという重さのほう。
func _on_end() -> void:
	if not _end_armed:
		_end_armed = true
		_end_btn.text = "もう一度押す"
		_end_note.text = "この村はここで終わり、言葉のところへ戻る。\n記録も間柄も残らない。"
		_end_note.visible = true
		return
	_disarm_end()
	ended.emit()


func _disarm_end() -> void:
	_end_armed = false
	if _end_btn != null:
		_end_btn.text = "この世界を終える"
	if _end_note != null:
		_end_note.text = ""
		_end_note.visible = false


func _on_delete_toggled(on: bool) -> void:
	_delete_mode = on
	_delete_btn.modulate = Color(1.0, 0.55, 0.5) if on else Color.WHITE
	_mode_label.text = "消すものを選んでいる" if on else ""
	_rebuild_params()
	_rebuild_recipes()
	_rebuild_people()


func _on_tab_changed(_i: int) -> void:
	_update_delete_btn()


## 世界タブ（3枚目）には消せるものが無い。隠すと右上のボタンの位置が動いてしまうので、
## 置いたまま効かなくする。
func _update_delete_btn() -> void:
	if _delete_btn == null or _tabs == null:
		return
	_delete_btn.visible = editable
	var usable := _tabs.current_tab != 2
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
	# 紙を見出しの下へ少し差し込む。ここが空くと札が浮いて、紙の束に見えない
	# （奥の札は選ばれた札ほど下へ伸びないので、その差を紙側で吸う）
	holder.add_theme_constant_override("margin_top", -3)
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
	var parts := UIKit.category_card(_param_box, col)
	var head: HBoxContainer = parts[0]
	var inner: VBoxContainer = parts[1]

	if editable:
		head.add_child(_flat_edit(cat, col, scope))
	else:
		head.add_child(UIKit.label(cat, 13, col.darkened(0.28)))
	if _can_delete():
		UIKit.icon_button(head, "✕", "%s を消す" % cat, _del_category.bind(scope, cat), 26, UIKit.ROW_H, 13)

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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.GAP_S)
	UIKit.row_pad(box).add_child(row)
	row.add_child(UIKit.label("●", 12, col.darkened(0.25)))

	if not editable:
		row.add_child(UIKit.label(String(def["label"]), 12, UIKit.TEXT))
		return

	# 罫線を行いっぱいに伸ばすと、書かれているのに「未記入の書類」に見える。
	# とりうる幅の列が消えたぶんだけ広げて、右の空きと釣り合わせる。
	var le := LineEdit.new()
	le.text = String(def["label"])
	le.add_theme_font_size_override("font_size", 11)
	le.custom_minimum_size = Vector2(240, UIKit.ROW_H)
	row.add_child(le)
	le.text_changed.connect(_set_label.bind(def))

	var mid := Control.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)

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
			return "%.1f歩/秒" % v
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
# ひと
# ---------------------------------------------------------------------------

func _rebuild_people() -> void:
	if _people_box == null:
		return
	_clear(_people_box)
	if not editable:
		_people_list()
		return

	UIKit.wrapped(_people_box,
		"この世界に置く村人。名前も性格も、その人がどう振る舞うかの素になる。", 11, UIKit.TEXT_DIM)

	for h in Schema.villagers:
		_build_person(h)

	if Schema.villagers.size() < Schema.MAX_VILLAGERS:
		UIKit.spacer(_people_box, 4)
		UIKit.add_button(_people_box, "＋ 村人を増やす", _add_villager)
	UIKit.spacer(_people_box, 10)


func _build_person(h: Dictionary) -> void:
	var hid := String(h["id"])
	var card := UIKit.card()
	_people_box.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.GAP_S)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.GAP_S)
	box.add_child(head)
	head.add_child(_color_swatch(h))

	var name_edit := LineEdit.new()
	name_edit.text = String(h["name"])
	name_edit.add_theme_font_size_override("font_size", 13)
	name_edit.add_theme_color_override("font_color", Color(h["color"]).darkened(0.42))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(90, UIKit.ROW_H + 2)
	head.add_child(name_edit)
	name_edit.text_changed.connect(func(t: String) -> void: h["name"] = t)

	var quirk := LineEdit.new()
	quirk.text = String(h["quirk"])
	quirk.placeholder_text = "一言でいうと"
	quirk.add_theme_font_size_override("font_size", 11)
	quirk.custom_minimum_size = Vector2(150, UIKit.ROW_H)
	head.add_child(quirk)
	quirk.text_changed.connect(func(t: String) -> void: h["quirk"] = t)

	if _can_delete() and Schema.villagers.size() > 1:
		UIKit.icon_button(head, "✕", "%s を消す" % String(h["name"]),
			_del_villager.bind(hid), 26, UIKit.ROW_H, 13)

	box.add_child(HSeparator.new())

	# 性格。見る側（インスペクタ）と同じ積み木・同じ両端の言葉
	for a in Personality.AXES:
		var key := String(a[0])
		UIKit.pole_slider(box, String(a[2]), String(a[3]),
			float(h["axes"].get(key, 0.5)),
			func(x: float) -> void: h["axes"][key] = x)

	# 持ち物。始まりに何を握らせておくか
	var have := HBoxContainer.new()
	have.add_theme_constant_override("separation", UIKit.GAP)
	box.add_child(have)
	have.add_child(UIKit.label("持ち物", 10, UIKit.TEXT_DIM))
	for item in Schema.all_items():
		_item_counter(have, h, String(item))


## 色は世界の上での見分けになる。押すと、まだ誰も使っていない色へ移る。
func _color_swatch(h: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(UIKit.ROW_H, UIKit.ROW_H)
	b.tooltip_text = "色を変える"
	var paint := func(col: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(5)
		sb.border_color = Color(0.46, 0.33, 0.21, 0.45)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
	paint.call(Color(h["color"]))
	b.pressed.connect(func() -> void:
		h["color"] = Schema.next_color(Color(h["color"]))
		paint.call(Color(h["color"])))
	return b


func _item_counter(parent: Node, h: Dictionary, iid: String) -> void:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 3)
	cell.tooltip_text = Schema.item_label(iid)
	parent.add_child(cell)
	cell.add_child(ItemIcon.of_item(iid, 18))

	var n := int(h["items"].get(iid, 0))
	# 増減は −／数／＋ の並び。場所ごとに形が変わると読み方が変わる
	var minus := UIKit._round_button("−")
	cell.add_child(minus)

	var val := UIKit.label(str(n), 11, UIKit.TEXT if n > 0 else UIKit.TEXT_DIM)
	val.custom_minimum_size = Vector2(16, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(val)

	var plus := UIKit._round_button("＋")
	cell.add_child(plus)

	var count := [n]
	var apply := func(d: int) -> void:
		count[0] = clampi(count[0] + d, 0, 9)
		val.text = str(count[0])
		val.add_theme_color_override("font_color",
			UIKit.TEXT if count[0] > 0 else UIKit.TEXT_DIM)
		if count[0] <= 0:
			h["items"].erase(iid)
		else:
			h["items"][iid] = count[0]
	minus.pressed.connect(func() -> void: apply.call(-1))
	plus.pressed.connect(func() -> void: apply.call(1))


## 始まったあとは、誰がいたかを1枚の紙で見るだけ
func _people_list() -> void:
	var card := UIKit.card()
	_people_box.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)

	var first := true
	for h in Schema.villagers:
		if not first:
			UIKit.hairline(box)
		first = false
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_top", 3)
		pad.add_theme_constant_override("margin_bottom", 3)
		box.add_child(pad)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UIKit.GAP_S)
		pad.add_child(row)

		var dot := ColorRect.new()
		dot.color = Color(h["color"])
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)

		var nm := UIKit.label(String(h["name"]), 12, UIKit.TEXT)
		nm.custom_minimum_size = Vector2(62, 0)
		row.add_child(nm)
		var q := UIKit.label(String(h["quirk"]), 11, UIKit.TEXT_DIM)
		q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(q)
	UIKit.spacer(_people_box, 10)


func _add_villager() -> void:
	Schema.add_villager()


func _del_villager(hid: String) -> void:
	Schema.remove_villager(hid)


# ---------------------------------------------------------------------------
# つくりかた（作れるもの / 建てられるもの）
#
# 定義が持つのは 名前 と 姿 だけ。材料の欄はない。
# 何をどれだけ使うかは、作る人が自分の持ち物を見て決める（DESIGN.md §1）。
# ---------------------------------------------------------------------------

func _rebuild_recipes() -> void:
	if _recipe_box == null:
		return
	_clear(_recipe_box)
	if editable:
		UIKit.wrapped(_recipe_box,
			"この世界で作れるものと、建てられるもの。\n"
			+ "何をどれだけ使うかは、作る人が持ち物を見て決める。", 11, UIKit.TEXT_DIM)

	_things_section("持てるもの", Schema.recipes, Schema.CRAFT_ARTS,
		"＋ つくりかたを増やす", _add_recipe, _del_recipe, _rename_recipe)
	_things_section("建てるもの", Schema.buildings, Schema.BUILDING_ARTS,
		"＋ 建てるものを増やす", _add_building, _del_building, _rename_building)
	UIKit.spacer(_recipe_box, 10)


## 作れるもの／建てるもの、どちらも「名前と姿」だけなので同じ形で並べる
func _things_section(title: String, defs: Array, arts: Array, add_text: String,
		on_add: Callable, on_del: Callable, on_rename: Callable) -> void:
	if defs.is_empty() and not editable:
		return

	# ことばタブと同じ、束より一段上の区分
	UIKit.spacer(_recipe_box, UIKit.GAP_S)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", UIKit.GAP_S)
	_recipe_box.add_child(sh)
	sh.add_child(UIKit.label(title, 15, UIKit.HEAD))
	var rule := HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(rule)
	UIKit.spacer(_recipe_box, 2)

	var card := UIKit.card()
	_recipe_box.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	card.add_child(rows)

	var first := true
	for d in defs:
		var def: Dictionary = d
		var did := String(def["id"])
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

		row.add_child(_art_picker(def, arts))
		if editable:
			var le := LineEdit.new()
			le.text = String(def["label"])
			le.add_theme_font_size_override("font_size", 12)
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.custom_minimum_size = Vector2(100, UIKit.ROW_H)
			row.add_child(le)
			le.text_changed.connect(func(t: String) -> void: on_rename.call(t, did))
		else:
			# 姿は絵が語っているので、名前の横に姿の名を添えない
			var nm := UIKit.label(String(def["label"]), 12, UIKit.TEXT)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nm)
		if _can_delete():
			UIKit.icon_button(row, "✕", "%s を消す" % String(def["label"]),
				func() -> void: on_del.call(did), 26, UIKit.ROW_H, 13)

	if editable:
		UIKit.spacer(rows, 2)
		UIKit.add_button(rows, add_text, on_add)


## 姿は用意されたものから選ぶ。押すたびに次の姿へ送る（色と同じ決め方）。
func _art_picker(def: Dictionary, arts: Array) -> Control:
	var art := String(def["art"])
	var tint: Color = (Schema.building_color(String(def["id"]))
		if Schema.is_building(String(def["id"])) else ItemIcon.NO_TINT)
	if not editable:
		var seen := ItemIcon.of_art(art, 22)
		seen.accent = tint
		seen.tooltip_text = String(Schema.ART_LABEL.get(art, ""))
		return seen

	var b := Button.new()
	b.custom_minimum_size = Vector2(UIKit.ROW_H + 4, UIKit.ROW_H + 4)
	b.tooltip_text = "姿を変える（いまは %s）" % String(Schema.ART_LABEL.get(art, ""))
	var ic := ItemIcon.of_art(art, 22)
	ic.accent = tint
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(ic)
	b.pressed.connect(func() -> void: Schema.cycle_art(def, arts))
	return b


func _add_recipe() -> void:
	Schema.add_recipe()


func _del_recipe(rid: String) -> void:
	Schema.remove_recipe(rid)


func _rename_recipe(text: String, rid: String) -> void:
	Schema.rename_recipe(rid, text)


func _add_building() -> void:
	Schema.add_building()


func _del_building(bid: String) -> void:
	Schema.remove_building(bid)


func _rename_building(text: String, bid: String) -> void:
	Schema.rename_building(bid, text)
