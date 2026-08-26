class_name BlockSlider
extends Control
## 値を決めるつまみ。積み木を並べて、押した分だけ積む。
##
## 溝とつまみのスライダーはOSの部品に見えるうえ、
## 進行中の画面が積み木で値を見せているのに、決める側が別の形だと
## 「自分が決めたものが村人の中で動いている」という繋がりが切れる。

signal changed(value: float)

const BLOCKS := 10
const GAP := 3.0

var value := 0.0
var min_value := 0.0
var max_value := 100.0
var step := 1.0
var tint := Color(0.55, 0.42, 0.26)

var _held := false


func _ready() -> void:
	custom_minimum_size = Vector2(112, UIKit.ROW_H - 6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func setup(p_value: float, p_min: float, p_max: float, p_step: float, p_tint: Color) -> void:
	min_value = p_min
	max_value = p_max
	step = p_step
	tint = p_tint
	value = clampf(p_value, p_min, p_max)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_held = event.pressed
		if _held:
			_set_from(event.position.x)
	elif event is InputEventMouseMotion and _held:
		_set_from(event.position.x)


func _set_from(x: float) -> void:
	var t: float = clampf(x / maxf(size.x, 1.0), 0.0, 1.0)
	var v := snappedf(min_value + t * (max_value - min_value), step)
	v = clampf(v, min_value, max_value)
	if not is_equal_approx(v, value):
		value = v
		queue_redraw()
		changed.emit(value)


func _draw() -> void:
	var t: float = (value - min_value) / maxf(max_value - min_value, 0.001)
	var w := (size.x - GAP * float(BLOCKS - 1)) / float(BLOCKS)
	for i in range(BLOCKS):
		var c := (float(i) + 0.5) / float(BLOCKS)
		var x := float(i) * (w + GAP)
		draw_colored_polygon(Iso.rounded(PackedVector2Array([
			Vector2(x, 0), Vector2(x + w, 0),
			Vector2(x + w, size.y), Vector2(x, size.y),
		]), 2.0), tint if c <= t else Color(0.30, 0.22, 0.14, 0.13))
