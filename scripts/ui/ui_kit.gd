class_name UIKit
extends RefCounted
## コードから UI を組み立てるための小さなヘルパ群。

const BG := Color(0.09, 0.10, 0.13, 0.94)
const BG_SOFT := Color(0.14, 0.15, 0.19, 0.94)
const TEXT := Color(0.88, 0.90, 0.94)
const TEXT_DIM := Color(0.60, 0.63, 0.70)

## 日本語は英字より行が高い。入力欄やボタンをこれより低くすると文字の上下が切れる。
const ROW_H := 27


static func panel(bg: Color = BG, radius: int = 8) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_color = Color(1, 1, 1, 0.07)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
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
	sp.custom_minimum_size = Vector2(0, 6)
	parent.add_child(sp)
	parent.add_child(l)
	var sep := HSeparator.new()
	parent.add_child(sep)
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
	pb.custom_minimum_size = Vector2(90, 12)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("background", bg)
	row.add_child(pb)
	var val := label("%d" % int(value), 11, TEXT_DIM)
	val.custom_minimum_size = Vector2(34, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)


static func button(parent: Node, text: String, on_press: Callable, size: int = 11) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, ROW_H)
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


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


## keys と labels は同じ長さ。選ばれた key が on_change に渡る。
static func option_row(parent: Node, name_text: String, keys: Array, labels: Array,
		current: String, on_change: Callable, name_width: int = 62) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var nm := label(name_text, 11, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)
	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", 11)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.custom_minimum_size = Vector2(90, ROW_H)
	for i in range(keys.size()):
		opt.add_item(String(labels[i]), i)
		if String(keys[i]) == current:
			opt.select(i)
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
