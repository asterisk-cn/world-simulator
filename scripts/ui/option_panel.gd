extends PanelContainer
## オプション。世界の中の話ではなく、この遊びそのものへの操作を置く紙。
##
## 世界を見る窓（村人・関係・ことば）に混ぜると、見るものと壊すものが同じ紙に乗る。
##
## ここには2つある。**世界の目盛り**と、**出口**。
## 目盛り（1日の長さ・歩く速さ・考え直す間合い…）は語彙ではないので、
## 始まったあとも触れる——上部バーの ▶▶ と同じ、神が世界の外から回すつまみ。
## 開始前は設計図の「世界」タブで決め、始まったあとはここから触る（同じ値の同じ面）。

signal closed
signal end_requested


func _ready() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP_S)
	UIKit.paper_sheet(self).add_child(root)

	UIKit.window_header(root, "オプション", _close)

	# ここでは畳まない。オプションを開いたのは、たいていこの目盛りのため
	UIKit.heading(root, "詳細",
		"世界そのものの目盛り。語彙ではないので、始まったあとも触れる。\n"
		+ "つまみは10段で、積み木の切れ目がそのまま値になる。")
	var rows := UIKit.rows(root)
	var first := true
	for k in SimConfig.PARAM_DEF:
		var key := String(k)
		var d: Array = SimConfig.PARAM_DEF[key]
		if not first:
			UIKit.hairline(rows)
		first = false
		UIKit.slider_row(UIKit.row_pad(rows), String(d[3]), SimConfig.p(key),
			float(d[1]), float(d[2]), SimConfig.step_of(key),
			func(x: float) -> void: SimConfig.set_param(key, x),
			UIKit.WOOD, 150, SimConfig.text_of.bind(key))

	# 出口は目盛りから離す。同じ紙でも、読むものと壊すものは別の段
	UIKit.spacer(root, UIKit.PAD_L)
	# 箱に入れない。ボタン1つを角丸の面で囲うと、押せるものが二重に見える。
	# 何が失われるかは、押したあとの一枚（`confirm_popup`）が言う。
	var b := UIKit.button(root, "この世界を終える", _on_end)
	b.custom_minimum_size = Vector2(0, 38)



func _close() -> void:
	closed.emit()


func _on_end() -> void:
	end_requested.emit()
