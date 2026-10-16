class_name Expect
extends RefCounted
## **シナリオの「期待」を判定する**（検証用）。単発（`JevScenarios`）と流れ（`FlowRun`）で共通。
##
## 判定するのは答え1つずつではなく、**集めた答えの平均や割合**。
## Jev は確率で手を引くので、1回の答えでは何も言えない。
##
## 期待1つは JSON の物1つ。比べ方は文字列で書く：
##   ">=0.5" "<=2" ">0" "<0" … 比べる
##   "-5..5"                … その幅に入る（両端を含む）
##
## 手の割合と手の一覧を外したときは**警告**、値（段階・動き）や流れの約束を外したときは**失敗**。
## 手は引くたびに揺れるが、値の向きが逆なら問いの形か読み方が壊れている。

const FAIL := "失敗"
const WARN := "警告"
const PASS := "通った"


## 答えの束（`JevBench._read` の形）を、判定に使う数へまとめる。
## `move_of(r, kind, key)` は答え1つで値がいくつ動いたか（無ければ null）。
## 単発と流れで動きの測り方が違うので、呼ぶ側が渡す
static func summarize(rs: Array, move_of: Callable) -> Dictionary:
	var n := rs.size()
	var acts := {}
	var self_sum := {}
	var pair_sum := {}
	var seen := {}
	var offered := {}
	for r in rs:
		for o in r.get("offered", []):
			offered[String(o)] = true
		if int(r["pick"]) >= 0:
			acts[String(r["act"])] = int(acts.get(String(r["act"]), 0)) + 1
		for label in r["scores"]:
			seen[String(label)] = true
			_add(self_sum, String(label), r["scores"][label], move_of.call(r, "self", label))
		for k in r["pair_by"]:
			seen[String(k)] = true
			_add(pair_sum, String(k), r["pair_by"][k], move_of.call(r, "pair", k))
	var frac := {}
	for a in acts:
		frac[a] = float(acts[a]) / float(maxi(n, 1))
	return {"n": n, "acts": frac, "self": _means(self_sum), "pairs": _means(pair_sum),
		"seen": seen, "offered": offered.keys()}


static func _add(into: Dictionary, key: String, got: Dictionary, move) -> void:
	if not into.has(key):
		into[key] = {"level": 0.0, "n": 0, "move": 0.0, "m": 0}
	into[key]["level"] += float(got["level"])
	into[key]["n"] += 1
	if move != null:
		into[key]["move"] += float(move)
		into[key]["m"] += 1


static func _means(sums: Dictionary) -> Dictionary:
	var out := {}
	for k in sums:
		var s: Dictionary = sums[k]
		out[k] = {"level": s["level"] / maxi(int(s["n"]), 1),
			"move": s["move"] / s["m"] if int(s["m"]) > 0 else null}
	return out


## 期待1つを判定する。返すのは {text, verdict, got}。
## `extra` は流れだけが持つ数（村人ごとの答えの数）
static func judge(e: Dictionary, sum: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var text := _describe(e)
	if e.has("手に入れかた"):
		var how := String(extra.get("tree", {}).get(String(e["手に入れかた"]), ""))
		return {"text": text, "verdict": PASS if how != "" else FAIL,
			"got": how if how != "" else "組まれていない"}
	if int(sum["n"]) == 0 and not e.has("考えた"):
		return {"text": text, "verdict": FAIL, "got": "答えが無い"}
	if e.has("手"):
		var got := float(sum["acts"].get(String(e["手"]), 0.0))
		return _cmp(text, got, String(e.get("割合", ">0")), WARN, "%.2f" % got)
	if e.has("感情"):
		return _value(text, e, sum["self"].get(String(e["感情"]), null))
	if e.has("相手"):
		var k := "%s の %s" % [String(e["相手"]), String(e.get("値", ""))]
		return _value(text, e, sum["pairs"].get(k, null))
	if e.has("答えに出る"):
		# 相手への言葉は「ミナ の 信頼」の形で訊かれるので、後ろが合えば出たことにする
		var word := String(e["答えに出る"])
		var on: bool = sum["seen"].keys().any(
			func(k): return String(k) == word or String(k).ends_with(" の " + word))
		return {"text": text, "verdict": PASS if on else FAIL, "got": "出た" if on else "出ない"}
	if e.has("一覧に出る"):
		var word := String(e["一覧に出る"])
		var hit: Array = sum["offered"].filter(func(o): return String(o).contains(word))
		# 一覧に出るのは、払える手だけ。材料を持っている人がいなければ出ないので警告に留める
		return {"text": text, "verdict": PASS if not hit.is_empty() else WARN,
			"got": String(hit[0]) if not hit.is_empty() else "出ない"}
	if e.has("考えた"):
		var got := int(extra.get("by", {}).get(String(e.get("村人", "")), 0))
		return _cmp(text, float(got), String(e["考えた"]), FAIL, str(got))
	return {"text": text, "verdict": FAIL, "got": "読めない期待"}


static func _value(text: String, e: Dictionary, s) -> Dictionary:
	if s == null:
		return {"text": text, "verdict": FAIL, "got": "訊かれていない"}
	if e.has("段階"):
		return _cmp(text, float(s["level"]), String(e["段階"]), FAIL, "%.1f" % s["level"])
	if e.has("動き"):
		if s["move"] == null:
			return {"text": text, "verdict": FAIL, "got": "動きが測れない"}
		return _cmp(text, float(s["move"]), String(e["動き"]), FAIL, "%+.1f" % s["move"])
	return {"text": text, "verdict": FAIL, "got": "段階か動きを書く"}


static func _cmp(text: String, got: float, rule: String, miss: String, shown: String) -> Dictionary:
	var ok = holds(got, rule)
	if ok == null:
		return {"text": text, "verdict": FAIL, "got": "比べ方「%s」が読めない" % rule}
	return {"text": text, "verdict": PASS if ok else miss, "got": shown}


## ">=0.5" や "-5..5" を当てる。読めなければ null
static func holds(x: float, rule: String) -> Variant:
	var r := rule.strip_edges()
	if r.contains(".."):
		var lo := r.get_slice("..", 0)
		var hi := r.get_slice("..", 1)
		if not lo.is_valid_float() or not hi.is_valid_float():
			return null
		return x >= float(lo) and x <= float(hi)
	for op in [">=", "<=", ">", "<"]:
		if r.begins_with(op):
			var v := r.substr(String(op).length())
			if not v.is_valid_float():
				return null
			match op:
				">=": return x >= float(v)
				"<=": return x <= float(v)
				">": return x > float(v)
				"<": return x < float(v)
	return null


## 表に出す一行。書いたものをそのまま読める形に
static func _describe(e: Dictionary) -> String:
	var head := ""
	if e.has("日"):
		head += "%s：" % _days_text(String(e["日"]))
	if e.has("村人") and not e.has("考えた"):
		head += "%s：" % String(e["村人"])
	if e.has("手"):
		return head + "「%s」を選ぶ割合 %s" % [e["手"], e.get("割合", ">0")]
	if e.has("感情"):
		return head + "%s の%s %s" % [e["感情"], "段階" if e.has("段階") else "動き",
			e.get("段階", e.get("動き", ""))]
	if e.has("相手"):
		return head + "%s への%s の%s %s" % [e["相手"], e.get("値", ""),
			"段階" if e.has("段階") else "動き", e.get("段階", e.get("動き", ""))]
	if e.has("答えに出る"):
		return head + "答えに「%s」が出る" % e["答えに出る"]
	if e.has("手に入れかた"):
		return head + "「%s」の手に入れかたが組まれる" % e["手に入れかた"]
	if e.has("一覧に出る"):
		return head + "手の一覧に「%s」が出る" % e["一覧に出る"]
	if e.has("考えた"):
		return head + "%s が考えた回数 %s" % [e.get("村人", "?"), e["考えた"]]
	return head + JSON.stringify(e)


## 「3」→「3日目」、「2-」→「2日目から」、「-2」→「2日目まで」、「2-4」→「2〜4日目」
static func _days_text(s: String) -> String:
	if not s.contains("-"):
		return "%s日目" % s
	var lo := s.get_slice("-", 0)
	var hi := s.get_slice("-", 1)
	if lo == "":
		return "%s日目まで" % hi
	if hi == "":
		return "%s日目から" % lo
	return "%s〜%s日目" % [lo, hi]


## 判定の表。`rows` は judge の返り値の並び
static func table(rows: Array) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("| 期待 | 結果 | 実際 |")
	out.append("|---|---|---:|")
	for r in rows:
		out.append("| %s | %s | %s |" % [r["text"], r["verdict"], r["got"]])
	return out


## `--judge` のときの判定を残す。まとめて流す側（`CheckRun`）が読む。
## `rows` は [{name, verdict, rows}]、`report` は表を書き出した先
static func save_check(id: String, rows: Array, report: String) -> void:
	var dir := "user://jev_bench/check"
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open("%s/%s.json" % [dir, id], FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"rows": rows,
			"report": ProjectSettings.globalize_path(report)}, "\t"))
		f.close()


## 失敗が1つでもあれば FAIL、警告だけなら WARN
static func worst(rows: Array) -> String:
	var w := PASS
	for r in rows:
		if r["verdict"] == FAIL:
			return FAIL
		if r["verdict"] == WARN:
			w = WARN
	return w
