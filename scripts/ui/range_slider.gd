class_name RangeSlider
extends Control
## 下限と上限を1本で決めるスライダー。つまみが2つある。

signal changed(lo: float, hi: float)

var min_value := -100.0
var max_value := 100.0
var step := 1.0
var lo := 0.0
var hi := 100.0
var tint := Color(0.55, 0.75, 0.95)

var _drag := -1  ## -1 なし / 0 下限 / 1 上限


func _ready() -> void:
	custom_minimum_size = Vector2(112, UIKit.ROW_H - 6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func setup(p_min: float, p_max: float, p_lo: float, p_hi: float,
		p_step: float, p_tint: Color) -> void:
	min_value = p_min
	max_value = p_max
	lo = clampf(p_lo, p_min, p_max)
	hi = clampf(p_hi, lo, p_max)
	step = p_step
	tint = p_tint
	queue_redraw()


func _pos_of(v: float) -> float:
	var t := (v - min_value) / maxf(max_value - min_value, 0.001)
	return clampf(t, 0.0, 1.0) * size.x


func _value_at(x: float) -> float:
	var t := clampf(x / maxf(size.x, 1.0), 0.0, 1.0)
	return snappedf(min_value + t * (max_value - min_value), step)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 押した位置に近いほうのつまみを掴む
			var dl := absf(event.position.x - _pos_of(lo))
			var dh := absf(event.position.x - _pos_of(hi))
			_drag = 0 if dl <= dh else 1
			_apply(event.position.x)
		else:
			_drag = -1
	elif event is InputEventMouseMotion and _drag >= 0:
		_apply(event.position.x)


func _apply(x: float) -> void:
	var v := _value_at(x)
	if _drag == 0:
		lo = minf(v, hi)
	else:
		hi = maxf(v, lo)
	queue_redraw()
	changed.emit(lo, hi)


## 値を見せる側（PipBar）と同じ積み木で描く。
## 決める側と見る側で形が違うと、自分が決めたものが村人の中で動いている感じが出ない。
const BLOCKS := 10
const BGAP := 3.0


func _draw() -> void:
	var span: float = maxf(max_value - min_value, 0.001)
	var t0: float = (lo - min_value) / span
	var t1: float = (hi - min_value) / span
	var w := (size.x - BGAP * float(BLOCKS - 1)) / float(BLOCKS)
	for i in range(BLOCKS):
		var c := (float(i) + 0.5) / float(BLOCKS)
		var x := float(i) * (w + BGAP)
		var on := c >= t0 and c <= t1
		draw_colored_polygon(Iso.rounded(PackedVector2Array([
			Vector2(x, 0), Vector2(x + w, 0),
			Vector2(x + w, size.y), Vector2(x, size.y),
		]), 2.0), tint if on else Color(0.30, 0.22, 0.14, 0.13))

	# 0 の位置に印。これが無いと「右半分が塗られている＝値が高い」に読めてしまう
	if min_value < 0.0 and max_value > 0.0:
		var zx: float = _pos_of(0.0)
		draw_line(Vector2(zx, -1.0), Vector2(zx, size.y + 1.0),
			Color(0.30, 0.22, 0.14, 0.40), 1.0)
