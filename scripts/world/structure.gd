class_name Structure
extends Node2D
## 家。持ち主がいて、2x2 の敷地を占める。他人は通り抜けられない。

enum Kind { HOUSE }

var kind: int = Kind.HOUSE
var cell: Vector2i = Vector2i.ZERO
var owner_id: int = -1
var owner_color: Color = Color(0.7, 0.7, 0.7)
var id: int = 0

static var _next_id: int = 1


func setup(p_kind: int, p_cell: Vector2i, p_owner_id: int, p_color: Color) -> void:
	id = _next_id
	_next_id += 1
	kind = p_kind
	cell = p_cell
	owner_id = p_owner_id
	owner_color = p_color
	position = Iso.cell_to_world(Vector2(cell))


## 家の敷地
func footprint() -> Array:
	return [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]


func contains_cell(c: Vector2i) -> bool:
	return c in footprint()


func _draw() -> void:
	# 敷地を持ち主の色で薄く塗る
	for c in footprint():
		var off := Iso.cell_to_world(Vector2(c)) - position
		draw_colored_polygon(
			Iso._shift(Iso.rounded(Iso.diamond(0.96), 5.0), off),
			Color(owner_color.r, owner_color.g, owner_color.b, 0.15))

	var center := Iso.cell_to_world(Vector2(cell) + Vector2(0.5, 0.5)) - position
	# 壁の上に屋根を積む。村人と同じ角丸ブロック。
	Iso.draw_block(self, 44.0, 22.0, 24.0, Color(0.86, 0.79, 0.66), center, 6.0)
	Iso.draw_block(self, 50.0, 25.0, 16.0, owner_color, center + Vector2(0, -24.0), 7.0)

	# 扉
	var door := Iso.rounded(PackedVector2Array([
		Vector2(5, -15), Vector2(19, -22), Vector2(19, -5), Vector2(5, 2)
	]), 3.0)
	draw_colored_polygon(Iso._shift(door, center), Color(0.28, 0.19, 0.13))
