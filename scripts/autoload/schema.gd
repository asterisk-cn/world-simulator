extends Node
## この世界に何が存在するかの定義。プレイヤー（神）が実行中に書き換える。
##
## - parameters: パラメータ。対象範囲が「自分」か「相手ごと」かが違うだけで、扱いは同じ。
## - actions:    アクション。名前と「動作の型」だけを持つ。
##
## 【前提】判断はAIが行う。
## パラメータはAIに渡される語彙であって、行動を決める式ではない。
## だからここには、値がどう動くかも、どの行動がいつ選ばれるかも書かれていない。
## 責務の分界は DESIGN.md を参照。

signal parameters_changed
signal actions_changed
signal recipes_changed
signal villagers_changed

const SCOPE_SELF := "self"
const SCOPE_PAIR := "pair"

const SCOPE_LABEL := {
	SCOPE_SELF: "胸のうち",
	SCOPE_PAIR: "間柄",
}

# ---------------------------------------------------------------------------
# 動作の型と対象
#
# アクションは「型 × 対象」で表す。型は何をするかの動詞、対象は何に対してか。
# ここに書いてあるのは世界で起きることだけで、
# 誰がいつそれを選ぶか、その結果どう感じるかは書かれていない。
# ---------------------------------------------------------------------------

const BEHAVIORS := {
	"move": {"label": "動く"},
	"gather": {"label": "採る"},
	"craft": {"label": "作る"},
	"build": {"label": "建てる"},
	"use": {"label": "使う"},
	"social": {"label": "関わる"},
}

## 型ごとに選べる対象。
##   targeted … 相手（村人）を取るか
##   reach    … その場で行うのに必要な近さ（マス）。
##              -1 は「目的地まで移動してから行う」動作。
##              0以上なら、いま届く範囲になければそもそも選択肢に出ない。
##              使用と交流は届く範囲でしか行えないので、遠ければ先に「動く」必要がある。
const TARGETS := {
	"move": {
		"anywhere": {"label": "適当な場所", "targeted": false, "duration": 0.8, "reach": -1.0},
		"toward": {"label": "誰かのそばへ", "targeted": true, "duration": 0.4, "reach": -1.0},
		"away": {"label": "誰かから離れて", "targeted": true, "duration": 0.4, "reach": -1.0},
		"home": {"label": "自分の家へ", "targeted": false, "duration": 0.4, "reach": -1.0},
		"board": {"label": "掲示板へ", "targeted": false, "duration": 0.4, "reach": -1.0},
	},
	"gather": {
		"berry": {"label": "木の実", "targeted": false, "duration": 1.4, "reach": -1.0},
		"tree": {"label": "木", "targeted": false, "duration": 1.4, "reach": -1.0},
		"rock": {"label": "石", "targeted": false, "duration": 1.4, "reach": -1.0},
	},
	"craft": {},
	"build": {
		"house": {"label": "家", "targeted": false, "duration": 2.5, "reach": -1.0},
	},
	"use": {
		"food": {"label": "食料", "targeted": false, "duration": 0.8, "reach": 999.0},
		"home": {"label": "自分の家", "targeted": false, "duration": 5.0, "reach": 1.6},
	},
	"social": {
		"talk": {"label": "誰かと話す", "targeted": true, "duration": 1.5, "reach": 2.2},
		"post": {"label": "掲示板に貼る", "targeted": false, "duration": 2.0, "reach": 2.2},
		"read": {"label": "掲示板を読む", "targeted": false, "duration": 1.5, "reach": 2.2},
	},
}

# ---------------------------------------------------------------------------
# 世界に置く人
#
# 名前も性格も、AIが「この人はこういう人だ」と受け取るための素でしかない。
# ここから行動が導出されることはない。だから定義が持つのは、
# 誰なのか（名前・色・一言）と、始まりの状態（性格の4軸・持ち物）だけ。
# ---------------------------------------------------------------------------

const NAMES := ["ハル", "ミナ", "ソウ", "リク", "ノア", "カイ", "ユキ", "トウ",
	"レン", "サキ", "ジン", "アオ"]

const PALETTE := [
	Color(0.90, 0.45, 0.40), Color(0.40, 0.65, 0.92), Color(0.55, 0.80, 0.45),
	Color(0.93, 0.75, 0.35), Color(0.72, 0.55, 0.92), Color(0.40, 0.82, 0.80),
	Color(0.92, 0.58, 0.75), Color(0.65, 0.70, 0.45), Color(0.85, 0.60, 0.35),
	Color(0.50, 0.55, 0.85), Color(0.70, 0.85, 0.60), Color(0.88, 0.50, 0.55),
]

## n×n の間柄が読める上限。これを超えると、見るための面が先に壊れる。
const MAX_VILLAGERS := 12

const DEFAULT_VILLAGERS := 8


## 世界に元からある持ち物。採取で手に入る。
const ITEMS := {
	"food": "木の実",
	"wood": "木",
	"stone": "石",
}

var parameters: Array = []
var actions: Array = []
var recipes: Array = []
var villagers: Array = []


func _ready() -> void:
	reset_all()


# ---------------------------------------------------------------------------
# レシピ
# ---------------------------------------------------------------------------

func _default_recipes() -> void:
	recipes = [
		{"id": "tool", "label": "道具", "inputs": {"wood": 1, "stone": 1}},
	]


func recipe_def(id: String) -> Variant:
	for r in recipes:
		if String(r["id"]) == id:
			return r
	return null


## 元からある持ち物と、レシピで作れるものを合わせた一覧
func all_items() -> Array:
	var out: Array = ITEMS.keys()
	for r in recipes:
		out.append(String(r["id"]))
	return out


func item_label(id: String) -> String:
	if ITEMS.has(id):
		return String(ITEMS[id])
	var r = recipe_def(id)
	return id if r == null else String(r["label"])


func add_recipe() -> Dictionary:
	var taken: Array = []
	for r in recipes:
		taken.append(String(r["id"]))
	var r2 := {"id": _unique_id("r", taken), "label": "新しいもの", "inputs": {}}
	recipes.append(r2)
	recipes_changed.emit()
	actions_changed.emit()
	return r2


func remove_recipe(id: String) -> void:
	for i in range(recipes.size()):
		if String(recipes[i]["id"]) == id:
			recipes.remove_at(i)
			break
	# 消えたレシピを材料にしていたものと、作ろうとしていたアクションを片付ける
	for r in recipes:
		r["inputs"].erase(id)
	var kept: Array = []
	for a in actions:
		if String(a["kind"]) == "craft" and String(a["target"]) == id:
			continue
		kept.append(a)
	actions = kept
	recipes_changed.emit()
	actions_changed.emit()


func set_recipe_input(id: String, item: String, n: int) -> void:
	var r = recipe_def(id)
	if r == null:
		return
	if n <= 0:
		r["inputs"].erase(item)
	else:
		r["inputs"][item] = n
	recipes_changed.emit()


func rename_recipe(id: String, label: String) -> void:
	var r = recipe_def(id)
	if r != null:
		r["label"] = label
		actions_changed.emit()


func reset_all() -> void:
	_default_recipes()
	_default_parameters()
	_default_actions()
	_default_villagers()
	parameters_changed.emit()
	recipes_changed.emit()
	actions_changed.emit()
	villagers_changed.emit()


# ---------------------------------------------------------------------------
# 世界に置く人
# ---------------------------------------------------------------------------

func _default_villagers() -> void:
	villagers = []
	for i in range(DEFAULT_VILLAGERS):
		villagers.append(_make_villager(i))


## 既定の一人。性格は振っておく。神が触らなければ、そのまま世界へ出る。
func _make_villager(i: int) -> Dictionary:
	var taken: Array = []
	for h in villagers:
		taken.append(String(h["id"]))
	var p := Personality.random()
	return {
		"id": _unique_id("h", taken),
		"name": NAMES[i % NAMES.size()],
		"color": PALETTE[i % PALETTE.size()],
		"quirk": p.quirk,
		"axes": {"ei": p.ei, "sn": p.sn, "tf": p.tf, "jp": p.jp},
		"items": {"food": randi_range(0, 2)},
	}


func add_villager() -> Dictionary:
	if villagers.size() >= MAX_VILLAGERS:
		return {}
	var h := _make_villager(villagers.size())
	villagers.append(h)
	villagers_changed.emit()
	return h


func remove_villager(id: String) -> void:
	if villagers.size() <= 1:
		return  # 誰もいない世界は観察できない
	for i in range(villagers.size()):
		if String(villagers[i]["id"]) == id:
			villagers.remove_at(i)
			break
	villagers_changed.emit()


## 次に空いている色。同じ色が2人いると、世界の上でも間柄の表でも見分けがつかない。
func next_color(from: Color) -> Color:
	var used := {}
	for h in villagers:
		used[Color(h["color"]).to_html(false)] = true
	var start := 0
	for i in range(PALETTE.size()):
		if PALETTE[i].is_equal_approx(from):
			start = i + 1
			break
	for k in range(PALETTE.size()):
		var c: Color = PALETTE[(start + k) % PALETTE.size()]
		if not used.has(c.to_html(false)):
			return c
	return PALETTE[(start) % PALETTE.size()]


# ---------------------------------------------------------------------------
# パラメータ
# ---------------------------------------------------------------------------

## カテゴリの色。カテゴリを作った順に上から割り当てる。
const CATEGORY_COLORS := [
	Color(0.92, 0.42, 0.34),
	Color(0.38, 0.72, 0.96),
	Color(0.52, 0.84, 0.46),
	Color(0.55, 0.85, 0.95),
	Color(1.00, 0.78, 0.40),
	Color(0.78, 0.62, 0.95),
	Color(0.95, 0.62, 0.45),
	Color(0.75, 0.78, 0.82),
]


func make_param(id: String, label: String, scope: String, category: String,
		vmin: float = 0.0, vmax: float = 100.0) -> Dictionary:
	return {
		"id": id, "label": label, "scope": scope, "category": category,
		"min": vmin, "max": vmax,
	}


func _default_parameters() -> void:
	parameters = [
		make_param("hunger", "空腹", SCOPE_SELF, "生存"),
		make_param("sleep", "睡眠", SCOPE_SELF, "生存"),
		make_param("safety", "不安", SCOPE_SELF, "生存"),
		make_param("home", "居住", SCOPE_SELF, "生存"),
		make_param("boredom", "退屈", SCOPE_SELF, "好奇心"),
		make_param("stagnation", "停滞", SCOPE_SELF, "好奇心"),
		make_param("loneliness", "孤独", SCOPE_SELF, "共同体"),
		make_param("crowding", "過密", SCOPE_SELF, "共同体"),
		make_param("unfairness", "不公平", SCOPE_SELF, "共同体"),

		make_param("affinity", "好感", SCOPE_PAIR, "親しみ", -100.0, 100.0),
		make_param("trust", "信頼", SCOPE_PAIR, "親しみ", -100.0, 100.0),
		make_param("respect", "敬意", SCOPE_PAIR, "評価"),
		make_param("debt", "負い目", SCOPE_PAIR, "評価", -100.0, 100.0),
	]


func params_in(scope: String) -> Array:
	var out: Array = []
	for d in parameters:
		if String(d["scope"]) == scope:
			out.append(d)
	return out


func self_params() -> Array:
	return params_in(SCOPE_SELF)


func pair_params() -> Array:
	return params_in(SCOPE_PAIR)


func ids_in(scope: String) -> Array:
	var out: Array = []
	for d in params_in(scope):
		out.append(String(d["id"]))
	return out


func param_def(id: String) -> Variant:
	for d in parameters:
		if String(d["id"]) == id:
			return d
	return null


func has_param(id: String) -> bool:
	return param_def(id) != null


func param_label(id: String) -> String:
	var d = param_def(id)
	return id if d == null else String(d["label"])


## 色はカテゴリで決まる。同じカテゴリの中では少しずつ明るさをずらして見分ける。
func category_color(cat: String) -> Color:
	var all := all_categories()
	var i := all.find(cat)
	if i < 0:
		return Color(0.75, 0.78, 0.82)
	return CATEGORY_COLORS[i % CATEGORY_COLORS.size()]


func all_categories() -> Array:
	var out: Array = []
	for d in parameters:
		var c := String(d["category"])
		if not out.has(c):
			out.append(c)
	return out


func param_color(id: String) -> Color:
	var d = param_def(id)
	if d == null:
		return Color.WHITE
	var cat := String(d["category"])
	var base := category_color(cat)
	var n := 0
	for other in parameters:
		if String(other["id"]) == id:
			break
		if String(other["category"]) == cat:
			n += 1
	return base.lightened(minf(float(n) * 0.14, 0.42))


func param_min(id: String) -> float:
	var d = param_def(id)
	return 0.0 if d == null else float(d["min"])


func param_max(id: String) -> float:
	var d = param_def(id)
	return 100.0 if d == null else float(d["max"])


func categories_in(scope: String) -> Array:
	var out: Array = []
	for d in params_in(scope):
		var c := String(d["category"])
		if not out.has(c):
			out.append(c)
	return out


## パラメータはカテゴリの中に足す。個々にカテゴリを選ばせない。
func add_param(scope: String, category: String, label: String = "新パラメータ") -> Dictionary:
	var taken: Array = []
	for d in parameters:
		taken.append(String(d["id"]))
	var p := make_param(_unique_id("p", taken), label, scope, category)
	parameters.append(p)
	parameters_changed.emit()
	return p


## 空のカテゴリは持てないので、カテゴリを作るときは中身を1つ添える
func add_category(scope: String) -> String:
	var taken := categories_in(scope)
	var i := 1
	while taken.has("新カテゴリ%d" % i):
		i += 1
	var cat := "新カテゴリ%d" % i
	add_param(scope, cat)
	return cat


func remove_category(scope: String, cat: String) -> void:
	var kept: Array = []
	for d in parameters:
		if String(d["scope"]) == scope and String(d["category"]) == cat:
			continue
		kept.append(d)
	parameters = kept
	parameters_changed.emit()


func rename_category(scope: String, old_name: String, new_name: String) -> void:
	if new_name.strip_edges() == "":
		return
	for d in parameters:
		if String(d["scope"]) == scope and String(d["category"]) == old_name:
			d["category"] = new_name
	parameters_changed.emit()


func remove_param(id: String) -> void:
	for i in range(parameters.size()):
		if String(parameters[i]["id"]) == id:
			parameters.remove_at(i)
			break
	parameters_changed.emit()


# ---------------------------------------------------------------------------
# アクション
# ---------------------------------------------------------------------------

func make_action(id: String, label: String, kind: String, target: String) -> Dictionary:
	return {"id": id, "label": label, "kind": kind, "target": target}


func _default_actions() -> void:
	actions = [
		make_action("eat", "食べる", "use", "food"),
		make_action("sleep", "眠る", "use", "home"),
		make_action("forage", "木の実を採る", "gather", "berry"),
		make_action("chop", "木を切る", "gather", "tree"),
		make_action("mine", "石を掘る", "gather", "rock"),
		make_action("build", "家を建てる", "build", "house"),
		make_action("talk", "話す", "social", "talk"),
		make_action("post", "掲示板に貼る", "social", "post"),
		make_action("read", "掲示板を読む", "social", "read"),
		make_action("approach", "近づく", "move", "toward"),
		make_action("avoid", "離れる", "move", "away"),
		make_action("craft_tool", "道具を作る", "craft", "tool"),
		make_action("wander", "歩き回る", "move", "anywhere"),
	]


func action_ids() -> Array:
	var out: Array = []
	for a in actions:
		out.append(String(a["id"]))
	return out


func action(id: String) -> Variant:
	for a in actions:
		if String(a["id"]) == id:
			return a
	return null


func add_action(label: String = "新しい行動") -> Dictionary:
	var id := _unique_id("a", action_ids())
	var a := make_action(id, label, "move", "anywhere")
	actions.append(a)
	actions_changed.emit()
	return a


func remove_action(id: String) -> void:
	for i in range(actions.size()):
		if String(actions[i]["id"]) == id:
			actions.remove_at(i)
			break
	actions_changed.emit()


func behavior_label(kind: String) -> String:
	if BEHAVIORS.has(kind):
		return String(BEHAVIORS[kind]["label"])
	return kind


## 制作の対象はレシピそのもの。レシピを足せば作れるものが増える。
func targets_of(kind: String) -> Dictionary:
	if kind == "craft":
		var out := {}
		for r in recipes:
			out[String(r["id"])] = {
				"label": String(r["label"]), "targeted": false,
				"duration": 1.6, "reach": 999.0,
			}
		return out
	return TARGETS.get(kind, {})


func target_def(kind: String, target: String) -> Variant:
	var t: Dictionary = targets_of(kind)
	return t.get(target, null)


func target_label(kind: String, target: String) -> String:
	var d = target_def(kind, target)
	return target if d == null else String(d["label"])


func is_targeted(kind: String, target: String) -> bool:
	var d = target_def(kind, target)
	return false if d == null else bool(d["targeted"])


func duration_of(kind: String, target: String) -> float:
	var d = target_def(kind, target)
	return 1.0 if d == null else float(d["duration"])


## その場で行うのに必要な近さ。-1 なら移動してから行う動作。
func reach_of(kind: String, target: String) -> float:
	var d = target_def(kind, target)
	return -1.0 if d == null else float(d["reach"])


## 型を変えたとき、対象がその型で使えなければ先頭の対象に寄せる
func first_target(kind: String) -> String:
	var t: Dictionary = targets_of(kind)
	return "" if t.is_empty() else String(t.keys()[0])


func _unique_id(prefix: String, taken: Array) -> String:
	var i := 1
	while taken.has("%s%d" % [prefix, i]):
		i += 1
	return "%s%d" % [prefix, i]
