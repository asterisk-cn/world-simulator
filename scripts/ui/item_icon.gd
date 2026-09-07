class_name ItemIcon
extends Control
## 世界に実在するものを、UI の中でも同じ絵で見せる小さな部品。
##
## 一覧やつくりかたを名前だけで並べると、そこだけ開発ツールの表になる。
## 神が名指ししている物は世界の上に本当に在るので、同じ絵で指させばいい。
##
## 頭上の吹き出し（`world/bubble.gd`）と絵を共有する。
## 同じ物が場所によって違う姿で出ると、繋がりが切れる。
##
## 姿は**あらかじめ用意したものだけ**（`Schema.CRAFT_ARTS` / `Schema.BUILDING_ARTS`）。
## 神が決められるのは名前と、どの姿にするか。世界に無い姿は生まれない。
## 建物の世界の上での姿は `world/structure.gd`。ここはその小さい版。

## 絵の基準の大きさ。この幅のとき縮尺 1.0 で描く。
const BASE := 16.0

## 姿そのものに色がないもの（家の屋根など）に使う既定の色
const NO_TINT := Color(0, 0, 0, 0)

const STONE := Color(0.60, 0.60, 0.65)
## 紙の上に置いても壁が見えるよう、世界の壁より少しだけ濃くする
const WALL := Color(0.80, 0.72, 0.57)
const ROOF := Color(0.78, 0.36, 0.32)

var art: String = "tool"
var px: float = BASE
var accent: Color = NO_TINT


## 持ち物 / 採る対象 / 建物 の id から、その姿を引く
static func art_of(id: String) -> String:
	return Schema.thing_art(id)


static func of_item(id: String, size_px: int = 16) -> ItemIcon:
	var i := of_art(art_of(id), size_px)
	if Schema.is_building(id):
		i.accent = Schema.building_color(id)
	return i


static func of_art(p_art: String, size_px: int = 16) -> ItemIcon:
	var i := ItemIcon.new()
	i.art = p_art
	i.px = float(size_px)
	i.custom_minimum_size = Vector2(size_px, size_px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	draw_art(self, size * 0.5, px / BASE, art, 1.0, accent)


## 世界にあるものを、そのまま小さく描く。
## a は消えかけの濃さ（吹き出し用）、tint は建物ごとの色。
static func draw_art(node: CanvasItem, c: Vector2, s: float, p_art: String,
		a: float = 1.0, tint: Color = NO_TINT) -> void:
	var accent_of := func(base: Color) -> Color:
		var col: Color = base if tint.a <= 0.0 else tint
		return Color(col.r, col.g, col.b, a)

	match p_art:
		# --- 採って手に入るもの ---
		"berry":
			# 茂みと赤い実
			blk(node, c + Vector2(0, 3.0) * s, 6.0 * s, 2.4 * s, Color(0.30, 0.56, 0.32, a))
			for dx in [-3.2, 0.0, 3.2]:
				node.draw_circle(c + Vector2(dx * s, -1.6 * s), 2.0 * s,
					Color(0.88, 0.30, 0.36, a))
		"tree":
			# 幹と葉
			blk(node, c + Vector2(0, 4.0) * s, 1.3 * s, 2.6 * s, Color(0.44, 0.31, 0.20, a))
			blk(node, c + Vector2(0, -1.5) * s, 5.0 * s, 4.0 * s, Color(0.26, 0.52, 0.30, a))
		"rock":
			# 平たい板にならないよう、天面を一段明るく置いて立体に見せる
			blk(node, c + Vector2(0, 1.4) * s, 4.8 * s, 3.4 * s, Color(0.60, 0.60, 0.65, a))
			blk(node, c + Vector2(0, -2.4) * s, 4.2 * s, 1.5 * s, Color(0.74, 0.74, 0.79, a))

		# --- 作れるもの ---
		"tool":
			# 木と石が1つになったもの
			blk(node, c + Vector2(-4.6, 2.0) * s, 2.4 * s, 2.4 * s, Color(0.44, 0.31, 0.20, a))
			blk(node, c + Vector2(4.6, 2.0) * s, 2.4 * s, 2.4 * s, Color(0.62, 0.62, 0.67, a))
			blk(node, c + Vector2(0, -3.4) * s, 3.0 * s, 2.6 * s, Color(0.78, 0.60, 0.28, a))
		"blade":
			# 柄と刃
			blk(node, c + Vector2(0, 4.6) * s, 1.5 * s, 2.6 * s, Color(0.44, 0.31, 0.20, a))
			node.draw_colored_polygon(Iso.rounded(PackedVector2Array([
				c + Vector2(-2.6, 1.8) * s, c + Vector2(2.6, 1.8) * s,
				c + Vector2(1.4, -6.4) * s, c + Vector2(-1.4, -5.0) * s,
			]), 1.6 * s), Color(0.74, 0.76, 0.82, a))
		"pot":
			# 胴とくびれ
			node.draw_circle(c + Vector2(0, 1.6) * s, 4.8 * s, Color(0.74, 0.48, 0.34, a))
			blk(node, c + Vector2(0, -3.6) * s, 2.0 * s, 1.6 * s, Color(0.64, 0.40, 0.28, a))
			blk(node, c + Vector2(0, -5.4) * s, 3.2 * s, 1.0 * s, Color(0.80, 0.55, 0.40, a))
		"bread":
			# 焼いたもの。切れ目で焼き物と分かる
			blk(node, c + Vector2(0, 0.6) * s, 5.6 * s, 3.6 * s, Color(0.80, 0.60, 0.34, a))
			for dx in [-2.0, 1.0]:
				node.draw_line(c + Vector2(dx - 1.0, -1.6) * s, c + Vector2(dx + 1.6, 1.4) * s,
					Color(0.60, 0.42, 0.24, a), 1.3 * s)
		"cloth":
			# 畳んだ布
			blk(node, c + Vector2(0, -1.0) * s, 5.4 * s, 3.0 * s, Color(0.56, 0.66, 0.80, a))
			blk(node, c + Vector2(0, 3.4) * s, 4.6 * s, 1.8 * s, Color(0.44, 0.54, 0.70, a))
		"rope":
			# 巻いた縄
			node.draw_arc(c, 4.6 * s, 0.0, TAU, 20, Color(0.72, 0.58, 0.34, a), 2.2 * s)
			node.draw_arc(c, 1.8 * s, 0.0, TAU, 12, Color(0.60, 0.47, 0.28, a), 1.6 * s)
		"jewel":
			# 飾り
			node.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -6.0) * s, c + Vector2(4.4, -0.6) * s,
				c + Vector2(0, 6.0) * s, c + Vector2(-4.4, -0.6) * s,
			]), Color(0.52, 0.78, 0.86, a))
			node.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -6.0) * s, c + Vector2(4.4, -0.6) * s,
				c + Vector2(0, -0.6) * s,
			]), Color(0.76, 0.92, 0.96, a))
		"torch":
			# 柄と炎
			blk(node, c + Vector2(0, 3.6) * s, 1.3 * s, 3.6 * s, Color(0.44, 0.31, 0.20, a))
			node.draw_circle(c + Vector2(0, -2.4) * s, 3.4 * s, Color(0.90, 0.52, 0.22, a))
			node.draw_circle(c + Vector2(0, -3.0) * s, 1.6 * s, Color(0.99, 0.84, 0.42, a))

		# --- 建てられるもの（世界の上の姿は world/structure.gd） ---
		"house":
			blk(node, c + Vector2(0, 2.6) * s, 5.0 * s, 2.8 * s, Color(WALL.r, WALL.g, WALL.b, a))
			node.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-6.4, -0.4) * s, c + Vector2(6.4, -0.4) * s,
				c + Vector2(0, -6.0) * s,
			]), accent_of.call(ROOF))
		"chapel":
			# 細い身廊と、高く尖った屋根
			blk(node, c + Vector2(0, 3.4) * s, 3.4 * s, 3.4 * s, Color(WALL.r, WALL.g, WALL.b, a))
			node.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-4.6, 0.2) * s, c + Vector2(4.6, 0.2) * s,
				c + Vector2(0, -7.2) * s,
			]), accent_of.call(ROOF))
		"hall":
			# 平屋根の広い建物
			blk(node, c + Vector2(0, 3.0) * s, 6.2 * s, 3.2 * s, Color(WALL.r, WALL.g, WALL.b, a))
			blk(node, c + Vector2(0, -1.4) * s, 7.0 * s, 1.6 * s, accent_of.call(ROOF))
			blk(node, c + Vector2(0, 4.2) * s, 1.4 * s, 2.0 * s, Color(0.42, 0.32, 0.24, a))
		"store":
			# 高床の倉
			for dx in [-3.4, 3.4]:
				blk(node, c + Vector2(dx, 5.0) * s, 0.9 * s, 2.0 * s, Color(0.44, 0.31, 0.20, a))
			blk(node, c + Vector2(0, 1.4) * s, 4.8 * s, 2.6 * s, Color(0.72, 0.62, 0.46, a))
			node.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-6.0, -1.0) * s, c + Vector2(6.0, -1.0) * s,
				c + Vector2(0, -5.8) * s,
			]), accent_of.call(ROOF))
		"well":
			# 石積みと屋根つきの滑車
			blk(node, c + Vector2(0, 4.2) * s, 4.6 * s, 2.0 * s, Color(STONE.r, STONE.g, STONE.b, a))
			for dx in [-3.0, 3.0]:
				blk(node, c + Vector2(dx, 0.2) * s, 0.7 * s, 3.0 * s, Color(0.44, 0.31, 0.20, a))
			node.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-5.4, -2.6) * s, c + Vector2(5.4, -2.6) * s,
				c + Vector2(0, -6.4) * s,
			]), accent_of.call(ROOF))
		"tower":
			# 細く高い塔
			blk(node, c + Vector2(0, 2.0) * s, 3.0 * s, 5.4 * s, Color(STONE.r, STONE.g, STONE.b, a))
			blk(node, c + Vector2(0, -4.6) * s, 4.0 * s, 1.4 * s, accent_of.call(ROOF))
		_:
			blk(node, c, 4.0 * s, 4.0 * s, Color(0.70, 0.66, 0.60, a))


## 世界と同じ角丸のブロック
static func blk(node: CanvasItem, c: Vector2, hw: float, hh: float, col: Color) -> void:
	node.draw_colored_polygon(Iso.rounded(PackedVector2Array([
		c + Vector2(-hw, -hh), c + Vector2(hw, -hh),
		c + Vector2(hw, hh), c + Vector2(-hw, hh),
	]), maxf(hw, hh) * 0.28), col)
