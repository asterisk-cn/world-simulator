extends Control
## 取り返しがつかないことを訊く一枚。世界の上に薄い幕を張って、紙を1枚だけ置く。
##
## エンジン既定のダイアログは使わない。OSの窓が出ると、そこだけ紙の世界から抜ける。
## 幕は後ろへの操作も止める。訊いている最中に世界を触れると、問いが宙に浮く。

signal confirmed
signal canceled

var _title := ""
var _note := ""
var _ok_text := "終了する"
var _no_text := "やめる"


func setup(title: String, note: String, ok_text: String, no_text: String = "やめる") -> void:
	_title = title
	_note = note
	_ok_text = ok_text
	_no_text = no_text


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

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
	paper.custom_minimum_size = Vector2(440, 0)
	center.add_child(paper)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.GAP)
	UIKit.body_of(paper).add_child(box)

	var t := UIKit.label(_title, UIKit.FS_HEAD, UIKit.HEAD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	if _note != "":
		var n := UIKit.wrapped(box, _note)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.GAP)
	box.add_child(row)

	var no := UIKit.button(row, _no_text, _on_no)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.custom_minimum_size = Vector2(0, 38)
	var ok := UIKit.accent_button(row, _ok_text, _on_ok)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.custom_minimum_size = Vector2(0, 38)
	# 既定は「やめる」側。開いた瞬間に Enter で終わってしまわないように
	no.grab_focus.call_deferred()


func _on_ok() -> void:
	confirmed.emit()
	queue_free()


func _on_no() -> void:
	canceled.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			accept_event()
			_on_no()
