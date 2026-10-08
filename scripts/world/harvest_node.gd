class_name HarvestNode
extends Node2D
## 世界に元から在る場所。茂み・木・岩。
##
## **ここで手に入るものは、場所ではなく物のほうが持っている。** 手に入る物が
## 「どこで手に入るか」を指している（`Schema.place_of`）——岩で石も鉄も手に入るなら、
## 石と鉄の手に入れかたが岩を指しているだけ。
## **名前も持たない。** 神がもちものの名前を変えれば、採れるものの名前も変わる
## （`Schema.WORLD_ARTS`）。消されたものは島に生えない。
## **いくつ寄越すかも持っていない。世界の物は尽きない。**

enum Kind { BERRY, TREE, ROCK }

## この場所が生えるもとの持ち物。それが消されていれば、島に生えない
const KIND_ITEM := {Kind.BERRY: "food", Kind.TREE: "wood", Kind.ROCK: "stone"}

## 手に入れかたの場所の名前（`Schema.WORLD_PLACES`）から、その場所の姿へ
const PLACE_KIND := {"bush": Kind.BERRY, "tree": Kind.TREE, "rock": Kind.ROCK}

var kind: int = Kind.BERRY
var cell: Vector2i = Vector2i.ZERO


func setup(p_kind: int, p_cell: Vector2i) -> void:
	kind = p_kind
	cell = p_cell
	position = Iso.cell_to_world(Vector2(cell))
	z_index = 0


func item_key() -> String:
	return KIND_ITEM[kind]


func _draw() -> void:
	Iso.draw_shadow(self, 0.55, 0.2)
	match kind:
		Kind.BERRY:
			# 低い茂みのブロックに実を乗せる
			Iso.draw_block(self, 13.0, 6.5, 10.0, Color(0.30, 0.56, 0.32), Vector2.ZERO, 4.0)
			for i in range(6):
				var a := TAU * float(i) / 6.0
				var o := Vector2(cos(a) * 7.0, sin(a) * 3.5 - 12.0)
				draw_circle(o, 2.6, Color(0.88, 0.30, 0.36))
		Kind.TREE:
			Iso.draw_block(self, 4.5, 2.2, 12.0, Color(0.44, 0.31, 0.20), Vector2.ZERO, 1.5)
			Iso.draw_block(self, 15.0, 7.5, 22.0, Color(0.26, 0.52, 0.30),
				Vector2(0, -12.0), 6.0)
		Kind.ROCK:
			Iso.draw_block(self, 14.0, 7.0, 14.0, Color(0.66, 0.66, 0.70), Vector2.ZERO, 4.0)
