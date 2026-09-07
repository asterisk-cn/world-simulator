class_name Structure
extends Node2D
## 建てられたもの。2x2 の敷地を占め、通り抜けられない。
##
## 何が建てられるかは神が「つくりかた」で決める（`Schema.buildings`）。
## 定義が持つのは名前と姿だけで、姿はあらかじめ用意した中から選ばれる。
##
## **家だけは建てた人のもの**で、一人に一軒。それ以外は村のもので、村に一つ。
##
## 在庫は持たない。井戸から何が汲めるかは名前を読んだ本人が答え（`Brain._how_much`）、
## いくつ汲めるかは誰も決めていない——世界の物は尽きない。
## UI の中の小さい絵は `ui/item_icon.gd`。同じものが場所によって違う姿で出ないよう対で保つ。

const WALL := Color(0.86, 0.79, 0.66)
const STONE := Color(0.66, 0.65, 0.64)
const TIMBER := Color(0.60, 0.47, 0.33)

var def_id: String = Schema.HOUSE
var cell: Vector2i = Vector2i.ZERO

var owner_id: int = -1
var owner_color: Color = Color(0.7, 0.7, 0.7)
var id: int = 0

static var _next_id: int = 1


var _lit := -1.0


## 灯りの具合が変わったときだけ描き直す
func _process(_delta: float) -> void:
	var d := SimClock.darkness()
	if absf(d - _lit) > 0.02:
		_lit = d
		queue_redraw()


func setup(p_def: String, p_cell: Vector2i, p_owner_id: int, p_color: Color) -> void:
	id = _next_id
	_next_id += 1
	def_id = p_def
	cell = p_cell
	owner_id = p_owner_id
	# 家は建てた人の色。村のものは建物ごとの色。
	owner_color = p_color if is_house() else Schema.building_color(def_id)
	position = Iso.cell_to_world(Vector2(cell))


func is_house() -> bool:
	return def_id == Schema.HOUSE


func label() -> String:
	return Schema.building_label(def_id)


## 敷地
func footprint() -> Array:
	return [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]


func contains_cell(c: Vector2i) -> bool:
	return c in footprint()


## 使うために近づく先。敷地の真ん中。
func center_cell() -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)



func _draw() -> void:
	# 敷地を建物の色で薄く塗る
	for c in footprint():
		var off := Iso.cell_to_world(Vector2(c)) - position
		draw_colored_polygon(
			Iso._shift(Iso.rounded(Iso.diamond(0.96), 5.0), off),
			Color(owner_color.r, owner_color.g, owner_color.b, 0.15))

	var center := Iso.cell_to_world(center_cell()) - position
	var lit := SimClock.darkness()

	# 壁の上に屋根を積む。村人と同じ角丸ブロック。
	match Schema.building_art(def_id):
		"house":
			Iso.draw_block(self, 44.0, 22.0, 24.0, WALL, center, 6.0)
			Iso.draw_block(self, 50.0, 25.0, 16.0, owner_color, center + Vector2(0, -24.0), 7.0)
			_window(center, lit)
		"chapel":
			# 細く高い身廊の上に、段を細めながら塔を積んで尖らせる
			Iso.draw_block(self, 26.0, 13.0, 48.0, WALL, center, 5.0)
			Iso.draw_block(self, 32.0, 16.0, 8.0, owner_color, center + Vector2(0, -48.0), 6.0)
			var spire := owner_color.darkened(0.08)
			Iso.draw_block(self, 13.0, 6.5, 13.0, spire, center + Vector2(0, -56.0), 3.0)
			Iso.draw_block(self, 8.0, 4.0, 12.0, spire, center + Vector2(0, -69.0), 2.5)
			Iso.draw_block(self, 4.0, 2.0, 10.0, spire, center + Vector2(0, -81.0), 1.5)
			_window(center + Vector2(0, -8.0), lit)
		"hall":
			Iso.draw_block(self, 54.0, 27.0, 18.0, WALL, center, 6.0)
			Iso.draw_block(self, 60.0, 30.0, 9.0, owner_color, center + Vector2(0, -18.0), 6.0)
			_window(center + Vector2(0, 2.0), lit)
		"store":
			# 高床。柱の上に箱が乗る
			for dx in [-16.0, 16.0]:
				Iso.draw_block(self, 5.0, 2.5, 14.0, TIMBER, center + Vector2(dx, 6.0), 2.0)
			Iso.draw_block(self, 38.0, 19.0, 20.0, TIMBER.lightened(0.22),
				center + Vector2(0, -14.0), 5.0)
			Iso.draw_block(self, 44.0, 22.0, 10.0, owner_color, center + Vector2(0, -34.0), 6.0)
		"well":
			# 石積みが見えるように、屋根は井桁より小さく葺く
			Iso.draw_block(self, 38.0, 19.0, 16.0, STONE, center, 7.0)
			# 水面。暗い口が開いていないと、ただの石の台に見える
			draw_colored_polygon(Iso._shift(Iso.rounded(Iso.diamond(0.42), 5.0),
				center + Vector2(0, -16.0)), Color(0.16, 0.20, 0.26))
			for dx in [-11.0, 11.0]:
				Iso.draw_block(self, 2.5, 1.3, 22.0, TIMBER, center + Vector2(dx, -16.0), 1.5)
			Iso.draw_block(self, 26.0, 13.0, 8.0, owner_color, center + Vector2(0, -38.0), 5.0)
		"tower":
			Iso.draw_block(self, 24.0, 12.0, 58.0, STONE, center, 4.0)
			Iso.draw_block(self, 32.0, 16.0, 10.0, owner_color, center + Vector2(0, -58.0), 5.0)
			_window(center + Vector2(0, -18.0), lit)
		_:
			Iso.draw_block(self, 40.0, 20.0, 22.0, WALL, center, 6.0)
			Iso.draw_block(self, 46.0, 23.0, 12.0, owner_color, center + Vector2(0, -22.0), 6.0)

	# 家は姿で読めるが、村のものは神がつけた名前でしか読めない。
	# 誰の家かは屋根の色で分かるので、家に札は立てない。
	if not is_house():
		_name_plate(center)


## 姿ごとの背丈。名札を頭の上に出すために使う。
const TOP := {
	"house": 40.0, "chapel": 91.0, "hall": 27.0,
	"store": 44.0, "well": 46.0, "tower": 68.0,
}


## 窓は壁の下のほうに置く。高いと屋根に食い込んで軒のように見え、
## 家というより庇つきの箱になる。
func _window(center: Vector2, lit: float) -> void:
	var window := Iso.rounded(PackedVector2Array([
		Vector2(6, -1), Vector2(18, -7), Vector2(18, 6), Vector2(6, 12)
	]), 3.0)
	if lit > 0.1:
		# 灯りのにじみ。夜に画面でいちばん明るいのは世界の側であってほしい
		for i in range(3):
			var g := 1.0 + float(i) * 0.55
			draw_colored_polygon(Iso._shift(Iso.rounded(PackedVector2Array([
				Vector2(-2 - 9 * g, -12 - 7 * g), Vector2(24 + 9 * g, -25 - 7 * g),
				Vector2(24 + 9 * g, 0 + 7 * g), Vector2(-2 - 9 * g, 12 + 7 * g),
			]), 10.0), center), Color(1.0, 0.84, 0.42, 0.10 * lit))
	var col := Color(0.28, 0.19, 0.13).lerp(Color(1.0, 0.94, 0.70), lit)
	draw_colored_polygon(Iso._shift(window, center), col)


## 村のものには名前を出す。世界の上の文字は村人の名札と同じ書き方に揃える。
func _name_plate(center: Vector2) -> void:
	var font: Font = SimConfig.ui_font if SimConfig.ui_font != null else ThemeDB.fallback_font
	var top: float = float(TOP.get(Schema.building_art(def_id), 30.0))
	var at := center + Vector2(-60, -top - 22.0)
	draw_string_outline(font, at, label(), HORIZONTAL_ALIGNMENT_CENTER, 120, 12, 4,
		Color(0.05, 0.06, 0.09, 0.75))
	draw_string(font, at, label(), HORIZONTAL_ALIGNMENT_CENTER, 120, 12,
		Color(1, 1, 1, 0.86))
