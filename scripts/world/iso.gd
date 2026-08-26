class_name Iso
extends RefCounted
## クォータービュー（アイソメトリック）の座標変換。
## セル座標 (x, y) は床のマス目。スクリーン座標はひし形に潰した菱形グリッド。

const TILE_W := 64.0
const TILE_H := 32.0
const HALF_W := TILE_W * 0.5
const HALF_H := TILE_H * 0.5


static func cell_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF_W, (cell.x + cell.y) * HALF_H)


static func world_to_cell(p: Vector2) -> Vector2:
	return Vector2(
		(p.x / HALF_W + p.y / HALF_H) * 0.5,
		(p.y / HALF_H - p.x / HALF_W) * 0.5
	)


## そのセルの床の菱形（ローカル原点はセル中心）
static func diamond(scale_factor: float = 1.0) -> PackedVector2Array:
	var w := HALF_W * scale_factor
	var h := HALF_H * scale_factor
	return PackedVector2Array([
		Vector2(0, -h), Vector2(w, 0), Vector2(0, h), Vector2(-w, 0)
	])


## 高さ h の箱を描くための3面（上面・左面・右面）
static func box_faces(w: float, d: float, h: float) -> Array:
	var top := PackedVector2Array([
		Vector2(0, -d - h), Vector2(w, -h), Vector2(0, d - h), Vector2(-w, -h)
	])
	var left := PackedVector2Array([
		Vector2(-w, -h), Vector2(0, d - h), Vector2(0, d), Vector2(-w, 0)
	])
	var right := PackedVector2Array([
		Vector2(w, -h), Vector2(0, d - h), Vector2(0, d), Vector2(w, 0)
	])
	return [top, left, right]


# ---------------------------------------------------------------------------
# 角丸のブロック
#
# この世界のものは、地面以外すべてこれで描く。
# キャラクターも木も家も同じ手触りにするための共通の形。
# ---------------------------------------------------------------------------

const ROUND_STEPS := 4


## 多角形の角を丸める。r は角から辺に沿って詰める距離。
static func rounded(points: PackedVector2Array, r: float) -> PackedVector2Array:
	var n := points.size()
	if n < 3 or r <= 0.0:
		return points
	var out := PackedVector2Array()
	for i in range(n):
		var prev: Vector2 = points[(i - 1 + n) % n]
		var cur: Vector2 = points[i]
		var next: Vector2 = points[(i + 1) % n]

		var to_prev := prev - cur
		var to_next := next - cur
		var lp := to_prev.length()
		var ln := to_next.length()
		if lp < 0.01 or ln < 0.01:
			out.append(cur)
			continue
		# 隣り合う角と食い合わないよう、辺の半分までに抑える
		var rr: float = minf(r, minf(lp, ln) * 0.5)
		var a := cur + to_prev / lp * rr
		var b := cur + to_next / ln * rr
		for s in range(ROUND_STEPS + 1):
			var t := float(s) / float(ROUND_STEPS)
			# 角を制御点にした二次ベジエで丸める
			var p := a.lerp(cur, t).lerp(cur.lerp(b, t), t)
			out.append(p)
	return out


## 角丸のブロック1つ。上面・左面・右面をまとめて描く。
## lift は浮かせる量（歩くときの上下など）。
static func draw_block(node: CanvasItem, w: float, d: float, h: float,
		top_color: Color, offset: Vector2 = Vector2.ZERO, radius: float = 3.0) -> void:
	var faces := box_faces(w, d, h)
	var left_col := top_color.darkened(0.34)
	var right_col := top_color.darkened(0.14)

	# まず全体の輪郭を側面色で塗り、その上に上面を重ねる。
	# 面ごとに丸めると継ぎ目が割れるので、輪郭で丸める。
	var body := PackedVector2Array([
		Vector2(0, -d - h), Vector2(w, -h), Vector2(w, 0),
		Vector2(0, d), Vector2(-w, 0), Vector2(-w, -h),
	])
	node.draw_colored_polygon(_shift(rounded(body, radius), offset), right_col)
	node.draw_colored_polygon(_shift(rounded(faces[1], radius), offset), left_col)
	node.draw_colored_polygon(_shift(rounded(faces[0], radius), offset), top_color)


## 影。ブロックの足元に敷く。
static func draw_shadow(node: CanvasItem, scale_factor: float, alpha: float = 0.22) -> void:
	node.draw_colored_polygon(rounded(diamond(scale_factor), 6.0), Color(0, 0, 0, alpha))


static func _shift(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	if off == Vector2.ZERO:
		return pts
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + off)
	return out
