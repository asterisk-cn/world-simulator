class_name RangeSlider
extends Control
## 下限と上限を1本で決めるスライダー。つまみが2つある。

signal changed(lo: float, hi: float)

const PAD := 7.0

var min_value := -100.0
var max_value := 100.0
var step := 1.0
var lo := 0.0
var hi := 100.0
var tint := Color(0.55, 0.75, 0.95)

var _drag := -1  ## -1 なし / 0 下限 / 1 上限


func _ready() -> void:
	custom_minimum_size = Vector2(90, 20)
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
	return PAD + clampf(t, 0.0, 1.0) * maxf(size.x - PAD * 2.0, 1.0)


func _value_at(x: float) -> float:
	var t := clampf((x - PAD) / maxf(size.x - PAD * 2.0, 1.0), 0.0, 1.0)
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


func _draw() -> void:
	var y := size.y * 0.5
	draw_line(Vector2(PAD, y), Vector2(size.x - PAD, y), Color(0.30, 0.22, 0.14, 0.16), 3.0)
	draw_line(Vector2(_pos_of(lo), y), Vector2(_pos_of(hi), y), tint, 3.0)
	# 0 の位置に目印
	if min_value < 0.0 and max_value > 0.0:
		var zx := _pos_of(0.0)
		draw_line(Vector2(zx, y - 5.0), Vector2(zx, y + 5.0), Color(0.30, 0.22, 0.14, 0.30), 1.0)
	# つまみは塗りつぶす。透けると溝の色が乗って掴めるものに見えない
	for x in [_pos_of(lo), _pos_of(hi)]:
		draw_circle(Vector2(x, y), 6.0, UIKit.WOOD)
		draw_circle(Vector2(x, y), 4.4, Color(0.98, 0.96, 0.90))
