class_name BulletinBoard
extends Node2D
## 村の掲示板。村人が情報・主張・告発を貼り出し、通りかかった者が読む。
## 集合知は存在しないので、これと直接の会話だけが情報伝達の経路になる。
## プレイヤーもここに書き込める（＝世界への干渉手段のひとつ）。

const KIND_INFO := "情報"
const KIND_CLAIM := "主張"
const KIND_ACCUSE := "告発"
const KIND_OFFER := "取引"

const MAX_POSTS := 12

var cell: Vector2i = Vector2i.ZERO
var posts: Array = []

static var _next_post_id: int = 1

signal posts_changed


func setup(p_cell: Vector2i) -> void:
	cell = p_cell
	position = Iso.cell_to_world(Vector2(cell))


## author_id が -1 のときはプレイヤー（村人から見て「誰が書いたか分からない張り紙」）
func post(author_id: int, author_name: String, kind: String, text: String, payload: Dictionary = {}) -> Dictionary:
	var entry := {
		"id": _next_post_id,
		"author_id": author_id,
		"author_name": author_name,
		"kind": kind,
		"text": text,
		"day": SimClock.day,
		"payload": payload.duplicate(),
	}
	_next_post_id += 1
	posts.append(entry)
	while posts.size() > MAX_POSTS:
		posts.pop_front()
	posts_changed.emit()
	queue_redraw()
	if author_id == -1:
		EventLog.notable("掲示板に差出人不明の張り紙が現れた：「%s」" % text)
	else:
		EventLog.social("%s が掲示板に貼った：「%s」" % [author_name, text])
	return entry


func remove_post(post_id: int) -> void:
	for i in range(posts.size()):
		if posts[i]["id"] == post_id:
			posts.remove_at(i)
			posts_changed.emit()
			queue_redraw()
			return


func unread_for(mem) -> Array:
	var out: Array = []
	for e in posts:
		if not mem.has_read_post(e["id"]):
			out.append(e)
	return out


# 板の寸法。
# 箱ではなく「1枚の板」に見せるため、マス目の軸に沿わせて面を1つだけ正面に向ける。
# box_faces を使うと左右2面が同時にこちらを向いてしまい、角の立った箱になる。
const HALF_LEN := 0.78    ## 板の長さ（マス）
const PANEL_H := 27.0     ## 板の高さ
const THICK := 0.07       ## 厚み（マス）。板なので薄く
const BASE_Y := -17.0     ## 板の下端


## 板の面に沿った方向（マス目の X 軸）
func _along() -> Vector2:
	return Vector2(Iso.HALF_W, Iso.HALF_H) * HALF_LEN


## 板の奥ゆき方向（見る側から向こうへ）
func _depth() -> Vector2:
	return Vector2(Iso.HALF_W, -Iso.HALF_H) * THICK


func _draw() -> void:
	Iso.draw_shadow(self, 0.8, 0.2)

	var v := _along()
	var back := _depth()
	var post := Color(0.44, 0.31, 0.20)

	# 支柱は板の両端の下に
	Iso.draw_block(self, 3.0, 1.5, -BASE_Y, post, -v * 0.86, 1.5)
	Iso.draw_block(self, 3.0, 1.5, -BASE_Y, post, v * 0.86, 1.5)

	var base := Color(0.66, 0.49, 0.30)
	var lo0 := Vector2(0, BASE_Y) - v
	var lo1 := Vector2(0, BASE_Y) + v
	var hi0 := lo0 + Vector2(0, -PANEL_H)
	var hi1 := lo1 + Vector2(0, -PANEL_H)

	# 奥の面 → 上端 → 手前の面 の順に重ねる
	draw_colored_polygon(Iso.rounded(PackedVector2Array([
		lo0 + back, lo1 + back, hi1 + back, hi0 + back]), 2.5), base.darkened(0.34))
	draw_colored_polygon(PackedVector2Array([hi0, hi1, hi1 + back, hi0 + back]),
		base.lightened(0.12))
	draw_colored_polygon(Iso.rounded(PackedVector2Array([lo0, lo1, hi1, hi0]), 2.5), base)

	# 貼り紙は手前の面に貼る
	var n: int = mini(posts.size(), 6)
	for i in range(n):
		var col := i % 3
		var row := i / 3
		var u := 0.09 + float(col) * 0.29
		var h := 0.17 + float(row) * 0.40
		var paper := Color(0.94, 0.92, 0.84)
		if posts[posts.size() - 1 - i]["author_id"] == -1:
			paper = Color(0.99, 0.86, 0.55)
		_draw_paper(u, h, 0.23, 0.33, paper)


## 手前の面を (u, v) で見た位置。u は板に沿う向き、v は高さ。
func _face_point(u: float, h: float) -> Vector2:
	var v := _along()
	var lo0 := Vector2(0, BASE_Y) - v
	return lo0 + v * 2.0 * u + Vector2(0, -PANEL_H * h)


func _draw_paper(u: float, h: float, w: float, ht: float, col: Color) -> void:
	draw_colored_polygon(Iso.rounded(PackedVector2Array([
		_face_point(u, h), _face_point(u + w, h),
		_face_point(u + w, h + ht), _face_point(u, h + ht),
	]), 1.6), col)
	for k in range(2):
		var t := h + ht * (0.34 + float(k) * 0.33)
		draw_line(_face_point(u + 0.04, t), _face_point(u + w - 0.04, t),
			Color(0.45, 0.45, 0.45, 0.8), 1.0)
