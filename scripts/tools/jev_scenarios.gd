class_name JevScenarios
extends Node
## **決めた姿を Jev に投げて数える**（検証用）。村は動かさない。
##
##   godot --headless --path . -- --jev-scenarios [--repeat=30] [--fixed-order] [--only=名前]
##
## シナリオは `res://bench/scenarios/*.json`。1つの姿（感情・相手・持ち物・
## 今感じていること・今日あったこと…）と手の一覧を書いておくと、
## **ゲームと同じ道**（`Inner.of` → `Brain._state`、`Brain.jev_questions_for`）で
## 文にして投げる。書き方は `bench/scenarios/README.md`。
##
## 手の並びは既定で毎回混ぜる——ゲームもそうしていて、混ぜないと
## 「何番めか」と「何の手か」が分けられない。`--fixed-order` なら毎回同じ並びで、
## そのときは**まったく同じ問い**が R 回飛ぶ（答えが揺れるかどうかを見る）。
##
## 結果は標準出力と `user://jev_bench/`。投げた姿もそのまま .md に載せる。

const DIR := "res://bench/scenarios"

var repeat := 30
var fixed := false
var only := ""

var _sc: Array = []      ## [{name, aim, state, criteria(並びどおりの文), keys, persona}]
var _got: Array = []     ## [[record…] シナリオごと]
var _pending := 0
var _done := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--repeat="):
			repeat = int(s.get_slice("=", 1))
		elif s.begins_with("--only="):
			only = s.get_slice("=", 1)
		elif s == "--fixed-order":
			fixed = true
	if not AI.can_decide():
		print("[シナリオ] Jev の鍵が無い（TYPESAFE_API_KEY か res://.typesafe-key）")
		get_tree().quit(1)
		return
	AI.text_off = true
	_load()
	if _sc.is_empty():
		print("[シナリオ] %s にシナリオが無い" % DIR)
		get_tree().quit(1)
		return
	for i in range(_sc.size()):
		_got.append([])
		_send(i)
	print("[シナリオ] %d本 × %d回（並び %s）＝ %d件"
		% [_sc.size(), repeat, "固定" if fixed else "毎回混ぜる", _pending])


func _process(_delta: float) -> void:
	if not _done and _pending <= 0 and not _sc.is_empty():
		_done = true
		_finish()


# ---------------------------------------------------------------------------
# 読む
# ---------------------------------------------------------------------------

func _load() -> void:
	var names: Array = []
	for f in DirAccess.get_files_at(DIR):
		if String(f).ends_with(".json"):
			names.append(String(f))
	names.sort()
	for f in names:
		if only != "" and not f.begins_with(only):
			continue
		var txt := FileAccess.get_file_as_string("%s/%s" % [DIR, f])
		var d = JSON.parse_string(txt)
		if typeof(d) != TYPE_DICTIONARY:
			print("[シナリオ] %s が読めない" % f)
			continue
		var sc := _build(d, f.get_basename())
		if not sc.is_empty():
			_sc.append(sc)


## JSON から、村人の代わりの入れ物を組んで、ゲームと同じ道で文にする
func _build(d: Dictionary, file: String) -> Dictionary:
	var p := Persona.new()
	var me: Dictionary = d.get("あなた", {})
	p.vname = String(me.get("名前", "ハル"))
	p.personality.quirk = String(me.get("性格", "働き者"))
	var words: Array = me.get("気質", [])
	for a in Personality.AXES:
		p.personality.set_axis(String(a[0]), 1.0 if words.has(String(a[3])) else 0.0)

	var feel: Dictionary = d.get("感情", {})
	for label in feel:
		var id := Schema.self_param_by_label(str(label))
		if id == "":
			print("[シナリオ] %s：感情「%s」はこの世界に無い" % [file, label])
			continue
		p.params.set_v(id, float(feel[label]))

	var others: Dictionary = d.get("相手", {})
	var oid := 100
	for who in others:
		oid += 1
		p.names[oid] = str(who)
		var pp := PairParams.new(oid)
		var vals: Dictionary = others[who]
		for label in vals:
			var pid := Schema.pair_param_by_label(str(label))
			if pid == "":
				print("[シナリオ] %s：相手の言葉「%s」はこの世界に無い" % [file, label])
				continue
			pp.set_v(pid, float(vals[label]))
		p.pairs[oid] = pp

	var hold: Dictionary = d.get("持ち物", {})
	for label in hold:
		var iid := _item_id(str(label))
		if iid == "":
			print("[シナリオ] %s：持ち物「%s」はこの世界に無い" % [file, label])
			continue
		p.inventory[iid] = int(hold[label])

	p.doing = String(d.get("していること", "考えている"))
	p.feeling = String(d.get("今感じていること", ""))
	for e in d.get("今日あったこと", []):
		p.memory.episodes.append(String(e))
	var heard := p.memory.episodes.size()
	for e in d.get("前に考えてから", []):
		p.memory.episodes.append(String(e))
	var story = d.get("覚えていること", "")
	p.memory.story = "\n".join(PackedStringArray(story)) if typeof(story) == TYPE_ARRAY \
		else String(story)

	var now: Dictionary = d.get("いま", {})
	SimClock.day = int(now.get("日", 1))
	SimClock.time_of_day = _time_of(String(now.get("時刻", "08:00")))
	var at: Array = now.get("座標", [10, 10])
	p.cell = Vector2(float(at[0]), float(at[1]))

	# 「この世界の言葉」の村人。書かなければ、自分と相手と一覧に出てくる名前
	var folk: Array = d.get("村人", [])
	if folk.is_empty():
		folk.append(p.vname)
		for who in others:
			if not folk.has(str(who)):
				folk.append(str(who))
	for who in folk:
		p.world.villagers.append(Other.new(String(who)))

	var brain := Brain.new(p)
	brain._heard = heard
	brain._thought_at = String(d.get("前に考えたのは", ""))
	var state: String = brain._state([])

	var lines: Array = []
	var keys: Array = []
	for c in d.get("手", []):
		var text := String(c.get("文", "")) if typeof(c) == TYPE_DICTIONARY else String(c)
		lines.append(text)
		keys.append(String(c.get("型", _key_of(text))) if typeof(c) == TYPE_DICTIONARY
			else _key_of(text))
	if lines.size() < 2:
		print("[シナリオ] %s：手が2つ未満" % file)
		return {}
	return {"name": String(d.get("名前", file)), "file": file,
		"aim": String(d.get("ねらい", "")), "state": state,
		"lines": lines, "keys": keys, "brain": brain, "persona": p,
		"self": feel, "pairs": others}


## 「木を使う（そこに在る 12, 5）」→「木を使う（そこに在る）」。座標だけ落とす
static func _key_of(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\s*-?\\d+,\\s*-?\\d+")
	var k := re.sub(text, "", true)
	return k.replace("（）", "")


static func _item_id(label: String) -> String:
	for item in Schema.all_items():
		if Schema.item_label(String(item)) == label:
			return String(item)
	return ""


## 「07:30」→ 時計の位置（一日は 06:00 から）
static func _time_of(hhmm: String) -> float:
	var h := float(hhmm.get_slice(":", 0)) + float(hhmm.get_slice(":", 1)) / 60.0
	return fposmod(h - SimClock.DAY_STARTS_AT, 24.0) / 24.0


# ---------------------------------------------------------------------------
# 投げる
# ---------------------------------------------------------------------------

func _send(si: int) -> void:
	var sc: Dictionary = _sc[si]
	var idx: Array = range(sc["lines"].size())
	for i in range(repeat):
		var order: Array = idx.duplicate()
		if not fixed:
			order.shuffle()
		var crit := {}
		var offered: Array = []
		for j in range(order.size()):
			crit[str(j + 1)] = String(sc["lines"][order[j]])
			offered.append(String(sc["keys"][order[j]]))
		var qs: Dictionary = sc["brain"].jev_questions_for(crit)
		if i == 0:
			sc["questions"] = qs
		var cb := func(ans) -> void:
			_pending -= 1
			if typeof(ans) != TYPE_DICTIONARY:
				return
			_got[si].append(JevBench._read(ans, offered))
		if AI.decide(String(sc["state"]), qs, cb, -1):
			_pending += 1


# ---------------------------------------------------------------------------
# 表にする
# ---------------------------------------------------------------------------

func _finish() -> void:
	var out := PackedStringArray()
	out.append("# Jev シナリオ（%s）" % Time.get_datetime_string_from_system(false, true))
	out.append("")
	out.append("- %d本 × %d回、並びは%s。投げた問い %d件（失敗 %d）"
		% [_sc.size(), repeat, "固定" if fixed else "毎回混ぜる", AI.sent, AI.failed])
	out.append("")
	out.append("| シナリオ | 答え | いちばん多い手 | その割合 | 出た手の種類 | 先頭を選んだ |")
	out.append("|---|---:|---|---:|---:|---:|")
	for si in range(_sc.size()):
		var rs: Array = _got[si]
		var acts := _count(rs)
		var top := _top(acts)
		var first := 0
		for r in rs:
			if int(r["pick"]) == 0:
				first += 1
		out.append("| %s | %d | %s | %s | %d | %s |" % [_sc[si]["name"], rs.size(), top,
			JevBench._pct(int(acts.get(top, 0)), rs.size()), acts.size(),
			JevBench._pct(first, rs.size())])
	for si in range(_sc.size()):
		out.append("")
		out.append_array(_one(si))
	var md := "\n".join(out)
	print("\n" + md)

	var dir := "user://jev_bench"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	var f := FileAccess.open("%s/scenarios-%s.md" % [dir, stamp], FileAccess.WRITE)
	if f != null:
		f.store_string(md)
		f.close()
	var raw: Array = []
	for si in range(_sc.size()):
		raw.append({"name": _sc[si]["name"], "state": _sc[si]["state"],
			"questions": _sc[si].get("questions", {}), "answers": _got[si]})
	var j := FileAccess.open("%s/scenarios-%s.json" % [dir, stamp], FileAccess.WRITE)
	if j != null:
		j.store_string(JSON.stringify(raw, "\t"))
		j.close()
	print("[シナリオ] 書き出した：%s/scenarios-%s.md" % [ProjectSettings.globalize_path(dir), stamp])
	get_tree().quit()


func _count(rs: Array) -> Dictionary:
	var acts := {}
	for r in rs:
		if int(r["pick"]) >= 0:
			acts[String(r["act"])] = int(acts.get(String(r["act"]), 0)) + 1
	return acts


static func _top(acts: Dictionary) -> String:
	var top := ""
	for a in acts:
		if top == "" or int(acts[a]) > int(acts[top]):
			top = a
	return top


func _one(si: int) -> PackedStringArray:
	var sc: Dictionary = _sc[si]
	var rs: Array = _got[si]
	var n := rs.size()
	var out := PackedStringArray()
	out.append("## %s" % sc["name"])
	if String(sc["aim"]) != "":
		out.append("")
		out.append("ねらい：%s" % sc["aim"])
	out.append("")

	# 手。書いた順に、選ばれなかったものも出す
	var chosen := {}
	var conf := {}
	for r in rs:
		if int(r["pick"]) < 0:
			continue
		var a := String(r["act"])
		chosen[a] = int(chosen.get(a, 0)) + 1
		conf[a] = float(conf.get(a, 0.0)) + float(r["conf"])
	out.append("| 手 | 選ばれた | 割合 | 確信 |")
	out.append("|---|---:|---:|---:|")
	var seen := {}
	for k in sc["keys"]:
		if seen.has(k):
			continue
		seen[k] = true
		var c := int(chosen.get(k, 0))
		out.append("| %s | %d | %s | %s |" % [k, c, JevBench._pct(c, n),
			"%.2f" % (float(conf[k]) / c) if c > 0 else "-"])
	out.append("")

	# 自分の言葉。渡した値と、答えた段階をゲームと同じ写し方で寄せた先
	var p = sc["persona"]
	out.append("| 自分の言葉 | 渡した値 | 段階の分布 | 確信 | 写した先（平均） |")
	out.append("|---|---:|---|---:|---:|")
	for d in Schema.self_params():
		var label := String(d["label"])
		var id := String(d["id"])
		var hist := [0, 0, 0, 0, 0]
		var m := 0
		var cs := 0.0
		var to_sum := 0.0
		var was: float = p.params.get_v(id)
		for r in rs:
			var s = r["scores"].get(label, null)
			if s == null:
				continue
			m += 1
			hist[clampi(int(s["level"]), 0, 4)] += 1
			cs += float(s["conf"])
			var t := float(s["level"]) / float(Brain.LEVELS.size() - 1)
			var to := Schema.param_min(id) + (Schema.param_max(id) - Schema.param_min(id)) * t
			to_sum += was + (to - was) * clampf(float(s["conf"]), 0.0, 1.0)
		if m == 0:
			continue
		out.append("| %s | %.0f | %s | %.2f | %.1f |" % [label, was,
			JevBench._hist_text(hist, m), cs / m, to_sum / m])

	# 相手への言葉。相手ごと
	var pk: Array = []
	for r in rs:
		for k in r["pair_by"]:
			if not pk.has(k):
				pk.append(k)
	if not pk.is_empty():
		out.append("")
		out.append("| 相手への言葉 | 渡した値 | 段階の分布 | 確信 | 写した先（平均） |")
		out.append("|---|---:|---|---:|---:|")
		for k in pk:
			var at := String(k).find(" の ")
			var who := String(k).substr(0, at)
			var pid := Schema.pair_param_by_label(String(k).substr(at + 3))
			var was := 0.0
			for oid in p.names:
				if p.names[oid] == who:
					was = p.pairs[oid].get_v(pid)
			var hist := [0, 0, 0, 0, 0]
			var m := 0
			var cs := 0.0
			var to_sum := 0.0
			for r in rs:
				var s = r["pair_by"].get(k, null)
				if s == null:
					continue
				m += 1
				hist[clampi(int(s["level"]), 0, 4)] += 1
				cs += float(s["conf"])
				var t := float(s["level"]) / float(Brain.LEVELS.size() - 1)
				var to := Schema.param_min(pid) \
					+ (Schema.param_max(pid) - Schema.param_min(pid)) * t
				to_sum += was + (to - was) * clampf(float(s["conf"]), 0.0, 1.0)
			out.append("| %s | %.0f | %s | %.2f | %.1f |" % [k, was,
				JevBench._hist_text(hist, m), cs / m, to_sum / m])

	out.append("")
	out.append("<details><summary>投げた姿と手の一覧</summary>")
	out.append("")
	out.append("```")
	out.append(String(sc["state"]))
	out.append("")
	out.append("# 手（並びは%s）" % ("このまま" if fixed else "毎回混ぜる"))
	for i in range(sc["lines"].size()):
		out.append("%d. %s" % [i + 1, sc["lines"][i]])
	out.append("```")
	out.append("")
	out.append("</details>")
	return out


## 村人の代わり。`Inner.of` と `Brain` が読むところだけを持つ
class Persona:
	extends RefCounted
	var vname := ""
	var personality := Personality.new()
	var params := SelfParams.new()
	var pairs := {}
	var inventory := {}
	var doing := "考えている"
	var feeling := ""
	var memory := Memory.new()
	var cell := Vector2(10, 10)
	var world := Names.new()   ## 相手の名前を引くところ
	var names: Dictionary:     ## 相手のid → 名前
		get:
			return world.names

	func item_count(item: String) -> int:
		return int(inventory.get(item, 0))

	func action_label() -> String:
		return doing

	func pair_peek(other_id: int):
		return pairs.get(other_id, null)


## 世界のふり。相手の名前を引くのと、村人の顔ぶれ（`Inner.words`）だけ
class Names:
	extends RefCounted
	var names := {}
	var villagers: Array = []

	func villager_by_id(oid: int):
		if not names.has(oid):
			return null
		return Other.new(String(names[oid]))


class Other:
	extends RefCounted
	var vname := ""

	func _init(n: String) -> void:
		vname = n
