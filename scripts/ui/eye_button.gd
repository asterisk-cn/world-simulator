class_name EyeButton
extends Button
## 「この人を見る」ボタン。文言だと行に並んだとき目立ちすぎるので、目を描く。

func _ready() -> void:
	custom_minimum_size = Vector2(28, UIKit.ROW_H - 3)
	var icon := _Eye.new()
	add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


class _Eye extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var ink := UIKit.TEXT
		# まぶた
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		for i in range(13):
			var t := float(i) / 12.0
			var x := -7.0 + t * 14.0
			var y := -sin(t * PI) * 4.2
			top.append(c + Vector2(x, y))
			bottom.append(c + Vector2(x, -y))
		draw_polyline(top, ink, 1.4)
		draw_polyline(bottom, ink, 1.4)
		draw_circle(c, 2.1, ink)
