extends PanelContainer

signal closed
## 検証用の近道だけ。見て楽しむ一覧は roster_panel.gd に移した。

## 検証用に配る数。何をどれだけ使うかは本人が決めるので、「1軒ぶん」という量はもう無い。
const GIVEN := 6

var world = null

var _summary: Label
var _accum := 0.0


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP_S)
	UIKit.paper_sheet(self).add_child(root)

	UIKit.window_header(root, "デバッグ", _close)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.GAP_S)
	root.add_child(head)
	var b1 := UIKit.button(head, "持ち物を配る", _give_materials)
	b1.custom_minimum_size = Vector2(120, UIKit.ROW_H)
	var b2 := UIKit.button(head, "建てるものを1つずつ", _build_one_each)
	b2.custom_minimum_size = Vector2(178, UIKit.ROW_H)

	_summary = UIKit.label("", UIKit.FS_NOTE, UIKit.TEXT_DIM)
	root.add_child(_summary)


func _process(delta: float) -> void:
	if not visible or world == null:
		return
	_accum += delta
	if _accum < 0.3:
		return
	_accum = 0.0
	var built := {}
	for st in world.structures:
		var name_text: String = st.label()
		built[name_text] = int(built.get(name_text, 0)) + 1
	if built.is_empty():
		_summary.text = "まだ何も建っていない"
		return
	var parts: Array = []
	for k in built:
		parts.append("%s %d" % [String(k), int(built[k])])
	_summary.text = "・".join(parts)


## 検証用。全員の手を埋める。
func _give_materials() -> void:
	for v in world.villagers:
		for item in Schema.ITEMS:
			v.add_item(String(item), GIVEN)
	EventLog.notable("神が全員に持ち物を配った")


## 建った状態をすぐ見るための近道。誰のものでもないので、村の真ん中の空きに置く。
func _build_one_each() -> void:
	var center := Vector2(World.GRID_W / 2.0, World.GRID_H / 2.0)
	for b in Schema.buildings:
		var c: Vector2i = world.find_build_cell(center)
		if c.x < 0:
			continue
		world.add_structure(String(b["id"]), c)
	EventLog.notable("神が建てた")


func _close() -> void:
	closed.emit()
