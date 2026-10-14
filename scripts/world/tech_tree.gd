class_name TechTree
## 【AI差し替え口】この世界の技術ツリー。物ごとの手に入れかた（材料と場所）を Jev に訊く。
##
## 神が決めるのは**何が在りうるか**（名前と姿）まで。それを何から、どこで手に入れるかは
## 神には見せず、**世界が始まるときに Jev が答える**（物ごとに1回、全部同時に）。同じ設計図でも、
## 始めるたびにツリーは変わる。神が後から物を足しても、次に始めるときに組み込まれる。
##
## 木の実・木・石（島に在るもの、`Schema.WORLD_ARTS`）は根なので訊かない
## （茂み・木・岩で、材料なし）。神が消した根は、島にも木にも無い。
##
## **世界が見るのは今と同じ規則だけ**（`Schema.set_input` / `set_place`）。
##   輪になる答え … 成り立たないので、その枝だけ落ちる（先に答えた枝が残る）
##   採る物の「どこでも」 … 手に入らないので読まない（場所は確率の高い順に、次のものを取る）
##   それ以外で手に入らない枝 … その世界では手に入らない物になる。答えなので直さない
##
## 【FutureWork】世界に1本のツリーではなく、一人ひとりが自分の作り方を持つ（DESIGN.md §12）。

## **Jev には物ごとに1回。** 持ち物には「その場所で採る物か、材料から作る物か」と場所、
## どれにも材料が何種類かと要る材料を訊く。数は Jev には訊かない（`_ask_counts`）。
##
## ここまでに試して分かったこと（Jev の確率をそのまま見た）：
## - 「要らない／1つ／…／4つ」を1本の物差しにすると、確率が「要らない」と「1つ」に寄る
## - 要るか・いくつかを分けると、数の分布は材料が何であっても同じ形で返る（Jev は数を読まない）
## - 材料を順に選ばせると、材料どうしの順位は筋が通る（パンなら木の実、ハンマーなら石）が、
##   選択肢に「要らない」があると、パンでも 0.80 でそれを選ぶ
## だから「要らない」かどうかは、材料の問いとは別の問いにする。

## 採るか、作るか
const WAYS := {"1": "その場所で採る（材料は要らない）", "2": "材料から作る"}

## 材料が何種類か。**「いちばん要る材料」「次に要る材料」…と順に訊いて2番目に
## 「もう要らない」を置くと、毎回それが勝ち、材料がどの物も1種類になった。**
## 何種類かは別の問いにして、材料は1つの問いの**確率の高い順に**その数だけ取る
## （順位を別々の問いにすると、どれにも同じ一番が選ばれて重なる）
const KINDS := {"1": "1種類", "2": "2種類", "3": "3種類"}

## 場所の選択肢で「どこでも」を表す言葉
const ANYWHERE := "どこでも（手の中で済む）"


## 訊く。答えが返って木を組み終えたら `on_done.call(true)`、
## 1つでも返らなかったら `on_done.call(false)`。Jev が使えなければ訊かずに false を返す。
##
## **物ごとに1回ずつ、全部同時に投げる。** 1回にまとめると問いが100を超え、
## 答えが「要らない」側に倒れた。待ち時間は1回ぶんとほぼ変わらない
##
## `fresh_only` は夜に書き足したとき（DESIGN.md §7）。**まだ固まっていない物だけ**を訊き、
## 固まった物の枝は組み直さない——村人がもう覚えている作り方が、夜のうちに変わってしまう。
## 新しい物は固まった物を材料や場所に指せるが、逆は起きないので輪にはならない
static func grow(on_done: Callable, fresh_only: bool = false) -> bool:
	var things := _things(fresh_only)
	# 訊く物が無ければ、Jev が使えなくても組み終えている
	if things.is_empty():
		on_done.call(true)
		return true
	if not AI.can_decide():
		return false
	var places := _places()
	## 物のid → {"way": "採る"/"作る", "places": [場所…], "inputs": [材料のid…], "want": 種類の数}
	## 場所も材料も**確率の高い順の並び**のまま持つ。輪になる答えは、木に入れるときに
	## 次の答えへ置き換える（`_apply`）
	var got := {}
	_ask_all(things, func(tid: String) -> Dictionary: return _questions(tid, places),
		func(tid: String, ans: Dictionary, asked: Dictionary) -> void:
			var c: Dictionary = asked["choices"]
			var g := {}
			if c.has("場所"):
				g["way"] = _pick(ans.get("採るか作るか", null), c["採るか作るか"])
				# **採る物は「どこでも」を飛ばす。** 材料も場所も無いと手に入らないので、
				# 場所は Jev が返す確率の高い順に見て、「どこでも」でない最初のものを取る
				var ranked := _ranked(ans.get("場所", null), c["場所"])
				if String(g["way"]) == "採る":
					ranked = ranked.filter(func(p): return String(p) != "")
				if ranked.is_empty():
					# 採れる場所が1つも無い世界（根が全部消され、建物も無い）。作る物として扱う
					g["way"] = "作る"
					ranked = [""]
				g["places"] = ranked
			# 材料は確率の高い順に、答えた種類の数だけ取る（採る物では読まない、`_apply`）
			var kinds = _pick(ans.get("材料の種類", null), c["材料の種類"])
			g["want"] = 1 if kinds == null else int(kinds)
			g["inputs"] = _ranked(ans.get("材料", null), c["材料"])
			got[tid] = g,
		func(ok: bool) -> void:
			if not ok:
				on_done.call(false)
				return
			_apply(got, things)
			# 2段目：数だけを文章のモデルに
			_ask_counts(things, func() -> void: on_done.call(true)))
	return true


## **数だけは文章のモデル（gpt-4o-mini）に訊く。** Jev は数を読まなかった
## （どの材料でも同じ分布が返った）。文章のモデルは名前の知識で数を出せる
## （家に木4・石2）が、手に入れかたを丸ごと任せると、一覧に無い物を書いたり
## （パンに小麦）、採る物に場所を付けずに手に入らなくしたりした。
## だから**何を・どこでは Jev、いくつかだけ文章のモデル**に分ける。
##
## 答えの形は JSON Schema で縛る（`AI.ask` の `shape`）——物の名前も材料の名前も
## Jev が選んだものだけ、数は 1〜4 だけ。文で縛っても守られなかったところ。
## 繋がっていない／返らないときは、数は1つのまま始める（何を・どこでは揃っているので）
const COUNT_MAX := 4

static func _ask_counts(things: Array, done: Callable) -> void:
	var makes: Array = things.filter(func(t): return not Schema.inputs_of(String(t)).is_empty())
	if makes.is_empty() or not AI.available():
		done.call()
		return
	var props := {}
	var lines := PackedStringArray()
	var by_label := {}    ## 名前 → 物のid（答えを戻すため）
	for t in makes:
		var tid := String(t)
		var name := _label(tid)
		by_label[name] = tid
		var mats := {}
		var names: Array = []
		for m in Schema.inputs_of(tid):
			var ml := Schema.item_label(String(m))
			mats[ml] = {"type": "integer", "enum": range(1, COUNT_MAX + 1)}
			names.append(ml)
		props[name] = {"type": "object", "additionalProperties": false,
			"required": mats.keys(), "properties": mats}
		lines.append("・%s（%s）… %s" % [name,
			"建てる" if Schema.is_building(tid) else "1つ作る", "・".join(names)])
	var shape := {"type": "object", "additionalProperties": false,
		"required": props.keys(), "properties": props}
	var sys := "ある村の世界で、物を作るのに材料がいくつ要るかを決めます。\n" \
		+ "何を材料にするかは決まっています。それぞれの材料について、1つ作る（建てる）たびに\n" \
		+ "いくつ減るかを 1〜%d で答えます。" % COUNT_MAX
	var prompt := "# 作る物と、その材料\n%s" % "\n".join(lines)
	var take := func(text: String) -> void:
		if EventLog.echo:
			print("[ツリー] 数の答え：%s" % (text if text != "" else "（返らなかった：%s）" % AI.last_error))
		var ans = JSON.parse_string(text) if text != "" else null
		if typeof(ans) == TYPE_DICTIONARY:
			for name in ans:
				var tid := String(by_label.get(String(name), ""))
				var counts = ans[name]
				if tid == "" or typeof(counts) != TYPE_DICTIONARY:
					continue
				for m in Schema.inputs_of(tid).keys():
					var ml := Schema.item_label(String(m))
					if counts.has(ml):
						Schema.set_input(tid, String(m),
							clampi(int(counts[ml]), 1, COUNT_MAX))
		if EventLog.echo:
			for t in makes:
				print("[ツリー] %s の数 ← %s" % [_label(String(t)), Schema.recipe_text(String(t))])
		done.call()
	if not AI.ask(prompt, sys, take, 400, true, -1, shape):
		done.call()


## いくつかの物について、同時に1回ずつ訊く。全部返ったら `done(ok)`。
## 1つでも返らなければ ok は false
static func _ask_all(ids: Array, make_q: Callable, read: Callable, done: Callable) -> void:
	if ids.is_empty():
		done.call(true)
		return
	var left := [ids.size()]
	var failed := [false]
	var all_things := _things()
	for t in ids:
		var tid := String(t)
		var asked: Dictionary = make_q.call(tid)
		var take := func(ans) -> void:
			if typeof(ans) != TYPE_DICTIONARY or ans.is_empty():
				failed[0] = true
			else:
				read.call(tid, ans, asked)
			left[0] -= 1
			if left[0] == 0:
				done.call(not failed[0])
		if not AI.decide(_state(all_things, tid), asked["qs"], take):
			failed[0] = true
			left[0] -= 1
			if left[0] == 0:
				done.call(false)


## 1つの物について Jev に訊くこと。持ち物には「採るか作るか」と場所、
## どれにも「材料は何種類か」と「要る材料」（「要らない」は置かない）。
## 採ると答えた物の材料は読まない——材料の問いに「要らない」を置くと Jev がそれを選ぶので、
## 要るかどうかは「採るか作るか」のほうで答えてもらう
static func _questions(tid: String, places: Array) -> Dictionary:
	var name := _label(tid)
	var building := Schema.is_building(tid)
	var qs := {}
	var choices := {}
	if not building:
		var pcrit := {}
		for i in range(places.size()):
			pcrit[str(i + 1)] = _place_text(String(places[i]))
		qs["採るか作るか"] = {
			"type": "choice",
			"instructions": "この世界で「%s」は、どこかで採る物か、材料から作る物か" % name,
			"criteria": WAYS,
		}
		choices["採るか作るか"] = ["採る", "作る"]
		qs["場所"] = {
			"type": "choice",
			"instructions": "この世界で「%s」を手に入れるには、どこへ行くか" % name,
			"criteria": pcrit,
		}
		choices["場所"] = places
	var doing := "建てる" if building else "作る"
	var items: Array = []
	for m in Schema.all_items():
		if String(m) != tid:
			items.append(String(m))
	qs["材料の種類"] = {
		"type": "choice",
		"instructions": "この世界で「%s」を%sのに、使うものは何種類か" % [name, doing],
		"criteria": KINDS,
	}
	choices["材料の種類"] = [1, 2, 3]
	var crit := {}
	for i in range(items.size()):
		crit[str(i + 1)] = Schema.item_label(String(items[i]))
	qs["材料"] = {
		"type": "choice",
		"instructions": "この世界で「%s」を%sのに、使うもの" % [name, doing],
		"criteria": crit,
	}
	choices["材料"] = items
	return {"qs": qs, "choices": choices}


## 並び（確率の高い順）の頭から、`tid` が指しても輪にならないものを `n` 個。
## 「どこでも」（空）と世界の場所は輪にならない
static func _first_allowed(tid: String, ranked: Array, n: int) -> Array:
	var out: Array = []
	for x in ranked:
		if out.size() >= n:
			break
		var xs := String(x)
		if xs == "" or Schema.can_need(tid, xs):
			out.append(xs)
	return out


## 輪になって飛ばした答えを記録に出す（`--echo-log` のとき）
static func _say_skipped(tid: String, what: String, ranked: Array, picked: Array, n: int) -> void:
	if not EventLog.echo:
		return
	var head: Array = ranked.slice(0, n)
	if head == picked:
		return
	var skipped: Array = head.filter(func(x): return not picked.has(x))
	print("[ツリー] %s の%s：%s は輪になるので、%s" % [_label(tid), what,
		"・".join(skipped.map(func(x): return _thing_text(String(x)))),
		"・".join(picked.map(func(x): return _thing_text(String(x)))) if not picked.is_empty()
			else "（代わりが無い）"])


static func _thing_text(id: String) -> String:
	if id == "":
		return "どこでも"
	if Schema.WORLD_PLACES.has(id):
		return Schema.place_label(id)
	return _label(id)


## 選ぶ問いの答えを、確率の高い順に並べた選択肢。確率が無ければ選んだ1つだけ
static func _ranked(a, opts: Array) -> Array:
	if typeof(a) != TYPE_DICTIONARY:
		return []
	var probs = a.get("probabilities", {})
	if typeof(probs) != TYPE_DICTIONARY or probs.is_empty():
		var one = _pick(a, opts)
		return [] if one == null else [one]
	var keys: Array = probs.keys()
	keys.sort_custom(func(x, y): return float(probs[x]) > float(probs[y]))
	var out: Array = []
	for k in keys:
		var n := int(str(k)) - 1
		if n >= 0 and n < opts.size():
			out.append(opts[n])
	return out


static func _pick(a, opts: Array) -> Variant:
	if typeof(a) != TYPE_DICTIONARY:
		return null
	var n := int(str(a.get("choice", "0"))) - 1
	return opts[n] if n >= 0 and n < opts.size() else null


## 訊く物。根（木の実・木・石）を除く、もちものとたてもの全部。
## `fresh_only` なら、まだ固まっていない物だけ
static func _things(fresh_only: bool = false) -> Array:
	var out: Array = []
	for r in Schema.recipes:
		if Schema.is_world_item(String(r["id"])):
			continue
		if fresh_only and Schema.is_fixed(r):
			continue
		out.append(String(r["id"]))
	for b in Schema.buildings:
		if fresh_only and Schema.is_fixed(b):
			continue
		out.append(String(b["id"]))
	return out


## 場所の候補。どこでも ＋ 茂み・木・岩 ＋ 建物。
## **島に生えていない場所は並べない**——木の実が消された世界で茂みを選ばれると、
## そこで手に入る物は手に入らなくなる
static func _places() -> Array:
	var out: Array = [""]
	for p in Schema.WORLD_PLACES:
		if Schema.place_alive(String(p)):
			out.append(String(p))
	for b in Schema.buildings:
		out.append(String(b["id"]))
	return out


static func _label(id: String) -> String:
	return Schema.building_label(id) if Schema.is_building(id) else Schema.item_label(id)


static func _place_text(place: String) -> String:
	if place == "":
		return ANYWHERE
	if Schema.WORLD_PLACES.has(place):
		return "%s（世界に元から在る）" % Schema.place_label(place)
	return "%s（建物）" % Schema.place_label(place)


## 渡す姿。この世界に何が在るか。根の3つがどこで手に入るかも書く——
## それが分かっていないと、木の実を茂み以外で手に入れる木を組みかねない
static func _state(things: Array, focus: String) -> String:
	var out := PackedStringArray()
	out.append("ある村の世界で、物を何から・どこで手に入れるかを決める。")
	out.append("材料は、手に入れるたびに手の中から減る。材料が要らない物は、その場所へ行けば手に入る。")
	out.append("")
	out.append("# 元から手に入る物")
	for r in Schema.recipes:
		if Schema.is_world_item(String(r["id"])):
			out.append("・%s … %sで、材料なしで手に入る" % [String(r["label"]),
				Schema.place_label(String(r["place"]))])
	out.append("")
	out.append("# この世界のほかの物")
	for t in things:
		var tid := String(t)
		out.append("・%s（%s）" % [_label(tid), "建物" if Schema.is_building(tid) else "持ち物"])
	out.append("")
	out.append("# いま決めるのは「%s」の手に入れかた" % _label(focus))
	return "\n".join(out)


## 答えを木にする。**前の木は捨てる**——始めるたびに組み直す。
## 物の並び順に、場所 → 材料 の順で入れる。採る物には材料を付けない。
##
## **輪になる答えは、その問いで次に確率の高い答えに置き換える。** 黙って落とすと、
## どちらの枝が残るかが物の並び順という意味の無い理由で決まり、落ち方によっては
## 手に入らない物ができた（井戸が先に「水を使う」を取ると、水は「井戸で採る」を失う）。
## 置き換えたことは記録に出す
static func _apply(got: Dictionary, things: Array) -> void:
	for t in things:
		var d = Schema.thing_def(String(t))
		if d == null:
			continue
		d["inputs"] = {}
		if not Schema.is_building(String(t)):
			d["place"] = ""
	for t in things:
		var tid := String(t)
		var g: Dictionary = got.get(tid, {})
		var places: Array = g.get("places", [])
		if not places.is_empty():
			var p = _first_allowed(tid, places, 1)
			if not p.is_empty():
				Schema.set_place(tid, String(p[0]))
			_say_skipped(tid, "場所", places, p, 1)
		if String(g.get("way", "")) == "採る":
			continue
		var ranked: Array = g.get("inputs", [])
		var want := int(g.get("want", 1))
		var picked := _first_allowed(tid, ranked, want)
		for m in picked:
			Schema.set_input(tid, String(m), 1)
		_say_skipped(tid, "使うもの", ranked, picked, want)
	if EventLog.echo:
		for t in things:
			var tid := String(t)
			var g: Dictionary = got.get(tid, {})
			var text := Schema.recipe_text(tid)
			print("[ツリー] %s（%s）← %s%s" % [_label(tid),
				"建物" if Schema.is_building(tid) else String(g.get("way", "?")),
				text if text != "" else "（なし）",
				"" if Schema.obtainable(tid) else "　※手に入らない"])
