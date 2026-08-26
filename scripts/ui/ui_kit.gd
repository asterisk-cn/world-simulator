class_name UIKit
extends RefCounted
## コードから UI を組み立てるための小さなヘルパ群。

# ---------------------------------------------------------------------------
# 紙と木。
#
# 神は紙に書いて板に貼る。世界はパステルの積み木でできている。
# UIを無彩色のダークスレートにすると、そこだけ開発ツールになってしまうので、
# 世界と同じ素材で作る。
# ---------------------------------------------------------------------------

const BG := Color(0.95, 0.91, 0.82)       ## 紙
const BG_SOFT := Color(0.90, 0.85, 0.74)  ## 紙の上に置く紙
const TEXT := Color(0.20, 0.17, 0.13)     ## 墨
const TEXT_DIM := Color(0.46, 0.41, 0.34)
const WOOD := Color(0.46, 0.33, 0.21)     ## 枠
const HEAD := Color(0.36, 0.26, 0.16)     ## 見出し
const INK := Color(0.30, 0.22, 0.14, 0.10)   ## 押せるものの下地
const INK_HOVER := Color(0.30, 0.22, 0.14, 0.18)
const INK_ACTIVE := Color(0.30, 0.22, 0.14, 0.28)
const SUNK := Color(0.30, 0.22, 0.14, 0.13)  ## 入力欄のくぼみ
const ACCENT := Color(0.86, 0.52, 0.18)   ## 神の手が届くところ。ここぞという1か所にだけ

## 日本語は英字より行が高い。入力欄やボタンをこれより低くすると文字の上下が切れる。
const ROW_H := 27

## 読み取り専用バーの太さ。場所によって変わらないよう1か所で決める。
const BAR_H := 10

## 縦スクロールする中身は、スクロールバーとこれだけ離す。
const SCROLL_GUTTER := 12

## 余白の基準。ここ以外に数字を置かない。
const PAD := 14      ## パネルの内側
const PAD_S := 10    ## パネルの中に置く小さなカードの内側
const GAP := 10      ## まとまりどうしの間
const GAP_S := 6     ## 並んだ行どうしの間
const GAP_INLINE := 10  ## 1行の中の、ラベルと中身の間


## UI全体の見た目を1か所で決める。
## これを敷かないと、ボタンや入力欄だけがエンジン既定の暗い箱を持ってしまい、
## そこだけ影が差したように見える。
static func build_theme(font: Font) -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 12

	var flat := func(col: Color, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(radius)
		sb.content_margin_left = pad_x
		sb.content_margin_right = pad_x
		sb.content_margin_top = pad_y
		sb.content_margin_bottom = pad_y
		return sb

	for t in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
		th.set_stylebox("normal", t, flat.call(INK, 6, 8, 4))
		th.set_stylebox("hover", t, flat.call(INK_HOVER, 6, 8, 4))
		th.set_stylebox("pressed", t, flat.call(INK_ACTIVE, 6, 8, 4))
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
		th.set_stylebox("disabled", t, flat.call(Color(0.30, 0.22, 0.14, 0.04), 6, 8, 4))
		th.set_color("font_color", t, TEXT)
		th.set_color("font_hover_color", t, Color(0.10, 0.08, 0.05))
		th.set_color("font_pressed_color", t, Color(0.10, 0.08, 0.05))
		th.set_color("font_disabled_color", t, Color(0.30, 0.26, 0.20, 0.4))

	th.set_stylebox("normal", "LineEdit", flat.call(SUNK, 6, 8, 4))
	th.set_stylebox("focus", "LineEdit", flat.call(Color(0.30, 0.22, 0.14, 0.22), 6, 8, 4))
	th.set_color("font_color", "LineEdit", TEXT)
	th.set_color("font_placeholder_color", "LineEdit", Color(0.30, 0.26, 0.20, 0.45))
	th.set_color("caret_color", "LineEdit", TEXT)

	th.set_stylebox("panel", "PopupMenu", flat.call(BG_SOFT, 8, 6, 6))
	th.set_color("font_color", "PopupMenu", TEXT)
	th.set_color("font_hover_color", "PopupMenu", Color(0.10, 0.08, 0.05))
	th.set_stylebox("hover", "PopupMenu", flat.call(INK_HOVER, 5, 6, 3))

	th.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	# 選ばれているタブは木の色で塗り、紙の文字を乗せる。半端な濃さだと選択が読めない
	var tab_on := StyleBoxFlat.new()
	tab_on.bg_color = WOOD
	# 下だけ角が立っていると、中身の面に刺さって切れたように見える。札として全周を丸める
	tab_on.set_corner_radius_all(7)
	tab_on.content_margin_left = 14
	tab_on.content_margin_right = 14
	tab_on.content_margin_top = 6
	tab_on.content_margin_bottom = 6
	th.set_stylebox("tab_selected", "TabContainer", tab_on)
	th.set_stylebox("tab_unselected", "TabContainer",
		flat.call(Color(0.30, 0.22, 0.14, 0.08), 7, 14, 6))
	th.set_stylebox("tab_hovered", "TabContainer",
		flat.call(Color(0.30, 0.22, 0.14, 0.16), 7, 14, 6))
	th.set_color("font_selected_color", "TabContainer", Color(0.97, 0.94, 0.87))
	th.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	th.set_color("font_hovered_color", "TabContainer", TEXT)

	th.set_color("separator", "HSeparator", Color(0.30, 0.22, 0.14, 0.22))
	th.set_constant("separation", "HSeparator", 6)

	# スクロールバー。既定のままだと紙の上で黒い棒に見える
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.30, 0.22, 0.14, 0.07)
	track.set_corner_radius_all(4)
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.46, 0.33, 0.21, 0.45)
	grab.set_corner_radius_all(4)
	var grab_on := StyleBoxFlat.new()
	grab_on.bg_color = Color(0.46, 0.33, 0.21, 0.70)
	grab_on.set_corner_radius_all(4)
	for t in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", t, track)
		th.set_stylebox("grabber", t, grab)
		th.set_stylebox("grabber_highlight", t, grab_on)
		th.set_stylebox("grabber_pressed", t, grab_on)
	return th


static func panel_style(bg: Color = BG, radius: int = 10, pad: int = PAD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	# 木の枠。世界の掲示板や木の幹と同じ色域なので浮かない
	sb.border_color = WOOD
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	return sb


## パネルの中に置くカード。枠と影を持たせると、そこが一番強い要素になってしまう。
static func card(bg: Color = BG_SOFT, pad: int = PAD_S) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(7)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", sb)
	return p


static func panel(bg: Color = BG, radius: int = 10, pad: int = PAD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, radius, pad))
	return p


static func label(text: String, size: int = 12, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## 章の見出し（強）。この下にカテゴリ（中）、その下に行（弱）が来る。
static func section(parent: Node, text: String, col: Color = HEAD) -> Label:
	var l := label(text, 13, col)
	l.add_theme_constant_override("line_spacing", 2)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 12)
	parent.add_child(sp)
	parent.add_child(l)
	var sep := HSeparator.new()
	parent.add_child(sep)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 2)
	parent.add_child(sp2)
	return l


static func wrapped(parent: Node, text: String, size: int = 11, col: Color = TEXT_DIM) -> Label:
	var l := label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 0)
	parent.add_child(l)
	return l


## ラベル + スライダー + 数値。on_change(new_value) が呼ばれる。
static func slider_row(
	parent: Node, name_text: String, value: float,
	vmin: float, vmax: float, step: float,
	on_change: Callable, bar_color: Color = Color(0.5, 0.7, 0.95),
	name_width: int = 62
) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_INLINE)
	parent.add_child(row)

	var nm := label(name_text, 11, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)

	var s := HSlider.new()
	s.min_value = vmin
	s.max_value = vmax
	s.step = step
	s.value = clampf(value, vmin, vmax)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(80, 18)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = bar_color
	grabber.set_corner_radius_all(3)
	s.add_theme_stylebox_override("grabber_area", grabber)
	s.add_theme_stylebox_override("grabber_area_highlight", grabber)
	row.add_child(s)

	var val := label(_fmt(s.value, step), 11, TEXT_DIM)
	val.custom_minimum_size = Vector2(44, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

	s.value_changed.connect(func(x: float) -> void:
		val.text = _fmt(x, step)
		on_change.call(x)
	)
	return s


## 両極の値。ゲージの左右に、どちらへ寄っているかの言葉を置く。
static func pole_row(parent: Node, left: String, right: String, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_INLINE)
	parent.add_child(row)

	var l := label(left, 10, TEXT if value < 0.45 else TEXT_DIM)
	l.custom_minimum_size = Vector2(46, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l)

	var pips := PipBar.new()
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	pips.setup(value * 100.0, 0.0, 100.0, Color(0.48, 0.36, 0.66))

	var r := label(right, 10, TEXT if value > 0.55 else TEXT_DIM)
	r.custom_minimum_size = Vector2(46, 0)
	row.add_child(r)


## 読み取り専用の値表示。積み木を並べて見せる。
static func bar_row(parent: Node, name_text: String, value: float,
		vmin: float, vmax: float, col: Color, idle: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	parent.add_child(row)
	var nm := label(name_text, 11, TEXT_DIM if idle else TEXT)
	nm.custom_minimum_size = Vector2(62, 0)
	row.add_child(nm)
	var pips := PipBar.new()
	if idle:
		pips.modulate = Color(1, 1, 1, 0.5)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	pips.setup(value, vmin, vmax, col)


static func button(parent: Node, text: String, on_press: Callable, size: int = 11) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, ROW_H)
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


## 「＋ なにか」の控えめな追加ボタン。幅いっぱいに伸ばさない。
static func add_button(parent: Node, text: String, on_press: Callable) -> Button:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var b := button(row, text, on_press, 11)
	b.custom_minimum_size = Vector2(0, ROW_H - 3)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


## タブの中身を一枚の紙として見せる。札（タブ）と紙が繋がって、
## めくって切り替えている感じになる。
static func page_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.89)
	sb.set_corner_radius_all(8)
	sb.corner_radius_top_left = 2
	sb.content_margin_left = PAD_S
	sb.content_margin_right = PAD_S
	sb.content_margin_top = PAD_S
	sb.content_margin_bottom = PAD_S
	sb.border_color = Color(0.46, 0.33, 0.21, 0.30)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.10)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


## 一覧の行と行を分ける細い線
static func hairline(parent: Node) -> void:
	var l := ColorRect.new()
	l.color = Color(0.46, 0.33, 0.21, 0.13)
	l.custom_minimum_size = Vector2(0, 1)
	parent.add_child(l)


## 縦スクロールする中身を包み、スクロールバーとの余白を作る。
static func scroll_body(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_right", SCROLL_GUTTER)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", GAP_S)
	pad.add_child(box)
	return box


## 浮いている窓の見出し。題名と閉じるボタンを揃える。
static func window_header(parent: Node, title: String, on_close: Callable,
		col: Color = HEAD) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	row.add_child(label(title, 14, col))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	icon_button(row, "✕", "閉じる", on_close, 26, ROW_H, 13)
	return row


## アイコンだけのボタン。何のボタンかはツールチップで補う。
static func icon_button(parent: Node, glyph: String, tip: String, on_press: Callable,
		w: int = 28, h: int = ROW_H, size: int = 15) -> Button:
	var b := Button.new()
	b.text = glyph
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(w, h)
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


## いま選ばれている／開いていることが見えるボタン。
## 押せるだけで状態が見えないと、速度も窓の開閉も確かめようがない。
static func toggle_button(parent: Node, text: String, tip: String, on_press: Callable,
		w: int = 34, size: int = 11) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(w, ROW_H)
	var on := StyleBoxFlat.new()
	on.bg_color = WOOD
	on.set_corner_radius_all(6)
	on.content_margin_left = 8
	on.content_margin_right = 8
	on.content_margin_top = 4
	on.content_margin_bottom = 4
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_pressed_color", Color(0.97, 0.94, 0.87))
	b.add_theme_color_override("font_hover_pressed_color", Color(1, 0.99, 0.95))
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


## 神が押す、いちばん強いボタン。画面に1つだけ置く。
static func accent_button(parent: Node, text: String, on_press: Callable,
		size: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, ROW_H + 6)
	var mk := func(a: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(ACCENT.r * a, ACCENT.g * a, ACCENT.b * a)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		return sb
	b.add_theme_stylebox_override("normal", mk.call(0.86))
	b.add_theme_stylebox_override("hover", mk.call(1.0))
	b.add_theme_stylebox_override("pressed", mk.call(0.72))
	b.add_theme_color_override("font_color", Color(0.99, 0.96, 0.90))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.99, 0.96, 0.90))
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


## 削除モードの切り替え。× は「閉じる」に見えるのでゴミ箱を描く。
static func trash_toggle(parent: Node, tip: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(30, ROW_H)
	parent.add_child(b)
	var icon := TrashIcon.new()
	b.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return b


static func line_edit_row(parent: Node, name_text: String, value: String,
		on_change: Callable, name_width: int = 62) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_INLINE)
	parent.add_child(row)
	var nm := label(name_text, 11, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)
	var le := LineEdit.new()
	le.text = value
	le.add_theme_font_size_override("font_size", 11)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(80, ROW_H)
	row.add_child(le)
	le.text_changed.connect(on_change)
	return le


## 選択肢のラジオ印は要らないので、項目をアイコンなしのチェック表示にする。
static func dropdown(keys: Array, labels: Array, current: String) -> OptionButton:
	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", 11)
	opt.custom_minimum_size = Vector2(90, ROW_H)
	opt.fit_to_longest_item = false
	var pop := opt.get_popup()
	pop.add_theme_font_size_override("font_size", 11)
	pop.hide_on_checkable_item_selection = true
	for i in range(keys.size()):
		opt.add_item(String(labels[i]), i)
		pop.set_item_as_radio_checkable(i, false)
		pop.set_item_as_checkable(i, false)
		if String(keys[i]) == current:
			opt.select(i)
	return opt


## keys と labels は同じ長さ。選ばれた key が on_change に渡る。
static func option_row(parent: Node, name_text: String, keys: Array, labels: Array,
		current: String, on_change: Callable, name_width: int = 62) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_INLINE)
	parent.add_child(row)
	var nm := label(name_text, 11, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)
	var opt := dropdown(keys, labels, current)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(opt)
	opt.item_selected.connect(func(i: int) -> void: on_change.call(String(keys[i])))
	return opt


static func check_row(parent: Node, name_text: String, value: bool, on_toggle: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = name_text
	cb.button_pressed = value
	cb.add_theme_font_size_override("font_size", 11)
	parent.add_child(cb)
	cb.toggled.connect(on_toggle)
	return cb


## 下限と上限を1本で決める行
static func range_row(parent: Node, name_text: String, vmin: float, vmax: float,
		lo: float, hi: float, step: float, on_change: Callable, col: Color,
		name_width: int = 62) -> RangeSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_INLINE)
	parent.add_child(row)
	var nm := label(name_text, 11, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)

	var val := label("%d〜%d" % [int(lo), int(hi)], 11, TEXT_DIM)
	val.custom_minimum_size = Vector2(58, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

	var rs := RangeSlider.new()
	rs.custom_minimum_size = Vector2(112, ROW_H)
	row.add_child(rs)
	rs.setup(vmin, vmax, lo, hi, step, col)

	rs.changed.connect(func(l: float, h: float) -> void:
		val.text = "%d〜%d" % [int(l), int(h)]
		on_change.call(l, h)
	)
	return rs


## ラベル + −/数/+ の行。on_change(new_count) が呼ばれる。
static func stepper_row(parent: Node, name_text: String, value: int, vmax: int,
		on_change: Callable, name_width: int = 62) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_S)
	parent.add_child(row)
	var nm := label(name_text, 11, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)

	var minus := Button.new()
	minus.text = "−"
	minus.add_theme_font_size_override("font_size", 11)
	minus.custom_minimum_size = Vector2(24, 22)
	row.add_child(minus)

	var val := label(str(value), 11, TEXT if value > 0 else TEXT_DIM)
	val.custom_minimum_size = Vector2(24, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)

	var plus := Button.new()
	plus.text = "＋"
	plus.add_theme_font_size_override("font_size", 11)
	plus.custom_minimum_size = Vector2(24, 22)
	row.add_child(plus)

	var count := [value]
	var apply := func(d: int) -> void:
		count[0] = clampi(count[0] + d, 0, vmax)
		val.text = str(count[0])
		val.add_theme_color_override("font_color", TEXT if count[0] > 0 else TEXT_DIM)
		on_change.call(count[0])
	minus.pressed.connect(func() -> void: apply.call(-1))
	plus.pressed.connect(func() -> void: apply.call(1))


## 折りたたみ。中身を入れる VBoxContainer を返す。
static func collapsible(parent: Node, title: String, open: bool = false) -> VBoxContainer:
	var head := Button.new()
	head.text = ("▼ " if open else "▶ ") + title
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_theme_font_size_override("font_size", 11)
	head.custom_minimum_size = Vector2(0, 22)
	parent.add_child(head)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	body.visible = open
	parent.add_child(body)
	head.pressed.connect(func() -> void:
		body.visible = not body.visible
		head.text = ("▼ " if body.visible else "▶ ") + title
	)
	return body


static func spacer(parent: Node, h: int = 6) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	parent.add_child(c)


static func _fmt(x: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(x))
	if step >= 0.1:
		return "%.1f" % x
	return "%.2f" % x
