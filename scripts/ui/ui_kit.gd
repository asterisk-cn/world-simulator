class_name UIKit
extends RefCounted
## コードから UI を組み立てるための小さなヘルパ群。

const BG := Color(0.10, 0.11, 0.14)
const BG_SOFT := Color(0.15, 0.16, 0.20)
const INK := Color(1, 1, 1, 0.07)      ## 押せるものの下地
const INK_HOVER := Color(1, 1, 1, 0.14)
const INK_ACTIVE := Color(1, 1, 1, 0.20)
const SUNK := Color(0, 0, 0, 0.22)     ## 入力欄のくぼみ
const TEXT := Color(0.88, 0.90, 0.94)
const TEXT_DIM := Color(0.60, 0.63, 0.70)

## 日本語は英字より行が高い。入力欄やボタンをこれより低くすると文字の上下が切れる。
const ROW_H := 27

## 読み取り専用バーの太さ。場所によって変わらないよう1か所で決める。
const BAR_H := 10

## 縦スクロールする中身は、スクロールバーとこれだけ離す。
const SCROLL_GUTTER := 12

## 余白の基準。ここ以外に数字を置かない。
const PAD := 14      ## パネルの内側
const PAD_S := 10    ## パネルの中に置く小さなカードの内側
const GAP := 8       ## まとまりどうしの間
const GAP_S := 4     ## 並んだ行どうしの間


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
		th.set_stylebox("disabled", t, flat.call(Color(1, 1, 1, 0.03), 6, 8, 4))
		th.set_color("font_color", t, TEXT)
		th.set_color("font_hover_color", t, Color(1, 1, 1, 0.98))
		th.set_color("font_pressed_color", t, Color(1, 1, 1, 0.98))
		th.set_color("font_disabled_color", t, Color(1, 1, 1, 0.28))

	th.set_stylebox("normal", "LineEdit", flat.call(SUNK, 6, 8, 4))
	th.set_stylebox("focus", "LineEdit", flat.call(Color(1, 1, 1, 0.10), 6, 8, 4))
	th.set_color("font_color", "LineEdit", TEXT)
	th.set_color("font_placeholder_color", "LineEdit", Color(1, 1, 1, 0.30))
	th.set_color("caret_color", "LineEdit", TEXT)

	th.set_stylebox("panel", "PopupMenu", flat.call(BG_SOFT, 8, 6, 6))
	th.set_color("font_color", "PopupMenu", TEXT)
	th.set_color("font_hover_color", "PopupMenu", Color(1, 1, 1, 0.98))
	th.set_stylebox("hover", "PopupMenu", flat.call(INK_HOVER, 5, 6, 3))

	th.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	th.set_stylebox("tab_selected", "TabContainer", flat.call(INK_ACTIVE, 6, 12, 5))
	th.set_stylebox("tab_unselected", "TabContainer", flat.call(Color(1, 1, 1, 0.03), 6, 12, 5))
	th.set_stylebox("tab_hovered", "TabContainer", flat.call(INK_HOVER, 6, 12, 5))
	th.set_color("font_selected_color", "TabContainer", Color(1, 1, 1, 0.98))
	th.set_color("font_unselected_color", "TabContainer", TEXT_DIM)

	th.set_color("separator", "HSeparator", Color(1, 1, 1, 0.08))
	th.set_constant("separation", "HSeparator", 6)
	return th


static func panel_style(bg: Color = BG, radius: int = 10, pad: int = PAD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.border_color = Color(1, 1, 1, 0.07)
	sb.set_border_width_all(1)
	return sb


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


static func section(parent: Node, text: String, col: Color = Color(0.72, 0.78, 0.9)) -> Label:
	var l := label(text, 12, col)
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
	row.add_theme_constant_override("separation", 6)
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


## 読み取り専用のバー表示。下限が負のパラメータもあるので、
## バーの伸び方は下限から測り、数字は実際の値を出す。
static func bar_row(parent: Node, name_text: String, value: float,
		vmin: float, vmax: float, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var nm := label(name_text, 11, TEXT)
	nm.custom_minimum_size = Vector2(62, 0)
	row.add_child(nm)
	var pb := ProgressBar.new()
	pb.min_value = vmin
	pb.max_value = vmax
	pb.value = clampf(value, vmin, vmax)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(90, BAR_H)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 行の高さに引き延ばされると場所によって太さが変わるので、中央に固定する
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("background", bg)
	row.add_child(pb)


static func button(parent: Node, text: String, on_press: Callable, size: int = 11) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, ROW_H)
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


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
		col: Color = Color(0.85, 0.9, 0.98)) -> HBoxContainer:
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
	row.add_theme_constant_override("separation", 6)
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
	row.add_theme_constant_override("separation", 6)
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
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var nm := label(name_text, 11, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)

	var rs := RangeSlider.new()
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rs)
	rs.setup(vmin, vmax, lo, hi, step, col)

	var val := label("%d〜%d" % [int(lo), int(hi)], 11, TEXT_DIM)
	val.custom_minimum_size = Vector2(60, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

	rs.changed.connect(func(l: float, h: float) -> void:
		val.text = "%d〜%d" % [int(l), int(h)]
		on_change.call(l, h)
	)
	return rs


## ラベル + −/数/+ の行。on_change(new_count) が呼ばれる。
static func stepper_row(parent: Node, name_text: String, value: int, vmax: int,
		on_change: Callable, name_width: int = 62) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
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
