class_name WritePopup
extends Control
## 言葉を書く一枚。世界の上に薄い幕を張って、紙を1枚だけ置く。
##
## 一覧の行に罫線の入力欄を並べていたが、**書き込める場所だと伝わらなかった**。
## 行は読むための形にして、書くときだけこの紙を出す。
## 神は紙に書くのだから、書く場所も紙であるべきで、行の中の細い罫ではない。
##
## `confirm_popup.gd` と同じ作り（幕・中央の紙・Esc でやめる）。
## あちらは「取り返しがつかないことを訊く」、こちらは「言葉を受け取る」。
##
## 欄は何本でも置ける（村人は 名前 と 一言 を一緒に書く）。
## **空のまま決めたら、元のまま。** 消したいのではなく、書かなかっただけ。

signal submitted(values: PackedStringArray)
signal canceled

## 紙の幅。**飛んでいく紙（`paper_fly.gd`）が放たれる大きさの元**なので、
## ここを変えると飛び始めの大きさも一緒に動く。神が書いていた紙が
## そのまま飛んでいくのだから、二つが別々の値を持っていてはいけない
const SHEET_W := 560.0

var _title := ""
var _fields: Array = []      ## [{label, text, placeholder}]
var _ok_text := "決める"
var _accent := false

var _edits: Array = []
var _paper: Control = null


## fields は [{"label": 欄の名前, "text": いまの言葉, "placeholder": 空のときの案内}]
func setup(title: String, fields: Array, ok_text: String = "決める",
		accent: bool = false) -> void:
	_title = title
	_fields = fields
	_ok_text = ok_text
	_accent = accent


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `CanvasLayer` は Control ではないので、Window に置いたテーマが中へ伝わらない。
	# あて忘れると、書く欄とボタンだけがエンジン既定の灰色の箱になる（DESIGN.md §9）
	theme = SimConfig.ui_theme

	var veil := ColorRect.new()
	veil.color = Color(0.18, 0.13, 0.09, 0.42)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)

	# 紙の丈は中身が決める。枠を先に決めると、下に用のない余白が残る
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var paper := UIKit.panel()
	paper.custom_minimum_size = Vector2(SHEET_W, 0)
	center.add_child(paper)
	_paper = paper

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.GAP)
	UIKit.body_of(paper).add_child(box)

	box.add_child(UIKit.label(_title, UIKit.FS_HEAD, UIKit.HEAD))

	for f in _fields:
		var field: Dictionary = f
		var name_text := String(field.get("label", ""))
		if name_text != "":
			box.add_child(UIKit.label(name_text, UIKit.FS_NOTE, UIKit.TEXT_DIM))
		var le := LineEdit.new()
		le.text = String(field.get("text", ""))
		le.placeholder_text = String(field.get("placeholder", ""))
		# 書く場所なので、行の中の欄より一段大きい字で受ける
		le.add_theme_font_size_override("font_size", UIKit.FS_HEAD)
		le.custom_minimum_size = Vector2(0, UIKit.ROW_H + UIKit.GAP)
		box.add_child(le)
		le.text_submitted.connect(func(_t: String) -> void: _on_ok())
		_edits.append(le)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.GAP)
	box.add_child(row)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var no := UIKit.button(row, "やめる", _on_no)
	no.custom_minimum_size = Vector2(120, 38)
	# 橙は神が押すいちばん強い1か所。書くだけの紙では使わない
	var ok: Button
	if _accent:
		ok = UIKit.accent_button(row, _ok_text, _on_ok)
	else:
		ok = UIKit.button(row, _ok_text, _on_ok)
	ok.custom_minimum_size = Vector2(120, 38)

	# 開いたらすぐ書けるように、最初の欄に指を置く
	if not _edits.is_empty():
		var first: LineEdit = _edits[0]
		first.grab_focus.call_deferred()
		first.select_all.call_deferred()


## **書いていた紙そのものを渡す。** 別の紙を描いて飛ばすと、決めた瞬間に
## フォームが消えて別の形の紙が現れる（貼り紙の縦横比は 1.44:1 固定なので、
## 幅を合わせても丈が2倍になる）。書いた紙が飛ぶのだから、その紙を渡す。
##
## `submitted` は `queue_free` の前に出しているので、受けた側がここで
## 取り上げれば、窓と一緒に消えることはない。取り上げなければ普通に消える。
func take_sheet() -> Control:
	if _paper == null:
		return null
	var sheet := _paper
	_paper = null
	# 飛ぶあいだ触れる場所ではない。欄の指も外す（外さないと桁が残る）
	for e in _edits:
		(e as LineEdit).release_focus()
	_no_touch(sheet)
	# 紙の親は真ん中に寄せる入れ物で、この窓そのものではない
	sheet.get_parent().remove_child(sheet)
	# **`CanvasLayer` と同じ罠。** ここを渡すと親が Node2D になるので、
	# 窓に置いたテーマが中へ伝わらない。あて忘れると、飛んでいく紙の中の
	# 欄とボタンだけがエンジン既定の灰色の箱になる（DESIGN.md §9）
	sheet.theme = SimConfig.ui_theme
	sheet.size = sheet.size
	return sheet


static func _no_touch(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_no_touch(c)


func _on_ok() -> void:
	var out := PackedStringArray()
	for i in range(_edits.size()):
		var le: LineEdit = _edits[i]
		var typed := le.text.strip_edges()
		# 空のまま決めたら元のまま。消したいのではなく、書かなかっただけ
		out.append(typed if typed != "" else String(_fields[i].get("text", "")))
	submitted.emit(out)
	queue_free()


func _on_no() -> void:
	canceled.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			accept_event()
			_on_no()
