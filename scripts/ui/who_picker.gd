class_name WhoPicker
extends HBoxContainer
## 判断を担うAIを選ぶ行。**「あいて」とは呼ばない**——
## この世界で「あいて」は村人から見た他の村人（設計図の章名）で、別のもの。**世界の語彙ではなく、この機械の話**なので、
## 目盛りと同じ扱いにする——開始前は設計図の「詳細」、始まったあとはオプション。
## 同じ値の同じ面が2か所に出る（DESIGN.md §9）。
##
## 選ぶ箱は**紙**にする。OSの選択窓を出すと、そこだけ別の世界の部品になる。
## 中身は名前を並べただけの行で、いま使っているものだけ見出しの色。

const LIST_W := 240

var _btn: Button = null
var _box: PopupPanel = null
var _note: Label = null
var _tick := 0.0


func _init() -> void:
	add_theme_constant_override("separation", UIKit.GAP_S)


func _ready() -> void:
	add_child(UIKit.label("判断を担うもの", UIKit.FS_BODY, UIKit.TEXT))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(gap)

	_btn = UIKit.button(self, AI.here_name(), _open)
	_btn.custom_minimum_size = Vector2(210, UIKit.ROW_H - UIKit.HAIR)

	# **何人ぶん流れるかは算数。** 村人の数は神のものなので、決めるのは神。
	# ここは事実だけを出す（いまの速さと、それで足りる人数）
	_note = UIKit.label("", UIKit.FS_NOTE, UIKit.TEXT_DIM)
	add_child(_note)

	_box = PopupPanel.new()
	_box.add_theme_stylebox_override("panel", UIKit.panel_style(UIKit.PAGE, 10, 0))
	add_child(_box)

	AI.choices_changed.connect(_rebuild)
	AI.refresh_choices()
	_rebuild()


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	if not is_instance_valid(_note):
		return
	if AI.down():
		_note.text = "返事が来ない"
		return
	if not AI.available():
		_note.text = ""
		return
	var r := AI.rate()
	if r <= 0.0:
		_note.text = ""
		return
	# 一人が次の手を決めるまでにかかる間（`ACT_SPAN`）で割ると、何人ぶんか
	_note.text = "毎秒 %.1f 件（%d人ぶん）" % [r, int(round(r * ACT_SPAN))]


## 1手にかかるおおよその時間（秒）。歩きを含めた実測から
const ACT_SPAN := 3.2


func _open() -> void:
	_rebuild()
	var at := _btn.get_screen_position() + Vector2(0, _btn.size.y + UIKit.HAIR)
	_box.popup(Rect2i(Vector2i(at), Vector2i(LIST_W, 0)))


func _rebuild() -> void:
	if _btn == null:
		return
	_btn.text = AI.here_name()
	if _box == null:
		return
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, UIKit.PAD_S)
	_box.add_child(pad)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	pad.add_child(list)

	var here := AI.here()
	var all := AI.choices()
	for i in range(all.size()):
		if i > 0:
			UIKit.hairline(list)
		var b := Button.new()
		b.text = String(all[i]["name"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_font_size_override("font_size", UIKit.FS_BODY)
		b.add_theme_color_override("font_color",
			UIKit.HEAD if i == here else UIKit.TEXT)
		b.custom_minimum_size = Vector2(LIST_W - UIKit.PAD_S * 2, UIKit.ROW_H)
		list.add_child(b)
		b.pressed.connect(_choose.bind(i))


func _choose(i: int) -> void:
	AI.use(i)
	_box.hide()
	_rebuild()
