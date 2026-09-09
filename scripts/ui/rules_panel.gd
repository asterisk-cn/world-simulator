extends PanelContainer
## 設計図。この世界に何が存在し、誰がいて、どんな物理で動くかを神が決める。
##
## 「この世界の言葉」と呼んでいたが、**言葉だけではない**——
## 誰を置くかも、世界の目盛りも、ここで決める。図面としてまとめて持つ。
##
## タブは **ことば / 村人 / 世界** の3枚。
## 「つくりかた」は別のタブではなく、**ことばの中の区分**にした（§後述）。
##
## 編集できるのは開始前だけ。始まったあとは「ことば」の1枚だけが閲覧用に残り、
## 村人は村人の窓、世界の目盛りはオプションが持つ（同じものを2か所に置かない）。

signal started
signal closed

var world = null
var editable := true

var _tabs: TabContainer
var _people_box: VBoxContainer
var _head_row: HBoxContainer
var _word_box: VBoxContainer
var _world_box: VBoxContainer
var _title: Label
var _title_lead: Control
var _help_btn: Control
var _start_btn: Button
var _reset_btn: Button
var _delete_btn: Button
var _close_btn: Button
var _mode_label: Label
var _delete_mode := false


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP)
	UIKit.paper_sheet(self).add_child(root)

	# 題の出しかたは、開始前と進行中で変わる（`set_editable`）。
	#
	# 開始前は**この紙が主役**なので、題を中央に大きく置く。
	# 進行中は世界を見るための窓の1枚なので、村人・掲示板・間柄と同じ顔にする
	# （`UIKit.window_header` と同じ形——左に題、右端に ✕）。
	# 同じ紙が同じ大きさの題で残っていると、そこだけ別の種類の窓に見える。
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(title_row)
	_title_lead = Control.new()
	_title_lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_lead)
	_title = UIKit.label("設計図", UIKit.FS_TITLE, UIKit.HEAD)
	title_row.add_child(_title)
	# 何をする場かは題の横の「?」で言う。紙に副題として書き足すと、
	# 決めるための面の一番上が読み物になる。
	# 右端の ✕ の隣に置くと、押せる印が2つ並んだ塊に見えるので、題にくっつける。
	_help_btn = UIKit.help(title_row, "")
	var gap_after := Control.new()
	gap_after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(gap_after)
	_close_btn = UIKit.icon_button(title_row, "✕", "閉じる", _close, 30, UIKit.ROW_H, UIKit.FS_SUB)
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(head)
	_head_row = head
	_mode_label = UIKit.label("", UIKit.FS_NOTE, Color(0.72, 0.30, 0.20))
	head.add_child(_mode_label)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)

	_reset_btn = UIKit.button(head, "はじめに戻す", _reset_all)
	_reset_btn.custom_minimum_size = Vector2(112, UIKit.ROW_H - UIKit.HAIR)

	_delete_btn = UIKit.trash_toggle(head, "消すものを選ぶ")
	_delete_btn.toggled.connect(_on_delete_toggled)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_tabs.tab_changed.connect(_on_tab_changed)

	# 決める順に並べる。何があるかを決め、誰を置くかを決め、最後に流れかたを決める。
	#
	# 「つくりかた」を別のタブにしていたが、**あれもことば**だった——
	# 神が与えるのは名詞だけで（DESIGN.md §1）、
	# 胸のうち・間柄・もちもの・たてもの はどれも「この世界にある言葉」。
	# 1枚に4つの区分として並べる。
	_word_box = _make_tab("ことば",
		"この世界にある言葉。村人が自分と他人について語れることばと、\n"
		+ "世界に在れるものの名前。どれもAIに渡す語彙そのものになる。")
	_people_box = _make_tab("村人",
		"この世界に置く人。\n名前も性格も、その人がどう振る舞うかの素になる。")
	_world_box = _make_tab("世界",
		"世界そのものの流れかた。\n始まったあとはオプションから触る。")

	_start_btn = UIKit.accent_button(root, "この世界を始める", _on_start, UIKit.FS_HEAD)
	_start_btn.custom_minimum_size = Vector2(0, 46)

	Schema.parameters_changed.connect(_rebuild_words)
	Schema.recipes_changed.connect(_rebuild_words)
	Schema.buildings_changed.connect(_rebuild_words)
	Schema.villagers_changed.connect(_rebuild_people)
	_rebuild_words()
	_rebuild_world()
	_rebuild_people()


func set_editable(on: bool) -> void:
	editable = on
	_title.text = "設計図" if on else "ことば"
	UIKit.set_help(_help_btn, "この世界にある言葉と、置く人と、世界の流れかたを決める。\n"
		+ "始めたあとは、もう変えられない。" if on
		else "始まった世界の言葉は、もう変えられない。\n見るだけの窓。")
	_start_btn.visible = on
	_reset_btn.visible = on
	_close_btn.visible = not on
	_head_row.visible = on
	# 開始前は主役の紙（題は中央に大きく）、進行中は見る窓の1枚（他の窓と同じ顔）
	_title_lead.visible = on
	_title.add_theme_font_size_override("font_size",
		UIKit.FS_TITLE if on else UIKit.FS_HEAD)

	# 進行中は「ことば」の1枚だけ。村人は村人の窓が、世界の目盛りはオプションが持つ。
	# 同じものを2か所に置くと、どちらが本体か分からなくなる。
	_tabs.tabs_visible = on
	for i in [1, 2]:
		_tabs.set_tab_hidden(i, not on)
	if not on:
		_tabs.current_tab = 0

	if not on:
		_delete_mode = false
		_delete_btn.set_pressed_no_signal(false)
		_mode_label.text = ""
	_update_delete_btn()
	_rebuild_words()
	_rebuild_world()
	_rebuild_people()


func _on_start() -> void:
	started.emit()


func _close() -> void:
	closed.emit()


func _on_delete_toggled(on: bool) -> void:
	_delete_mode = on
	# 押されていることはボタンの下地（テーマの pressed）が言う。
	# 色を被せると、押した瞬間だけ別の部品に化ける。
	_mode_label.text = "消すものを選んでいる" if on else ""
	_rebuild_words()
	_rebuild_people()


func _on_tab_changed(_i: int) -> void:
	_update_delete_btn()


## 世界タブ（3枚目）には消せるものが無い。隠すと右上のボタンの位置が動いてしまうので、
## 置いたまま効かなくする。
func _update_delete_btn() -> void:
	if _delete_btn == null or _tabs == null:
		return
	_delete_btn.visible = editable
	var usable := _tabs.current_tab != _tabs.get_tab_count() - 1
	_delete_btn.disabled = not usable
	# 薄くするのは効かないときだけ。ゴミ箱の絵は自分で墨を引くので、
	# 薄めないと押せるように見えてしまう。
	_delete_btn.modulate = Color(1, 1, 1, 1.0 if usable else 0.30)
	if not usable and _delete_mode:
		_delete_btn.set_pressed_no_signal(false)
		_on_delete_toggled(false)


func _can_delete() -> bool:
	return editable and _delete_mode


## タブの説明はその札のツールチップに持たせる。紙の一番上に1行書くと、
## 毎回読み飛ばす注記が3枚とも同じ場所に居座る。
##
## **中身に角丸の面を敷かない。** 選ばれている札の中身は、この紙そのもの。
## 紙の上にもう1枚紙を置いていたので、ロール紙の中に角丸の箱が残っていた
## （§9「箱は別の物体が乗っているときだけ」）。
## 奥の札だけが沈んだ色になり、選ばれた札は紙と地続きになる。
func _make_tab(tab_name: String, tip: String) -> VBoxContainer:
	var holder := MarginContainer.new()
	holder.name = tab_name
	holder.add_theme_constant_override("margin_top", UIKit.GAP)
	_tabs.add_child(holder)
	_tabs.set_tab_tooltip(_tabs.get_tab_count() - 1, tip)
	return UIKit.scroll_body(holder, UIKit.BG)


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

## 名前を書く欄の幅。ことば・もちもの・たてもの で同じにする。
## 区分ごとに幅が違うと、同じ紙に並んでいるのに別の種類のものに見える。
const WORD_W := 240

## スコープの読み方。同じ形の言葉が、何人ぶん持たれるかだけが違う。
const SCOPE_TIP := {
	Schema.SCOPE_SELF: "一人につき1つ持つ言葉。\n「どれだけ」の話なので 0〜100。",
	Schema.SCOPE_PAIR: "相手ひとりごとに1つ持つ言葉。\n「どちらへ」の話なので −100〜100。\n真ん中が何とも思っていないところ。",
}

## ことばタブ。**胸のうち / 間柄 / もちもの / たてもの** の4区分を1枚に並べる。
## 神が与えるのは名詞だけなので（DESIGN.md §1）、
## 「村人が語れることば」と「世界に在れるものの名前」は同じ種類のもの。
func _rebuild_words() -> void:
	if _word_box == null:
		return
	_clear(_word_box)

	for scope in [Schema.SCOPE_SELF, Schema.SCOPE_PAIR]:
		var sc := String(scope)
		# 束（カテゴリ）はやめた。区分はスコープの2つだけで、
		# その中は罫で区切った一続きの一覧。
		UIKit.heading(_word_box, String(Schema.SCOPE_LABEL[sc]), SCOPE_TIP[sc])
		var rows := UIKit.rows(_word_box)

		var first := true
		for d in Schema.params_in(sc):
			if not first:
				UIKit.hairline(rows)
			first = false
			_build_param(rows, d)

		if editable:
			UIKit.spacer(rows, UIKit.HAIR)
			UIKit.add_button(rows, "＋ ことばを増やす", _add_param.bind(sc))
		UIKit.spacer(_word_box, UIKit.PAD_L)

	_things_section("もちもの", Schema.recipes, Schema.CRAFT_ARTS,
		"＋ もちものを増やす", _add_recipe, _del_recipe, _rename_recipe,
		"手に持てるもの。名前と姿だけを決める。材料の欄はない。\n"
		+ "何をどれだけ使うかは、作る人が自分の持ち物を見て決める。")
	_things_section("たてもの", Schema.buildings, Schema.BUILDING_ARTS,
		"＋ たてものを増やす", _add_building, _del_building, _rename_building,
		"世界の上に建つもの。建てた人のものになる（屋根がその人の色になる）。\n"
		+ "何軒建つかは決まっていないし、他人のものを使うのも世界は止めない。\n"
		+ "何を寄越すか（井戸なら水）は、名前を読んだ本人が答える。")
	UIKit.spacer(_word_box, UIKit.PAD_L)


func _build_param(box: Node, def: Dictionary) -> void:
	var pid := String(def["id"])
	var col := Schema.param_color(pid)

	var row := UIKit.list_row(box, UIKit.dot(col.darkened(0.25)))

	if not editable:
		row.add_child(UIKit.read_only(String(def["label"])))
		return

	# 罫線を行いっぱいに伸ばすと、書かれているのに「未記入の書類」に見える。
	# 幅は `WORD_W` で1か所に決める——同じ紙に4つの一覧が並ぶので、
	# 欄の幅が区分ごとに違うと、同じ種類のものに見えない。
	var le := LineEdit.new()
	le.text = String(def["label"])
	le.custom_minimum_size = Vector2(WORD_W, UIKit.ROW_H)
	row.add_child(le)
	le.text_changed.connect(_set_label.bind(def))

	var mid := Control.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)

	if _can_delete():
		UIKit.icon_button(row, "✕", "%s を消す" % String(def["label"]),
			_del_param.bind(pid), 30, UIKit.ROW_H, UIKit.FS_SUB)


func _add_param(scope: String) -> void:
	Schema.add_param(scope)


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

	# 他のタブと同じ形——罫で区切った一続きの一覧
	UIKit.heading(_world_box, "流れかた", "世界そのものの目盛り。\nつまみは10段で、積み木の切れ目がそのまま値になる。")
	var rows := UIKit.rows(_world_box)

	var first := true
	for k in SimConfig.PARAM_DEF:
		var key := String(k)
		var d: Array = SimConfig.PARAM_DEF[key]
		if not first:
			UIKit.hairline(rows)
		first = false
		# ここには先頭に置くものが無いが、欄は空けておく。
		# タブを替えたときに字の左端が動くと、別の紙に見える。
		var row := UIKit.list_row(rows)
		if editable:
			UIKit.slider_row(row, String(d[3]), SimConfig.p(key),
				float(d[1]), float(d[2]), SimConfig.step_of(key),
				_set_world.bind(key), UIKit.WOOD, 150, SimConfig.text_of.bind(key))
		else:
			var nm := UIKit.read_only(String(d[3]))
			nm.custom_minimum_size = Vector2(150, 0)
			row.add_child(nm)
			row.add_child(UIKit.label(SimConfig.text_of(SimConfig.p(key), key),
				UIKit.FS_NOTE, UIKit.TEXT_DIM))

	UIKit.spacer(_world_box, UIKit.PAD_L)


func _set_world(x: float, key: String) -> void:
	SimConfig.set_param(key, x)


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

	var first := true
	for h in Schema.villagers:
		# 人と人のあいだは、罫1本と大きめの余白。囲うより軽い区切りで足りる
		if not first:
			UIKit.spacer(_people_box, UIKit.GAP)
			UIKit.hairline(_people_box)
			UIKit.spacer(_people_box, UIKit.GAP)
		first = false
		_build_person(h)

	if Schema.villagers.size() < Schema.MAX_VILLAGERS:
		UIKit.spacer(_people_box, UIKit.PAD_L)
		UIKit.add_button(_people_box, "＋ 村人を増やす", _add_villager)
	UIKit.spacer(_people_box, UIKit.PAD_L)


## 一人ぶん。**角丸の面で囲わない。**
## 名前がその人の色を持っているので、囲わなくても人と人の境目は読める。
## 区切りは罫1本と、次の人までの大きめの余白。
func _build_person(h: Dictionary) -> void:
	var hid := String(h["id"])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.GAP_S)
	_people_box.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.GAP_S)
	box.add_child(head)
	head.add_child(_color_swatch(h))

	var name_edit := LineEdit.new()
	name_edit.text = String(h["name"])
	name_edit.add_theme_font_size_override("font_size", UIKit.FS_SUB)
	name_edit.add_theme_color_override("font_color", Color(h["color"]).darkened(0.42))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(90, UIKit.ROW_H)
	head.add_child(name_edit)
	name_edit.text_changed.connect(func(t: String) -> void: h["name"] = t)

	var quirk := LineEdit.new()
	quirk.text = String(h["quirk"])
	quirk.placeholder_text = "一言でいうと"
	quirk.custom_minimum_size = Vector2(180, UIKit.ROW_H)
	head.add_child(quirk)
	quirk.text_changed.connect(func(t: String) -> void: h["quirk"] = t)

	if _can_delete() and Schema.villagers.size() > 1:
		UIKit.icon_button(head, "✕", "%s を消す" % String(h["name"]),
			_del_villager.bind(hid), 30, UIKit.ROW_H, UIKit.FS_SUB)

	# 性格。見る側（インスペクタ）と同じ積み木・同じ両端の言葉
	var rows := UIKit.rows(box)
	var first := true
	for a in Personality.AXES:
		if not first:
			UIKit.hairline(rows)
		first = false
		var key := String(a[0])
		UIKit.pole_slider(UIKit.row_pad(rows), String(a[2]), String(a[3]),
			float(h["axes"].get(key, 0.5)),
			func(x: float) -> void: h["axes"][key] = x)


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


## 始まったあとは、誰がいたかを見るだけ
func _people_list() -> void:
	var box := UIKit.rows(_people_box)
	var first := true
	for h in Schema.villagers:
		if not first:
			UIKit.hairline(box)
		first = false
		var row := UIKit.list_row(box, UIKit.dot(Color(h["color"])))
		var nm := UIKit.read_only(String(h["name"]))
		nm.custom_minimum_size = Vector2(UIKit.NAME_W, 0)
		row.add_child(nm)
		var q := UIKit.label(String(h["quirk"]), UIKit.FS_NOTE, UIKit.TEXT_DIM)
		q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(q)
	UIKit.spacer(_people_box, UIKit.PAD_L)


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

## 作れるもの／建てるもの、どちらも「名前と姿」だけなので同じ形で並べる
func _things_section(head_text: String, defs: Array, arts: Array, add_text: String,
		on_add: Callable, on_del: Callable, on_rename: Callable,
		tip: String = "") -> void:
	if defs.is_empty() and not editable:
		return

	# ことばタブと同じ、束より一段上の区分
	UIKit.heading(_word_box, head_text, tip)

	var rows := UIKit.rows(_word_box)

	var first := true
	for d in defs:
		var def: Dictionary = d
		var did := String(def["id"])
		if not first:
			UIKit.hairline(rows)
		first = false

		# 姿は先頭の欄へ。ことばタブの点と同じ欄なので、名前の左端が揃う
		var row := UIKit.list_row(rows, _art_picker(def, arts))
		if editable:
			var le := LineEdit.new()
			le.text = String(def["label"])
			le.custom_minimum_size = Vector2(WORD_W, UIKit.ROW_H)
			row.add_child(le)
			le.text_changed.connect(func(t: String) -> void: on_rename.call(t, did))
			var mid := Control.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(mid)
		else:
			# 姿は絵が語っているので、名前の横に姿の名を添えない
			var nm := UIKit.read_only(String(def["label"]))
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nm)
		if _can_delete():
			UIKit.icon_button(row, "✕", "%s を消す" % String(def["label"]),
				func() -> void: on_del.call(did), 30, UIKit.ROW_H, UIKit.FS_SUB)

	if editable:
		UIKit.spacer(rows, UIKit.HAIR)
		UIKit.add_button(rows, add_text, on_add)


## 姿は用意されたものから選ぶ。押すたびに次の姿へ送る（色と同じ決め方）。
func _art_picker(def: Dictionary, arts: Array) -> Control:
	var art := String(def["art"])
	var tint: Color = (Schema.building_color(String(def["id"]))
		if Schema.is_building(String(def["id"])) else ItemIcon.NO_TINT)
	if not editable:
		var seen := ItemIcon.of_art(art, 20)
		seen.accent = tint
		seen.tooltip_text = String(Schema.ART_LABEL.get(art, ""))
		return seen

	var b := Button.new()
	b.custom_minimum_size = Vector2(UIKit.LEAD_W, UIKit.LEAD_W)
	b.tooltip_text = "姿を変える（いまは %s）" % String(Schema.ART_LABEL.get(art, ""))
	var ic := ItemIcon.of_art(art, 20)
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
