class_name HemFade
extends Control
## 巻物の下端の霞み。「まだ下に続いている」を、字が薄れることで言う。
##
## **紙の地色をべた塗りで被せてはいけない。** 粒は紙自身が持っているので
## （`roll_paper.gd`）、上から無地の面を敷くと、そこだけ質感の無い明るい帯になる
## ——粒のある紙は平均 233、べた塗りは 242。霞みではなく**仕切り**に見えてしまう。
## だから霞みも、紙と同じように粒を張って塗る。
##
## 段に刻んで濃さを変える。1枚の四角では四隅しか色を持てないので、
## 上から下へ滑らかに濃くするには段が要る。

## 濃さを刻む段数。少ないと縞に見え、多いと描く数だけ増える
const BANDS := 12

## ここから下で濃くなりはじめる（0 が霞みの上端、1 が下端）。
## 以前は 0.88 から一気に濃くしていたので、細い線が1本入るだけだった
const RAMP := 0.30

var bg: Color = Color(0.95, 0.91, 0.82)

## 紙の地合い。頂点の色に掛け算で乗る
var grain: Texture2D = null

## 絵が1周する幅
var grain_px := 128.0


func setup(p_bg: Color, p_grain: Texture2D = null) -> void:
	bg = p_bg
	grain = p_grain
	if grain != null:
		grain_px = float(grain.get_width())
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ci := get_canvas_item()
	if grain != null:
		RenderingServer.canvas_item_set_default_texture_repeat(ci,
			RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	var tex := grain.get_rid() if grain != null else RID()
	for i in range(BANDS):
		var u0 := float(i) / float(BANDS)
		var u1 := float(i + 1) / float(BANDS)
		var c0 := Color(bg.r, bg.g, bg.b, smoothstep(RAMP, 1.0, u0))
		var c1 := Color(bg.r, bg.g, bg.b, smoothstep(RAMP, 1.0, u1))
		var y0 := u0 * size.y
		var y1 := u1 * size.y
		var pts := PackedVector2Array([
			Vector2(0, y0), Vector2(size.x, y0),
			Vector2(size.x, y1), Vector2(0, y1),
		])
		var cols := PackedColorArray([c0, c0, c1, c1])
		if tex.is_valid():
			var uvs := PackedVector2Array()
			for p in pts:
				uvs.append(p / grain_px)
			RenderingServer.canvas_item_add_polygon(ci, pts, cols, uvs, tex)
		else:
			RenderingServer.canvas_item_add_polygon(ci, pts, cols)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
