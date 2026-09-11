extends PanelContainer
## 設計図。この世界に何が存在し、誰がいて、どんな物理で動くかを神が決める。
##
## 「この世界の言葉」と呼んでいたが、**言葉だけではない**——
## 誰を置くかも、世界の目盛りも、ここで決める。図面としてまとめて持つ。
##
## **一枚の巻物。** 紙を切り替えるのではなく、**送る**。
##
## タブ（角丸の札）を紙の上に置いたら、後ろに何も無いので浮いた。
## 後ろの紙を本当に描いてもみたが、実体は1枚で後ろの紙は縁だけの飾りになり、
## 手前に来ている紙が名前の並びから抜けるので、読む順も変わってしまった。
##
## ロール紙なのだから、切り替える装置は要らない。
## 章を平らに6つ並べ（じぶん / あいて / もちもの / たてもの / 村人 / 詳細）、
## 紙の頭の**目次**を押すとその章まで送る。区分けの文法は
## すでにある「章の見出し → 罫で区切った行」だけで足りる。
##
## 「つくりかた」という中間の段も作らない——神が与えるのは名詞だけなので（DESIGN.md §1）、
## じぶん・あいて・もちもの・たてもの はどれも同じ高さの章。
## 名詞の章は**単語を2列**に割る。1列に積むと9語のじぶんだけで1画面が終わり、
## この世界にどんな言葉があるかを一目で見られない。
##
## 編集できるのは開始前だけ。始まったあとは前の4章だけが閲覧用に残り、
## 村人は村人の窓、世界の目盛りはオプションが持つ（同じものを2か所に置かない）。

signal started
signal closed

## 名前を書く欄の幅。ことば・もちもの・たてもの で同じにする。
## 区分ごとに幅が違うと、同じ紙に並んでいるのに別の種類のものに見える。
const WORD_W := 200

## スコープの読み方。同じ形の言葉が、何人ぶん持たれるかだけが違う。
const SCOPE_TIP := {
	Schema.SCOPE_SELF: "一人につき1つ持つ言葉。\n「どれだけ」の話なので 0〜100。",
	Schema.SCOPE_PAIR: "相手ひとりごとに1つ持つ言葉。\n「どちらへ」の話なので −100〜100。\n真ん中が何とも思っていないところ。",
}

var world = null
var editable := true

var _body: VBoxContainer
var _scroll: ScrollContainer
var _head_row: HBoxContainer
var _title: Label
var _title_lead: Control
var _help_btn: Control
var _start_btn: Button
var _reset_btn: Button
var _delete_btn: Button
var _close_btn: Button
var _mode_label: Label
var _delete_mode := false

## 詳細を開いているか。組み直しても畳み方は覚えておく
var _detail_open := false

## 章の目次。村人の紙と同じ部品（`chapter_index.gd`）
var _index: ChapterIndex


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP)
	UIKit.paper_sheet(self).add_child(root)

	# 題の出しかたは、開始前と進行中で変わる（`set_editable`）。
	#
	# 開始前は**この紙が主役**なので、題を中央に大きく置く。
	# 進行中は世界を見るための窓の1枚なので、村人・掲示板・関係と同じ顔にする。
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(title_row)
	# 開始前は題を中央に。左右に伸びる空きで挟んで真ん中へ寄せる
	# （進行中は左の空きを畳んで、他の窓と同じ左寄せになる）
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

	# 目次は**手の行**に置く。題は中央、目次は左、操作は右——と3つ揃えが違うと、
	# 目次だけが揃いの外れた副題に見える。押すものと同じ行に居れば、
	# 下線を足さなくても「この行は押す行」と場所が言ってくれる
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(head)
	_head_row = head

	_index = ChapterIndex.new()
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_index)

	_mode_label = UIKit.label("", UIKit.FS_NOTE, Color(0.72, 0.30, 0.20))
	head.add_child(_mode_label)

	_reset_btn = UIKit.button(head, "はじめに戻す", _reset_all)
	_reset_btn.custom_minimum_size = Vector2(112, UIKit.ROW_H - UIKit.HAIR)

	_delete_btn = UIKit.trash_toggle(head, "消すものを選ぶ")
	_delete_btn.toggled.connect(_on_delete_toggled)

	# 一枚の巻物。章はこの中に平らに並ぶ
	_body = UIKit.scroll_body(root, UIKit.BG)
	_scroll = _body.get_meta("scroll")
	_index.follow(_body)

	_start_btn = UIKit.accent_button(root, "この世界を始める", _on_start, UIKit.FS_HEAD)
	_start_btn.custom_minimum_size = Vector2(0, 46)

	Schema.parameters_changed.connect(_rebuild)
	Schema.recipes_changed.connect(_rebuild)
	Schema.buildings_changed.connect(_rebuild)
	Schema.villagers_changed.connect(_rebuild)
	_rebuild()


func set_editable(on: bool) -> void:
	editable = on
	_title.text = "設計図" if on else "ことば"
	UIKit.set_help(_help_btn, "この世界にある言葉と、そこに置く人を決める。\n"
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
	_delete_btn.visible = on
	if not on:
		_delete_mode = false
		_delete_btn.set_pressed_no_signal(false)
		_mode_label.text = ""
	_rebuild()


func _on_start() -> void:
	started.emit()


func _close() -> void:
	closed.emit()


func _on_delete_toggled(on: bool) -> void:
	_delete_mode = on
	# 押されていることはボタンの下地（テーマの pressed）が言う。
	# 色を被せると、押した瞬間だけ別の部品に化ける。
	_mode_label.text = "消すものを選んでいる" if on else ""
	_rebuild()


func _can_delete() -> bool:
	return editable and _delete_mode


func _reset_all() -> void:
	Schema.reset_all()
	SimConfig.reset_params()
	_rebuild()


# ---------------------------------------------------------------------------
# 巻物を組み立てる
# ---------------------------------------------------------------------------

## 章はどれも同じ高さで平らに並ぶ。中間の段（「ことば」でひとまとめ）は作らない。
##
## 進行中は前の4章だけ。村人は村人の窓が、世界の目盛りはオプションが持つ。
## 同じものを2か所に置くと、どちらが本体か分からなくなる。
func _rebuild() -> void:
	if _body == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_index.clear()

	# 名詞の章は、単語を**2列**に割る（`UIKit.two_columns`）
	_chapter(String(Schema.SCOPE_LABEL[Schema.SCOPE_SELF]), SCOPE_TIP[Schema.SCOPE_SELF],
		Schema.params_in(Schema.SCOPE_SELF).is_empty())
	_params_of(Schema.SCOPE_SELF)
	_chapter(String(Schema.SCOPE_LABEL[Schema.SCOPE_PAIR]), SCOPE_TIP[Schema.SCOPE_PAIR],
		Schema.params_in(Schema.SCOPE_PAIR).is_empty())
	_params_of(Schema.SCOPE_PAIR)

	_chapter("もちもの",
		"手に持てるもの。名前と姿だけを決める。材料の欄はない。\n"
		+ "何をどれだけ使うかは、作る人が自分の持ち物を見て決める。",
		Schema.recipes.is_empty())
	_things(Schema.recipes, Schema.CRAFT_ARTS, "＋ もちものを増やす",
		_add_recipe, _del_recipe, _rename_recipe)
	_chapter("たてもの",
		"世界の上に建つもの。建てた人のものになる（屋根がその人の色になる）。\n"
		+ "何軒建つかは決まっていないし、他人のものを使うのも世界は止めない。\n"
		+ "何を寄越すか（井戸なら水）は、名前を読んだ本人が答える。",
		Schema.buildings.is_empty())
	_things(Schema.buildings, Schema.BUILDING_ARTS, "＋ たてものを増やす",
		_add_building, _del_building, _rename_building)

	if editable:
		_chapter("村人",
			"この世界に置く人。\n名前も性格も、その人がどう振る舞うかの素になる。",
			Schema.villagers.is_empty())
		_people()
		# 目盛りは普段いじらないので、畳んでおく（`詳細`）
		_detail()

	UIKit.spacer(_body, UIKit.PAD_L)
	_index.rebuild()


## 章の見出し。目次の行き先としても覚えておく。
## `empty` はまだ何も書かれていない章で、目次に淡く出る
func _chapter(name_text: String, tip: String, empty: bool = false) -> void:
	_index.chapter(_body, name_text, tip, empty)


# ---------------------------------------------------------------------------
# 章の中身
# ---------------------------------------------------------------------------

func _params_of(scope: String) -> void:
	var defs := Schema.params_in(scope)
	var cols := UIKit.two_columns(_body)
	# 左の列を上から下まで埋めてから、右の列へ
	var half := int(ceil(float(defs.size()) / 2.0))
	for i in range(defs.size()):
		var box: VBoxContainer = cols[0] if i < half else cols[1]
		# 列の先頭には罫を引かない
		if i != 0 and i != half:
			UIKit.hairline(box)
		_build_param(box, defs[i])
	if editable:
		# 増やすボタンは2列の下に1つ。列ごとに置くと、どちらに足されるのか読めない
		UIKit.spacer(_body, UIKit.GAP_S)
		UIKit.add_button(_body, "＋ ことばを増やす", _add_param.bind(scope))
	UIKit.spacer(_body, UIKit.PAD_L)


func _build_param(box: Node, def: Dictionary) -> void:
	var pid := String(def["id"])
	var col := Schema.param_color(pid)

	# **行は読むための形。書くのは紙の上でやる。**
	# 罫線の欄を並べていたが、書き込める場所だと伝わらなかった（`PencilIcon`）。
	# 開始前と進行中で行の形が変わらないので、始まった瞬間に字が動かない。
	var label_text := String(def["label"])
	var row := UIKit.list_row(box, UIKit.dot(col.darkened(0.25)))
	row.add_child(UIKit.read_only(label_text))

	# 消すものを選んでいるあいだは鉛筆を隠す。押せる印が2つ並ぶと、
	# どちらを押すのか迷う
	if editable and not _can_delete():
		UIKit.pencil_button(row, "%s を書き直す" % label_text,
			_write_param.bind(def))

	var mid := Control.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)

	if _can_delete():
		UIKit.icon_button(row, "✕", "%s を消す" % label_text,
			_del_param.bind(pid), 30, UIKit.ROW_H, UIKit.FS_SUB)


func _add_param(scope: String) -> void:
	Schema.add_param(scope)


func _del_param(pid: String) -> void:
	Schema.remove_param(pid)


func _write_param(def: Dictionary) -> void:
	_write("ことばを書く", [{"label": "", "text": String(def["label"])}],
		func(v: PackedStringArray) -> void:
			def["label"] = v[0]
			_rebuild())


## 書く紙を1枚出す。世界の上に幕を張るので、`hud` ではなくこの紙の親に置く。
func _write(title: String, fields: Array, on_done: Callable) -> void:
	var pop = preload("res://scripts/ui/write_popup.gd").new()
	pop.setup(title, fields)
	get_parent().add_child(pop)
	pop.submitted.connect(on_done)


# ---------------------------------------------------------------------------
# もちもの / たてもの
#
# 定義が持つのは 名前 と 姿 だけ。材料の欄はない。
# 何をどれだけ使うかは、作る人が自分の持ち物を見て決める（DESIGN.md §1）。
# ---------------------------------------------------------------------------

## もちもの／たてもの、どちらも「名前と姿」だけなので同じ形で並べる
func _things(defs: Array, arts: Array, add_text: String,
		on_add: Callable, on_del: Callable, on_rename: Callable) -> void:
	var cols := UIKit.two_columns(_body)
	var half := int(ceil(float(defs.size()) / 2.0))

	for i in range(defs.size()):
		var def: Dictionary = defs[i]
		var did := String(def["id"])
		var rows: VBoxContainer = cols[0] if i < half else cols[1]
		if i != 0 and i != half:
			UIKit.hairline(rows)

		# 姿は先頭の欄へ。ことばの点と同じ欄なので、名前の左端が揃う
		var label_text := String(def["label"])
		var row := UIKit.list_row(rows, _art_picker(def, arts))
		# 姿は絵が語っているので、名前の横に姿の名を添えない
		row.add_child(UIKit.read_only(label_text))
		if editable and not _can_delete():
			UIKit.pencil_button(row, "%s を書き直す" % label_text,
				func() -> void: _write("名前を書く",
					[{"label": "", "text": label_text}],
					func(v: PackedStringArray) -> void: on_rename.call(v[0], did)))
		var mid := Control.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mid)
		if _can_delete():
			UIKit.icon_button(row, "✕", "%s を消す" % label_text,
				func() -> void: on_del.call(did), 30, UIKit.ROW_H, UIKit.FS_SUB)

	if editable:
		UIKit.spacer(_body, UIKit.GAP_S)
		UIKit.add_button(_body, add_text, on_add)
	UIKit.spacer(_body, UIKit.PAD_L)


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


# ---------------------------------------------------------------------------
# 村人
# ---------------------------------------------------------------------------

## **畳まない。** 畳むと決める対象そのものが隠れ、8人ぶん開いて回る二度手間になる。
## 人数には上限があるので（`Schema.MAX_VILLAGERS`）長さは有限で、
## 目次から送れるなら長さは害にならない。
func _people() -> void:
	var first := true
	for h in Schema.villagers:
		# 人と人のあいだは、罫1本と大きめの余白。囲うより軽い区切りで足りる
		if not first:
			UIKit.spacer(_body, UIKit.GAP)
			UIKit.hairline(_body)
			UIKit.spacer(_body, UIKit.GAP)
		first = false
		_build_person(h)

	if Schema.villagers.size() < Schema.MAX_VILLAGERS:
		UIKit.spacer(_body, UIKit.PAD_L)
		UIKit.add_button(_body, "＋ 村人を増やす", _add_villager)
	UIKit.spacer(_body, UIKit.PAD_L)


## 一人ぶん。**角丸の面で囲わない。**
## 名前がその人の色を持っているので、囲わなくても人と人の境目は読める。
func _build_person(h: Dictionary) -> void:
	var hid := String(h["id"])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.GAP_S)
	_body.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.GAP_S)
	box.add_child(head)
	head.add_child(_color_swatch(h))

	# 名前と一言は**1枚の紙で一緒に書く**。同じ人のことなので、鉛筆も1人に1つ。
	var nm := String(h["name"])
	head.add_child(UIKit.read_only(nm, UIKit.FS_SUB, Color(h["color"]).darkened(0.42)))
	head.add_child(UIKit.read_only(String(h["quirk"]), UIKit.FS_NOTE, UIKit.TEXT_DIM))

	if _can_delete():
		var mid := Control.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(mid)
		if Schema.villagers.size() > 1:
			UIKit.icon_button(head, "✕", "%s を消す" % nm,
				_del_villager.bind(hid), 30, UIKit.ROW_H, UIKit.FS_SUB)
	else:
		UIKit.pencil_button(head, "%s のことを書き直す" % nm,
			func() -> void: _write("この人のこと", [
				{"label": "名前", "text": nm},
				{"label": "一言でいうと", "text": String(h["quirk"]),
					"placeholder": "臆病、働き者、口が軽い…"},
			], func(v: PackedStringArray) -> void:
				h["name"] = v[0]
				h["quirk"] = v[1]
				_rebuild()))
		var mid := Control.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(mid)

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


func _add_villager() -> void:
	Schema.add_villager()


func _del_villager(hid: String) -> void:
	Schema.remove_villager(hid)


# ---------------------------------------------------------------------------
# 詳細（世界の目盛り）
#
# 「流れかた」と呼んでいたが、何の話なのか読めなかった。
# 1日の長さや歩く速さは、この世界の**言葉ではなく目盛り**なので、
# 名前も素っ気なくていい。ただし「設定」は付けない——
# **設定ダイアログの言葉を使わない**のがこの作品の決めごと（DESIGN.md §9）。
# **普段はいじらないので、畳んでおく。**
# ---------------------------------------------------------------------------

func _detail() -> void:
	var body := UIKit.fold_heading(_body, "詳細",
		"世界そのものの目盛り。\nつまみは10段で、積み木の切れ目がそのまま値になる。\n"
		+ "始まったあとはオプションから触る。",
		_detail_open, func(on: bool) -> void: _detail_open = on)
	_index.remember("詳細", body.get_meta("head_row"))
	_who(body)
	_world(body)
	UIKit.spacer(_body, UIKit.PAD_L)


## 判断を担うAIも、目盛りと同じくここで決められる（始まったあとはオプション）。
## 世界の語彙ではないので、章の中でも目盛りの側に置く
func _who(box: Node) -> void:
	var rows := UIKit.rows(box)
	UIKit.row_pad(rows).add_child(WhoPicker.new())


func _world(box: Node) -> void:
	var rows := UIKit.rows(box)
	var first := true
	for k in SimConfig.PARAM_DEF:
		var key := String(k)
		var d: Array = SimConfig.PARAM_DEF[key]
		if not first:
			UIKit.hairline(rows)
		first = false
		# ここには先頭に置くものが無いが、欄は空けておく。
		# 章が変わったときに字の左端が動くと、別の面に見える。
		UIKit.slider_row(UIKit.list_row(rows), String(d[3]), SimConfig.p(key),
			float(d[1]), float(d[2]), SimConfig.step_of(key),
			_set_world.bind(key), UIKit.WOOD, 150, SimConfig.text_of.bind(key))


func _set_world(x: float, key: String) -> void:
	SimConfig.set_param(key, x)
