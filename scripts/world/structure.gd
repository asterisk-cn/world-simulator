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
	_draw_house()


func _draw_house() -> void:
	# 2x2 の敷地を薄く塗る（持ち主の色）
	for c in footprint():
		var off := Iso.cell_to_world(Vector2(c)) - position
		draw_colored_polygon(_offset(Iso.diamond(0.98), off), Color(owner_color.r, owner_color.g, owner_color.b, 0.16))

	var center := Iso.cell_to_world(Vector2(cell) + Vector2(0.5, 0.5)) - position
	var faces := Iso.box_faces(46.0, 23.0, 30.0)
	var wall := Color(0.80, 0.72, 0.58)
	draw_colored_polygon(_offset(faces[1], center), wall.darkened(0.28))
	draw_colored_polygon(_offset(faces[2], center), wall.darkened(0.10))
	# 屋根は持ち主の色
	var roof := Iso.box_faces(52.0, 26.0, 44.0)
	draw_colored_polygon(_offset(roof[0], center), owner_color)
	draw_colored_polygon(_offset(roof[1], center), owner_color.darkened(0.3))
	draw_colored_polygon(_offset(roof[2], center), owner_color.darkened(0.12))
	# 扉
	draw_colored_polygon(_offset(PackedVector2Array([
		Vector2(6, -14), Vector2(20, -21), Vector2(20, -5), Vector2(6, 2)
	]), center), Color(0.30, 0.20, 0.14))


func _offset(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for pt in pts:
		out.append(pt + off)
	return out
