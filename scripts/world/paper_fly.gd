class_name PaperFly
extends Node2D
## 神が放った紙が、世界の掲示板まで飛んでいく。
##
## 押した瞬間に一覧へ行が増えるだけだと、神が紙を落とした感じにならない。
## 干渉は世界の上で起こす（頭上の吹き出しと同じ考え方）。

signal landed

const DUR := 0.85

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var _t := 0.0


func setup(p_from: Vector2, p_to: Vector2) -> void:
	from = p_from
	to = p_to
	position = from
	z_index = 900


func _process(delta: float) -> void:
	_t = minf(_t + delta / DUR, 1.0)
	# 放物線。まっすぐ飛ぶと「値が移動した」に見えて、紙が舞う感じにならない
	var lift := from.lerp(to, 0.5) + Vector2(0, -minf(from.distance_to(to) * 0.32, 190.0))
	var a := from.lerp(lift, _t)
	var b := lift.lerp(to, _t)
	position = a.lerp(b, _t)
	rotation = sin(_t * PI * 2.4) * 0.30 * (1.0 - _t)
	queue_redraw()
	if _t >= 1.0:
		set_process(false)
		landed.emit()
		queue_free()


func _draw() -> void:
	# 世界にある貼り紙と同じ姿。小さくなりながら板に吸い込まれる
	var s: float = lerpf(1.5, 0.85, _t)
	var paper := Color(0.99, 0.97, 0.92)
	ItemIcon.blk(self, Vector2.ZERO, 5.0 * s, 6.4 * s, Color(0.86, 0.60, 0.20))
	ItemIcon.blk(self, Vector2.ZERO, 4.2 * s, 5.6 * s, paper)
	for i in range(3):
		var y := (-2.4 + float(i) * 2.4) * s
		draw_line(Vector2(-2.6 * s, y), Vector2(2.6 * s, y),
			Color(0.46, 0.41, 0.34, 0.75), 1.0)
