extends PanelContainer
## オプション。世界の中の話ではなく、この遊びそのものへの操作を置く紙。
##
## いまここにあるのは出口だけ。世界を見る窓（村人・間柄・言葉）に混ぜると、
## 見るものと壊すものが同じ紙に乗ってしまう。

signal closed
signal end_requested


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP_S)
	UIKit.paper_sheet(self).add_child(root)

	UIKit.window_header(root, "オプション", _close)

	# 箱に入れない。ボタン1つを角丸の面で囲うと、押せるものが二重に見える。
	# 何が失われるかは、押したあとの一枚（`confirm_popup`）が言う。
	var b := UIKit.button(root, "この世界を終える", _on_end)
	b.custom_minimum_size = Vector2(0, 38)


func _close() -> void:
	closed.emit()


func _on_end() -> void:
	end_requested.emit()
