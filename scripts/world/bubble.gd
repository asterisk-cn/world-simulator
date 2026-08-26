class_name Bubble
extends RefCounted
## 村人の頭の上に出す小さな吹き出し。
##
## 出来事がログにしか出ないと、文字を読んでから世界を探すことになる。
## 何が起きたかは世界の上で起こす。
##
## 中身は記号ではなく絵。フォント任せの記号は意味が引けない。
## 絵は**アクションの型 × 対象**にそのまま対応させる。
## 世界に実在するもの（木の実・木・石・家・貼り紙）をそのまま小さく描けば、
## 何をしたのかは説明なしに読める。

const PAPER := Color(0.99, 0.98, 0.94)

## 型と対象の組から、何を描くかを引く。Schema の TARGETS と対で保つ。
const FOR := {
	"gather/berry": "berry",
	"gather/tree": "tree",
	"gather/rock": "rock",
	"craft": "craft",
	"build/house": "house",
	"use/food": "eat",
	"use/home": "sleep",
	"social/talk": "talk",
	"social/post": "post",
	"social/read": "read",
}

var art: String = "talk"
var life: float = 0.0
var span: float = 1.0
var tint: Color = PAPER


## 型と対象から吹き出しを作る。対応がなければ出さない。
static func of(kind: String, target: String, span: float = 1.8,
		tint: Color = PAPER) -> Bubble:
	var key := "%s/%s" % [kind, target]
	var art: String = String(FOR.get(key, FOR.get(kind, "")))
	if art == "":
		return null
	return Bubble.new(art, span, tint)


func _init(p_art: String, p_span: float = 1.8, p_tint: Color = PAPER) -> void:
	art = p_art
	span = p_span
	life = p_span
	tint = p_tint


func advance(dt: float) -> bool:
	life -= dt
	return life > 0.0


## 出るときにふわっと上がって、消えるときに薄くなる
func draw_on(node: CanvasItem, at: Vector2) -> void:
	var t := 1.0 - life / span
	var rise := -7.0 * minf(t * 4.0, 1.0)
	var fade: float = clampf(life / (span * 0.35), 0.0, 1.0)
	var pos := at + Vector2(0, rise)
	var w := 13.0

	node.draw_colored_polygon(Iso.rounded(PackedVector2Array([
		pos + Vector2(-w, -12), pos + Vector2(w, -12),
		pos + Vector2(w, 6), pos + Vector2(-w, 6),
	]), 5.0), Color(tint.r, tint.g, tint.b, 0.95 * fade))
	node.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-3, 5), pos + Vector2(3, 5), pos + Vector2(0, 11),
	]), Color(tint.r, tint.g, tint.b, 0.95 * fade))

	_draw_art(node, pos + Vector2(0, -3), fade)


## 世界にあるものを、そのまま小さく描く
func _draw_art(node: CanvasItem, c: Vector2, fade: float) -> void:
	var paper := Color(tint.r, tint.g, tint.b, fade)
	match art:
		"berry":
			# 茂みと赤い実
			_blk(node, c + Vector2(0, 3.0), 6.0, 2.4, Color(0.30, 0.56, 0.32, fade))
			for dx in [-3.2, 0.0, 3.2]:
				node.draw_circle(c + Vector2(dx, -1.6), 2.0, Color(0.88, 0.30, 0.36, fade))
		"tree":
			# 幹と葉
			_blk(node, c + Vector2(0, 4.0), 1.3, 2.6, Color(0.44, 0.31, 0.20, fade))
			_blk(node, c + Vector2(0, -1.5), 5.0, 4.0, Color(0.26, 0.52, 0.30, fade))
		"rock":
			_blk(node, c + Vector2(0, 1.0), 5.4, 4.0, Color(0.62, 0.62, 0.67, fade))
		"craft":
			# 2つが1つになる
			_blk(node, c + Vector2(-4.6, 2.0), 2.4, 2.4, Color(0.44, 0.31, 0.20, fade))
			_blk(node, c + Vector2(4.6, 2.0), 2.4, 2.4, Color(0.62, 0.62, 0.67, fade))
			_blk(node, c + Vector2(0, -3.4), 3.0, 2.6, Color(0.78, 0.60, 0.28, fade))
		"house":
			_blk(node, c + Vector2(0, 2.6), 5.0, 2.8, Color(0.86, 0.79, 0.66, fade))
			node.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-6.4, -0.4), c + Vector2(6.4, -0.4), c + Vector2(0, -6.0),
			]), Color(0.78, 0.36, 0.32, fade))
		"eat":
			# かじられた木の実
			node.draw_circle(c, 4.4, Color(0.88, 0.30, 0.36, fade))
			node.draw_circle(c + Vector2(3.4, -2.8), 2.4, paper)
		"sleep":
			# 眠り
			for i in range(2):
				var s := 3.2 - float(i) * 1.3
				var o := c + Vector2(-2.4 + float(i) * 4.6, -1.0 + float(i) * 3.0)
				node.draw_line(o + Vector2(-s, -s), o + Vector2(s, -s),
					Color(0.30, 0.34, 0.55, fade), 1.4)
				node.draw_line(o + Vector2(s, -s), o + Vector2(-s, s),
					Color(0.30, 0.34, 0.55, fade), 1.4)
				node.draw_line(o + Vector2(-s, s), o + Vector2(s, s),
					Color(0.30, 0.34, 0.55, fade), 1.4)
		"talk":
			# 小さな吹き出しが2つ向き合う
			_blk(node, c + Vector2(-4.0, -1.5), 3.4, 2.6, Color(0.34, 0.52, 0.66, fade))
			_blk(node, c + Vector2(4.0, 2.0), 3.4, 2.6, Color(0.52, 0.66, 0.76, fade))
		"post", "read":
			# 貼り紙
			_blk(node, c, 4.0, 5.0, Color(0.86, 0.60, 0.20, fade) if art == "post"
				else Color(0.55, 0.45, 0.32, fade))
			for i in range(2):
				var y := c.y - 1.6 + float(i) * 3.2
				node.draw_line(Vector2(c.x - 2.4, y), Vector2(c.x + 2.4, y), paper, 1.0)


static func _blk(node: CanvasItem, c: Vector2, hw: float, hh: float, col: Color) -> void:
	node.draw_colored_polygon(Iso.rounded(PackedVector2Array([
		c + Vector2(-hw, -hh), c + Vector2(hw, -hh),
		c + Vector2(hw, hh), c + Vector2(-hw, hh),
	]), 1.4), col)
