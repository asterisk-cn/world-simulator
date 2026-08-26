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


# 板の寸法。他のものと同じく角丸ブロックで組む。
const PANEL_W := 26.0
const PANEL_D := 4.5
const PANEL_H := 27.0
const PANEL_OFF := Vector2(0, -17.0)


func _draw() -> void:
	Iso.draw_shadow(self, 0.8, 0.2)

	# 支柱。斜めの向きに合わせて少しずらして立てる。
	var post := Color(0.44, 0.31, 0.20)
	Iso.draw_block(self, 3.2, 1.6, 19.0, post, Vector2(-19.0, 2.0), 1.5)
	Iso.draw_block(self, 3.2, 1.6, 19.0, post, Vector2(19.0, -2.0), 1.5)

	# 板
	Iso.draw_block(self, PANEL_W, PANEL_D, PANEL_H, Color(0.66, 0.49, 0.30), PANEL_OFF, 4.0)

	# 貼り紙は板の手前の面に貼る
	var n: int = mini(posts.size(), 6)
	for i in range(n):
		var col := i % 3
		var row := i / 3
		var u := 0.10 + float(col) * 0.28
		var v := 0.16 + float(row) * 0.40
		var paper := Color(0.94, 0.92, 0.84)
		if posts[posts.size() - 1 - i]["author_id"] == -1:
			paper = Color(0.99, 0.86, 0.55)
		_draw_paper(u, v, 0.22, 0.32, paper)


## 板の手前の面を (u, v) の座標系で見て、そこに小さな紙を貼る
func _face_point(u: float, v: float) -> Vector2:
	var inner := PANEL_OFF + Vector2(0, PANEL_D - PANEL_H)
	return inner + Vector2(PANEL_W, -PANEL_D) * u + Vector2(0, PANEL_H) * v


func _draw_paper(u: float, v: float, w: float, h: float, col: Color) -> void:
	var quad := PackedVector2Array([
		_face_point(u, v), _face_point(u + w, v),
		_face_point(u + w, v + h), _face_point(u, v + h),
	])
	draw_colored_polygon(Iso.rounded(quad, 1.6), col)
	# 文字に見立てた線
	for k in range(2):
		var t := 0.32 + float(k) * 0.34
		draw_line(_face_point(u + 0.04, v + h * t), _face_point(u + w - 0.04, v + h * t),
			Color(0.45, 0.45, 0.45, 0.8), 1.0)
