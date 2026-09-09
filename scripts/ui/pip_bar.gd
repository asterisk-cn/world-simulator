class_name PipBar
extends Control
## パラメータの値を、積み木を並べて見せる。
##
## 連続したバーはグラフに見えて、世界の積み木と馴染まない。
## 世界と同じ角丸のブロックを並べる形にすると、数字ではなく「持ち物」に見える。
##
## 下限が負のパラメータは真ん中から左右へ伸びる。
## どちら側にどれだけ振れているかが、印を足さなくても分かる。

const PIPS := 10
const GAP := 3.0
const EMPTY := Color(0.30, 0.22, 0.14, 0.13)

var value := 0.0
var vmin := 0.0
var vmax := 100.0
var tint := Color(0.6, 0.6, 0.6)

## 真ん中より下（負の側）を塗る色。間柄は「どちらへ」の話なので、
## 好感の裏の嫌悪、敬意の裏の侮りが同じ色だと、向きが読めない。
## 下限が負でないパラメータでは使われない。
var neg := Color(0.74, 0.26, 0.22)


## 大きさは作る側（`UIKit.bar_row` / `pole_row`）が決める。
## ここから UIKit を参照すると UIKit → PipBar → UIKit の輪ができて、
## UIKit に関数を1つ足すたびにエディタが古い UIKit を見たまま止まる。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_value: float, p_min: float, p_max: float, p_tint: Color) -> void:
	value = p_value
	vmin = p_min
	vmax = p_max
	tint = p_tint
	queue_redraw()


func _draw() -> void:
	var span: float = maxf(vmax - vmin, 0.001)
	var t: float = clampf((value - vmin) / span, 0.0, 1.0)
	# 下限が負なら 0 の位置が起点。そうでなければ左端から。
	var origin: float = clampf((0.0 - vmin) / span, 0.0, 1.0) if vmin < 0.0 else 0.0
	var lo: float = minf(origin, t)
	var hi: float = maxf(origin, t)

	# 積み木の数だけでなく、色の濃さでも振れ幅を語らせる。
	# 数だけだと、たとえば緑の「孤独」がたくさん並んでいても健やかに見えてしまう。
	var reach: float = maxf(maxf(origin, 1.0 - origin), 0.001)
	var amount: float = clampf(absf(t - origin) / reach, 0.0, 1.0)
	var base := neg if (vmin < 0.0 and t < origin) else tint
	var fill := base.lightened(0.34 * (1.0 - amount)).darkened(0.22 * amount)

	var w := (size.x - GAP * float(PIPS - 1)) / float(PIPS)
	for i in range(PIPS):
		var c := (float(i) + 0.5) / float(PIPS)
		var on := c >= lo and c <= hi
		var x := float(i) * (w + GAP)
		draw_colored_polygon(Iso.rounded(PackedVector2Array([
			Vector2(x, 0), Vector2(x + w, 0),
			Vector2(x + w, size.y), Vector2(x, size.y),
		]), 2.0), fill if on else EMPTY)
