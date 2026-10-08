class_name JevBench
extends Node
## **Jev の答えを数える**（検証用）。村を動かして、Jev が何を選び、値をどう答えたかを集める。
##
##   godot --headless --path . -- --autostart --jev-bench [--secs=90] [--repeat=0]
##
## 見るのは2つ（issue #17・#6）。
##   - 行動選択の偏り … どの手が、一覧に出た回数のわりにどれだけ選ばれたか。
##     一覧は毎回混ぜているので（`Brain.feasible`）、**何番めを選んだか**も数える
##   - 感情の数値変動 … 段階の答えの分布、確信、1回の答えで値がいくつ動いたか、
##     村の平均がどう推移したか
##
## `--repeat=R` を付けると、動かしたあとに時間を止め、**同じ姿を R 回ずつ**訊き直す。
## 一覧の順だけ混ぜ直すので、答えの揺れ（同じ姿でどれだけ違う手を選ぶか）が分かる。
## このぶんの答えは村には戻さない。
##
## Jev は安い（入力 $0.042/M、出力は無料）ので、大きい n で測ってよい。
## **文章の相手（作者の財布から出るほう）は既定で止める**（`AI.text_off`）。
## 話す1行目・貼り紙・気持ちの一言も見たいときは `--with-text`。
##
## 結果は標準出力と `user://jev_bench/` に（.md が表、.json が答えそのもの）。

## 動かしているあいだ、`Brain._read_jev` から呼ばれる
static var active := false
static var _live: Array = []
static var _t0 := 0.0

var world
var secs := 90.0
var repeat := 0
var speed := 1.0

var _phase := "wait"
var _clock := 0.0
var _rep: Array = []
var _pending := 0
var _snaps: Array = []   ## [{who, n}]


func _init(p_world = null) -> void:
	world = p_world


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		var s := String(a)
		if s.begins_with("--secs="):
			secs = float(s.get_slice("=", 1))
		elif s.begins_with("--repeat="):
			repeat = int(s.get_slice("=", 1))
		elif s.begins_with("--speed="):
			speed = float(s.get_slice("=", 1))
	if not AI.can_decide():
		print("[ベンチ] Jev の鍵が無い（TYPESAFE_API_KEY か res://.typesafe-key）")
		get_tree().quit(1)
		return
	AI.text_off = not args.has("--with-text")
	_live = []
	print("[ベンチ] %.0f秒動かす（速さ ×%.1f）、同じ姿の訊き直し %d回、文章の相手 %s"
		% [secs, speed, repeat, "使う" if not AI.text_off else "使わない"])


func _process(delta: float) -> void:
	match _phase:
		"wait":
			if world != null and world.villagers.size() > 0 and not SimClock.paused:
				_phase = "live"
				_clock = 0.0
				_t0 = _now()
				SimClock.speed = speed
				active = true
		"live":
			_clock += delta
			if _clock >= secs:
				active = false
				if repeat > 0:
					_start_repeat()
				else:
					_finish()
		"repeat":
			if _pending <= 0:
				_finish()


static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


# ---------------------------------------------------------------------------
# 動かしているあいだの答え
# ---------------------------------------------------------------------------

## `Brain._read_jev` が値を書き終えたところで呼ぶ。`before` は書く前の自分の値
static func heard(v, ans: Dictionary, cands: Array, before: Dictionary) -> void:
	var r := _read(ans, _offered(v, cands))
	r["t"] = _now() - _t0
	r["who"] = String(v.vname)
	for id in before:
		var label := _self_label(String(id))
		if r["scores"].has(label):
			r["scores"][label]["before"] = float(before[id])
			r["scores"][label]["after"] = v.params.get_v(String(id))
	_live.append(r)


## 一覧の手を、数える名前に
static func _offered(v, cands: Array) -> Array:
	var out: Array = []
	for c in cands:
		out.append(_act_key(v, c))
	return out


## 答え1つを、数えられる形に。`offered` は一覧の並びどおりの手の名前
static func _read(ans: Dictionary, offered: Array) -> Dictionary:
	var r := {"n": offered.size(), "offered": offered, "pick": -1, "act": "",
		"conf": 0.0, "scores": {}, "pairs": {}, "pair_by": {}}
	var pick = ans.get("手", null)
	if typeof(pick) == TYPE_DICTIONARY:
		var n := int(str(pick.get("choice", "0"))) - 1
		if n >= 0 and n < offered.size():
			r["pick"] = n
			r["act"] = offered[n]
			r["conf"] = float(pick.get("confidence", 0.0))
	for key in ans:
		var a = ans[key]
		if typeof(a) != TYPE_DICTIONARY or String(a.get("type", "")) != "score":
			continue
		var k := str(key)
		var got := {"level": int(round(float(a.get("score", 0.0)))),
			"conf": float(a.get("confidence", 0.0))}
		var at := k.find(" の ")
		if at >= 0:
			var pl := k.substr(at + 3)
			if not r["pairs"].has(pl):
				r["pairs"][pl] = []
			r["pairs"][pl].append(got)
			r["pair_by"][k] = got
		else:
			r["scores"][k] = got
	return r


## 手の型。「ハルと話す」と「ミナと話す」は同じ手として数える
static func _act_key(v, c: Dictionary) -> String:
	var kind := String(c["kind"])
	var name: String
	if c.get("obj", null) is Villager:
		name = "誰かと話す" if kind == "talk" else "誰かのところへ向かう"
	else:
		name = v._brain._name_act(c)
	match String(c.get("where", "")):
		"hand":
			name += "（手の中）"
		"world":
			name += "（そこに在る）"
		"building":
			name += "（建物）"
	return name


static func _self_label(id: String) -> String:
	for d in Schema.self_params():
		if String(d["id"]) == id:
			return String(d["label"])
	return id


# ---------------------------------------------------------------------------
# 同じ姿を R 回
# ---------------------------------------------------------------------------

func _start_repeat() -> void:
	SimClock.paused = true
	_phase = "repeat"
	for v in world.villagers:
		if not is_instance_valid(v):
			continue
		var brain = v._brain
		var cands: Array = brain.feasible()
		if cands.size() <= 1:
			continue
		var si := _snaps.size()
		_snaps.append({"who": String(v.vname), "n": cands.size()})
		for i in range(repeat):
			var order := cands.duplicate()
			order.shuffle()
			var qs: Dictionary = brain.jev_questions(order)
			var state: String = brain._state(order)
			var cb := func(ans) -> void:
				_pending -= 1
				if typeof(ans) != TYPE_DICTIONARY or not is_instance_valid(v):
					return
				var r := _read(ans, _offered(v, order))
				r["snap"] = si
				_rep.append(r)
			if AI.decide(state, qs, cb, -1):
				_pending += 1
	print("[ベンチ] 時間を止めて、%d人ぶんを %d回ずつ訊く（%d件）"
		% [_snaps.size(), repeat, _pending])


# ---------------------------------------------------------------------------
# 表にする
# ---------------------------------------------------------------------------

func _finish() -> void:
	_phase = "done"
	var md := _report()
	print("\n" + md)
	var dir := "user://jev_bench"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	var f := FileAccess.open("%s/%s.md" % [dir, stamp], FileAccess.WRITE)
	if f != null:
		f.store_string(md)
		f.close()
	var j := FileAccess.open("%s/%s.json" % [dir, stamp], FileAccess.WRITE)
	if j != null:
		j.store_string(JSON.stringify({"live": _live, "repeat": _rep, "snaps": _snaps}, "\t"))
		j.close()
	print("[ベンチ] 書き出した：%s/%s.md" % [ProjectSettings.globalize_path(dir), stamp])
	get_tree().quit()


func _report() -> String:
	var out := PackedStringArray()
	out.append("# Jev ベンチ（%s）" % Time.get_datetime_string_from_system(false, true))
	out.append("")
	out.append("- 動かした時間 %.0f秒（×%.1f）、村人 %d人、Jev の答え %d件"
		% [secs, speed, world.villagers.size(), _live.size()])
	out.append("- 投げた問い %d件（失敗 %d・置き換え %d）。文章の相手は%s"
		% [AI.sent, AI.failed, AI.dropped, "使った" if not AI.text_off else "止めた"])
	out.append("")
	out.append("## 行動選択の偏り（動かしているあいだ）")
	out.append("")
	out.append_array(_act_table(_live))
	out.append("")
	out.append_array(_pos_table(_live))
	out.append("")
	out.append("## 感情の数値変動（動かしているあいだ）")
	out.append("")
	out.append_array(_score_table(_live))
	out.append("")
	out.append_array(_trend_table(_live))
	out.append("")
	out.append_array(_pair_table(_live))
	if repeat > 0:
		out.append("")
		out.append("## 同じ姿を %d回訊き直したとき" % repeat)
		out.append("")
		out.append_array(_rep_tables())
	return "\n".join(out)


## 手ごとに、選ばれた数と、**当てずっぽうなら選ばれたはずの数**（一覧に出るたび 1/n）
func _act_table(rs: Array) -> PackedStringArray:
	var chosen := {}
	var offered := {}
	var expect := {}
	var conf := {}
	var answered := 0
	for r in rs:
		if int(r["pick"]) < 0:
			continue
		answered += 1
		var n := float(r["n"])
		for k in r["offered"]:
			offered[k] = int(offered.get(k, 0)) + 1
			expect[k] = float(expect.get(k, 0.0)) + 1.0 / n
		var a := String(r["act"])
		chosen[a] = int(chosen.get(a, 0)) + 1
		conf[a] = float(conf.get(a, 0.0)) + float(r["conf"])
	var keys := offered.keys()
	keys.sort_custom(func(x, y) -> bool:
		return int(chosen.get(x, 0)) > int(chosen.get(y, 0)) \
			or (int(chosen.get(x, 0)) == int(chosen.get(y, 0))
				and int(offered[x]) > int(offered[y])))
	var out := PackedStringArray()
	out.append("手を選んだ答え %d件。倍率は「選ばれた ÷ 当てずっぽうなら」——1より大きいほど好まれている" % answered)
	out.append("")
	out.append("| 手 | 選ばれた | 割合 | 一覧に出た | 当てずっぽうなら | 倍率 | 確信 |")
	out.append("|---|---:|---:|---:|---:|---:|---:|")
	for k in keys:
		var c := int(chosen.get(k, 0))
		var e := float(expect[k])
		out.append("| %s | %d | %s | %d | %.1f | %s | %s |" % [k, c,
			_pct(c, answered), int(offered[k]), e,
			"%.2f" % (c / e) if e > 0.0 else "-",
			"%.2f" % (float(conf[k]) / c) if c > 0 else "-"])
	return out


## 一覧の何番めを選んだか。並びは毎回混ぜているので、偏りがあれば位置への偏り
func _pos_table(rs: Array) -> PackedStringArray:
	const BINS := 5
	var hist := []
	hist.resize(BINS)
	hist.fill(0)
	var first := 0
	var last := 0
	var e_first := 0.0
	var total := 0
	for r in rs:
		var p := int(r["pick"])
		if p < 0:
			continue
		var n := int(r["n"])
		total += 1
		hist[mini(int(float(p) / n * BINS), BINS - 1)] += 1
		if p == 0:
			first += 1
		if p == n - 1:
			last += 1
		e_first += 1.0 / n
	var out := PackedStringArray()
	out.append("一覧の位置（先頭から5つに分けて）。当てずっぽうなら各20%前後")
	out.append("")
	out.append("| 位置 | 前1/5 | 2/5 | 3/5 | 4/5 | 後1/5 | 先頭ちょうど | 末尾ちょうど |")
	out.append("|---|---:|---:|---:|---:|---:|---:|---:|")
	var cells := PackedStringArray()
	for h in hist:
		cells.append(_pct(int(h), total))
	out.append("| 選んだ | %s | %s（当てずっぽうなら %s） | %s |" % [" | ".join(cells),
		_pct(first, total), _pct(int(round(e_first)), total), _pct(last, total)])
	return out


## 自分の言葉ごとに、段階の分布と、1回の答えで動いたぶん
func _score_table(rs: Array) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("段階は %s" % " / ".join(Brain.LEVELS))
	out.append("")
	out.append("| 言葉 | 答え | 段階の分布 | 確信 | 1回の動き（平均の大きさ） | 値の最小〜最大 |")
	out.append("|---|---:|---|---:|---:|---|")
	for d in Schema.self_params():
		var label := String(d["label"])
		var hist := [0, 0, 0, 0, 0]
		var n := 0
		var conf := 0.0
		var move := 0.0
		var lo := INF
		var hi := -INF
		for r in rs:
			var s = r["scores"].get(label, null)
			if s == null:
				continue
			n += 1
			hist[clampi(int(s["level"]), 0, 4)] += 1
			conf += float(s["conf"])
			if s.has("after"):
				move += absf(float(s["after"]) - float(s["before"]))
				lo = minf(lo, float(s["after"]))
				hi = maxf(hi, float(s["after"]))
		if n == 0:
			out.append("| %s | 0 | - | - | - | - |" % label)
			continue
		out.append("| %s | %d | %s | %.2f | %.1f | %.0f〜%.0f（幅 %.0f〜%.0f） |" % [label, n,
			_hist_text(hist, n), conf / n, move / n, lo, hi,
			Schema.param_min(String(d["id"])), Schema.param_max(String(d["id"]))])
	return out


## 村の平均（答えたあとの値）の推移。動かした時間を6つに分ける
func _trend_table(rs: Array) -> PackedStringArray:
	const COLS := 6
	var span := maxf(secs, 1.0) / COLS
	var out := PackedStringArray()
	out.append("答えたあとの値の、村の平均の推移（%.0f秒ずつ）" % span)
	out.append("")
	var head := PackedStringArray()
	var rule := PackedStringArray()
	for i in range(COLS):
		head.append("〜%.0fs" % (span * (i + 1)))
		rule.append("---:")
	out.append("| 言葉 | %s |" % " | ".join(head))
	out.append("|---|%s|" % "|".join(rule))
	for d in Schema.self_params():
		var label := String(d["label"])
		var sum := []
		var cnt := []
		sum.resize(COLS)
		sum.fill(0.0)
		cnt.resize(COLS)
		cnt.fill(0)
		for r in rs:
			var s = r["scores"].get(label, null)
			if s == null or not s.has("after"):
				continue
			var i := clampi(int(float(r["t"]) / span), 0, COLS - 1)
			sum[i] += float(s["after"])
			cnt[i] += 1
		var cells := PackedStringArray()
		for i in range(COLS):
			cells.append("%.1f" % (sum[i] / cnt[i]) if int(cnt[i]) > 0 else "-")
		out.append("| %s | %s |" % [label, " | ".join(cells)])
	return out


## 相手への言葉。段階の分布だけ（真ん中が「どちらでもない」）
func _pair_table(rs: Array) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("相手への言葉。段階は %s" % " / ".join(Brain.LEVELS))
	out.append("")
	out.append("| 言葉 | 答え | 段階の分布 | 確信 |")
	out.append("|---|---:|---|---:|")
	for d in Schema.pair_params():
		var label := String(d["label"])
		var hist := [0, 0, 0, 0, 0]
		var n := 0
		var conf := 0.0
		for r in rs:
			for s in r["pairs"].get(label, []):
				n += 1
				hist[clampi(int(s["level"]), 0, 4)] += 1
				conf += float(s["conf"])
		out.append("| %s | %d | %s | %s |" % [label, n,
			_hist_text(hist, n) if n > 0 else "-", "%.2f" % (conf / n) if n > 0 else "-"])
	return out


## 一人ずつ：いちばん多かった手がR回のうち何回か、違う手が何種類出たか。
## 値は、いちばん多かった段階に揃った割合
func _rep_tables() -> PackedStringArray:
	var out := PackedStringArray()
	var labels: Array = []
	for d in Schema.self_params():
		labels.append(String(d["label"]))
	out.append("| 人 | 候補 | 答え | いちばん多い手 | その割合 | 出た手の種類 | %s |"
		% " | ".join(PackedStringArray(labels)))
	var rule := "|---|---:|---:|---|---:|---:|"
	for _l in labels:
		rule += "---|"
	out.append(rule)
	var top_sum := 0.0
	var rows := 0
	for si in range(_snaps.size()):
		var acts := {}
		var lv := {}
		var n := 0
		for r in _rep:
			if int(r["snap"]) != si:
				continue
			n += 1
			var a := String(r["act"])
			acts[a] = int(acts.get(a, 0)) + 1
			for l in labels:
				var s = r["scores"].get(l, null)
				if s == null:
					continue
				if not lv.has(l):
					lv[l] = [0, 0, 0, 0, 0]
				lv[l][clampi(int(s["level"]), 0, 4)] += 1
		if n == 0:
			continue
		var top := ""
		for a in acts:
			if top == "" or int(acts[a]) > int(acts[top]):
				top = a
		top_sum += float(acts[top]) / n
		rows += 1
		var cells := PackedStringArray()
		for l in labels:
			cells.append(_spread(lv.get(l, [])))
		out.append("| %s | %d | %d | %s | %s | %d | %s |" % [_snaps[si]["who"],
			int(_snaps[si]["n"]), n, top, _pct(int(acts[top]), n), acts.size(),
			" | ".join(cells)])
	out.append("")
	out.append("値の欄は、答えた段階の内訳（段階の番号×回数、0＝%s）" % Brain.LEVELS[0])
	if rows > 0:
		out.append("いちばん多い手の割合の平均：%.0f%%" % (top_sum / rows * 100.0))
	return out


static func _pct(a: int, b: int) -> String:
	return "-" if b <= 0 else "%.0f%%" % (float(a) / b * 100.0)


## [3, 10, 0, 1, 0] → 「0:13% 1:71% 3:7%」
static func _hist_text(hist: Array, n: int) -> String:
	var parts := PackedStringArray()
	for i in range(hist.size()):
		if int(hist[i]) > 0:
			parts.append("%d:%s" % [i, _pct(int(hist[i]), n)])
	return " ".join(parts)


## [0, 7, 3, 0, 0] → 「1×7 2×3」
static func _spread(hist: Array) -> String:
	var parts := PackedStringArray()
	for i in range(hist.size()):
		if int(hist[i]) > 0:
			parts.append("%d×%d" % [i, int(hist[i])])
	return " ".join(parts) if parts.size() > 0 else "-"
