extends PanelContainer
## オプション。世界の中の話ではなく、この遊びそのものへの操作を置く紙。
##
## 世界を見る窓（村人・関係・ことば）に混ぜると、見るものと壊すものが同じ紙に乗る。
##
## ここには2つある。**判断を担うAI**と、**出口**。
## 世界の目盛り（1日の長さ・歩く速さ…）は置かない。始まる前に設計図の「詳細」で
## 決めたら、それきり。途中で回せると、村人が覚えた昼の長さや道のりと食い違う。

signal closed
signal end_requested



func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP_S)
	UIKit.paper_sheet(self).add_child(root)

	UIKit.window_header(root, "オプション", _close)

	# **AI**。世界の語彙ではなく、この遊びの側の話なのでここに置く。
	# 開始前は設計図の「詳細」で決める（同じ値の同じ面）。
	# 「あいて」とは呼ばない——この世界では、あいては村人から見た他の村人
	UIKit.heading(root, "AI",
		"村人の判断を担うもの。次に何をするか、それを何と呼ぶかはここが答える。\n"
		+ "使えるものが並ぶ。世界の語彙ではないので、始まったあとも替えられる。")
	var who_rows := UIKit.rows(root)
	UIKit.row_pad(who_rows).add_child(WhoPicker.new())

	# 出口はAIの行から離す。同じ紙でも、読むものと壊すものは別の段
	UIKit.spacer(root, UIKit.PAD_L)
	# 箱に入れない。ボタン1つを角丸の面で囲うと、押せるものが二重に見える。
	# 何が失われるかは、押したあとの一枚（`confirm_popup`）が言う。
	var b := UIKit.button(root, "この世界を終える", _on_end)
	b.custom_minimum_size = Vector2(0, 38)



func _close() -> void:
	closed.emit()


func _on_end() -> void:
	end_requested.emit()
