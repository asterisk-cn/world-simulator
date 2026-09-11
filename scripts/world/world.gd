class_name World
extends Node2D
## 地形・資源・建造物・村人の保持と、村人の「知覚」に答えるクエリ群。

const GRID_W := 28
const GRID_H := 28

const GROUND_COLORS := [
	Color(0.38, 0.55, 0.30),
	Color(0.34, 0.51, 0.28),
	Color(0.45, 0.58, 0.33),
	Color(0.52, 0.47, 0.34),
	Color(0.40, 0.57, 0.32),
]

var ground := []
var entities: Node2D
var harvests: Array = []
var structures: Array = []
var villagers: Array = []
var board: BulletinBoard

## 建物は通り抜けられない（持ち主だけは中を通れる）。建物どうしの間は必ず空いているのでそこを通る。
var astar := AStarGrid2D.new()

# ---------------------------------------------------------------------------
# 世界が組み上がる。
#
# 作り直しをぱっと入れ替えると、世界が生まれた感じにならない——ただ絵が
# 差し替わっただけに見える。**積み木の世界なのだから、組み上がるべき。**
# 真ん中から波が広がって、地面が敷かれ、その後ろから物が生えてくる。
# ---------------------------------------------------------------------------

## 0 = まだ何も無い、1 = でき上がり。`main` が始める儀式で送る
var birth := 1.0:
	set(v):
		birth = v
		_grow()
		queue_redraw()

## 波の縁の厚み（島の半径の割合）。薄いと切り取り線に見え、
## 厚いと粒が散らばって網点に見える
const BIRTH_EDGE := 0.14

## 物は地面より少し遅れて生える。同時だと土から生えた感じにならない
const BIRTH_LAG := 0.10


# ---------------------------------------------------------------------------
# 下見の島が崩れる。
#
# 一斉に薄くして消すと「絵が差し替わった」に見える。**世界が壊れるのだから、
# ボロボロと落ちるべき。** マスごとにばらばらの間で落ちはじめ、
# 加速しながら下へ抜けて薄れる。
# ---------------------------------------------------------------------------

## 0 = そのまま、1 = ぜんぶ落ちた
var crumble := 0.0:
	set(v):
		crumble = v
		_grow()
		queue_redraw()

## 一枚が落ちきるまで（全体の割合）。短いと一斉に落ちて、長いと粘って見える
const CRUMBLE_SPAN := 0.30

## 薄れ方。**1 より大きくして終盤に寄せる**——位置は加速（`f²`）なのに
## 薄れが一定だと、ほとんど落ちないうちに半分透けて、
## 落ちる前に消えてしまう（＝落ちるのが早く見える）
const CRUMBLE_FADE := 2.2

## 落ちる距離（px）。画面の外まで抜ければいい
const CRUMBLE_FALL := 420.0

## 落ちはじめの偏り。**1 より小さいと、早く落ちるマスが少なくなる**——
## 一様だと始まった途端に3割が動き出して「一斉」に見える。
## 焼けと重ねて見せるので、始まりはポツポツでなければならない。
## 0.80 で、崩れが始まって 0.15 秒後に動き出しているのは 1.2%
const CRUMBLE_BIAS := 0.80


func _ready() -> void:
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	_generate_ground()
	_scatter_resources()
	_place_board()
	_setup_astar()
	queue_redraw()


## 世界を作り直す。村を終えて言葉のところへ戻るときに呼ばれる。
##
## 同じ島に別の村を建て直すのではなく、島も資源も新しくする。
## 前の村の跡が残った土地に次の言葉を置くと、そこが「同じ世界の続き」に見えてしまう。
## 土地を作り直す。
##
## `keep_people` を立てると**村人だけ残す**——儀式のあいだに先に置いて、
## AIへの問いを走らせておくため（`main._begin_ritual`）。
## 残した村人の居場所は、作り直したあとで呼ぶ側が置き直す
func regenerate(keep_people: bool = false) -> void:
	for c in entities.get_children():
		if keep_people and c is Villager:
			continue
		entities.remove_child(c)
		c.queue_free()
	harvests.clear()
	structures.clear()
	if not keep_people:
		villagers.clear()
	board = null

	ground.clear()
	astar.clear()
	_generate_ground()
	_scatter_resources()
	_place_board()
	_setup_astar()
	queue_redraw()


func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, GRID_W, GRID_H)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()


# ---------------------------------------------------------------------------
# 生成
# ---------------------------------------------------------------------------

func _generate_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.09
	ground.resize(GRID_W)
	for x in range(GRID_W):
		var col := []
		col.resize(GRID_H)
		for y in range(GRID_H):
			var n := noise.get_noise_2d(float(x), float(y))
			var t := 0
			if n > 0.35:
				t = 2
			elif n > 0.12:
				t = 4
			elif n < -0.42:
				t = 3
			elif n < -0.15:
				t = 1
			col[y] = t
		ground[x] = col


func _scatter_resources() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.16
	for x in range(GRID_W):
		for y in range(GRID_H):
			if _is_village_core(Vector2i(x, y)):
				continue
			var n := noise.get_noise_2d(float(x), float(y))
			var r := randf()
			if n > 0.28 and r < 0.55:
				_add_harvest(HarvestNode.Kind.TREE, Vector2i(x, y))
			elif n < -0.34 and r < 0.35:
				_add_harvest(HarvestNode.Kind.ROCK, Vector2i(x, y))
			elif r < 0.055:
				_add_harvest(HarvestNode.Kind.BERRY, Vector2i(x, y))


func _is_village_core(c: Vector2i) -> bool:
	var center := Vector2i(GRID_W / 2, GRID_H / 2)
	return absi(c.x - center.x) <= 2 and absi(c.y - center.y) <= 2


func _add_harvest(kind: int, cell: Vector2i) -> void:
	var h := HarvestNode.new()
	h.setup(kind, cell)
	entities.add_child(h)
	harvests.append(h)


func _place_board() -> void:
	board = BulletinBoard.new()
	board.setup(Vector2i(GRID_W / 2, GRID_H / 2))
	entities.add_child(board)


# ---------------------------------------------------------------------------
# 登録
# ---------------------------------------------------------------------------

func register_villager(v) -> void:
	entities.add_child(v)
	villagers.append(v)


## 建てられたものを世界に置く。何が建つかは神の定義（`Schema.buildings`）で決まる。
## **建てた人のものになる**（屋根がその人の色になる）。
## 持ち主のないもの（神が建てたもの）は owner_id を渡さない。
func add_structure(def_id: String, cell: Vector2i, owner_id: int = -1,
		color: Color = Color.WHITE) -> Structure:
	var s := Structure.new()
	s.setup(def_id, cell, owner_id, color)
	entities.add_child(s)
	structures.append(s)
	# 建物はどれも通り抜けられない
	for c in s.footprint():
		if in_bounds(c):
			astar.set_point_solid(c, true)
	return s


# ---------------------------------------------------------------------------
# 経路
# ---------------------------------------------------------------------------

func is_blocked(c: Vector2i) -> bool:
	return in_bounds(c) and astar.is_point_solid(c)


## from から to までの経路。建物は通り抜けられないが、**自分のものの中は通れる**。
func find_path(from_cell: Vector2, to_cell: Vector2, own_id: int = -1) -> PackedVector2Array:
	var a := Vector2i(roundi(from_cell.x), roundi(from_cell.y))
	var b := Vector2i(roundi(to_cell.x), roundi(to_cell.y))
	if not in_bounds(a) or not in_bounds(b):
		return PackedVector2Array([from_cell])

	# 自分のものは一時的に通れるようにする（中に入るため）
	var opened: Array = []
	if own_id >= 0:
		for s in structures:
			if s.owner_id != own_id:
				continue
			for c in s.footprint():
				if in_bounds(c) and astar.is_point_solid(c):
					astar.set_point_solid(c, false)
					opened.append(c)

	if astar.is_point_solid(a):
		a = _nearest_open(a)
	# 目的地が塞がっていたら手前で止まる
	var reachable := not astar.is_point_solid(b)
	if not reachable:
		b = _nearest_open(b)

	var pts := astar.get_point_path(a, b)

	for c in opened:
		astar.set_point_solid(c, true)

	if pts.is_empty():
		return PackedVector2Array([from_cell])
	# 通れる目的地なら、最後だけ本来の小数座標に寄せる
	if reachable:
		pts[pts.size() - 1] = to_cell
	return pts


func _nearest_open(c: Vector2i) -> Vector2i:
	for r in range(1, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if in_bounds(n) and not astar.is_point_solid(n):
					return n
	return c


## 建物のまわりで空いているマス
func free_cell_around(at: Vector2i) -> Vector2i:
	var ring := [
		Vector2i(2, 0), Vector2i(2, 1), Vector2i(-1, 0), Vector2i(-1, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, -1), Vector2i(1, -1),
	]
	for d in ring:
		var c: Vector2i = at + d
		if not in_bounds(c) or is_blocked(c):
			continue
		if board != null and board.cell == c:
			continue
		var taken := false
		for s in structures:
			if s.cell == c:
				taken = true
				break
		for h in harvests:
			if h.cell == c:
				taken = true
				break
		if not taken:
			return c
	return at + Vector2i(2, 1)


# ---------------------------------------------------------------------------
# クエリ（村人の知覚）
# ---------------------------------------------------------------------------

## その場所を村人の言葉で言う。「(10,14)」のような生の座標は
## 村人の発話としても神の読み物としても浮くので、掲示板や記録には出さない。
const COMPASS := ["北", "北東", "東", "南東", "南", "南西", "西", "北西"]


func place_name(cell: Vector2i) -> String:
	var origin := Vector2(GRID_W, GRID_H) * 0.5
	if board != null:
		origin = Vector2(board.cell)
	var d := Vector2(cell) - origin
	if d.length() < 4.0:
		return "村の真ん中"
	# 画面の上が北。セル座標では -x-y の向き。
	var ang := atan2(d.x + d.y, d.y - d.x)
	var i := int(round(ang / (TAU / 8.0))) % 8
	var near := "" if d.length() > 10.0 else "すぐ"
	return "%s村の%s%s" % [near, COMPASS[(i + 8) % 8], "のはずれ" if d.length() > 10.0 else ""]


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID_W and c.y < GRID_H


func nearest_harvest(from_cell: Vector2, kind: int, max_dist: float = 999.0) -> HarvestNode:
	var best: HarvestNode = null
	var best_d := max_dist
	for h in harvests:
		if h.kind != kind:
			continue
		var d := from_cell.distance_to(Vector2(h.cell))
		if d < best_d:
			best_d = d
			best = h
	return best


func building_at(c: Vector2i) -> Structure:
	for s in structures:
		if s.contains_cell(c):
			return s
	return null


## その建物のうち、いちばん近いもの。
## 同じものが何軒建つかは誰も決めていないので、「村のその1つ」を指す言い方はしない。
func nearest_building(def_id: String, from_cell: Vector2) -> Structure:
	var best: Structure = null
	var best_d := INF
	for s in structures:
		if s.def_id != def_id:
			continue
		var d: float = from_cell.distance_to(s.center_cell())
		if d < best_d:
			best_d = d
			best = s
	return best


## その人のものの中で、いちばん近いもの。「自分のところ」の行き先になる。
## 何軒持っているかは決まっていないので、「その人の1軒」を指す言い方はしない。
func nearest_owned(owner_id: int, from_cell: Vector2) -> Structure:
	var best: Structure = null
	var best_d := INF
	for s in structures:
		if s.owner_id != owner_id:
			continue
		var d: float = from_cell.distance_to(s.center_cell())
		if d < best_d:
			best_d = d
			best = s
	return best


## 名前から引く。**AIが答えるのは名前のほう**なので、世界の側で本人に戻す。
## 同じ名前が二人いたら最初の一人（名前は神が付けるので、重複を禁じていない）
func villager_by_name(name_text: String):
	var want := name_text.strip_edges()
	for v in villagers:
		if is_instance_valid(v) and String(v.vname) == want:
			return v
	return null


func villager_by_id(vid: int):
	for v in villagers:
		if v.id == vid:
			return v
	return null


func neighbors_within(from_cell: Vector2, radius: float, exclude_id: int) -> Array:
	var out: Array = []
	for v in villagers:
		if v.id == exclude_id:
			continue
		if from_cell.distance_to(v.cell) <= radius:
			out.append(v)
	return out


## 建てられる空きマス（村の中心から外へらせん状に探す）。
## 他の村人が立っているマスは避ける（上に建物が建ってしまうので）。
func find_build_cell(near: Vector2, builder_id: int = -1) -> Vector2i:
	var start := Vector2i(roundi(near.x), roundi(near.y))
	for radius in range(1, 14):
		var candidates: Array = []
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := start + Vector2i(dx, dy)
				if _can_build_at(c) and not _villager_on(c, builder_id):
					candidates.append(c)
		if not candidates.is_empty():
			return candidates.pick_random()
	return Vector2i(-1, -1)


## 敷地に他の村人が立っていないか
func _villager_on(c: Vector2i, ignore_id: int) -> bool:
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var cc: Vector2i = c + d
		for v in villagers:
			if v.id == ignore_id:
				continue
			if Vector2i(roundi(v.cell.x), roundi(v.cell.y)) == cc:
				return true
	return false


## 建物どうしが密着すると、通りかかっただけで「侵入」が起き続けてしまうので間隔を空ける
const BUILD_SPACING := 3


func _can_build_at(c: Vector2i) -> bool:
	for s in structures:
		for oc in s.footprint():
			if maxi(absi(oc.x - c.x), absi(oc.y - c.y)) < BUILD_SPACING:
				return false
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var cc: Vector2i = c + d
		if not in_bounds(cc):
			return false
		if building_at(cc) != null:
			return false
		if board and board.cell == cc:
			return false
		for h in harvests:
			if h.cell == cc:
				return false
	return true


# ---------------------------------------------------------------------------
# 描画
# ---------------------------------------------------------------------------

func _draw() -> void:
	for x in range(GRID_W):
		for y in range(GRID_H):
			var cell := Vector2(x, y)
			# 落ちきったマスはもう無い
			var f := _fallen(cell)
			if f >= 1.0:
				continue
			# **敷かれる前のマスは描かない。** 縁では小さいまま置いて、広がりながら
			# ひし形いっぱいになる——一枚ずつ置いていくように見える。
			# 小さすぎるひし形は四隅が原点に潰れて、三角形に割れない
			var u := _laid(cell) * (1.0 - f)
			if u <= 0.03:
				continue
			# 落ちるほど速く（加速）、そして薄れる
			var p := Iso.cell_to_world(cell) + Vector2(0, CRUMBLE_FALL * f * f)
			var col: Color = GROUND_COLORS[ground[x][y]]
			col.a = 1.0 - pow(f, CRUMBLE_FADE)
			var poly := PackedVector2Array()
			for pt in Iso.diamond(u):
				poly.append(pt + p)
			draw_colored_polygon(poly, col)
	if birth < 1.0 or crumble > 0.0:
		return   # 外周は、島がぜんぶ敷かれているときだけ引く
	# 外周
	var corners := PackedVector2Array([
		Iso.cell_to_world(Vector2(-0.5, -0.5)),
		Iso.cell_to_world(Vector2(GRID_W - 0.5, -0.5)),
		Iso.cell_to_world(Vector2(GRID_W - 0.5, GRID_H - 0.5)),
		Iso.cell_to_world(Vector2(-0.5, GRID_H - 0.5)),
	])
	draw_polyline(corners + PackedVector2Array([corners[0]]), Color(0.15, 0.18, 0.15, 0.7), 3.0)


## そのマスがどれだけ敷かれたか（0〜1）。真ん中から広がる波。
##
## 隔たりは**マス目の四角**で測る（縦横の大きいほう）。画面での距離で測ると
## 波が円になって、島の四隅だけが最後まで残る。四角なら島の形と同じ向きに
## 広がって、四隅が同時に埋まる
func _laid(cell: Vector2, lag: float = 0.0) -> float:
	if birth >= 1.0:
		return 1.0
	var mid := Vector2(GRID_W - 1, GRID_H - 1) * 0.5
	var off := (cell - mid).abs()
	var d: float = maxf(off.x, off.y) / maxf(mid.x, mid.y)
	return clampf((birth - lag - d * (1.0 - BIRTH_EDGE)) / BIRTH_EDGE, 0.0, 1.0)


## 位置から決まる乱れ（0〜1）。マスごとにばらばらの間で落ちはじめる
func _grit(cell: Vector2) -> float:
	var h := sin(cell.x * 12.9898 + cell.y * 78.233) * 43758.5453
	return h - floor(h)


## そのマスがどれだけ落ちたか（0〜1）
func _fallen(cell: Vector2) -> float:
	if crumble <= 0.0:
		return 0.0
	var start := pow(_grit(cell), CRUMBLE_BIAS) * (1.0 - CRUMBLE_SPAN)
	return clampf((crumble - start) / CRUMBLE_SPAN, 0.0, 1.0)


## 地面の波の後ろから物が生え、崩れるときは一緒に落ちる
func _grow() -> void:
	if entities == null:
		return
	for c in entities.get_children():
		if c is Node2D:
			var n := c as Node2D
			var cell := Iso.world_to_cell(n.position - Vector2(0,
				float(n.get_meta("fall", 0.0))))
			var u := _laid(cell, BIRTH_LAG)
			var f := _fallen(cell)
			if not n.has_meta("base_y"):
				n.set_meta("base_y", n.position.y)
			var drop := CRUMBLE_FALL * f * f
			n.set_meta("fall", drop)
			n.position.y = float(n.get_meta("base_y")) + drop
			n.scale = Vector2.ONE * u * (1.0 - f * 0.4)
			n.modulate.a = 1.0 - pow(f, CRUMBLE_FADE)
			n.visible = u > 0.01 and f < 1.0
