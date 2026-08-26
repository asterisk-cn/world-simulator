class_name Bubble
extends RefCounted
## 村人の頭の上に出す小さな吹き出し。
##
## 出来事がログにしか出ないと、文字を読んでから世界を探すことになる。
## 何が起きたかは世界の上で起こす。吹き出しも角丸ブロックの仲間として描く。

## いま何をしているかを1文字で表す。パネルを見なくても村が読めるように。
const MARKS := {
	"move": "…",
	"gather": "✦",
	"craft": "✚",
	"build": "⌂",
	"use": "●",
	"social": "♪",
}

## 起きた瞬間に出す吹き出し
const TALK := "♪"
const BUILT := "⌂"
const GOT := "✦"
const ATE := "●"
const MADE := "✚"

var text: String = ""
var life: float = 0.0
var span: float = 1.0
var tint: Color = Color(0.99, 0.98, 0.94)


func _init(p_text: String, p_span: float = 1.6, p_tint: Color = Color(0.99, 0.98, 0.94)) -> void:
	text = p_text
	span = p_span
	life = p_span
	tint = p_tint


func advance(dt: float) -> bool:
	life -= dt
	return life > 0.0


## 出るときにふわっと上がって、消えるときに薄くなる
func draw_on(node: CanvasItem, font: Font, at: Vector2) -> void:
	var t := 1.0 - life / span
	var rise := -6.0 * minf(t * 4.0, 1.0)
	var fade: float = clampf(life / (span * 0.35), 0.0, 1.0)
	var pos := at + Vector2(0, rise)

	var w := 11.0 + float(text.length()) * 3.0
	var body := PackedVector2Array([
		pos + Vector2(-w, -11), pos + Vector2(w, -11),
		pos + Vector2(w, 5), pos + Vector2(-w, 5),
	])
	node.draw_colored_polygon(Iso.rounded(body, 5.0),
		Color(tint.r, tint.g, tint.b, 0.94 * fade))
	# しっぽ
	node.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-3, 4), pos + Vector2(3, 4), pos + Vector2(0, 10),
	]), Color(tint.r, tint.g, tint.b, 0.94 * fade))
	node.draw_string(font, pos + Vector2(-w, 2), text, HORIZONTAL_ALIGNMENT_CENTER,
		w * 2.0, 12, Color(0.20, 0.18, 0.16, fade))
