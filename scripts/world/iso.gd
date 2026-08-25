class_name Iso
extends RefCounted
## クォータービュー（アイソメトリック）の座標変換。
## セル座標 (x, y) は床のマス目。スクリーン座標はひし形に潰した菱形グリッド。

const TILE_W := 64.0
const TILE_H := 32.0
const HALF_W := TILE_W * 0.5
const HALF_H := TILE_H * 0.5


static func cell_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF_W, (cell.x + cell.y) * HALF_H)


static func world_to_cell(p: Vector2) -> Vector2:
	return Vector2(
		(p.x / HALF_W + p.y / HALF_H) * 0.5,
		(p.y / HALF_H - p.x / HALF_W) * 0.5
	)


## そのセルの床の菱形（ローカル原点はセル中心）
static func diamond(scale_factor: float = 1.0) -> PackedVector2Array:
	var w := HALF_W * scale_factor
	var h := HALF_H * scale_factor
	return PackedVector2Array([
		Vector2(0, -h), Vector2(w, 0), Vector2(0, h), Vector2(-w, 0)
	])


## 高さ h の箱を描くための3面（上面・左面・右面）
static func box_faces(w: float, d: float, h: float) -> Array:
	var top := PackedVector2Array([
		Vector2(0, -d - h), Vector2(w, -h), Vector2(0, d - h), Vector2(-w, -h)
	])
	var left := PackedVector2Array([
		Vector2(-w, -h), Vector2(0, d - h), Vector2(0, d), Vector2(-w, 0)
	])
	var right := PackedVector2Array([
		Vector2(w, -h), Vector2(0, d - h), Vector2(0, d), Vector2(w, 0)
	])
	return [top, left, right]
