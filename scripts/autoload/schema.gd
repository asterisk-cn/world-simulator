extends Node
## この世界に何が存在するかの定義。プレイヤー（神）が実行中に書き換える。
##
## - parameters: パラメータ。対象範囲が「自分」か「相手ごと」かが違うだけで、扱いは同じ。
## - recipes / buildings: つくりかた。作れるものと建てられるもの。名前と姿だけを持つ。
##
## アクションの定義は無い。型（動く・使う・作る・話す）は世界に元からあり、
## 対象はここにある物から導かれるので、並べて持つ意味がない。
##
## 【前提】判断はAIが行う。
## パラメータはAIに渡される語彙であって、行動を決める式ではない。
## だからここには、値がどう動くかも、どの行動がいつ選ばれるかも書かれていない。
## 責務の分界は DESIGN.md を参照。

signal parameters_changed
signal recipes_changed
signal buildings_changed
signal villagers_changed

const SCOPE_SELF := "self"
const SCOPE_PAIR := "pair"

## その言葉が誰のものか。**じぶん**は一人につき1つ、**あいて**は相手ひとりごとに1つ。
## 設計図の章の名前と、インスペクタの見出しは、どちらもここから出る（同じ物は同じ名前）。
const SCOPE_LABEL := {
	SCOPE_SELF: "じぶん",
	SCOPE_PAIR: "あいて",
}

# ---------------------------------------------------------------------------
# 動作の型と対象
#
# アクションは「型 × 対象」で表す。型は何をするかの動詞、対象は何に対してか。
#
# **型は4つしかなく、増やせない。** 神が与えるのは名詞（ことば・つくりかた）のほうで、
# 動詞は世界に元からある。だから「ふるまいの一覧」という定義は存在せず、
# いま何ができるかは 型 × 対象 から毎回そのまま導かれる（`Brain.feasible`）。
#
# 採る は 使う に畳んだ。そこに生っている木の実に何かするのも、
# 手の中の木の実に何かするのも、その人にとっては同じ「使う」で、
# 違うのは世界の側で何が増えて何が減るかだけ。
# 建てる は 作る に畳んだ。持てるものを作るか、建つものを作るかの違いしかない。
# ---------------------------------------------------------------------------

const BEHAVIORS := {
	"move": {"label": "動く"},
	"use": {"label": "使う"},
	"make": {"label": "作る"},
	"talk": {"label": "話す"},
}

## 型ごとに選べる対象のうち、世界に元からあるもの。
##   duration … かかる時間
##   reach    … その場で行うのに必要な近さ（マス）。
##              -1 は「目的地まで移動してから行う」動作。
##              0以上なら、いま届く範囲になければそもそも選択肢に出ない。
##              遠ければ先に「動く」必要がある。
const TARGETS := {
	"move": {
		"anywhere": {"label": "適当な場所", "duration": 0.8, "reach": -1.0},
		"toward": {"label": "誰かのところ", "duration": 0.4, "reach": -1.0},
		"mine": {"label": "自分のところ", "duration": 0.4, "reach": -1.0},
		"board": {"label": "掲示板", "duration": 0.4, "reach": -1.0},
	},
	"talk": {
		"talk": {"label": "誰か", "duration": 1.5, "reach": 2.2},
		"post": {"label": "掲示板に貼る", "duration": 2.0, "reach": 2.2},
		"read": {"label": "掲示板を読む", "duration": 1.5, "reach": 2.2},
	},
	# 使う / 作る の対象は、世界にある物と神が決めた「つくりかた」から作る。
	"use": {},
	"make": {},
}

## 「使う」は、それがどこにあるかで間合いと時間が変わる。
## 何をするか（採る / 食べる / 祈る）ではなく、どこにあるかだけで決まる。
const USE_WAYS := {
	"world": {"duration": 1.4, "reach": -1.0},    # そこに在るものへ行って使う
	"hand": {"duration": 0.8, "reach": 999.0},    # 手の中のものを使う
	"building": {"duration": 4.0, "reach": 1.6},  # 建物のそばで使う
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

## n×n の関係の表が読める上限。これを超えると、見るための面が先に壊れる。
const MAX_VILLAGERS := 12

const DEFAULT_VILLAGERS := 8


## 世界に元からある持ち物。世界に在るそれを「使う」と手に入る。
const ITEMS := {
	"food": "木の実",
	"wood": "木",
	"stone": "石",
}

## 元からある持ち物の姿。世界に在るときと手の中にあるときで同じ絵になる。
const ITEM_ART := {"food": "berry", "wood": "tree", "stone": "rock"}

# ---------------------------------------------------------------------------
# 姿
#
# 世界に出るものの姿は、あらかじめ用意した中から神が選ぶ。
# 名前は神の言葉だが、姿は世界の側の持ち物なので、勝手に増えない。
# 絵の実体は `ui/item_icon.gd`（小さい絵）と `world/structure.gd`（世界の上の姿）。
# ---------------------------------------------------------------------------

## 作れるものに使える姿
const CRAFT_ARTS := ["tool", "blade", "pot", "bread", "cloth", "rope", "jewel", "torch"]

## 建てられるものに使える姿
const BUILDING_ARTS := ["house", "chapel", "hall", "store", "well", "tower"]

const ART_LABEL := {
	"berry": "木の実", "tree": "木", "rock": "石",
	"tool": "道具", "blade": "刃物", "pot": "壺", "bread": "焼いたもの",
	"cloth": "布", "rope": "縄", "jewel": "飾り", "torch": "あかり",
	"house": "家", "chapel": "尖り屋根", "hall": "広間", "store": "倉",
	"well": "井戸", "tower": "塔",
}

## 建物の色。建てるものを作った順に上から割り当てる。
## 世界の上に建ったものは**持ち主の色**になるので、ここが使われるのは
## まだ誰も建てていないとき（つくりかたタブの絵）と、持ち主のないもの（神が建てたもの）。
const BUILDING_COLORS := [
	Color(0.78, 0.36, 0.32), Color(0.55, 0.62, 0.82), Color(0.72, 0.66, 0.44),
	Color(0.48, 0.68, 0.58), Color(0.74, 0.55, 0.70), Color(0.62, 0.60, 0.58),
]

var parameters: Array = []
var recipes: Array = []
var buildings: Array = []
var villagers: Array = []


func _ready() -> void:
	reset_all()


# ---------------------------------------------------------------------------
# つくりかた（作れるもの / 建てられるもの）
#
# 定義が持つのは 名前 と 姿 だけ。
#
# 【前提】判断はAIが行う。
# 何をどれだけ使って作るかは、作る人が自分の持ち物を見て決める。
# だからここに材料は書かれていない。プログラムは「持っていないものは払えない」しか見ない。
# ---------------------------------------------------------------------------

func _default_recipes() -> void:
	recipes = [
		{"id": "tool", "label": "道具", "art": "tool"},
	]


## 家も、ただの「建てるもの」の1つ。建てた人のものになるが、何軒建つかは決まっていない。
func _default_buildings() -> void:
	buildings = [
		{"id": "b1", "label": "家", "art": "house"},
	]


func recipe_def(id: String) -> Variant:
	for r in recipes:
		if String(r["id"]) == id:
			return r
	return null


func building_def(id: String) -> Variant:
	for b in buildings:
		if String(b["id"]) == id:
			return b
	return null


func is_building(id: String) -> bool:
	return building_def(id) != null


## 元からある持ち物と、つくりかたで作れるものを合わせた一覧
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


## 持ち物の姿。元からある物は決まっていて、作るものは神が選んだ姿になる。
func item_art(id: String) -> String:
	if ITEM_ART.has(id):
		return String(ITEM_ART[id])
	var r = recipe_def(id)
	if r != null:
		return String(r["art"])
	# 姿の名前をそのまま渡されたとき（世界の物を直に指すとき）はそれを使う
	return id if ART_LABEL.has(id) else "tool"


func building_label(id: String) -> String:
	var b = building_def(id)
	return id if b == null else String(b["label"])


func building_art(id: String) -> String:
	var b = building_def(id)
	return "house" if b == null else String(b["art"])


func building_color(id: String) -> Color:
	for i in range(buildings.size()):
		if String(buildings[i]["id"]) == id:
			return BUILDING_COLORS[i % BUILDING_COLORS.size()]
	return BUILDING_COLORS[0]


func thing_art(id: String) -> String:
	return building_art(id) if is_building(id) else item_art(id)


func add_recipe() -> Dictionary:
	var taken: Array = []
	for r in recipes:
		taken.append(String(r["id"]))
	var r2 := {"id": _unique_id("r", taken), "label": "新しいもの",
		"art": CRAFT_ARTS[recipes.size() % CRAFT_ARTS.size()]}
	recipes.append(r2)
	recipes_changed.emit()
	return r2


func remove_recipe(id: String) -> void:
	for i in range(recipes.size()):
		if String(recipes[i]["id"]) == id:
			recipes.remove_at(i)
			break
	recipes_changed.emit()


func rename_recipe(id: String, label: String) -> void:
	var r = recipe_def(id)
	if r != null:
		r["label"] = label
		recipes_changed.emit()


func add_building() -> Dictionary:
	var taken: Array = []
	for b in buildings:
		taken.append(String(b["id"]))
	var b2 := {"id": _unique_id("b", taken), "label": "新しい建物",
		"art": BUILDING_ARTS[buildings.size() % BUILDING_ARTS.size()]}
	buildings.append(b2)
	buildings_changed.emit()
	return b2


func remove_building(id: String) -> void:
	for i in range(buildings.size()):
		if String(buildings[i]["id"]) == id:
			buildings.remove_at(i)
			break
	buildings_changed.emit()


func rename_building(id: String, label: String) -> void:
	var b = building_def(id)
	if b != null:
		b["label"] = label
		buildings_changed.emit()


## 姿を選ぶ。押すたびに、用意された姿を順に送る。
func cycle_art(d: Dictionary, arts: Array) -> void:
	var i := arts.find(String(d["art"]))
	d["art"] = String(arts[(i + 1) % arts.size()])
	recipes_changed.emit()
	buildings_changed.emit()


func reset_all() -> void:
	_default_recipes()
	_default_buildings()
	_default_parameters()
	_default_villagers()
	parameters_changed.emit()
	recipes_changed.emit()
	buildings_changed.emit()
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
		# 手ぶらで始まる。神が握らせておく欄は作らない——
		# 何を持つかはその人が世界から取ってくることで決まる。
		"items": {},
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


## 次に空いている色。同じ色が2人いると、世界の上でも関係の表でも見分けがつかない。
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

## 言葉の色。**語ごとに色を持たせるのはやめた。**
##
## 束（カテゴリ）を消したので、色を割り当てる順番そのものが無くなった。
## 順番で色相を回しても、じぶんの9語を暖色に閉じれば色相差が小さすぎて見分けられず、
## 閉じなければあいての色と混ざる。そして**色は人のもの**——
## 村人の色が世界でもUIでも識別子なので、語からも色を出すと競う。
##
## 語が何であるかは常に隣に字で書いてある。色は「どちらの話か」だけを言う。
const SCOPE_COLORS := {
	SCOPE_SELF: Color(0.55, 0.42, 0.26),  ## じぶん。土の色。「どれだけ」の話
	SCOPE_PAIR: Color(0.30, 0.55, 0.52),  ## あいての正の側。「どちらへ」の話
}

## あいての負の側。好感の裏の嫌悪、敬意の裏の侮り。
## **積み木（`PipBar`）と n×n の表（`matrix_panel`）で同じ赤を使う。**
## 表は色しか持たないので向きを色で言うしかなく、そこだけ赤で、
## インスペクタの積み木は1色、では同じものを2つの言い方で見せることになる。
const PAIR_NEG := Color(0.74, 0.26, 0.22)


## とりうる幅は神が決めるものではなく、スコープから決まる。
##
## じぶんは「どれだけ」の話なので 0〜100。空腹が負になることはない。
## あいては「どちらへ」の話なので −100〜100。真ん中が何とも思っていないところで、
## 好感の裏には嫌悪があり、敬意の裏には侮りがある。
## 幅を1本ずつ決めさせても、読み方が増えるだけで世界の見え方は変わらなかった。
const SCOPE_RANGE := {
	SCOPE_SELF: [0.0, 100.0],
	SCOPE_PAIR: [-100.0, 100.0],
}


func make_param(id: String, label: String, scope: String) -> Dictionary:
	var r: Array = SCOPE_RANGE.get(scope, [0.0, 100.0])
	return {
		"id": id, "label": label, "scope": scope,
		"min": float(r[0]), "max": float(r[1]),
	}


func _default_parameters() -> void:
	parameters = [
		make_param("hunger", "空腹", SCOPE_SELF),
		make_param("sleep", "睡眠", SCOPE_SELF),
		make_param("safety", "不安", SCOPE_SELF),
		make_param("home", "居住", SCOPE_SELF),
		make_param("boredom", "退屈", SCOPE_SELF),
		make_param("stagnation", "停滞", SCOPE_SELF),
		make_param("loneliness", "孤独", SCOPE_SELF),
		make_param("crowding", "過密", SCOPE_SELF),
		make_param("unfairness", "不公平", SCOPE_SELF),

		make_param("affinity", "好感", SCOPE_PAIR),
		make_param("trust", "信頼", SCOPE_PAIR),
		make_param("respect", "敬意", SCOPE_PAIR),
		make_param("debt", "負い目", SCOPE_PAIR),
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


## 色はスコープで決まる。語ごとの色は持たない。
func param_color(id: String) -> Color:
	var d = param_def(id)
	if d == null:
		return SCOPE_COLORS[SCOPE_SELF]
	return SCOPE_COLORS.get(String(d["scope"]), SCOPE_COLORS[SCOPE_SELF])


func scope_color(scope: String) -> Color:
	return SCOPE_COLORS.get(scope, SCOPE_COLORS[SCOPE_SELF])


func param_min(id: String) -> float:
	var d = param_def(id)
	return 0.0 if d == null else float(d["min"])


func param_max(id: String) -> float:
	var d = param_def(id)
	return 100.0 if d == null else float(d["max"])


## 言葉を1つ足す。属するのはスコープだけ（じぶんか、あいてか）。
func add_param(scope: String, label: String = "新しいことば") -> Dictionary:
	var taken: Array = []
	for d in parameters:
		taken.append(String(d["id"]))
	var p := make_param(_unique_id("p", taken), label, scope)
	parameters.append(p)
	parameters_changed.emit()
	return p


func remove_param(id: String) -> void:
	for i in range(parameters.size()):
		if String(parameters[i]["id"]) == id:
			parameters.remove_at(i)
			break
	parameters_changed.emit()


# ---------------------------------------------------------------------------
# アクション
#
# 定義は無い。**型 × 対象** がそのままアクションなので、一覧を持つ必要がない。
# 名前も持たない——何をしているかは、そのつどAIが名づける（`Brain._name_act`）。
# ---------------------------------------------------------------------------

## 型ごとに選べる対象。
##   使う … 世界にある物と持ち物（同じもの）＋ 建物
##          そこに在るのを使うのか手の中のを使うのかは、候補を作るときに分かれる
##   作る … つくりかたにあるもの（持てるもの / 建てるもの）
##   動く … 建てられるものぶんだけ行き先が増える（同じものが何軒あっても、いちばん近いところへ）。
##          「自分のところ」は元からある行き先で、自分が建てたもののうち近いところ
func targets_of(kind: String) -> Dictionary:
	var out := {}
	match kind:
		"use":
			for item in all_items():
				out[String(item)] = _target(item_label(String(item)))
			for b in buildings:
				out[String(b["id"])] = _target(String(b["label"]))
		"make":
			for r in recipes:
				out[String(r["id"])] = _target(String(r["label"]), 1.6, 999.0)
			for b in buildings:
				out[String(b["id"])] = _target(String(b["label"]), 2.5, -1.0)
		"move":
			out = TARGETS["move"].duplicate(true)
			for b in buildings:
				out["go:%s" % String(b["id"])] = _target(String(b["label"]), 0.4, -1.0)
		_:
			return TARGETS.get(kind, {})
	return out


func _target(label: String, duration: float = 0.8, reach: float = 999.0) -> Dictionary:
	return {"label": label, "duration": duration, "reach": reach}


## 「動く」の行き先が建物なら、その建物の id。そうでなければ空。
func move_building(target: String) -> String:
	return target.substr(3) if target.begins_with("go:") else ""


func target_def(kind: String, target: String) -> Variant:
	var t: Dictionary = targets_of(kind)
	return t.get(target, null)


func target_label(kind: String, target: String) -> String:
	var d = target_def(kind, target)
	return target if d == null else String(d["label"])


func _unique_id(prefix: String, taken: Array) -> String:
	var i := 1
	while taken.has("%s%d" % [prefix, i]):
		i += 1
	return "%s%d" % [prefix, i]
