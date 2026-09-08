class_name RollPaper
extends StyleBox
## ロール紙から切った一枚。
##
## 角丸の箱に木の枠を付けていたので、紙ではなく**額**に見えていた。
## ロール紙なら、**ロールの幅の側はまっすぐ**で、**切り離した側だけがちぎれている**。
## 枠は持たない——紙の縁そのものが輪郭になる。
##
## 縦に引き出す紙（縦長のパネル）は上下がちぎれ、
## 横に引き出す紙（上部の帯）は左右がちぎれる（`horizontal`）。
##
## **粒は紙自身が持つ。** 四角い層を上に敷くと、ちぎれの帯には乗らず
## （層は器の「内側の矩形」に置かれ、ちぎれのぶんは余白として除かれる）、
## かといって層を紙いっぱいに広げると、ちぎれの外側——世界の上——にも粒が出る。
## 紙の形そのものに絵を張って塗る。

## ちぎれの深さ。これより深いと「破れた紙」になり、浅いと切り揃えた紙になる
const TEAR := 5.0

## ちぎれを測る間隔。細かすぎるとギザギザの飾りに見え、粗いと波打った紙になる
const STEP := 9.0

## 紙の厚みの影。落とす先は下だけ（板に貼られているのではなく、置かれている）
const SHADOW := Color(0, 0, 0, 0.22)
const SHADOW_DROP := 4.0

var bg: Color = Color(0.95, 0.91, 0.82)

## 紙の地合い。頂点の色（紙の色）に掛け算で乗る
var grain: Texture2D = null

## 絵が1周する幅。この間隔で繰り返す
var grain_px := 128.0

## 切り離した縁がどちらに来るか。false = 上下、true = 左右
var horizontal := false

## 一枚ごとにちぎれ方を変える。同じ形の紙が2枚並ぶと、印刷物に見える
var tear_seed: float = 0.0


func _init() -> void:
	tear_seed = randf() * 100.0


## ちぎれのぶんだけ字を入れない。ここを空けないと、字が縁の欠けに乗る。
func setup(p_bg: Color, pad: float, p_horizontal: bool = false,
		p_grain: Texture2D = null) -> void:
	bg = p_bg
	horizontal = p_horizontal
	grain = p_grain
	if grain != null:
		grain_px = float(grain.get_width())
	var extra := TEAR
	content_margin_left = pad + (extra if horizontal else 0.0)
	content_margin_right = pad + (extra if horizontal else 0.0)
	content_margin_top = pad + (0.0 if horizontal else extra)
	content_margin_bottom = pad + (0.0 if horizontal else extra)


## その位置でのちぎれの深さ（0〜TEAR）。毎フレーム同じ形になるよう、位置から引く
func _bite(i: float) -> float:
	var h := sin(i * 12.9898 + tear_seed * 78.233) * 43758.5453
	var a: float = h - floor(h)
	# 2つの粗さを混ぜる。1つだと等間隔の山に見える
	var h2 := sin(i * 4.1414 + tear_seed * 31.7) * 24634.6345
	var b: float = h2 - floor(h2)
	return (a * 0.65 + b * 0.35) * TEAR


## 四隅を渡して1枚塗る。絵があれば、位置から割り出した uv で張る
## （uv は 0〜1 で1周なので、位置を絵の幅で割ると繰り返しになる）。
func _quad(ci: RID, pts: PackedVector2Array, col: Color, tex: RID,
		uv_shift: float) -> void:
	var cols := PackedColorArray([col, col, col, col])
	if not tex.is_valid():
		RenderingServer.canvas_item_add_polygon(ci, pts, cols)
		return
	var uvs := PackedVector2Array()
	for pt in pts:
		uvs.append(Vector2(pt.x, pt.y - uv_shift) / grain_px)
	RenderingServer.canvas_item_add_polygon(ci, pts, cols, uvs, tex)


## ちぎれた縁を、縁に平行な四角の列で塗る。
## 1枚の多角形にするとへこみを含むので、三角に割られたときに形が壊れる。
func _band(ci: RID, a0: float, a1: float, base: float, dir: float, col: Color,
		along_x: bool, tex: RID, uv_shift: float) -> void:
	var a := a0
	var prev := _bite(a)
	while a < a1:
		var na: float = minf(a + STEP, a1)
		var nxt := _bite(na)
		var quad: PackedVector2Array
		if along_x:
			quad = PackedVector2Array([
				Vector2(a, base), Vector2(na, base),
				Vector2(na, base - nxt * dir), Vector2(a, base - prev * dir),
			])
		else:
			quad = PackedVector2Array([
				Vector2(base, a), Vector2(base, na),
				Vector2(base - nxt * dir, na), Vector2(base - prev * dir, a),
			])
		_quad(ci, quad, col, tex, uv_shift)
		prev = nxt
		a = na


## 紙の本体（ちぎれていない側でできた四角）と、ちぎれた2辺
func _paper(ci: RID, rect: Rect2, col: Color, drop: float, tex: RID) -> void:
	var x0 := rect.position.x
	var x1 := rect.end.x
	var y0 := rect.position.y + drop
	var y1 := rect.end.y + drop
	if horizontal:
		var bx0 := x0 + TEAR
		var bx1 := x1 - TEAR
		_quad(ci, PackedVector2Array([
			Vector2(bx0, y0), Vector2(bx1, y0), Vector2(bx1, y1), Vector2(bx0, y1),
		]), col, tex, drop)
		_band(ci, y0, y1, bx0, 1.0, col, false, tex, drop)
		_band(ci, y0, y1, bx1, -1.0, col, false, tex, drop)
	else:
		var by0 := y0 + TEAR
		var by1 := y1 - TEAR
		_quad(ci, PackedVector2Array([
			Vector2(x0, by0), Vector2(x1, by0), Vector2(x1, by1), Vector2(x0, by1),
		]), col, tex, drop)
		_band(ci, x0, x1, by0, 1.0, col, true, tex, drop)
		_band(ci, x0, x1, by1, -1.0, col, true, tex, drop)


func _draw(ci: RID, rect: Rect2) -> void:
	# 絵は繰り返して張る。この面の既定を繰り返しにしておく
	if grain != null:
		RenderingServer.canvas_item_set_default_texture_repeat(ci,
			RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	# 影を先に、同じ形で少し下へ。紙は置かれているので、下にだけ落ちる。
	# 影に粒は要らない
	_paper(ci, rect, SHADOW, SHADOW_DROP, RID())
	# 紙。粒は紙の色に掛け算で乗るので、ちぎれの帯にも同じように乗る。
	# **ちぎれ目に線は引かない**——断面を描くと、
	# ちぎれた縁ではなく「縁取りのある帯」に見える
	_paper(ci, rect, bg, 0.0,
		grain.get_rid() if grain != null else RID())
