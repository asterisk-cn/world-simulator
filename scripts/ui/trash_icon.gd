class_name TrashIcon
extends Control
## 削除モードの目印。× だと「閉じる」に見えてしまうので、ゴミ箱を描く。
## 角は世界のブロックと同じ Iso.rounded で丸める。

## 色は作る側（`UIKit.trash_toggle`）が決める。
## ここから UIKit を参照すると輪になる（`PipBar` と同じ理由）。
var tint := Color(0.20, 0.17, 0.13)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var w := 10.0
	var h := 11.0

	# 取っ手
	draw_colored_polygon(Iso.rounded(_quad(
		c.x - 2.4, c.y - h * 0.62, 4.8, h * 0.16), 0.8), tint)
	# 蓋
	draw_colored_polygon(Iso.rounded(_quad(
		c.x - w * 0.5, c.y - h * 0.46, w, h * 0.18), 1.2), tint)
	# 本体（下すぼまり）
	draw_colored_polygon(Iso.rounded(PackedVector2Array([
		Vector2(c.x - w * 0.40, c.y - h * 0.22),
		Vector2(c.x + w * 0.40, c.y - h * 0.22),
		Vector2(c.x + w * 0.30, c.y + h * 0.52),
		Vector2(c.x - w * 0.30, c.y + h * 0.52),
	]), 1.6), tint)


func _quad(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)
	])
