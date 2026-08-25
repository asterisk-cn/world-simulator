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

const HARVEST_KIND := {
	"berry": HarvestNode.Kind.BERRY,
	"tree": HarvestNode.Kind.TREE,
	"rock": HarvestNode.Kind.ROCK,
}

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
	return cands.pick_random()


## いまこの村人に実行可能な行動の一覧。AI版でもそのままAIへ渡す。
func feasible() -> Array:
	var out: Array = []
	for a in Schema.actions:
		if not bool(a["enabled"]):
			continue
		out.append_array(_candidates_for(a))
	return out


# ---------------------------------------------------------------------------
# 実現可能性の判定（プログラムの責務）
# ---------------------------------------------------------------------------

func _candidates_for(a: Dictionary) -> Array:
	var target := String(a["target"])
	match String(a["kind"]):
		"move":
			return _move(a, target)
		"gather":
			return _one(_gather(a, target))
		"build":
			return _one(_build(a, target))
		"use":
			return _one(_use(a, target))
		"social":
			return _social(a, target)
		"craft":
			return []
	return []


func _one(c) -> Array:
	return [] if c == null else [c]


func _pack(a: Dictionary, target_cell: Vector2, obj, label: String) -> Dictionary:
	return {
		"action_id": String(a["id"]), "kind": String(a["kind"]), "target": String(a["target"]),
		"target_cell": target_cell, "obj": obj, "label": label,
		"duration": Schema.duration_of(String(a["kind"]), String(a["target"])),
	}


# ---------------------------------------------------------------------------

func _move(a: Dictionary, target: String) -> Array:
	var out: Array = []
	match target:
		"anywhere":
			out.append(_pack(a, _random_spot(), null, String(a["label"])))
		"home":
			if v.home != null:
				out.append(_pack(a, Vector2(v.home.cell), null, String(a["label"])))
		"board":
			if v.world.board != null:
				out.append(_pack(a, Vector2(v.world.board.cell), null, String(a["label"])))
		"toward":
			for o in v.world.neighbors_within(v.cell, 14.0, v.id):
				out.append(_pack(a, o.cell, o, "%s に%s" % [o.vname, String(a["label"])]))
		"away":
			for o in v.world.neighbors_within(v.cell, 8.0, v.id):
				var d: Vector2 = v.cell - o.cell
				if d.length() < 0.01:
					d = Vector2(1, 0)
				var spot: Vector2 = v.cell + d.normalized() * 6.0
				spot.x = clampf(spot.x, 0.0, float(World.GRID_W - 1))
				spot.y = clampf(spot.y, 0.0, float(World.GRID_H - 1))
				out.append(_pack(a, spot, o, "%s から%s" % [o.vname, String(a["label"])]))
	return out


func _gather(a: Dictionary, target: String):
	if not HARVEST_KIND.has(target):
		return null
	var h = v.world.nearest_harvest(v.cell, HARVEST_KIND[target], 22.0)
	if h == null:
		return null
	return _pack(a, Vector2(h.cell), h, String(a["label"]))


func _build(a: Dictionary, target: String):
	if target != "house" or v.home != null:
		return null
	if int(v.inventory["wood"]) < Rules.BUILD_WOOD or int(v.inventory["stone"]) < Rules.BUILD_STONE:
		return null
	var c: Vector2i = v.world.find_build_cell(v.cell, v.id)
	if c.x < 0:
		return null
	var out := _pack(a, Vector2(c), null, String(a["label"]))
	out["build_cell"] = c
	return out


## 届く範囲か。遠ければそもそも候補に出さない（先に「動く」必要がある）
func _in_reach(a: Dictionary, at: Vector2) -> bool:
	var r := Schema.reach_of(String(a["kind"]), String(a["target"]))
	if r < 0.0:
		return true
	return v.cell.distance_to(at) <= r


func _use(a: Dictionary, target: String):
	match target:
		"food":
			if int(v.inventory["food"]) <= 0:
				return null
			return _pack(a, v.cell, null, String(a["label"]))
		"home":
			if v.home == null:
				return null
			var at: Vector2 = Vector2(v.home.cell) + Vector2(0.5, 0.5)
			if not _in_reach(a, at):
				return null
			return _pack(a, v.cell, null, String(a["label"]))
	return null


func _social(a: Dictionary, target: String) -> Array:
	var out: Array = []
	var board = v.world.board
	var reach := Schema.reach_of(String(a["kind"]), target)
	match target:
		"talk":
			for o in v.world.neighbors_within(v.cell, reach, v.id):
				out.append(_pack(a, v.cell, o, "%s と%s" % [o.vname, String(a["label"])]))
		"post":
			if board == null or int(v._last_post_day) == SimClock.day:
				return out
			if _in_reach(a, Vector2(board.cell)):
				out.append(_pack(a, v.cell, board, String(a["label"])))
		"read":
			if board == null or board.unread_for(v.memory).is_empty():
				return out
			if _in_reach(a, Vector2(board.cell)):
				out.append(_pack(a, v.cell, board, String(a["label"])))
	return out


func _random_spot() -> Vector2:
	var r := randf_range(2.0, 7.0)
	var ang := randf() * TAU
	var tc: Vector2 = v.cell + Vector2(cos(ang), sin(ang)) * r
	tc.x = clampf(tc.x, 0.0, float(World.GRID_W - 1))
	tc.y = clampf(tc.y, 0.0, float(World.GRID_H - 1))
	return tc


## アクションが一つも成立しなかったときに立ち尽くさないための保険。
func _fallback() -> Dictionary:
	return {
		"action_id": "", "kind": "move", "target": "anywhere",
		"target_cell": _random_spot(), "obj": null, "duration": 0.8, "label": "手持ち無沙汰",
	}
