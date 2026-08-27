class_name SwapButton
extends Button
## 「向きを反転」ボタン。A→B と B→A を入れ替える。
##
## 文字で置くと、間柄の見出しの中でいちばん強い要素になってしまう。
## ここで見せたいのは向きなので、向きそのものを描く。

func _ready() -> void:
	custom_minimum_size = Vector2(30, UIKit.ROW_H)
	tooltip_text = "向きを反転"
	var icon := _Arrows.new()
	add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


class _Arrows extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var ink := UIKit.TEXT
		# 上は右へ、下は左へ。2本で「入れ替える」になる
		_arrow(c + Vector2(0, -3.5), 1.0, ink)
		_arrow(c + Vector2(0, 3.5), -1.0, ink)

	func _arrow(at: Vector2, dir: float, ink: Color) -> void:
		var half := 6.5
		draw_line(at + Vector2(-half * dir, 0), at + Vector2(half * dir, 0), ink, 1.4)
		var tip := at + Vector2(half * dir, 0)
		draw_colored_polygon(PackedVector2Array([
			tip, tip + Vector2(-3.4 * dir, -2.6), tip + Vector2(-3.4 * dir, 2.6),
		]), ink)
