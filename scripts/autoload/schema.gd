extends Node
## この世界に何が存在するかの定義。プレイヤー（神）が実行中に書き換える。
##
## - parameters: パラメータ。対象範囲が「自分」か「相手ごと」かが違うだけで、扱いは同じ。
## - recipes / buildings: 手に入るものと建てられるもの。名前と姿と、手に入れかた（材料・場所）。
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
# 採る と 作る は1つの「手に入れる」に畳んだ。茂みで木の実を手に入れるのも、
# 木と石で道具を手に入れるのも、材料が空か、場所が要るかの違いしかない。
# 建てる もこの型の中にある（手に入るのではなく、世界の上に建つ）。
# 「使う」に残るのは、手の中のものと建物に向けた手だけ。
# ---------------------------------------------------------------------------

const BEHAVIORS := {
	"move": {"label": "動く"},
	"use": {"label": "使う"},
	"make": {"label": "作る"},
	"talk": {"label": "話す"},
}

## 型ごとに選べる対象のうち、世界に元からあるもの。
##   duration … かかる時間。**ゆっくり**——見ている人が目で追える速さに揃えてある
##   reach    … どこまで近づいてから行うか（マス）。歩きは手の中に畳んであり、
##              この近さに入ったところで足を止める。相手が人なら追う。
##              -1 は「その場所まで行ってから行う」（ぶらぶらの行き先）。
##              物・建物は 1.6、人・掲示板は 2.2
const TARGETS := {
	# **「動く」に行き先は無い。** 話す・使う・作るは歩きを手の中に畳んでいる
	# （相手の間合いまで歩いてから行う）ので、
	# 「◯◯のところへ向かう」を別に並べると、同じ一手を二度訊くことになる。
	# 実際それが候補の過半を占め、選ばれた手の 74% が「向かう」で、
	# 着いた先で何かをするところまで繋がらなかった。
	# ここに残すのは**行き先の無い動き**だけ——ぶらぶらするのは、それ自体が一手
	"move": {
		"anywhere": {"label": "適当な場所", "duration": 1.6, "reach": -1.0},
	},
	"talk": {
		"talk": {"label": "誰か", "duration": 3.0, "reach": 2.2},
		"post": {"label": "掲示板に貼る", "duration": 4.0, "reach": 2.2},
		"read": {"label": "掲示板を読む", "duration": 3.0, "reach": 2.2},
	},
	# 使う / 作る の対象は、世界にある物と神が決めた「つくりかた」から作る。
	"use": {},
	"make": {},
}

## 「使う」は、それがどこにあるかで間合いと時間が変わる。
## 何をするか（食べる / 祈る）ではなく、どこにあるかだけで決まる。
## 手に入れる・建てるのにかかる時間。**対象では変えない。**
## 何を作るのが大変かをプログラムは知らない——知っているのは神が付けた名前だけで、
## 名前から手間は読めない（籠と家で時間が違うはず、と決めるのは世界の越権）。
const MAKE_SEC := 3.2
const BUILD_SEC := 5.0

const USE_WAYS := {
	"hand": {"duration": 1.6, "reach": 999.0},    # 手の中のものを使う
	"building": {"duration": 8.0, "reach": 1.6},  # 建物のそばで使う
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


## 島に在る持ち物と、その姿。茂み・木・岩へ行くと、材料なしで手に入る（技術ツリーの根）。
##
## **いまは固定。** 設計図が空から始まっても、この3つだけは最初から在り、
## 名前も姿も変えられず、消せない（どう扱うかは #35 で決める）。
## 定義は他のもちものと同じ一覧（`recipes`）に並ぶ。
## 姿は選べない——茂みが壺の絵で手に入ったら、世界の上の姿と手の中の姿が食い違う
const WORLD_ARTS := {"food": "berry", "wood": "tree", "stone": "rock"}

## 世界に元から在る場所。何かを手に入れる場所として選べる（建物も選べる）。
## 何が採れるかは場所ではなく、手に入るもののほうに書く——
## 岩から石も鉄も採れるなら、それは石と鉄の手に入れかたが岩を指しているだけ
const WORLD_PLACES := {"bush": "茂み", "tree": "木", "rock": "岩"}

## 世界の場所が、どの持ち物から生えるか（`HarvestNode.KIND_ITEM` と同じ対応）
const PLACE_ITEM := {"bush": "food", "tree": "wood", "rock": "stone"}

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
# 固まった言葉
#
# **書き足せるが、書き直せない。** 世界が動きはじめたら、それまでに書いたものは
# 村人の記憶と値の前提になる。途中で名前が変わると、覚えていることと辻褄が合わない。
# だから夜に設計図が戻ってきても、触れるのはその夜に書き足したものだけ。
# ---------------------------------------------------------------------------

## 書いてあるものを全部固める。紙を焼いた瞬間に呼ぶ
func fix_all() -> void:
	for list in [parameters, recipes, buildings, villagers]:
		for d in list:
			d["fixed"] = true


## 世界を終えたら、また全部書き直せる。島に在るものは固定のまま
func unfix_all() -> void:
	for list in [parameters, recipes, buildings, villagers]:
		for d in list:
			if not WORLD_ARTS.has(String(d["id"])):
				d.erase("fixed")


func is_fixed(d: Dictionary) -> bool:
	return bool(d.get("fixed", false))


func _remove_from(list: Array, id: String) -> void:
	for i in range(list.size()):
		if String(list[i]["id"]) == id:
			if not is_fixed(list[i]):
				list.remove_at(i)
			return


# ---------------------------------------------------------------------------
# 手に入れかた（技術ツリー）
#
# 物ごとに持つのは 名前・姿 と、**手に入れかた**——材料（何をいくつ）と場所の2つだけ。
#
#   材料 … 手に入れるときに手の中から減るもの。数も決まっている（Jev が答える）。
#          道具も材料の1つ（減る）。減らない道具という区別は持たない
#   場所 … そこへ行って行う。世界に元から在る場所（茂み・木・岩）か、建物。
#          空ならどこでも（手の中で済む）
#
# 材料が空なら「採る」、あれば「作る」——だが世界はそれを分けない。
# どちらも1回の手で1つ手に入る（`make_move`）。
#
# 他の物を材料や場所に指せるので、物どうしが段になって木の形になる。
# **材料も場所も無いものは手に入らない**（無から物は生まれない）。
# 輪になる指し方（道具の材料に道具が要る、のような）は受け付けない（`can_need`）。
#
# **手に入れかたを決めるのは神ではなく Jev。** 神が決めるのは名前と姿だけで、
# 根（木の実・木・石）以外の手に入れかたは、世界が始まるときに Jev が1回で答える
# （`world/tech_tree.gd`）。だからここでは空で生まれる。
#
# 【FutureWork】世界に1本のツリーではなく、一人ひとりのAIが自分の作り方を持つ
# （DESIGN.md §12）。
# ---------------------------------------------------------------------------

func _default_recipes() -> void:
	recipes = _world_recipes()
	recipes.append({"id": "tool", "label": "ハンマー", "art": "tool", "inputs": {}, "place": ""})


## 島に在るもの（技術ツリーの根）。固定なので、生まれたときから固まっている
func _world_recipes() -> Array:
	return [
		{"id": "food", "label": "木の実", "art": "berry", "inputs": {}, "place": "bush", "fixed": true},
		{"id": "wood", "label": "木", "art": "tree", "inputs": {}, "place": "tree", "fixed": true},
		{"id": "stone", "label": "石", "art": "rock", "inputs": {}, "place": "rock", "fixed": true},
	]


## 家も、ただの「建てるもの」の1つ。建てた人のものになるが、何軒建つかは決まっていない。
## 建てるものは建つ先が場所なので、手に入れかたは材料だけ。
func _default_buildings() -> void:
	buildings = [
		{"id": "b1", "label": "家", "art": "house", "inputs": {}},
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


func thing_def(id: String) -> Variant:
	var r = recipe_def(id)
	return r if r != null else building_def(id)


## もちものの一覧。島に在るものも、作るものも同じ一覧にある
func all_items() -> Array:
	var out: Array = []
	for r in recipes:
		out.append(String(r["id"]))
	return out


# --- 手に入れかた ---------------------------------------------------------

## 材料。{持ち物のid: 数}
func inputs_of(id: String) -> Dictionary:
	var d = thing_def(id)
	return {} if d == null else d.get("inputs", {})


## 場所。世界の場所（`WORLD_PLACES`）か建物のid。空ならどこでも。建てるものは常に空
func place_of(id: String) -> String:
	var r = recipe_def(id)
	return "" if r == null else String(r.get("place", ""))


func place_label(place: String) -> String:
	if WORLD_PLACES.has(place):
		return String(WORLD_PLACES[place])
	return building_label(place)


## その場所がいまの世界に在るか。建物は書かれているものだけ。
## 茂み・木・岩は、いまは固定なので常に在る（#35 で消せるようになっても、ここで見る）
func place_alive(place: String) -> bool:
	if WORLD_PLACES.has(place):
		return is_world_item(String(PLACE_ITEM[place]))
	return building_def(place) != null


func set_input(id: String, item: String, n: int) -> void:
	var d = thing_def(id)
	if d == null or not can_need(id, item):
		return
	var inputs: Dictionary = d.get("inputs", {})
	if n <= 0:
		inputs.erase(item)
	else:
		inputs[item] = n
	d["inputs"] = inputs
	_changed(id)


func set_place(id: String, place: String) -> void:
	var r = recipe_def(id)
	if r == null or (place != "" and not WORLD_PLACES.has(place) and not can_need(id, place)):
		return
	r["place"] = place
	_changed(id)


func _changed(id: String) -> void:
	if is_building(id):
		buildings_changed.emit()
	else:
		recipes_changed.emit()


## a を手に入れるのに、どこかの段で b が要るか（材料にも場所にも辿る）
func needs(a: String, b: String) -> bool:
	return _needs(a, b, {})


func _needs(a: String, b: String, seen: Dictionary) -> bool:
	if seen.has(a):
		return false
	seen[a] = true
	var deps: Array = inputs_of(a).keys()
	if place_of(a) != "":
		deps.append(place_of(a))
	for x in deps:
		if String(x) == b or _needs(String(x), b, seen):
			return true
	return false


## a の材料・場所に b を指してよいか。**輪になる指し方は選べない**——
## 道具を手に入れるのに道具が要るなら、その世界で道具は永遠に手に入らない
func can_need(a: String, b: String) -> bool:
	if WORLD_PLACES.has(b):
		return true
	return thing_def(b) != null and a != b and not needs(b, a)


## いまの定義で、いつか手に入るか。材料も場所も無い物と、
## そこから辿った先にそういう物がある物は、手に入らない
func obtainable(id: String) -> bool:
	return _obtainable(id, {})


func _obtainable(id: String, seen: Dictionary) -> bool:
	if WORLD_PLACES.has(id):
		return place_alive(id)
	if seen.has(id):
		return false
	seen[id] = true
	if thing_def(id) == null:
		return false
	var inputs := inputs_of(id)
	var place := place_of(id)
	# 無から物は生まれない。建つものは建つ先が場所なので、材料が要る
	if inputs.is_empty() and (place == "" or is_building(id)):
		return false
	for x in inputs:
		if not _obtainable(String(x), seen.duplicate()):
			return false
	return place == "" or _obtainable(place, seen.duplicate())


## 材料を「木×2・石×1」と言う
func inputs_text(id: String) -> String:
	var parts: Array = []
	var inputs := inputs_of(id)
	for x in inputs:
		parts.append("%s×%d" % [item_label(String(x)), int(inputs[x])])
	return "・".join(parts)


## 手に入れかたを1行で（「木×1・石×1」「茂みで」「鉄×2・炉で」）
func recipe_text(id: String) -> String:
	var parts: Array = []
	var cost := inputs_text(id)
	if cost != "":
		parts.append(cost)
	if place_of(id) != "":
		parts.append("%sで" % place_label(place_of(id)))
	return "　".join(parts)


## 手に入れる1回で、持ち物がどう動くか。**数は手に入れかたにある**（本人は決めない）。
## 材料は減り、手に入るものは1つ増える（建つものは持ち物にならない）
func make_move(id: String) -> Dictionary:
	var move := {}
	var inputs := inputs_of(id)
	for x in inputs:
		move[String(x)] = -int(inputs[x])
	if not is_building(id):
		move[id] = 1
	return move


## 島に在るもちものか
func is_world_item(id: String) -> bool:
	return WORLD_ARTS.has(id) and recipe_def(id) != null


## 島に在るもちもののうち、いま定義に残っているもの
func world_items() -> Array:
	var out: Array = []
	for id in WORLD_ARTS:
		if recipe_def(String(id)) != null:
			out.append(String(id))
	return out


## 神が付けた名前から言葉を引く。**AIが答えるのは名前のほう**なので、
## 世界の側でidに戻す。無い名前は空（世界に無い言葉は動かせない）
func self_param_by_label(label: String) -> String:
	return _by_label(self_params(), label)


func pair_param_by_label(label: String) -> String:
	return _by_label(pair_params(), label)


func _by_label(defs: Array, label: String) -> String:
	var want := label.strip_edges()
	for d in defs:
		if String(d["label"]) == want:
			return String(d["id"])
	return ""


func item_label(id: String) -> String:
	var r = recipe_def(id)
	return id if r == null else String(r["label"])


## 持ち物の姿。島に在る物は決まっていて、作るものは神が選んだ姿になる。
func item_art(id: String) -> String:
	if WORLD_ARTS.has(id):
		return String(WORLD_ARTS[id])
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
	# 手に入れかたは空で生まれる。世界が始まるときに Jev が組み込む（`TechTree`）
	var r2 := {"id": _unique_id("r", taken), "label": "新しいもの",
		"art": CRAFT_ARTS[(recipes.size() - world_items().size()) % CRAFT_ARTS.size()],
		"inputs": {}, "place": ""}
	recipes.append(r2)
	recipes_changed.emit()
	return r2


## 消せるのは固まっていない物だけ（始める前か、その夜に書き足した物）。
## 他の物の手に入れかたは直さない。固まっていない物は、まだどの枝にも指されていない
## （枝は焼いたときに組む、`TechTree`）ので、消えた物を指す枝は残らない
func remove_recipe(id: String) -> void:
	_remove_from(recipes, id)
	recipes_changed.emit()


func rename_recipe(id: String, label: String) -> void:
	var r = recipe_def(id)
	if r != null and not is_fixed(r):
		r["label"] = label
		recipes_changed.emit()


func add_building() -> Dictionary:
	var taken: Array = []
	for b in buildings:
		taken.append(String(b["id"]))
	var b2 := {"id": _unique_id("b", taken), "label": "新しい建物",
		"art": BUILDING_ARTS[buildings.size() % BUILDING_ARTS.size()],
		"inputs": {}}
	buildings.append(b2)
	buildings_changed.emit()
	return b2


func remove_building(id: String) -> void:
	_remove_from(buildings, id)
	buildings_changed.emit()


func rename_building(id: String, label: String) -> void:
	var b = building_def(id)
	if b != null and not is_fixed(b):
		b["label"] = label
		buildings_changed.emit()


## 姿を選ぶ。押すたびに、用意された姿を順に送る。固まったものの姿は動かない
func cycle_art(d: Dictionary, arts: Array) -> void:
	if is_fixed(d):
		return
	var i := arts.find(String(d["art"]))
	d["art"] = String(arts[(i + 1) % arts.size()])
	recipes_changed.emit()
	buildings_changed.emit()


## **最初は何もない。** 言葉も物も人も、神が書き足していく（DESIGN.md §7）。
## 島に在るもの（木の実・木・石）だけは、いまは固定で最初から在る
func reset_all() -> void:
	parameters = []
	recipes = _world_recipes()
	buildings = []
	villagers = []
	_emit_all()


## 書き足すところを飛ばして、既定の顔ぶれで埋める。`--autostart` の観察用
func load_defaults() -> void:
	_default_recipes()
	_default_buildings()
	_default_parameters()
	_default_villagers()
	_emit_all()


func _emit_all() -> void:
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
	_remove_from(villagers, id)
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
## 順番で色相を回しても、じぶんの言葉を暖色に閉じれば色相差が小さすぎて見分けられず、
## 閉じなければあいての色と混ざる。そして**色は人のもの**——
## 村人の色が世界でもUIでも識別子なので、語からも色を出すと競う。
##
## 語が何であるかは常に隣に字で書いてある。色は「どちらの話か」だけを言う。
const SCOPE_COLORS := {
	SCOPE_SELF: Color(0.55, 0.42, 0.26),  ## じぶん。土の色
	SCOPE_PAIR: Color(0.30, 0.55, 0.52),  ## あいて。青緑
}

## 負の側の赤。**幅が負から始まるときだけ使う**——いまはどのスコープも 0〜100 なので出ない。
## 幅を −50〜50 にしていた頃の、裏（好感の裏の嫌悪）を塗る色。
## **積み木（`PipBar`）と n×n の表（`matrix_panel`）で同じ赤を使う。**
## 表は色しか持たないので向きを色で言うしかなく、そこだけ赤で、
## インスペクタの積み木は1色、では同じものを2つの言い方で見せることになる。
const NEG := Color(0.74, 0.26, 0.22)


## とりうる幅は神が決めるものではなく、スコープから決まる。
##
## **どちらも「どれだけ」の話で 0〜100。** 値は5件法の答え（`Brain.LEVELS`）を
## 0 / 25 / 50 / 75 / 100 に写したもので、0 は「まったくそう思わない」＝感じていない。
##
## −50〜50 にして負を「裏」（空腹の裏の満腹、好感の裏の嫌悪）にしていたが、
## 5件法の「そう思わない」は「感じていない」であって裏ではない。
## 両側に開く目盛りは「その逆」を言わせる言い回しが要り、5件法なら見慣れた文言で済む。
## 裏を失うかわりに、目盛りと幅の読み方が一致する。
## 幅を1本ずつ決めさせても、読み方が増えるだけで世界の見え方は変わらなかった。
##
## 100 で「どこが満ちたのか読めなかった」のは、増減を申告させていた頃の話。
## いまは段階を写すだけなので、幅の大きさは目盛りの呼び名でしかない。積み木10粒で **1粒＝10**。
const SCOPE_RANGE := {
	SCOPE_SELF: [0.0, 100.0],
	SCOPE_PAIR: [0.0, 100.0],
}


func make_param(id: String, label: String, scope: String) -> Dictionary:
	var r: Array = SCOPE_RANGE.get(scope, [0.0, 10.0])
	return {
		"id": id, "label": label, "scope": scope,
		"min": float(r[0]), "max": float(r[1]),
	}


func _default_parameters() -> void:
	parameters = [
		make_param("hunger", "空腹", SCOPE_SELF),
		make_param("safety", "不安", SCOPE_SELF),
		make_param("loneliness", "孤独", SCOPE_SELF),
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


func param_label(id: String) -> String:
	var d = param_def(id)
	return id if d == null else String(d["label"])


## 色はスコープで決まる。語ごとの色は持たない。
func param_color(id: String) -> Color:
	var d = param_def(id)
	if d == null:
		return SCOPE_COLORS[SCOPE_SELF]
	return SCOPE_COLORS.get(String(d["scope"]), SCOPE_COLORS[SCOPE_SELF])


func param_min(id: String) -> float:
	var d = param_def(id)
	return 0.0 if d == null else float(d["min"])


func param_max(id: String) -> float:
	var d = param_def(id)
	return 10.0 if d == null else float(d["max"])


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
	_remove_from(parameters, id)
	parameters_changed.emit()


# ---------------------------------------------------------------------------
# アクション
#
# 定義は無い。**型 × 対象** がそのままアクションなので、一覧を持つ必要がない。
# 名前も持たない——何をしているかは、そのつどAIが名づける（`Brain._name_act`）。
# ---------------------------------------------------------------------------

## 型ごとに選べる対象。
##   使う … 手の中の持ち物 ＋ 建物
##   作る … 手に入るもの（持てるもの）と建てるもの。採るのもここ（材料が空なだけ）
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
			# 場所が要る物はそこまで歩いてから行う（候補に座標が入る）
			for r in recipes:
				out[String(r["id"])] = _target(String(r["label"]), MAKE_SEC, -1.0)
			for b in buildings:
				out[String(b["id"])] = _target(String(b["label"]), BUILD_SEC, 1.6)
		"move":
			# 建物への行き先も並べない。建っているものは「使う」で行ける
			out = TARGETS["move"].duplicate(true)
		_:
			return TARGETS.get(kind, {})
	return out


func _target(label: String, duration: float = 1.6, reach: float = 999.0) -> Dictionary:
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
