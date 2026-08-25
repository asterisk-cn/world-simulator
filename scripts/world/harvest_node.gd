class_name HarvestNode
extends Node2D
## 採取対象。木の実（食料）・木（木材）・岩（石材）。

enum Kind { BERRY, TREE, ROCK }

const KIND_NAME := {Kind.BERRY: "木の実", Kind.TREE: "木", Kind.ROCK: "岩"}
const KIND_ITEM := {Kind.BERRY: "food", Kind.TREE: "wood", Kind.ROCK: "stone"}

var kind: int = Kind.BERRY
var cell: Vector2i = Vector2i.ZERO
var amount: int = 3
var max_amount: int = 3
var regrow_timer: float = 0.0


func setup(p_kind: int, p_cell: Vector2i) -> void:
	kind = p_kind
	cell = p_cell
	max_amount = 4 if kind == Kind.BERRY else 6
	amount = max_amount
	position = Iso.cell_to_world(Vector2(cell))
	z_index = 0


func _process(delta: float) -> void:
	if SimClock.paused:
		return
	if amount >= max_amount:
		return
	# 岩は再生しない。木と木の実は時間で戻る。
	if kind == Kind.ROCK:
		return
	regrow_timer += delta * SimClock.speed
	var period := SimConfig.p("day_length_sec") * (0.35 if kind == Kind.BERRY else 0.9)
	if regrow_timer >= period:
		regrow_timer = 0.0
		amount += 1
		queue_redraw()


func take(n: int = 1) -> int:
	var got: int = mini(n, amount)
	amount -= got
	if got > 0:
		queue_redraw()
	return got


func item_key() -> String:
	return KIND_ITEM[kind]


func depleted() -> bool:
	return amount <= 0


func _draw() -> void:
	draw_colored_polygon(Iso.diamond(0.55), Color(0, 0, 0, 0.18))
	if depleted():
		draw_colored_polygon(Iso.diamond(0.25), Color(0.35, 0.33, 0.28, 0.6))
		return
	match kind:
		Kind.BERRY:
			for i in range(amount):
				var a := TAU * float(i) / float(max_amount)
				var o := Vector2(cos(a) * 9.0, sin(a) * 4.5 - 6.0)
				draw_circle(o, 5.0, Color(0.25, 0.55, 0.28))
				draw_circle(o + Vector2(0, -1), 2.4, Color(0.86, 0.28, 0.34))
		Kind.TREE:
			draw_rect(Rect2(-3, -16, 6, 16), Color(0.36, 0.25, 0.16))
			var lush := float(amount) / float(max_amount)
			draw_circle(Vector2(0, -24), 12.0 + lush * 6.0, Color(0.18, 0.42, 0.22))
			draw_circle(Vector2(-6, -30), 8.0 + lush * 4.0, Color(0.22, 0.5, 0.26))
			draw_circle(Vector2(7, -29), 7.0 + lush * 4.0, Color(0.15, 0.38, 0.2))
		Kind.ROCK:
			var faces := Iso.box_faces(14.0, 7.0, 10.0 + float(amount))
			draw_colored_polygon(faces[0], Color(0.62, 0.62, 0.66))
			draw_colored_polygon(faces[1], Color(0.40, 0.40, 0.45))
			draw_colored_polygon(faces[2], Color(0.50, 0.50, 0.55))
