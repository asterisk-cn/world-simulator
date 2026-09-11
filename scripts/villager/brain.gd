class_name Brain
extends RefCounted
## キャラクターの判断の置き場所。
##
## 【前提】判断はAIが行う。
## いまここに判断は一つも実装されていない。choose() は実行可能な行動から
## ランダムに1つ返すだけで、パラメータを読まないし動かしもしない。
## AIを繋いだときに、この穴がそのまま埋まる。
##
## プログラムの責務は「いま何ができるか」を列挙することと、選ばれたものを実行すること。
## 候補の列挙（実現可能性の判定）はAI版でもここに残る。AIには
## 「いまできることの一覧」と自分の文脈が渡り、どれを選ぶかを答える。
##
## ただし次の2つは一覧に含まれない。どちらもその人の言葉と判断だから。
##   - 持ち物がどう動くか（`_how_much`）——いくつ取るか、何をどれだけ使うか
##   - それを何と呼ぶか（`_name_act`）——名前の定義は世界のどこにも無い

var v = null  ## Villager（循環参照を避けるため型注釈なし）


func _init(p_villager) -> void:
	v = p_villager


# ---------------------------------------------------------------------------
# 【AI差し替え口】いま何をするか
#
# AI版ではここに、実行可能な候補・自分のパラメータ・相手ごとのパラメータ・
# 性格・記憶を渡し、どれを選ぶか（あるいは何もしないか）を答えさせる。
# ---------------------------------------------------------------------------

func choose() -> Dictionary:
	var cands := feasible()
	if cands.is_empty():
		return _fallback()
	var c: Dictionary = cands.pick_random()
	_decide_how(c)
	return c


## いまこの村人に実行可能な行動の一覧。AI版でもそのままAIへ渡す。
## 型 × 対象がそのままアクションなので、定義された一覧を引くのではなく毎回組み立てる。
func feasible() -> Array:
	var out: Array = []
	for kind in Schema.BEHAVIORS:
		var k := String(kind)
		for target in Schema.targets_of(k):
			out.append_array(_candidates(k, String(target)))
	return out


# ---------------------------------------------------------------------------
# 【AI差し替え口】選んだ行動を、どうやるか
#
# 選ぶのと同じ一回の判断で答えられるもの。AI版では自分の持ち物と文脈を見て、
#   持ち物がどう動くか … いくつ取るか、何をどれだけ使うか
#   それをどう呼ぶか   … 教会なら「祈る」「懺悔する」、木の実なら「かじる」
# を返す。プログラムはその答えを世界に適用するだけで、中身を決めない。
# ---------------------------------------------------------------------------

func _decide_how(c: Dictionary) -> void:
	var kind := String(c["kind"])
	if kind == "use" or kind == "make":
		c["move"] = _how_much(c)
	# 何をしているのかが、そのまま世界の上と記録と一覧に出る
	c["label"] = _name_act(c)


## 【AI差し替え口】この行動で、自分の持ち物がどう動くか。
##
##   正 … 受け取る（そこに在るものを取る / 作ったものを手にする）
##   負 … 払う（使う / 材料にする）
##   空 … 何も動かない（教会に入る）、あるいは「できない」という答え
##
## AI版では「木を2本と石を1つあれば家になる」「熟れているから3つもいでおく」
## のような判断がここに入る。**建物から何が受け取れるかもここ。**
## 井戸と水がこの世界に並んでいるなら、汲めることは名前を読めば分かるので、
## どこにも設定は要らない。いまは判断がないので、適当な数を言うだけ。
##
## プログラムはこの答えを、世界が許すところまで実際に動かす（`Villager._apply`）。
## 見ているのは「無いものは払えない」「無から物は生まれない」の2つだけ。
func _how_much(c: Dictionary) -> Dictionary:
	var target := String(c["target"])
	match String(c["kind"]):
		"use":
			match String(c.get("where", "hand")):
				"world":
					return {target: randi_range(1, 2)}
				"hand":
					return {target: -1}
			# 建物：何が受け取れるかは名前を読まないと分からないので、いまは何も動かさない
			return {}
		"make":
			var move := _spend_from_hand(target)
			if move.is_empty():
				return {}
			if not Schema.is_building(target):
				move[target] = 1  # 建物は世界の上に建つので、持ち物にはならない
			return move
	return {}


## 手持ちから払うぶんを見繕う。判断ではなく、穴を埋めるための出まかせ。
func _spend_from_hand(product: String) -> Dictionary:
	var cost := {}
	for item in v.inventory:
		var iid := String(item)
		if iid == product or v.item_count(iid) <= 0:
			continue
		var n := randi_range(0, mini(v.item_count(iid), 3))
		if n > 0:
			cost[iid] = -n
	if cost.is_empty():
		var held := _held_but(product)
		if held.is_empty():
			return {}
		cost[held.pick_random()] = -1
	return cost


## 【AI差し替え口】いま自分がしていることを、なんと呼ぶか。
##
## 世界にあるのは「型 × 対象」だけで、行動の名前はどこにも定義されていない。
## 教会に向かうのが「詣でる」なのか、木の実を使うのが「食べる」なのかは、
## そのつどその人が決めること。AI版はここで一言を返す。
## いまは判断がないので、世界の言い方をそのまま短く言うだけ。
func _name_act(c: Dictionary) -> String:
	var who = c.get("obj", null)
	var other_name := String(who.vname) if who != null and who is Villager else ""
	var thing := Schema.target_label(String(c["kind"]), String(c["target"]))
	match String(c["kind"]):
		"move":
			if String(c["target"]) == "toward":
				return "%sのそばに向かう" % other_name
			return "%sに向かう" % thing
		"use":
			return "%sを使う" % thing
		"make":
			return "%sを%s" % [thing, "建てる" if Schema.is_building(String(c["target"]))
				else "作る"]
		"talk":
			if String(c["target"]) == "talk":
				return "%sと話す" % other_name
			return thing
	return thing


## 手持ちのうち、それ自身を除いたもの
func _held_but(product: String) -> Array:
	var out: Array = []
	for item in v.inventory:
		if String(item) != product and v.item_count(String(item)) > 0:
			out.append(String(item))
	return out


# ---------------------------------------------------------------------------
# 実現可能性の判定（プログラムの責務）
# ---------------------------------------------------------------------------

func _candidates(kind: String, target: String) -> Array:
	match kind:
		"move":
			return _move(target)
		"use":
			return _use(target)
		"make":
			return _one(_make(target))
		"talk":
			return _talk(target)
	return []


func _one(c) -> Array:
	return [] if c == null else [c]


func _pack(kind: String, target: String, target_cell: Vector2, obj,
		way: Dictionary) -> Dictionary:
	return {
		"kind": kind, "target": target,
		"target_cell": target_cell, "obj": obj,
		"label": "", "duration": float(way["duration"]),
	}


## 世界に元からある対象の間合い（動く / 話す）
func _way(kind: String, target: String) -> Dictionary:
	var d = Schema.target_def(kind, target)
	return {"duration": 1.0, "reach": -1.0} if d == null else d


## 届く範囲か。遠ければそもそも候補に出さない（先に「動く」必要がある）
func _in_reach(way: Dictionary, at: Vector2) -> bool:
	var r := float(way["reach"])
	if r < 0.0:
		return true
	return v.cell.distance_to(at) <= r


# ---------------------------------------------------------------------------

func _move(target: String) -> Array:
	var out: Array = []
	var way := _way("move", target)
	match target:
		"anywhere":
			out.append(_pack("move", target, _random_spot(), null, way))
		"mine":
			# 自分のもののうち、いちばん近いところ。持っていなければ行き先にならない
			var mine = v.world.nearest_owned(v.id, v.cell)
			if mine != null:
				out.append(_pack("move", target, mine.center_cell(), mine, way))
		"board":
			if v.world.board != null:
				out.append(_pack("move", target, Vector2(v.world.board.cell), null, way))
		"toward":
			for o in v.world.neighbors_within(v.cell, 14.0, v.id):
				out.append(_pack("move", target, o.cell, o, way))
		_:
			# 建っているものへ。まだ建っていなければ行き先にならない。
			var s = _building_for(Schema.move_building(target))
			if s != null:
				out.append(_pack("move", target, s.center_cell(), s, way))
	return out


## 使えるものは3通りある。同じ木の実でも、そこに生っているのと手の中にあるのとでは、
## 行く必要があるかと、世界の側で何が増えて何が減るかが違う。
##
## 候補には**どこに在るか**を添える。同じ「木の実を使う」が2つ並ぶとき、
## それを見分けるのは名前ではなく、そこに在るのか手の中にあるのかのほうだから。
func _use(target: String) -> Array:
	var out: Array = []
	if Schema.is_building(target):
		var s = _building_for(target)
		var bway: Dictionary = Schema.USE_WAYS["building"]
		if s != null and _in_reach(bway, s.center_cell()):
			out.append(_use_pack(target, v.cell, s, "building"))
		return out

	# そこに在るもの（採るのはこれ）
	var kind: int = HarvestNode.KIND_OF_ITEM.get(target, -1)
	if kind >= 0:
		var h = v.world.nearest_harvest(v.cell, kind, 22.0)
		if h != null:
			out.append(_use_pack(target, Vector2(h.cell), h, "world"))
	# 手の中のもの
	if v.item_count(target) > 0:
		out.append(_use_pack(target, v.cell, null, "hand"))
	return out


func _use_pack(target: String, at: Vector2, obj, where: String) -> Dictionary:
	var c := _pack("use", target, at, obj, Schema.USE_WAYS[where])
	c["where"] = where
	return c


## 何か持っていれば作れる。何を使うかは本人が決めるので、材料は見ない。
## 建つものに数の枠はない。見るのは置ける場所が空いているかだけ。
func _make(target: String):
	var way = Schema.target_def("make", target)
	if way == null or _held_but(target).is_empty():
		return null
	if not Schema.is_building(target):
		# 持てるものは手の中で完結するので移動はしない
		return _pack("make", target, v.cell, null, way)
	var c: Vector2i = v.world.find_build_cell(v.cell, v.id)
	if c.x < 0:
		return null
	var out := _pack("make", target, Vector2(c), null, way)
	out["build_cell"] = c
	return out


## その建物の実体。同じものが何軒あっても、いちばん近いところを指す。
func _building_for(def_id: String):
	if def_id == "":
		return null
	return v.world.nearest_building(def_id, v.cell)


func _talk(target: String) -> Array:
	var out: Array = []
	var board = v.world.board
	var way := _way("talk", target)
	match target:
		"talk":
			for o in v.world.neighbors_within(v.cell, float(way["reach"]), v.id):
				out.append(_pack("talk", target, v.cell, o, way))
		"post":
			if board == null or int(v._last_post_day) == SimClock.day:
				return out
			if _in_reach(way, Vector2(board.cell)):
				out.append(_pack("talk", target, v.cell, board, way))
		"read":
			if board == null or board.unread_for(v.memory).is_empty():
				return out
			if _in_reach(way, Vector2(board.cell)):
				out.append(_pack("talk", target, v.cell, board, way))
	return out


func _random_spot() -> Vector2:
	var r := randf_range(2.0, 7.0)
	var ang := randf() * TAU
	var tc: Vector2 = v.cell + Vector2(cos(ang), sin(ang)) * r
	tc.x = clampf(tc.x, 0.0, float(World.GRID_W - 1))
	tc.y = clampf(tc.y, 0.0, float(World.GRID_H - 1))
	return tc


## 行けるところも使えるものも一つも無いときに、立ち尽くさないための保険。
func _fallback() -> Dictionary:
	return {
		"kind": "move", "target": "anywhere", "target_cell": _random_spot(),
		"obj": null, "duration": 0.8, "label": "手持ち無沙汰",
	}
