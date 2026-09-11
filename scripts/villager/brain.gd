class_name Brain
extends RefCounted
## キャラクターの判断の置き場所。
##
## **何をするかはAIが選ぶ**（`choose`）。繋がっていなければ、
## 実行可能な行動からランダムに1つ返す——世界は止めない。
##
## プログラムの責務は「いま何ができるか」を列挙することと、選ばれたものを実行すること。
## 候補の列挙（実現可能性の判定）はAI版でもここに残る。AIには
## 「いまできることの一覧」と自分の文脈が渡り、どれを選ぶかを答える。
##
## ただし次の2つは一覧に含まれない。どちらもその人の言葉と判断だから。
##   - 持ち物がどう動くか（`_how_much`）——いくつ取るか、何をどれだけ使うか
##   - それを何と呼ぶか（`_name_act`）——名前の定義は世界のどこにも無い

var v = null  ## Villager（循環参照を避けるため型注釈なし）

## 中身の失敗で一度訊き直したか。二度は繰り返さない
var _retried := false

## 二度とも駄目だったときに、次に訊くまでの間（秒）
const RETHINK := 2.0

## 1回の問いで答えてもらう手の数。**長すぎると決め打ちになる**——
## 途中で起きたことを無視して動き続ける人は、判断していないのと同じ
const PLAN_MAX := 3

## これからするつもり。[{kind, target, obj, said}]
var _plan: Array = []


func _init(p_villager) -> void:
	v = p_villager


# ---------------------------------------------------------------------------
# 【AI差し替え口】いま何をするか
#
# AI版ではここに、実行可能な候補・自分のパラメータ・相手ごとのパラメータ・
# 性格・記憶を渡し、どれを選ぶか（あるいは何もしないか）を答えさせる。
# ---------------------------------------------------------------------------

## いま始める行動を返す。**空を返したら、立ち止まって待つ。**
## 返事が来たら `Villager.begin()` が呼ばれて、その場で切り替わる。
##
## **つもりが立っていれば、その次の手を始める。** 尽きたら訊いて、立ち止まって待つ。
## 代わりに適当な手で動かすと、**プログラムが判断していること**になる——
## それはこの作品が引いている一線（DESIGN.md §1）の向こう側で、
## 遅さを隠すために越えていい線ではない。
##
## **当てずっぽうに落ちるのは、AIが居ないときだけ**（`AI.available()` が false）。
## 答えが読めなかったのはAIの失敗で、村人の気まぐれではない——
## そこを当てずっぽうにすると、モデルの調子が悪い日ほど村人がふらふらして見える。
func choose() -> Dictionary:
	var cands := feasible()
	if cands.is_empty():
		return _fallback()

	# つもりが立っていれば、その次の手を始める
	var step := _from_plan(cands)
	if not step.is_empty():
		# **最後の手を始めたら、そこで次のつもりを訊いておく。**
		# 手を動かしているあいだに考えが戻るので、待ちが隠れる
		if _plan.is_empty():
			_ask(cands)
		return step

	# つもりが尽きた。AIが居れば訊いて待つ（立ち止まる）
	if v.asking:
		return {}
	if _ask(cands):
		return {}
	if AI.available():
		return {}   # 訊けなかっただけ。次のきっかけで訊き直す
	var r := _pick(cands.pick_random())
	r["by"] = "ランダム"
	return r


## つもりの次の手を、いまの世界で始められる形にする。
## **成り立たなければ、つもりごと捨てる**——着いてみたら相手が居ない、
## 持っていたはずのものが無い。そこから先の順番も、もう本人の考えと合わない
func _from_plan(cands: Array) -> Dictionary:
	while not _plan.is_empty():
		var step: Dictionary = _plan.pop_front()
		var who = step.get("obj", null)
		if who != null and not is_instance_valid(who):
			_plan.clear()
			return {}
		for e in cands:
			var c: Dictionary = e
			if String(c["kind"]) != String(step["kind"]) \
					or String(c["target"]) != String(step["target"]):
				continue
			# **相手が決まっている手は、その相手でなければ別の手**（誰と話すかは違う話）。
			# 決まっていない手（適当な場所へ、木を使う）は、
			# いま立っているものに読み替える——「どの木か」は本人も見ていない
			if who != null and c.get("obj", null) != who:
				continue
			if String(step.get("said", "")) != "":
				c["said"] = String(step["said"])
			var got := _pick(c)
			got["by"] = "AI"
			return got
		_plan.clear()   # この手が成り立たないなら、続きも合わない
		return {}
	return {}


## 身に何か起きた。つもりは白紙にする（`Villager.stirred`）
func forget_plan() -> void:
	_plan.clear()


## 検証用の通し番号。どの手がどこから来たかを数えるためだけに持つ
static var _serial := 0


## 選んだ1つを、始められる形にする
func _pick(c: Dictionary) -> Dictionary:
	_decide_how(c)
	_serial += 1
	c["serial"] = _serial
	return c


## AIに訊く。受け付けられたら true（答えは後から `Villager.begin()` へ）。
##
## 答えが読めなかったときはその場でランダムに落として始める——
## **答えが来ない相手を待ち続けると、村人は二度と動かない。**
func _ask(cands: Array) -> bool:
	if not AI.available() or cands.size() <= 1:
		return false
	var asked := cands
	var take := func(text: String) -> void:
		if not is_instance_valid(v):
			return
		v.asking = false
		var read := _read(text, asked)
		if read.is_empty():
			_missed(asked)
			return
		_retried = false
		_plan = read["つもり"]
		# 立ち止まって待っていたなら、その場で動き出す。
		# 手を動かしている最中なら、つもりのまま置いておく
		if v.action_phase == "think":
			v.begin(choose())
	v.asking = AI.ask(_prompt(asked), _system(), take, AI.MAX_OUT, true, v.id)
	return v.asking


## **中身の失敗**（空・読めない・番号が範囲外）。もう一度だけ訊く——
## 引き直せばたいてい通る。2度目も駄目なら立ち止まって、次のきっかけを待つ。
## 当てずっぽうにはしない（AIは居るのだから、村人のせいにしない）
func _missed(asked: Array) -> void:
	if not _retried:
		_retried = true
		if _ask(asked):
			return
	_retried = false
	if v.action_phase == "think":
		v.action_phase = "idle"
		v.think_again_at = AI._now() + RETHINK


## 答えを読む。**使えなければ空**を返す（読めなかったのはAIの失敗で、
## 村人の気まぐれではない）。返るのは `{"つもり": [手, ...]}`
func _read(text: String, cands: Array) -> Dictionary:
	if text == "":
		return {}
	# **読めない答えで騒がない。** `JSON.parse_string` は失敗を標準エラーに吐くので、
	# 繋がらない機械では毎回それが出る。ここでは「読めなかった」で十分
	var j := JSON.new()
	if j.parse(text) != OK or typeof(j.data) != TYPE_DICTIONARY:
		if EventLog.echo:
			print("[AI] 読めない答え: ", text.substr(0, 120))
		return {}
	var got: Dictionary = j.data
	# **形にうるさくしない。** 頼んだ形（`{"つもり": [...]}`）で返らないことがある——
	# 手が1つだけ、番号だけの列、いきなり中身。読める形はどれも読む
	var steps = got.get("つもり", null)
	if typeof(steps) != TYPE_ARRAY:
		steps = [got] if got.has("番号") else null
	if typeof(steps) != TYPE_ARRAY or steps.is_empty():
		return {}
	var plan: Array = []
	for e in steps:
		if plan.size() >= PLAN_MAX:
			break
		var n := -1
		var said := ""
		if typeof(e) == TYPE_DICTIONARY:
			n = int(e.get("番号", 0)) - 1
			said = String(e.get("呼び名", "")).strip_edges()
		elif typeof(e) == TYPE_FLOAT or typeof(e) == TYPE_INT:
			n = int(e) - 1
		if n < 0 or n >= cands.size():
			continue
		var c: Dictionary = cands[n]
		# 名前は**その人の言葉**。長い説明が返ったら頭だけ使う
		plan.append({
			"kind": String(c["kind"]), "target": String(c["target"]),
			"obj": c.get("obj", null),
			"said": said.substr(0, NAME_MAX),
		})
	if plan.is_empty():
		if EventLog.echo:
			print("[AI] つもりが読めない: ", text.substr(0, 120))
		return {}
	return {"つもり": plan}


const NAME_MAX := 16


static func _system() -> String:
	return """あなたは、ある村に住む一人の人間です。
渡された姿と「いまできること」を読んで、**この先することを順に**答えます。

返すのは JSON の物1つだけ。
{"つもり": [{"番号": できることの番号, "呼び名": "それを自分ならどう言うか"}, ...]}

- つもりは1つから%d つまで。先のことほど大まかでいい
- 番号は一覧にあるものから選ぶ。無いものは選べない。同じ番号を続けてもよい
- 呼び名は%d字以内。世界の言い方をなぞらなくていい——
  教会へ向かうのを「詣でる」と言うか「行く」と言うかは、あなたが決めること
- 説明も理由も書かない""" % [PLAN_MAX, NAME_MAX]


func _prompt(cands: Array) -> String:
	var out := PackedStringArray()
	out.append(Inner.of(v))
	out.append("")
	out.append("# いまできること")
	for i in range(cands.size()):
		out.append("%d. %s%s" % [i + 1, _name_act(cands[i]), _far(cands[i])])
	out.append("")
	out.append("この先%d手まで、するつもりのことを順に。" % PLAN_MAX)
	return "\n".join(out)


## どれくらい歩くか。**距離は事実**なので添えてよい（判断ではない）
func _far(c: Dictionary) -> String:
	var d: float = v.cell.distance_to(c.get("target_cell", v.cell))
	if d < 1.5:
		return ""
	return "（少し歩く）" if d < 8.0 else "（遠い）"


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
	# 何をしているのかが、そのまま世界の上と記録と一覧に出る。
	# 本人が名前を言っていればそれを使う（`said`）
	c["label"] = String(c["said"]) if c.has("said") else _name_act(c)


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
				return "%sのところへ向かう" % other_name
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
		if s != null:
			# **歩きは手の中**。遠いからと候補から外すと、
			# 「向かう」と「使う」で2回訊くことになる（`_reach_cell`）
			out.append(_use_pack(target, s.center_cell(), s, "building"))
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
			# **誰とでも話せる。遠ければ歩いてから話す**（歩きは手の中）。
			# 世界の規則としての間合いは残っていて（着かないと話は起きない）、
			# 変わったのは「近い人しか候補に立たない」のをやめたこと
			for o in v.world.villagers:
				if o != null and is_instance_valid(o) and o.id != v.id:
					out.append(_pack("talk", target, o.cell, o, way))
		"post":
			if board == null or int(v._last_post_day) == SimClock.day:
				return out
			out.append(_pack("talk", target, Vector2(board.cell), board, way))
		"read":
			if board == null or board.unread_for(v.memory).is_empty():
				return out
			out.append(_pack("talk", target, Vector2(board.cell), board, way))
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
