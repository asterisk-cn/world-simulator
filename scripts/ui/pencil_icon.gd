class_name PencilIcon
extends Control
## 「ここは書き直せる」の印。
##
## 罫線の入力欄を一覧に並べていたが、**書き込める場所だと伝わらなかった**。
## 鉛筆を名前の直後に置く。押すと紙が1枚浮いて、そこに書く（`write_popup.gd`）。
##
## ✎ の字ではなく描いた鉛筆。glyph は書体によって太さも角度も変わるので、
## ゴミ箱（`trash_icon.gd`）や目（`eye_button.gd`）と並べたときに族が揃わない。

## 色は作る側（`UIKit.pencil_button`）が決める。
## ここから UIKit を参照すると輪になる（`PipBar` と同じ理由）。
var tint := Color(0.46, 0.41, 0.34)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 14px の絵なので、段は3つしか作れない——**先・軸・尻**。
## それぞれ 5px 前後を確保しないと、斜めの塊にしか見えない。
## 先は長く尖らせ、尻は間を1つ空けて薄く置く。その空きが口金の代わりになる。
func _draw() -> void:
	var c := size * 0.5
	# **先は左下へ向ける。** 右手に持った鉛筆が紙に触れている向きで、
	# 尻が右上に来る。逆に向けると、置いてある鉛筆に見えて「書く」が出ない。
	# 立てると万年筆に見える。
	var dir := Vector2(-0.707, 0.707)
	var side := Vector2(dir.y, -dir.x)
	var half := 8.5
	var w := 2.4
	var point := 5.0   ## 削った先の長さ
	var butt := 3.6    ## 尻の長さ
	var nick := 1.2    ## 軸と尻のあいだの空き

	var tip := c + dir * half
	var tail := c - dir * half
	var shoulder := tip - dir * point
	var waist := tail + dir * butt + dir * nick

	# 軸。先の付け根から、尻の手前まで
	draw_colored_polygon(PackedVector2Array([
		shoulder + side * w, shoulder - side * w,
		waist - side * w, waist + side * w,
	]), tint)
	# 削った先。軸の幅から一点へ絞る
	draw_colored_polygon(PackedVector2Array([
		tip, shoulder - side * w, shoulder + side * w,
	]), tint)
	# 尻。間を空けて薄く置く。ここが無いと、ただの棒に見える
	draw_colored_polygon(PackedVector2Array([
		tail + dir * butt + side * w, tail + dir * butt - side * w,
		tail - side * w, tail + side * w,
	]), Color(tint.r, tint.g, tint.b, tint.a * 0.5))
