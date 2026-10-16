class_name FlowRun
extends Node
## **流れのシナリオを通しで動かす**（検証用）。最初の顔ぶれと、夜ごとに書き足す言葉・人を
## ファイルに書いておき、村を何日か動かして、Jev が何を選び、値をどう答えたかを日ごとに数える。
##
##   godot --headless --path . -- --flow=名前 [--days=N] [--speed=1] [--seed=N] [--with-text] [--judge]
##
## シナリオは `res://bench/flows/*.json`、書き方は `bench/flows/README.md`。
## 名前はファイル名の頭（`--flow=01` で `01_….json`）。
##
## 始めるのは `--autostart` と同じ道（`main._autostart`）で、`Schema.load_defaults` の代わりに
## ファイルから組む。夜は、書き足しがあれば**夜の紙と同じ順で絵を通さずに**入れる
## （`main.night_quiet`）：書き足した物の手に入れかたを Jev に訊く → 書き足した人を置いて考えさせる
## → 固める → 時間を動かす。書き足しの無い夜は、そのまま朝へ進む。
##
## 終わりは**村の中の日**で決める（`終わり.日` の次の日になったら止める）。実時間の秒では数えない——
## 夜に Jev を待って止まっているあいだも秒は進むので。
##
## 文章の相手（作者の財布から出るほう）は既定で止める（`AI.text_off`）。
## 結果は標準出力と `user://jev_bench/flow-*.md`（.json が答えそのもの）。

const DIR := "res://bench/flows"
## Jev が返らずに止まったままのとき、実時間でここまで待ったら打ち切る（村の時間の何倍か）
const STUCK_RATIO := 3.0
const STUCK_PAD := 120.0

var world
var main
var flow_name := ""
var check := false
var speed := 1.0

var _d: Dictionary = {}
var _file := ""
var _end_day := 1
var _phase := "wait"
var _t_start := 0.0
var _limit := 0.0
var _timed_out := false
## 夜ごとに何が足されたか（表に出す）。{日: [文…]}
var _added := {}
## 夜の書き足しが Jev で止まった
var _night_failed := ""


func _init(p_world = null, p_main = null, p_name := "") -> void:
	world = p_world
	main = p_main
	flow_name = p_name


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var days := -1
	for a in args:
		var s := String(a)
		if s.begins_with("--days="):
			days = int(s.get_slice("=", 1))
		elif s.begins_with("--speed="):
			speed = float(s.get_slice("=", 1))
		elif s.begins_with("--seed="):
			seed(int(s.get_slice("=", 1)))
		elif s == "--judge":
			check = true
	# 書き方の誤りは、鍵が無くても先に言う
	if not _load():
		return
	var errors := _build()
	if not errors.is_empty():
		for e in errors:
			print("[流れ] %s：%s" % [_file, e])
		_quit_early("書き方に誤りがあるので始めない")
		return
	if not AI.can_decide():
		_quit_early("Jev の鍵が無い（TYPESAFE_API_KEY か res://.typesafe-key）")
		return
	AI.text_off = not args.has("--with-text")
	_end_day = days if days > 0 else int(_d.get("終わり", {}).get("日", 3))
	var day_len := SimConfig.p("day_length_sec")
	_limit = float(_end_day) * day_len / maxf(speed, 0.01) * STUCK_RATIO + STUCK_PAD
	JevBench._live = []
	JevBench._closed = []
	print("[流れ] %s を %d日目まで（1日 %.0f秒・速さ ×%.1f）、村人 %d人、文章の相手 %s"
		% [_file, _end_day, day_len, speed, Schema.villagers.size(),
			"使う" if not AI.text_off else "使わない"])
	_t_start = _now()
	main._autostart()


func _process(_delta: float) -> void:
	match _phase:
		"wait":
			if world != null and world.villagers.size() > 0 and not SimClock.paused:
				_phase = "live"
				SimClock.speed = speed
				JevBench._t0 = _now()
				JevBench.active = true
		"live":
			if SimClock.day > _end_day or _night_failed != "":
				_finish()
				return
	if _phase != "done" and _now() - _t_start > _limit:
		_timed_out = true
		_finish()


static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _quit_early(why: String) -> void:
	print("[流れ] %s" % why)
	_phase = "done"
	if check:
		Expect.save_check("flow-%s" % (_file if _file != "" else flow_name),
			[{"name": String(_d.get("名前", _file if _file != "" else flow_name)), "verdict": Expect.FAIL,
				"rows": [{"text": "始める", "verdict": Expect.FAIL, "got": why}]}], "")
	get_tree().quit(1)


# ---------------------------------------------------------------------------
# 読む・組む
# ---------------------------------------------------------------------------

func _load() -> bool:
	var names: Array = []
	for f in DirAccess.get_files_at(DIR):
		if String(f).ends_with(".json") and String(f).begins_with(flow_name):
			names.append(String(f))
	names.sort()
	if names.is_empty():
		_quit_early("%s に「%s」で始まる流れが無い" % [DIR, flow_name])
		return false
	if names.size() > 1:
		_quit_early("「%s」で始まる流れが%d本ある（%s）。1本に絞る" % [flow_name, names.size(),
			"、".join(PackedStringArray(names))])
		return false
	_file = String(names[0]).get_basename()
	var d = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [DIR, names[0]]))
	if typeof(d) != TYPE_DICTIONARY:
		_quit_early("%s が JSON として読めない" % names[0])
		return false
	_d = d
	return true


## ファイルから Schema と目盛りを組む。誤りの一覧を返す（空なら組めた）。
## **1つでも誤りがあれば始めない**——言葉が1つ欠けた流れは、確かめたい話が成り立たない
func _build() -> Array:
	var errors: Array = []
	Schema.reset_all()

	var scale: Dictionary = _d.get("目盛り", {})
	for label in scale:
		var key := ""
		for k in SimConfig.PARAM_DEF:
			if String(SimConfig.PARAM_DEF[k][3]) == String(label):
				key = k
		if key == "":
			errors.append("目盛り「%s」は無い" % label)
			continue
		SimConfig.set_param(key, float(scale[label]))

	var first: Dictionary = _d.get("はじめ", {})
	_add_words(first, errors, "はじめ")
	if Schema.villagers.is_empty():
		errors.append("はじめに村人がいない")
	var taken := _labels()
	for kind in taken:
		var seen := {}
		for label in taken[kind]:
			if seen.has(label):
				errors.append("はじめ：「%s」が2つある" % label)
			seen[label] = true

	var end_day := int(_d.get("終わり", {}).get("日", 3))
	var nights: Dictionary = _d.get("夜", {})
	for k in nights:
		if not String(k).is_valid_int() or int(k) < 1:
			errors.append("夜「%s」は日の番号で書く" % k)
		elif int(k) >= end_day:
			errors.append("夜 %s は終わり（%d日目）より後なので来ない" % [k, end_day])
	# 夜の分も、名前がぶつからないかだけ先に確かめる（足すのはその夜）
	for k in nights:
		for e in _check_night(nights[k], taken):
			errors.append("夜 %s：%s" % [k, e])
	return errors


## 言葉・物・建物・人を Schema に足す。足した文の一覧を返す
func _add_words(part: Dictionary, errors: Array, where: String) -> Array:
	var said: Array = []
	for scope in [Schema.SCOPE_SELF, Schema.SCOPE_PAIR]:
		var key := "じぶん" if scope == Schema.SCOPE_SELF else "あいて"
		for label in part.get(key, []):
			var p := Schema.add_param(scope, String(label))
			p["label"] = String(label)
			said.append("%s「%s」" % [key, label])
	for it in part.get("もちもの", []):
		var label := _name_of(it)
		if Schema.recipe_def(_root_id(label)) != null:
			continue   # 島に在るもの（木の実・木・石）は、はじめから在る
		var r := Schema.add_recipe()
		r["label"] = label
		_art(r, it, Schema.CRAFT_ARTS, errors, where)
		said.append("もちもの「%s」" % label)
	for it in part.get("たてもの", []):
		var label := _name_of(it)
		var b := Schema.add_building()
		b["label"] = label
		_art(b, it, Schema.BUILDING_ARTS, errors, where)
		said.append("たてもの「%s」" % label)
	for h in part.get("村人", []):
		var one: Dictionary = h if typeof(h) == TYPE_DICTIONARY else {"名前": String(h)}
		var v := Schema.add_villager()
		if v.is_empty():
			errors.append("%s：村人が %d人を超える" % [where, Schema.MAX_VILLAGERS])
			break
		v["name"] = String(one.get("名前", v["name"]))
		if one.has("性格"):
			v["quirk"] = String(one["性格"])
		if one.has("気質"):
			var words: Array = one["気質"]
			for a in Personality.AXES:
				v["axes"][String(a[0])] = 1.0 if words.has(String(a[3])) else 0.0
		said.append("村人「%s」" % v["name"])
	Schema._emit_all()
	return said


## 島に在るものの名前 → id（無ければ空）
static func _root_id(label: String) -> String:
	for id in Schema.WORLD_ARTS:
		if Schema.item_label(String(id)) == label:
			return String(id)
	return ""


static func _name_of(it) -> String:
	return String(it.get("名前", "")) if typeof(it) == TYPE_DICTIONARY else String(it)


## 姿。書いてあれば、用意された姿の名前（「家」「井戸」「道具」…）から選ぶ
static func _art(d: Dictionary, it, arts: Array, errors: Array, where: String) -> void:
	if typeof(it) != TYPE_DICTIONARY or not it.has("姿"):
		return
	for a in arts:
		if String(Schema.ART_LABEL.get(a, "")) == String(it["姿"]):
			d["art"] = a
			return
	errors.append("%s：姿「%s」は無い" % [where, it["姿"]])


## いま在る名前（ぶつかりを見る用）。言葉・物と建物・人で別々に
static func _labels() -> Dictionary:
	var out := {"words": [], "things": [], "people": []}
	for p in Schema.parameters:
		out["words"].append(String(p["label"]))
	for r in Schema.recipes:
		out["things"].append(String(r["label"]))
	for b in Schema.buildings:
		out["things"].append(String(b["label"]))
	for h in Schema.villagers:
		out["people"].append(String(h["name"]))
	return out


## 夜の分を足すとぶつかるか。`taken` は足していく（夜をまたいでぶつかるのも見る）
static func _check_night(part, taken: Dictionary) -> Array:
	var errors: Array = []
	if typeof(part) != TYPE_DICTIONARY:
		return ["中身は物で書く"]
	for key in part:
		if not ["じぶん", "あいて", "もちもの", "たてもの", "村人"].has(String(key)):
			errors.append("「%s」は書き足せない" % key)
	var pairs := [["じぶん", "words"], ["あいて", "words"], ["もちもの", "things"],
		["たてもの", "things"], ["村人", "people"]]
	for pr in pairs:
		for it in part.get(pr[0], []):
			var label := _name_of(it)
			if taken[pr[1]].has(label):
				errors.append("%s「%s」はもう在る" % [pr[0], label])
			taken[pr[1]].append(label)
	if taken["people"].size() > Schema.MAX_VILLAGERS:
		errors.append("村人が %d人を超える" % Schema.MAX_VILLAGERS)
	return errors


# ---------------------------------------------------------------------------
# 夜
# ---------------------------------------------------------------------------

## `main._open_night` から呼ばれる。書き足しがあれば入れ、無ければ何もしない（朝へ進む）
func night(day: int) -> void:
	var part = _d.get("夜", {}).get(str(day), null)
	if part == null or _phase != "live":
		return
	var errors: Array = []
	var said := _add_words(part, errors, "夜 %d" % day)
	_added[day] = said
	print("[流れ] %d日目の夜：%s" % [day, "、".join(PackedStringArray(said))])
	main.night_quiet(func(ok: bool) -> void:
		if not ok:
			_night_failed = "%d日目の夜：Jev から手に入れかたが返らない" % day)


# ---------------------------------------------------------------------------
# 表にする
# ---------------------------------------------------------------------------

func _finish() -> void:
	_phase = "done"
	JevBench.active = false
	var rs: Array = JevBench._live
	var verdicts := _judge(rs)
	var out := PackedStringArray()
	out.append("# 流れ：%s（%s）" % [String(_d.get("名前", _file)),
		Time.get_datetime_string_from_system(false, true)])
	out.append("")
	if String(_d.get("ねらい", "")) != "":
		out.append("ねらい：%s" % _d["ねらい"])
		out.append("")
	out.append("- %d日目まで（1日 %.0f秒・速さ ×%.1f）、村人 %d人、Jev の答え %d件"
		% [_end_day, SimConfig.p("day_length_sec"), speed, world.villagers.size(), rs.size()])
	out.append("- 投げた問い %d件（失敗 %d・置き換え %d）。文章の相手は%s"
		% [AI.sent, AI.failed, AI.dropped, "使った" if not AI.text_off else "止めた"])
	if _timed_out:
		out.append("- **時間切れ**：%.0f秒たっても %d日目が終わらなかった（%d日目で止めた）"
			% [_limit, _end_day, SimClock.day])
	if _night_failed != "":
		out.append("- **止まった**：%s" % _night_failed)
	out.append("")
	if not verdicts.is_empty():
		out.append("## 期待")
		out.append("")
		out.append_array(Expect.table(verdicts))
		out.append("")
	out.append("## 日ごと")
	out.append("")
	out.append_array(_day_table(rs))
	out.append("")
	out.append("## 手に入れかた（Jev が組んだ木）")
	out.append("")
	for r in Schema.recipes:
		out.append("- %s：%s" % [r["label"], Schema.recipe_text(String(r["id"]))])
	for b in Schema.buildings:
		out.append("- %s：%s" % [b["label"], Schema.inputs_text(String(b["id"]))])
	out.append("")
	out.append("<details><summary>流れのファイル</summary>")
	out.append("")
	out.append("```json")
	out.append(JSON.stringify(_d, "  ", false))
	out.append("```")
	out.append("")
	out.append("</details>")
	var md := "\n".join(out)
	print("\n" + md)

	var dir := "user://jev_bench"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	var path := "%s/flow-%s-%s.md" % [dir, _file, stamp]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(md)
		f.close()
	var j := FileAccess.open(path.replace(".md", ".json"), FileAccess.WRITE)
	if j != null:
		j.store_string(JSON.stringify({"flow": _d, "added": _added, "live": rs,
			"closed": JevBench._closed}, "\t"))
		j.close()
	print("[流れ] 書き出した：%s" % ProjectSettings.globalize_path(path))

	var w := Expect.worst(verdicts) if not verdicts.is_empty() else Expect.PASS
	if _timed_out or _night_failed != "":
		w = Expect.FAIL
	if check:
		Expect.save_check("flow-%s" % _file, [{"name": String(_d.get("名前", _file)),
			"verdict": w, "rows": verdicts}], path)
	get_tree().quit(1 if check and w == Expect.FAIL else 0)


## 期待を判定する。`日` と `村人` で答えを絞ってから数える
func _judge(rs: Array) -> Array:
	var out: Array = []
	var move_of := func(r: Dictionary, kind: String, key: String):
		if kind != "self":
			return null
		var s: Dictionary = r["scores"][key]
		if not s.has("before"):
			return null
		return float(s["after"]) - float(s["before"])
	# 物の名前 → 手に入れかたの文（材料も場所も無ければ空）
	var tree := {}
	for r in Schema.recipes:
		var id := String(r["id"])
		tree[String(r["label"])] = Schema.recipe_text(id) \
			if not Schema.inputs_of(id).is_empty() or Schema.place_of(id) != "" else ""
	for b in Schema.buildings:
		var id := String(b["id"])
		tree[String(b["label"])] = Schema.inputs_text(id) \
			if not Schema.inputs_of(id).is_empty() else ""
	for e in _d.get("期待", []):
		var span := _days(String(e.get("日", "")))
		var picked: Array = []
		var by := {}
		for r in rs:
			var day := int(r.get("day", 0))
			if day < span[0] or day > span[1]:
				continue
			by[String(r["who"])] = int(by.get(String(r["who"]), 0)) + 1
			if e.has("村人") and not e.has("考えた") and String(r["who"]) != String(e["村人"]):
				continue
			picked.append(r)
		out.append(Expect.judge(e, Expect.summarize(picked, move_of), {"by": by, "tree": tree}))
	return out


## 「3」「3-」「-2」「2-4」→ [から, まで]。空なら全部の日
static func _days(s: String) -> Array:
	if s == "":
		return [0, 1 << 30]
	if not s.contains("-"):
		return [int(s), int(s)]
	var lo := s.get_slice("-", 0)
	var hi := s.get_slice("-", 1)
	return [int(lo) if lo != "" else 0, int(hi) if hi != "" else 1 << 30]


## 日ごとの表。答えの数、いちばん多い手、自分の言葉の段階の平均、その夜に足したもの
func _day_table(rs: Array) -> PackedStringArray:
	var labels: Array = []
	for d in Schema.self_params():
		labels.append(String(d["label"]))
	var head := "| 日 | 答え | 考えた人 | いちばん多い手 | 割合 |"
	var line := "|---:|---:|---:|---|---:|"
	for l in labels:
		head += " %s |" % l
		line += "---:|"
	head += " その夜に足したもの |"
	line += "---|"
	var out := PackedStringArray([head, line])
	for day in range(1, _end_day + 1):
		var picked: Array = rs.filter(func(r): return int(r.get("day", 0)) == day)
		var who := {}
		for r in picked:
			who[String(r["who"])] = true
		var sum := Expect.summarize(picked, func(_r, _k, _key): return null)
		var top := ""
		for a in sum["acts"]:
			if top == "" or float(sum["acts"][a]) > float(sum["acts"][top]):
				top = a
		var row := "| %d | %d | %d | %s | %s |" % [day, picked.size(), who.size(),
			top if top != "" else "-",
			"%.0f%%" % (float(sum["acts"][top]) * 100.0) if top != "" else "-"]
		for l in labels:
			var s = sum["self"].get(l, null)
			row += " %s |" % ("%.1f" % s["level"] if s != null else "-")
		row += " %s |" % "、".join(PackedStringArray(_added.get(day, [])))
		out.append(row)
	out.append("")
	out.append("自分の言葉の数は、答えた段階（0〜%d）の平均" % (Brain.LEVELS.size() - 1))
	return out
