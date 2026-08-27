class_name Seal
extends Control
## 世界が始まる合図に、紙へ押される封蝋。
##
## 定義を確定させる操作は取り返しがつかない。確認のダイアログを挟むと
## 「間違えないか」の話になるが、ここで出したいのは重さのほうなので、一拍だけ置く。

var pop := 0.0:
	set(v):
		pop = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if pop <= 0.0:
		return
	var c := size * 0.5
	# 押しつけられる瞬間だけ大きく、すぐ紙に沈む
	var r: float = 46.0 * lerpf(1.7, 1.0, pop)
	var a: float = clampf(pop * 1.6, 0.0, 1.0)
	draw_circle(c, r * 1.10, Color(0.52, 0.14, 0.12, 0.22 * a))
	draw_circle(c, r, Color(0.72, 0.20, 0.17, 0.92 * a))
	draw_arc(c, r * 0.74, 0.0, TAU, 40, Color(0.95, 0.86, 0.80, 0.55 * a), 2.0)
	# 中の印は、この世界の地面と同じひし形
	var d := PackedVector2Array([
		c + Vector2(0, -r * 0.40), c + Vector2(r * 0.52, 0),
		c + Vector2(0, r * 0.40), c + Vector2(-r * 0.52, 0),
	])
	draw_colored_polygon(Iso.rounded(d, 5.0), Color(0.95, 0.88, 0.82, 0.80 * a))
