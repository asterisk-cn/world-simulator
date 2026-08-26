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
	Iso.draw_shadow(self, 0.55, 0.2)
	if depleted():
		Iso.draw_block(self, 8.0, 4.0, 3.0, Color(0.40, 0.38, 0.32), Vector2.ZERO, 2.0)
		return

	var lush := float(amount) / float(max_amount)
	match kind:
		Kind.BERRY:
			# 低い茂みのブロックに実を乗せる
			Iso.draw_block(self, 13.0, 6.5, 7.0 + lush * 3.0, Color(0.30, 0.56, 0.32),
				Vector2.ZERO, 4.0)
			for i in range(amount):
				var a := TAU * float(i) / float(max_amount)
				var o := Vector2(cos(a) * 7.0, sin(a) * 3.5 - 9.0 - lush * 3.0)
				draw_circle(o, 2.6, Color(0.88, 0.30, 0.36))
		Kind.TREE:
			Iso.draw_block(self, 4.5, 2.2, 12.0, Color(0.44, 0.31, 0.20), Vector2.ZERO, 1.5)
			Iso.draw_block(self, 15.0, 7.5, 16.0 + lush * 6.0, Color(0.26, 0.52, 0.30),
				Vector2(0, -12.0), 6.0)
		Kind.ROCK:
			Iso.draw_block(self, 14.0, 7.0, 9.0 + lush * 5.0, Color(0.66, 0.66, 0.70),
				Vector2.ZERO, 4.0)
