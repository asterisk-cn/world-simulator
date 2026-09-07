class_name Villager
extends Node2D
## 一人の村人。パラメータ・性格・記憶をすべて自分の中に持つ。
## 集合知は存在しない。他人のことは「会話」と「掲示板」からしか知り得ない。
##
## 【前提】判断はAIが行う。
## このクラスが持つのは「世界で何が起きたか」だけ。
## 起きたことをどう受け取るか、次に何をするかは一切書かれていない。
## いまは Brain がランダムに1つ選んでいるだけで、パラメータは動かない。
##
## パラメータは自分スコープ（params）と相手スコープ（pairs）に分かれるが、
## 相手ごとに1つ持つかどうかが違うだけで、扱いは同じ。

var id: int = 0
var vname: String = "村人"
var color: Color = Color.WHITE

var cell: Vector2 = Vector2.ZERO
var world = null  ## World（循環参照を避けるため型注釈なし）

var params: SelfParams
var personality: Personality
var memory: Memory

## 自分から見た相手ごとのパラメータ。other_id -> PairParams
var pairs := {}

var inventory := {}  ## item_id -> 個数。何が持てるかは Schema が決める
var home: Structure = null

var current_action := {}
var action_phase := "idle"  ## "move" | "act"
var act_timer := 0.0
var decision_timer := 0.0

var _last_post_day := -1
var _path: PackedVector2Array = PackedVector2Array()
var _path_i := 0
var _bubbles: Array = []
var _brain = null
var _bob := 0.0
var selected := false


func setup(p_world, p_id: int, p_name: String, p_color: Color, p_cell: Vector2) -> void:
	world = p_world
	id = p_id
	vname = p_name
	color = p_color
	cell = p_cell
	params = SelfParams.new()
	personality = Personality.random()
	memory = Memory.new()
	_brain = Brain.new(self)
	position = Iso.cell_to_world(cell)
	_bob = randf() * TAU


# ---------------------------------------------------------------------------
# パラメータ
# ---------------------------------------------------------------------------

func pair_to(other_id: int) -> PairParams:
	if not pairs.has(other_id):
		pairs[other_id] = PairParams.new(other_id)
	return pairs[other_id]


func knows(other_id: int) -> bool:
	return pairs.has(other_id)


## 覗くだけ。pair_to と違って、無ければ作らない。
## 見ただけで「会ったことがある」が生まれてしまうのを防ぐ。
func pair_peek(other_id: int) -> PairParams:
	return pairs.get(other_id, null)


func item_count(item: String) -> int:
	return int(inventory.get(item, 0))


func add_item(item: String, n: int) -> void:
	inventory[item] = maxi(0, item_count(item) + n)


func wealth() -> float:
	var w := float(carried())
	if home != null:
		w += 20.0
	return w


func carried() -> int:
	var t := 0
	for k in inventory:
		t += int(inventory[k])
	return t


# ---------------------------------------------------------------------------
# メインループ
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if SimClock.paused:
		return
	var dt := delta * SimClock.speed

	decision_timer -= dt
	if action_phase == "idle" or decision_timer <= 0.0:
		if action_phase == "idle":
			_decide()
		decision_timer = SimConfig.p("decision_interval")

	_execute(dt)
	_bob += dt * 6.0

	var kept: Array = []
	for b in _bubbles:
		if b.advance(dt):
			kept.append(b)
	_bubbles = kept

	queue_redraw()


## 起きたことを世界の上で見せる。ログを読んでから探させない。
## 何を描くかはアクションの型と対象から引くので、ここで絵を選ばない。
func say(kind: String, target: String, span: float = 1.8) -> void:
	var b := Bubble.of(kind, target, span)
	if b == null:
		return
	if _bubbles.size() >= 2:
		_bubbles.pop_front()
	_bubbles.append(b)


func _decide() -> void:
	current_action = _brain.choose()
	action_phase = "move"
	act_timer = 0.0
	# 家は通り抜けられないので、間の空きを通って回り込む
	_path = world.find_path(cell, current_action.get("target_cell", cell), id)
	_path_i = 0


func _execute(dt: float) -> void:
	if current_action.is_empty():
		action_phase = "idle"
		return

	if action_phase == "move":
		var step := SimConfig.p("move_speed") * dt
		while step > 0.0:
			if _path_i >= _path.size():
				action_phase = "act"
				break
			var wp: Vector2 = _path[_path_i]
			var to := wp - cell
			var d := to.length()
			if d <= 0.05:
				_path_i += 1
				continue
			var m: float = minf(step, d)
			cell += to / d * m
			step -= m
		position = Iso.cell_to_world(cell)
		if action_phase == "move":
			return

	if action_phase == "act":
		act_timer += dt
		if act_timer >= float(current_action.get("duration", 0.6)):
			_complete_action()
			action_phase = "idle"
			current_action = {}


## 型 × 対象ごとに、世界で何が起きるかだけを決める。
## その結果パラメータがどう動くかはここには書かれていない（AIの担当）。
##
## 作る／建てる／使う は、本人が決めたこと（何を払うか・そこで何をするか）を
## `current_action` から受け取って適用するだけ。決めているのは Brain のほう。
func _complete_action() -> void:
	var kind := String(current_action.get("kind", "move"))
	var target := String(current_action.get("target", ""))
	var obj = current_action.get("obj", null)
	var done := true

	match kind:
		"move":
			if (target == "toward" or target == "away") and obj != null \
					and is_instance_valid(obj):
				memory.record("移動：%s" % action_label())
		"use":
			done = _do_use(target, obj)
		"make":
			done = _do_make(target)
		"talk":
			match target:
				"talk":
					if obj != null and is_instance_valid(obj):
						_do_talk(obj)
				"post":
					_do_post()
				"read":
					_do_read_board()

	# 使うのは空振りすることがあり（採り尽くされていた）、
	# 作るのは払えないことがある。実際に起きたときだけ世界の上に見せる。
	if done:
		say(kind, target)


## 本人が答えたぶん（`Brain._how_much`）を、そのまま世界に映す。
##
## **量については何も見ない。** いくつ取るか、何をどれだけ使うか、いくつできるかは
## 全部その人の答えで、世界の物は尽きないし、上限もどこにも無い。
## プログラムが見るのは、**それが何であるか**にまつわる3つだけ。
##
##   無いものは払えない       — 減らせるのは、持っているぶんまで
##   世界に無い物は生まれない — 名前があるのは、神がこの世界に置いた物だけ
##   増えるのは、世界の物に触れているときか、作っているとき
##       手の中のものを「使う」だけで物が増えるなら、「作る」という型が要らなくなる。
##       これは量の話ではなく、動詞の意味の話。
##
## 何が寄越されるかも、それが何かを知っている側が答える。
##   世界に元から在るもの（茂み・木・岩）… プログラムはそれが何かを知っているので、
##       寄越すのはその物だけ
##   建てたもの … プログラムは神がつけた名前しか知らないので、何を寄越すかは
##       名前を読んだ本人が答える（井戸と水が並んでいれば、汲めると分かる）
##   作る … 何ができるかも本人の答え。削りかすが一緒に出てもいい
func _apply(want: Dictionary, kind: String, target: String, obj) -> Dictionary:
	var moved := {}
	for item in want:
		var n := int(want[item])
		if n >= 0:
			continue
		var pay: int = mini(-n, item_count(String(item)))
		if pay <= 0:
			continue
		add_item(String(item), -pay)
		moved[String(item)] = -pay

	var touching = obj if obj != null and is_instance_valid(obj) else null
	for item in want:
		var n := int(want[item])
		var iid := String(item)
		if n <= 0 or not Schema.all_items().has(iid):
			continue
		if touching is HarvestNode and iid != target:
			continue  # 茂みが寄越すのは木の実だけ
		if touching == null and kind != "make":
			continue  # 手の中のものを使っただけでは増えない
		add_item(iid, n)
		moved[iid] = int(moved.get(iid, 0)) + n
	return moved


## 動いた持ち物を「2つ手に入れた」「木×2 石×1」のように言う。
## 行動の名前が既に言っていることは足さない——対象そのものを1つ使っただけのときと、
## 払って1つできただけのとき。
func _moved_text(moved: Dictionary, target: String) -> String:
	var paid: Array = []
	for item in moved:
		var iid := String(item)
		var n := int(moved[iid])
		if n < 0 and not (iid == target and n == -1):
			paid.append("%s×%d" % [Schema.item_label(iid), -n])

	var got: Array = []
	for item in moved:
		var iid := String(item)
		var n := int(moved[iid])
		if n <= 0:
			continue
		if iid == target:
			if n > 1 or paid.is_empty():
				got.append("%dつ手に入れた" % n)
		else:
			# 名前が違うもの（井戸から水）は、何を手にしたのかを言う
			got.append("%sを%dつ手に入れた" % [Schema.item_label(iid), n])

	var parts: Array = []
	if not paid.is_empty():
		parts.append(" ".join(paid))
	parts.append_array(got)
	return "" if parts.is_empty() else "（%s）" % "、".join(parts)


## 払ったぶんが、手の中の1つになるか、世界の上に建つ。
##
## 建てはじめてから建て終わるまでに、誰かが同じものを建ててしまうことがある。
## 家は一人に一軒、村のものは村に一つなので、置く直前にもう一度確かめる。
func _do_make(target: String) -> bool:
	if not Schema.is_building(target):
		if Schema.recipe_def(target) == null:
			return false
		var moved := _apply(current_action.get("move", {}), "make", target, null)
		if moved.is_empty():
			return false
		memory.record("制作：%s%s" % [action_label(), _moved_text(moved, target)])
		return true

	if Schema.building_def(target) == null:
		return false
	var already := ((home != null) if target == Schema.HOUSE
		else (world.building_of(target) != null))
	if already:
		return false
	var c: Vector2i = current_action.get("build_cell", Vector2i(-1, -1))
	if c.x < 0 or not world._can_build_at(c):
		return false
	var paid := _apply(current_action.get("move", {}), "make", target, null)
	if paid.is_empty():
		return false  # 持ち物が何も動かないなら、その人は建てなかった
	var s: Structure = world.add_structure(target, c, id, color)
	if s.is_house():
		home = s
	memory.record("建築：%s%s" % [action_label(), _moved_text(paid, target)])
	EventLog.notable("%s が%sを建てた" % [vname, s.label()], s.position, id)
	return true


## 使う。何をしたか（採る／食べる／祈る）は本人の言葉（`Brain._name_act`）で、
## 世界の側で起きるのは「どこにあるものを使ったか」だけで決まる。
##   そこに在るもの … 1つ手に入る（採るのはこれ）
##   手の中のもの   … 1つ減る
##   建物           … 何も減らない
func _do_use(target: String, obj) -> bool:
	var where := String(current_action.get("where", "hand"))
	if where == "building" and (obj == null or not is_instance_valid(obj)):
		return false
	var moved := _apply(current_action.get("move", {}), "use", target, obj)
	# 建物に入るように、持ち物が何も動かない使い方もある。それは空振りではない。
	if where != "building" and moved.is_empty():
		return false
	memory.record("使用：%s%s" % [action_label(), _moved_text(moved, target)])
	return true


## 会話。起きた事実だけを双方に記録する。
## 【AI差し替え口】何を話すか・何を伝えるか・相手をどう思うようになったかはAIの担当。
func _do_talk(other) -> void:
	# 会ったことがあるという事実だけ、相手ごとの入れ物を作って残す
	pair_to(other.id)
	other.pair_to(id)
	memory.last_talk_day[other.id] = SimClock.day
	other.memory.last_talk_day[id] = SimClock.day
	memory.record("会話：%s と話した" % other.vname)
	other.memory.record("会話：%s と話した" % vname)
	# 話しかけられた側にも同じ絵を出す。誰と話しているかは2つ並ぶことで読める
	other.say("talk", "talk", 2.2)


## 掲示板に貼る。いまは観測した事実だけを貼る。
## 【AI差し替え口】何をどう書くかはAIの担当。
func _do_post() -> void:
	var board = world.board
	if board == null:
		return
	_last_post_day = SimClock.day
	var berry = world.nearest_harvest(cell, HarvestNode.Kind.BERRY)
	if berry == null:
		return
	var text := "%s に木の実がある" % world.place_name(berry.cell)
	for e in board.posts:
		if int(e["author_id"]) == id and String(e["text"]) == text:
			return
	board.post(id, vname, text)
	memory.record("掲示板：「%s」を貼った" % text)


## 掲示板を読む。読んだという事実だけを残す。
## 【AI差し替え口】文面をどう受け取り、誰への評価がどう変わるかはAIの担当。
func _do_read_board() -> void:
	var board = world.board
	if board == null:
		return
	var unread: Array = board.unread_for(memory)
	if unread.is_empty():
		return
	for e in unread:
		memory.mark_post_read(int(e["id"]), 1.0)
		# 誰の紙かより、何が書いてあったかが記憶に残る
		memory.record("掲示板：「%s」（%s）を読んだ"
			% [String(e["text"]), String(e["author_name"])])


# ---------------------------------------------------------------------------
# 夜
# ---------------------------------------------------------------------------

## 【要検討】記憶の扱いは未決。いまは一日ぶんの出来事を要約に畳んでいるだけ。
func on_night() -> void:
	memory.nightly_compress(vname, SimClock.day)


# ---------------------------------------------------------------------------
# ヘルパ
# ---------------------------------------------------------------------------

func action_label() -> String:
	return String(current_action.get("label", "待機"))


# ---------------------------------------------------------------------------
# 描画
# ---------------------------------------------------------------------------

func _draw() -> void:
	var font: Font = SimConfig.ui_font if SimConfig.ui_font != null else ThemeDB.fallback_font
	var lift := sin(_bob) * (1.6 if action_phase == "move" else 0.4)
	var up := Vector2(0, -lift)

	Iso.draw_shadow(self, 0.5, 0.26)

	if selected:
		# パネルの数字と世界の姿を結ぶ線。夜でも沈まないよう、外側に淡い輪をもう1本置く
		var halo := Iso.rounded(Iso.diamond(1.24), 7.0)
		draw_polyline(halo + PackedVector2Array([halo[0]]), Color(1, 0.95, 0.5, 0.35), 4.0)
		var ring := Iso.rounded(Iso.diamond(1.0), 6.0)
		draw_polyline(ring + PackedVector2Array([ring[0]]), Color(1, 0.95, 0.5), 3.0)

	# 夜は世界全体が暗く落ちるので、村人だけ持ち上げて見失わないようにする
	var night := SimClock.darkness()
	var body := color.lerp(Color(1, 1, 1), night * 0.30)
	var head := Color(0.95, 0.86, 0.74).lerp(Color(1, 1, 1), night * 0.30)
	Iso.draw_block(self, 9.0, 4.5, 17.0, body, up, 3.5)
	Iso.draw_block(self, 7.0, 3.5, 11.0, head, up + Vector2(0, -17.0), 3.5)

	# 集まったときが一番見たい瞬間なのに、そこで名前が重なって読めなくなる。
	# 近くに誰かいるときは段をずらし、選んでいない村人は薄くして譲る。
	var crowd: int = world.neighbors_within(cell, 2.2, id).size()
	var tier := float(id % 3) * 9.0 if crowd > 0 else 0.0
	var alpha := 0.95 if selected else (0.52 if crowd > 0 else 0.78)

	for i in range(_bubbles.size()):
		_bubbles[i].draw_on(self, Vector2(0, -48 - lift - tier - float(i) * 18.0))

	_label(font, vname, Vector2(-40, -30 - lift - tier), 80, 11, Color(1, 1, 1, alpha))


## 世界の上に置く文字。縁取りがないと昼は白飛び、夜は沈んで読めない。
func _label(font: Font, text: String, at: Vector2, w: int, size: int, col: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 4,
		Color(0.05, 0.06, 0.09, 0.75))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
