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

## 話すだけは相手が物ではないので、何を描くかをここで決める。
## 使う／作る は、その対象そのものを描く（`Schema.thing_art`）。
const FOR_SOCIAL := {
	"talk": "talk",
	"post": "post",
	"read": "read",
}

var art: String = "talk"
var life: float = 0.0
var span: float = 1.0
var tint: Color = PAPER
var accent: Color = ItemIcon.NO_TINT


## 型と対象から吹き出しを作る。対応がなければ出さない。
##
## 使うときに何をしたか（食べる／祈る）は本人の言葉なので、絵には描けない。
## 絵になるのは**何に対してだったか**のほう。木の実の絵が出れば木の実に、
## 教会の絵が出れば教会に、その人が何かをしたと読める。
static func of(kind: String, target: String, span: float = 1.8,
		tint: Color = PAPER) -> Bubble:
	var art := ""
	var accent: Color = ItemIcon.NO_TINT
	match kind:
		"talk":
			art = String(FOR_SOCIAL.get(target, ""))
		"use", "make":
			art = Schema.thing_art(target)
			if Schema.is_building(target):
				accent = Schema.building_color(target)
	if art == "":
		return null
	var b := Bubble.new(art, span, tint)
	b.accent = accent
	return b


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
		"talk":
			# 小さな吹き出しが2つ向き合う
			ItemIcon.blk(node, c + Vector2(-4.0, -1.5), 3.4, 2.6, Color(0.34, 0.52, 0.66, fade))
			ItemIcon.blk(node, c + Vector2(4.0, 2.0), 3.4, 2.6, Color(0.52, 0.66, 0.76, fade))
		"post", "read":
			# 貼り紙
			ItemIcon.blk(node, c, 4.0, 5.0, Color(0.86, 0.60, 0.20, fade) if art == "post"
				else Color(0.55, 0.45, 0.32, fade))
			for i in range(2):
				var y := c.y - 1.6 + float(i) * 3.2
				node.draw_line(Vector2(c.x - 2.4, y), Vector2(c.x + 2.4, y), paper, 1.0)
		_:
			# 世界の物そのものは UI と同じ絵を使う（`ui/item_icon.gd`）。
			# 同じ物が場所によって違う姿で出ると、繋がりが切れる。
			ItemIcon.draw_art(node, c, 1.0, art, fade, accent)
