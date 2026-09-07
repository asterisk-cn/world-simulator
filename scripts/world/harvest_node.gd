class_name HarvestNode
extends Node2D
## 世界に元から在る物。木の実・木・石。使うと、そのまま同じ名前の持ち物になる。
##
## 何を寄越すかはプログラムが知っている（それが何であるかを知っている数少ない物）。
## **いくつ寄越すかは持っていない。世界の物は尽きない。**
## 摘み尽くさないことも判断なので、そこは本人（AI）に残す。

enum Kind { BERRY, TREE, ROCK }

const KIND_NAME := {Kind.BERRY: "木の実", Kind.TREE: "木", Kind.ROCK: "石"}
const KIND_ITEM := {Kind.BERRY: "food", Kind.TREE: "wood", Kind.ROCK: "stone"}

## 持ち物からその資源へ。世界に生っている木の実と、手の中の木の実は同じもので、
## 「使う」の対象としても同じ一つに見える（違うのはどこに在るかだけ）。
const KIND_OF_ITEM := {"food": Kind.BERRY, "wood": Kind.TREE, "stone": Kind.ROCK}

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
