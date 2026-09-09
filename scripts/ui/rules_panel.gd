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
## 章を平らに6つ並べ（胸のうち / 間柄 / もちもの / たてもの / 村人 / 詳細設定）、
## 紙の頭の**目次**を押すとその章まで送る。区分けの文法は
## すでにある「章の見出し → 罫で区切った行」だけで足りる。
##
## 「つくりかた」という中間の段も作らない——神が与えるのは名詞だけなので（DESIGN.md §1）、
## 胸のうち・間柄・もちもの・たてもの はどれも同じ高さの章。
## 名詞の章は**単語を2列**に割る。1列に積むと9語の胸のうちだけで1画面が終わり、
## この世界にどんな言葉があるかを一目で見られない。
##
## 編集できるのは開始前だけ。始まったあとは前の4章だけが閲覧用に残り、
## 村人は村人の窓、世界の目盛りはオプションが持つ（同じものを2か所に置かない）。

signal started
signal closed

## 送るときの一拍。即座に飛ぶと、結局「札の切り替え」に見える。
## 封蝋や紙が飛ぶのと同じ族の、動いた方向が目に残る速さ。
const GLIDE := 0.25

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
var _index_row: HBoxContainer
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

## 詳細設定を開いているか。組み直しても畳み方は覚えておく
var _detail_open := false

## 章の見出し行。目次の行き先と、いまどの章を見ているかの判定に使う
var _chapters: Array = []      ## [{name, row}]
var _index_btns: Array = []
var _here := 0
var _glide: Tween = null


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP)
	UIKit.paper_sheet(self).add_child(root)

	# 題の出しかたは、開始前と進行中で変わる（`set_editable`）。
	#
	# 開始前は**この紙が主役**なので、題を中央に大きく置く。
	# 進行中は世界を見るための窓の1枚なので、村人・掲示板・間柄と同じ顔にする。
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

	# 目次。**箱でも札でもなく、1行の文**にする。
	# 章名を淡い「・」で繋ぐだけで、下線も枠も影も持たない。
	# いま見ている章だけ見出しと同じ色になるので、目次と本文が繋がる。
	_index_row = HBoxContainer.new()
	_index_row.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(_index_row)

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

	# 一枚の巻物。章はこの中に平らに並ぶ
	_body = UIKit.scroll_body(root, UIKit.BG)
	_scroll = _body.get_meta("scroll")
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _mark_here())

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
	_chapters.clear()

	# 名詞の章は、単語を**2列**に割る（`UIKit.two_columns`）
	_chapter("胸のうち", SCOPE_TIP[Schema.SCOPE_SELF])
	_params_of(Schema.SCOPE_SELF)
	_chapter("間柄", SCOPE_TIP[Schema.SCOPE_PAIR])
	_params_of(Schema.SCOPE_PAIR)

	_chapter("もちもの",
		"手に持てるもの。名前と姿だけを決める。材料の欄はない。\n"
		+ "何をどれだけ使うかは、作る人が自分の持ち物を見て決める。")
	_things(Schema.recipes, Schema.CRAFT_ARTS, "＋ もちものを増やす",
		_add_recipe, _del_recipe, _rename_recipe)
	_chapter("たてもの",
		"世界の上に建つもの。建てた人のものになる（屋根がその人の色になる）。\n"
		+ "何軒建つかは決まっていないし、他人のものを使うのも世界は止めない。\n"
		+ "何を寄越すか（井戸なら水）は、名前を読んだ本人が答える。")
	_things(Schema.buildings, Schema.BUILDING_ARTS, "＋ たてものを増やす",
		_add_building, _del_building, _rename_building)

	if editable:
		_chapter("村人",
			"この世界に置く人。\n名前も性格も、その人がどう振る舞うかの素になる。")
		_people()
		# 目盛りは普段いじらないので、畳んでおく（`詳細設定`）
		_detail()

	UIKit.spacer(_body, UIKit.PAD_L)
	_rebuild_index()


## 章の見出し。目次の行き先としても覚えておく。
func _chapter(name_text: String, tip: String) -> void:
	var row := UIKit.heading(_body, name_text, tip)
	_chapters.append({"name": name_text, "row": row})


## 目次。章名を淡い「・」で繋いだ1行。
func _rebuild_index() -> void:
	for c in _index_row.get_children():
		_index_row.remove_child(c)
		c.queue_free()
	_index_btns.clear()
	if _chapters.size() <= 1:
		_index_row.visible = false
		return
	_index_row.visible = true
	for i in range(_chapters.size()):
		if i > 0:
			var dot := UIKit.label("・", UIKit.FS_BODY, Color(0.46, 0.41, 0.34, 0.55))
			_index_row.add_child(dot)
		var b := Button.new()
		b.text = String(_chapters[i]["name"])
		b.add_theme_font_size_override("font_size", UIKit.FS_BODY)
		# 押せる箱ではなく、字そのもの。下地も枠も持たない
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.add_theme_color_override("font_hover_color", UIKit.TEXT)
		_index_row.add_child(b)
		b.pressed.connect(_glide_to.bind(i))
		_index_btns.append(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index_row.add_child(gap)
	_mark_here.call_deferred()


## その章まで送る。**するすると動かす**——即座に飛ぶと、
## 紙を送ったのではなく面が入れ替わったように見える。
func _glide_to(i: int) -> void:
	if i < 0 or i >= _chapters.size() or _scroll == null:
		return
	var row: Control = _chapters[i]["row"]
	if not is_instance_valid(row):
		return
	# 章の上の余白（`PAD`）は残して止める
	var to: float = maxf(row.position.y - float(UIKit.PAD), 0.0)
	if _glide != null and _glide.is_valid():
		_glide.kill()
	_glide = create_tween()
	_glide.tween_property(_scroll, "scroll_vertical", int(to), GLIDE) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## いま読んでいる章。見出しが紙の上端を越えた最後のものがそれ。
func _mark_here() -> void:
	if _scroll == null or _index_btns.is_empty():
		return
	var at := float(_scroll.scroll_vertical) + float(UIKit.PAD) + 1.0
	var found := 0
	for i in range(_chapters.size()):
		var row: Control = _chapters[i]["row"]
		if is_instance_valid(row) and row.position.y <= at:
			found = i
	# 最後の章は、その下に送るぶんの紙が無いので上端を越えられない。
	# 終わりまで送ったら最後の章に居る、と決める。
	var bar := _scroll.get_v_scroll_bar()
	if bar.max_value - bar.page - bar.value <= 1.0:
		found = _chapters.size() - 1
	_here = found
	for i in range(_index_btns.size()):
		var b: Button = _index_btns[i]
		b.add_theme_color_override("font_color",
			UIKit.HEAD if i == _here else UIKit.TEXT_DIM)


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

	var row := UIKit.list_row(box, UIKit.dot(col.darkened(0.25)))

	if not editable:
		row.add_child(UIKit.read_only(String(def["label"])))
		return

	# 罫線を行いっぱいに伸ばすと、書かれているのに「未記入の書類」に見える。
	# 幅は `WORD_W` で1か所に決める——同じ紙に4つの一覧が並ぶので、
	# 欄の幅が章ごとに違うと、同じ種類のものに見えない。
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


func _add_villager() -> void:
	Schema.add_villager()


func _del_villager(hid: String) -> void:
	Schema.remove_villager(hid)


# ---------------------------------------------------------------------------
# 詳細設定（世界の目盛り）
#
# 「流れかた」と呼んでいたが、何の話なのか読めなかった。
# 1日の長さや歩く速さは、この世界の**言葉ではなく目盛り**なので、
# 名前も設定の言い方でいい。**普段はいじらないので、畳んでおく。**
# ---------------------------------------------------------------------------

func _detail() -> void:
	var body := UIKit.fold_heading(_body, "詳細設定",
		"世界そのものの目盛り。\nつまみは10段で、積み木の切れ目がそのまま値になる。\n"
		+ "始まったあとはオプションから触る。",
		_detail_open, func(on: bool) -> void: _detail_open = on)
	_chapters.append({"name": "詳細設定", "row": body.get_meta("head_row")})
	_world(body)
	UIKit.spacer(_body, UIKit.PAD_L)


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
