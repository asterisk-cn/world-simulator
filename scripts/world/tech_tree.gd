class_name TechTree
## 【AI差し替え口】この世界の技術ツリー。物ごとの手に入れかた（材料と場所）を Jev に訊く。
##
## 神が決めるのは**何が在りうるか**（名前と姿）まで。それを何から、どこで手に入れるかは
## 神には見せず、**世界が始まるときに Jev が1回で答える**。同じ設計図でも、
## 始めるたびにツリーは変わる。神が後から物を足しても、次に始めるときに組み込まれる。
##
## 木の実・木・石（島に在るもの、`Schema.WORLD_ARTS`）は根なので訊かない
## （茂み・木・岩で、材料なし）。神が消した根は、島にも木にも無い。
##
## **世界が見るのは今と同じ規則だけ**（`Schema.set_input` / `set_place`）。
##   輪になる答え … 成り立たないので、その枝だけ落ちる（先に答えた枝が残る）
##   材料も場所も無い答え … その世界では手に入らない物になる。答えなので直さない
##
## 【FutureWork】世界に1本のツリーではなく、一人ひとりが自分の作り方を持つ（DESIGN.md §12）。

## 材料1つの数。段階のまま数になる（「2つ」なら 2）
const COUNTS := ["要らない", "1つ", "2つ", "3つ", "4つ"]

## 場所の選択肢で「どこでも」を表す鍵
const ANYWHERE := "どこでも（手の中で済む）"


## 訊く。答えが返って木を組み終えたら `on_done.call(true)`、
## 返らなかったら `on_done.call(false)`。Jev が使えなければ訊かずに false を返す
static func grow(on_done: Callable) -> bool:
	if not AI.can_decide():
		return false
	var things := _things()
	if things.is_empty():
		on_done.call(true)
		return true
	var qs := {}
	var keys := {}   ## 問いの鍵 → [物のid, "place" か 材料のid]
	var places := _places()
	for t in things:
		var tid := String(t)
		var name := _label(tid)
		if not Schema.is_building(tid):
			var crit := {}
			for i in range(places.size()):
				crit[str(i + 1)] = _place_text(String(places[i]))
			var k := "%sを手に入れる場所 [%s]" % [name, tid]
			qs[k] = {
				"type": "choice",
				"instructions": "この世界で「%s」を手に入れるには、どこへ行くか" % name,
				"criteria": crit,
			}
			keys[k] = [tid, "place"]
		for m in Schema.all_items():
			var mid := String(m)
			if mid == tid:
				continue
			var k := "%sに要る%s [%s/%s]" % [name, Schema.item_label(mid), tid, mid]
			qs[k] = {
				"type": "score",
				"instructions": "この世界で「%s」を%sのに、「%s」はいくつ要るか"
					% [name, "建てる" if Schema.is_building(tid) else "1つ手に入れる",
						Schema.item_label(mid)],
				"criteria": COUNTS,
			}
			keys[k] = [tid, mid]
	var take := func(ans) -> void:
		if typeof(ans) != TYPE_DICTIONARY or ans.is_empty():
			on_done.call(false)
			return
		_apply(ans, keys, things, places)
		on_done.call(true)
	return AI.decide(_state(things), qs, take)


## 訊く物。根（木の実・木・石）を除く、もちものとたてもの全部
static func _things() -> Array:
	var out: Array = []
	for r in Schema.recipes:
		if not Schema.is_world_item(String(r["id"])):
			out.append(String(r["id"]))
	for b in Schema.buildings:
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
static func _state(things: Array) -> String:
	var out := PackedStringArray()
	out.append("ある村の世界で、物を何から・どこで手に入れるかを決める。")
	out.append("材料は、手に入れるたびに手の中から減る。材料が要らない物は、その場所へ行けば手に入る。")
	out.append("材料も場所も要らない物は、手に入らない。")
	out.append("")
	out.append("# 元から手に入る物")
	for r in Schema.recipes:
		if Schema.is_world_item(String(r["id"])):
			out.append("・%s … %sで、材料なしで手に入る" % [String(r["label"]),
				Schema.place_label(String(r["place"]))])
	out.append("")
	out.append("# 手に入れかたを決める物")
	for t in things:
		var tid := String(t)
		out.append("・%s（%s）" % [_label(tid), "建物" if Schema.is_building(tid) else "持ち物"])
	return "\n".join(out)


## 答えを木にする。**前の木は捨てる**——始めるたびに組み直す。
## 物の並び順に、場所 → 材料 の順で入れる。輪になる枝は `Schema` が受け付けない
static func _apply(ans: Dictionary, keys: Dictionary, things: Array, places: Array) -> void:
	for t in things:
		var d = Schema.thing_def(String(t))
		if d == null:
			continue
		d["inputs"] = {}
		if not Schema.is_building(String(t)):
			d["place"] = ""
	for t in things:
		var tid := String(t)
		for k in keys:
			var pair: Array = keys[k]
			if String(pair[0]) != tid or String(pair[1]) != "place":
				continue
			var a = ans.get(k, null)
			if typeof(a) != TYPE_DICTIONARY:
				continue
			var n := int(str(a.get("choice", "0"))) - 1
			if n >= 0 and n < places.size():
				Schema.set_place(tid, String(places[n]))
		for k in keys:
			var pair: Array = keys[k]
			if String(pair[0]) != tid or String(pair[1]) == "place":
				continue
			var a = ans.get(k, null)
			if typeof(a) != TYPE_DICTIONARY:
				continue
			var count := clampi(int(round(float(a.get("score", 0.0)))), 0, COUNTS.size() - 1)
			if count > 0:
				Schema.set_input(tid, String(pair[1]), count)
	if EventLog.echo:
		for t in things:
			var tid := String(t)
			var text := Schema.recipe_text(tid)
			print("[ツリー] %s ← %s%s" % [_label(tid), text if text != "" else "（なし）",
				"" if Schema.obtainable(tid) else "　※手に入らない"])
