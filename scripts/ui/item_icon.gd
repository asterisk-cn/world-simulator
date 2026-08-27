class_name ItemIcon
extends Control
## 世界に実在するものを、UI の中でも同じ絵で見せる小さな部品。
##
## 一覧やレシピを名前だけで並べると、そこだけ開発ツールの表になる。
## 神が名指ししている物は世界の上に本当に在るので、同じ絵で指させばいい。
##
## 頭上の吹き出し（`world/bubble.gd`）と絵を共有する。
## 同じ物が場所によって違う姿で出ると、繋がりが切れる。

## 持ち物 / 採る対象 の id から、何を描くかを引く。
## ここに無いもの（プレイヤーが増やしたつくりかたの産物）は「作られたもの」になる。
const ART_OF := {
	"food": "berry", "wood": "tree", "stone": "rock",
	"berry": "berry", "tree": "tree", "rock": "rock",
	"craft": "crafted",
}

## 絵の基準の大きさ。この幅のとき縮尺 1.0 で描く。
const BASE := 16.0

var art: String = "crafted"
var px: float = BASE


static func art_of(item: String) -> String:
	return String(ART_OF.get(item, "crafted"))


static func of_item(item: String, size_px: int = 16) -> ItemIcon:
	return of_art(art_of(item), size_px)


static func of_art(p_art: String, size_px: int = 16) -> ItemIcon:
	var i := ItemIcon.new()
	i.art = p_art
	i.px = float(size_px)
	i.custom_minimum_size = Vector2(size_px, size_px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	draw_art(self, size * 0.5, px / BASE, art)


## 世界にあるものを、そのまま小さく描く。a は消えかけの濃さ（吹き出し用）。
static func draw_art(node: CanvasItem, c: Vector2, s: float, p_art: String,
		a: float = 1.0) -> void:
	match p_art:
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
		"crafted":
			# 木と石が1つになったもの
			blk(node, c + Vector2(-4.6, 2.0) * s, 2.4 * s, 2.4 * s, Color(0.44, 0.31, 0.20, a))
			blk(node, c + Vector2(4.6, 2.0) * s, 2.4 * s, 2.4 * s, Color(0.62, 0.62, 0.67, a))
			blk(node, c + Vector2(0, -3.4) * s, 3.0 * s, 2.6 * s, Color(0.78, 0.60, 0.28, a))
		"house":
			blk(node, c + Vector2(0, 2.6) * s, 5.0 * s, 2.8 * s, Color(0.86, 0.79, 0.66, a))
			node.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-6.4, -0.4) * s, c + Vector2(6.4, -0.4) * s,
				c + Vector2(0, -6.0) * s,
			]), Color(0.78, 0.36, 0.32, a))


## 世界と同じ角丸のブロック
static func blk(node: CanvasItem, c: Vector2, hw: float, hh: float, col: Color) -> void:
	node.draw_colored_polygon(Iso.rounded(PackedVector2Array([
		c + Vector2(-hw, -hh), c + Vector2(hw, -hh),
		c + Vector2(hw, hh), c + Vector2(-hw, hh),
	]), maxf(hw, hh) * 0.28), col)
