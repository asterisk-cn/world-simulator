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


func _draw() -> void:
	draw_colored_polygon(Iso.diamond(0.8), Color(0, 0, 0, 0.2))
	# 支柱
	draw_rect(Rect2(-16, -20, 5, 22), Color(0.36, 0.25, 0.16))
	draw_rect(Rect2(11, -20, 5, 22), Color(0.36, 0.25, 0.16))
	# 板
	var board := PackedVector2Array([
		Vector2(-26, -54), Vector2(26, -54), Vector2(26, -18), Vector2(-26, -18)
	])
	draw_colored_polygon(board, Color(0.55, 0.40, 0.24))
	draw_polyline(board + PackedVector2Array([board[0]]), Color(0.30, 0.21, 0.12), 2.0)
	# 貼り紙
	var n: int = mini(posts.size(), 6)
	for i in range(n):
		var col := i % 3
		var row := i / 3
		var x := -22.0 + float(col) * 15.0
		var y := -50.0 + float(row) * 16.0
		var paper := Color(0.94, 0.92, 0.84)
		if posts[posts.size() - 1 - i]["author_id"] == -1:
			paper = Color(0.99, 0.86, 0.55)
		draw_rect(Rect2(x, y, 12.0, 13.0), paper)
		draw_line(Vector2(x + 2, y + 4), Vector2(x + 10, y + 4), Color(0.4, 0.4, 0.4), 1.0)
		draw_line(Vector2(x + 2, y + 7), Vector2(x + 9, y + 7), Color(0.4, 0.4, 0.4), 1.0)
		draw_line(Vector2(x + 2, y + 10), Vector2(x + 10, y + 10), Color(0.4, 0.4, 0.4), 1.0)
