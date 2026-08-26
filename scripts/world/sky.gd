extends CanvasLayer
## 島の外側。時刻に連れて色が変わる空。
##
## ここが動かない中間グレーだと、島が「エディタのビューポートに置かれた
## 3Dオブジェクト」に見えてしまう。世界の外側も世界の一部として扱う。
##
## カメラに追従しない、画面に貼りついた背景なので CanvasLayer に置く。

const DAY_TOP := Color(0.50, 0.71, 0.87)
const DAY_BOTTOM := Color(0.73, 0.84, 0.78)
const NIGHT_TOP := Color(0.07, 0.10, 0.22)
const NIGHT_BOTTOM := Color(0.18, 0.22, 0.38)

var _canvas: Control
var _lit := -1.0


func _ready() -> void:
	layer = -100
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_paint)
	add_child(_canvas)


func _process(_delta: float) -> void:
	var d := SimClock.darkness()
	if absf(d - _lit) > 0.01:
		_lit = d
		_canvas.queue_redraw()


func _paint() -> void:
	var vp := _canvas.size
	var top := DAY_TOP.lerp(NIGHT_TOP, _lit)
	var bottom := DAY_BOTTOM.lerp(NIGHT_BOTTOM, _lit)
	# 上から下へのゆるい階調。帯で塗って継ぎ目を目立たせない。
	var bands := 28
	for i in range(bands):
		var t0 := float(i) / float(bands)
		var t1 := float(i + 1) / float(bands)
		_canvas.draw_rect(Rect2(0, vp.y * t0, vp.x, vp.y * (t1 - t0) + 1.0),
			top.lerp(bottom, t0))
