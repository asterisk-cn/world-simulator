class_name Villager
extends Node2D
## 一人の村人。パラメータ・性格・記憶をすべて自分の中に持つ。
## 集合知は存在しない。他人のことは「会話」と「掲示板」からしか知り得ない。
##
## 【前提】判断はAIが行う。
## このクラスが持つのは「世界で何が起きたか」だけ。
## 起きたことをどう受け取るか、次に何をするかは一切書かれていない。
## 何をするか・値がどう動いたかは Brain がAIに訊いて決める（`villager/brain.gd`）。
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

## 【AI差し替え口】いまの気持ちの一言（`villager/feeling.gd`）。
## 世界が知っているのは何が起きたかだけなので、どう感じているかはAIが答える。
## 繋がっていなければ空のまま——紙にはその行が出ない。
var feeling := ""
var feeling_at := 0.0   ## 最後に訊いた実時間。同じ人に訊き直す間隔の底

var current_action := {}
## AIに訊いていて、まだ返事が来ていない。**そのあいだは前の判断が続く**
var asking := false
## AIの答えが二度とも使えなかったとき、次に訊き直す時刻（実時間）
var think_again_at := 0.0

## 空振りの理由。**世界が見たこと**を、そのまま帳面に書くために持つ
var _miss := ""


## 話す手のいま。会話は**2往復で1つの場面**で、この手のあいだに閉じる
var _spoke := false            ## 1行目を言い終えたか
var _talking := false          ## 間合いに入って、場面が始まっているか
var _scene: Array = []         ## [{"who": 名前, "words": 言葉}] いまの会話
var _scene_wait := false       ## 次のひと言を訊いている最中
var _beat := 0.0               ## 次のひと言までの間

## 場面の往復。A→B→A→B で終わり。**長さは世界が決める**——
## どこで切り上げるかを本人に訊くと、それは別の手になる
const TALK_TURNS := 4

## ひと言と次のひと言のあいだ（実時間の秒）。読める速さに置く
const TALK_BEAT := 1.2

## 場面が閉じないまま流れる上限。返事が返らないときの歯止めで、尺ではない
const TALK_MAX := 24.0

## 貼る手のいま。**Jev が選んだ貼る手には文がまだ無い**ので、
## 板の前に着いてから文面だけを訊き、返るまで板の前で書いている（`Post`）
var _wrote := false            ## 文面を訊いたか
var _writing := false          ## 文面が返るのを待っている最中




## 最初のつもりを訊く（世界が目を覚ます前に、`main` から一度だけ）
func think_now() -> void:
	if _brain != null and action_phase == "idle":
		_decide()


## つもりが立ったか（あるいは自分で決めて動き出したか）
func has_thought() -> bool:
	return action_phase != "think" and action_phase != "idle"


## 【AI差し替え口】さっきしたことで、自分の中の値がどう動いたか。
##
## **動かすのは本人の答えだけ。** どの言葉がどれだけ動くかの表はどこにも無いし、
## 作らない（神が付けた言葉なので、作れない）。世界が見るのは
## **その言葉がこの世界にあるか**と、**目盛りの端**（`SelfParams.set_v` が丸める）だけ。
func move_values(mine: Dictionary, others: Dictionary) -> void:
	# 鍵も値も、AIが何の型で返すか分からない（`str()` で読む）
	for label in mine:
		var id := Schema.self_param_by_label(str(label))
		if id != "" and typeof(mine[label]) in [TYPE_INT, TYPE_FLOAT]:
			params.offset(id, float(mine[label]))
	for name in others:
		var who = world.villager_by_name(str(name))
		if who == null or not pairs.has(who.id):
			continue   # 会ったことのない相手への見え方は、まだ無い
		var moves = others[name]
		if typeof(moves) != TYPE_DICTIONARY:
			continue
		for label in moves:
			var pid := Schema.pair_param_by_label(str(label))
			if pid != "" and typeof(moves[label]) in [TYPE_INT, TYPE_FLOAT]:
				pairs[who.id].offset(pid, float(moves[label]))


## 【AI差し替え口】いまの値。**段階で訊いた答えを、幅に写す**（`Brain._read_jev`）。
## 増減の申告と違って、いくつ動くかを本人が測らなくていい——
## 「切迫している」と答えれば、それが幅のどこかは世界が知っている
func set_values(mine: Dictionary) -> void:
	for id in mine:
		params.set_v(String(id), float(mine[id]))


## 相手ごとの値も、いまどのくらいかで置く。
## `theirs` は {相手のid: {値のid: 値}}。会ったことのない相手は入れ物から作る
func set_pair_values(theirs: Dictionary) -> void:
	for oid in theirs:
		var pp := pair_to(int(oid))
		var vals = theirs[oid]
		if typeof(vals) != TYPE_DICTIONARY:
			continue
		for pid in vals:
			pp.set_v(String(pid), float(vals[pid]))


var action_phase := "idle"  ## "idle" | "think" | "move" | "act"
var act_timer := 0.0

var _path: PackedVector2Array = PackedVector2Array()
var _path_i := 0
var _aim := Vector2.ZERO   ## 道を引いた先。追う相手がここから動いたら引き直す
var _bubbles: Array = []
var _brain = null
var _bob := 0.0
var selected := false

## カーソルが乗っているか。**名前は常に出さない。**
## 8人ぶんの名札が always 出ていると、世界の上が字で埋まって
## 積み木の村が見えなくなる。かざしたときと、選んでいるときだけ出す。
var hovered := false:
	set(on):
		if hovered != on:
			hovered = on
			queue_redraw()


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


# ---------------------------------------------------------------------------
# メインループ
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# **止まっていても、ゆらゆらする。** 世界の時間が止まっていても、
	# 考え込んでいても、息をしていない人は置物に見える。
	# ここだけは世界の時間ではなく本当の時間で動く
	_bob += delta * (3.0 if SimClock.paused or action_phase == "think" else 6.0)
	if SimClock.paused or action_phase == "think":
		queue_redraw()
	if SimClock.paused:
		return

	# 【AI差し替え口】気持ちは**ひとりでに更新される**（`villager/feeling.gd`）。
	# 神が見ている人にだけ訊いていたので、誰も見ていない村では一言が
	# 一度も生まれず、変わっていく様子もどこにも残らなかった。
	# 間隔は `Feeling.COOL` が持っているので、ここは毎フレーム呼んでいい
	Feeling.ask(self)

	var dt := delta * SimClock.speed

	if action_phase == "idle" \
			and float(Time.get_ticks_msec()) / 1000.0 >= think_again_at:
		_decide()

	_execute(dt)


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
	var c: Dictionary = _brain.choose()
	if c.is_empty():
		# 訊いている最中。**立ち止まって待つ**——返事が来たら `begin()` が来る。
		# ここで代わりの行動を始めると、判断していないのに動いたことになる
		action_phase = "think"
		current_action = {}
		return
	begin(c)


## いま話している最中か
func _is_talk() -> bool:
	return String(current_action.get("kind", "")) == "talk" \
		and String(current_action.get("target", "")) == "talk"


func _close_act() -> void:
	action_phase = "idle"
	current_action = {}
	_spoke = false
	_talking = false
	_scene = []
	_scene_wait = false
	_beat = 0.0
	_wrote = false
	_writing = false


## 決まった行動を始める。AIの返事も、規則で選んだぶんも、ここを通る
func begin(c: Dictionary) -> void:
	if c.is_empty():
		action_phase = "idle"
		return
	_spoke = false
	_talking = false
	_scene = []
	_scene_wait = false
	_beat = 0.0
	_wrote = false
	_writing = false
	current_action = c
	action_phase = "move"
	act_timer = 0.0
	# 建物は通り抜けられないので、間の空きを通って回り込む
	_aim = current_action.get("target_cell", cell)
	_path = world.find_path(cell, _aim)
	_path_i = 0


func _execute(dt: float) -> void:
	if action_phase == "think":
		return   # 返事待ち。世界は動くが、この人は動かない
	if current_action.is_empty():
		action_phase = "idle"
		return

	if action_phase == "move":
		_follow()
		# **間合いに入ったら止まる。** 物の上や人の真上まで歩かない
		var near := float(current_action.get("reach", -1.0))
		var goal: Vector2 = current_action.get("target_cell", cell)
		var step := SimConfig.p("move_speed") * dt
		while step > 0.0:
			if near >= 0.0 and cell.distance_to(goal) <= near:
				action_phase = "act"
				break
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
		if _is_talk():
			_talk_tick(dt)
			return
		if _write_tick():
			return
		if act_timer >= float(current_action.get("duration", 0.6)):
			_complete_action()
			_close_act()


## 向かう相手が人なら、**いま居るところへ向け直す。** 歩き始めた時の場所へ行っても、
## もうそこには居ない。見えなくなったら追うのをやめて、その場で手を閉じる
## （`_do_talk` が見失ったと書く）
func _follow() -> void:
	var who = current_action.get("obj", null)
	if who == null or not is_instance_valid(who) or not (who is Villager):
		return
	if cell.distance_to(who.cell) > Rules.SIGHT:
		_path = PackedVector2Array()
		return
	# 止まるかどうかは**いまの居場所**で測る。道を引き直すのは半マス動いたときだけ
	current_action["target_cell"] = who.cell
	if _aim.distance_to(who.cell) <= 0.5:
		return
	_aim = who.cell
	_path = world.find_path(cell, who.cell)
	_path_i = 0


## 会話の場面を回す。**この手のあいだに始まって終わる**——
## 相手の手は止めないので、相手は歩きながら返すこともある（離れても閉じない）。
## 訊いているあいだ本人は立っているが、それは話しているあいだであって
## 「考えている」ではない（頭の粒は出さない）
func _talk_tick(dt: float) -> void:
	var other = current_action.get("obj", null)
	# **着いた瞬間に言う。** 言い終えてから返事を待つのであって、
	# 待ってから言うのではない
	if not _spoke:
		_spoke = true
		_complete_action()
		if not _talking:
			_close_act()   # 着いたら居なかった（空振りは `_complete_action` が記録済み）
			return
		_beat = TALK_BEAT
		return
	if _scene_wait:
		if act_timer >= TALK_MAX:
			_seal_scene("返事は返ってこなかった")
		return
	# **始まった会話は、離れても続く。** 言葉は声の届く範囲で運ばれるのではなく、
	# 一度向き合った二人のあいだで続いている。閉じるのは相手が世界から消えたときだけ
	if other == null or not is_instance_valid(other):
		_seal_scene("相手はもう居なかった")
		return
	_beat -= dt
	if _beat > 0.0:
		return
	if _scene.size() >= TALK_TURNS:
		_seal_scene("")
		return
	# 次に言うのは、いま言った人ではないほう
	var who = other if (_scene.size() % 2) == 1 else self
	var to = self if who == other else other
	_scene_wait = true
	var mine: int = id
	var got := func(line: String) -> void:
		if not is_instance_valid(self) or id != mine or not _scene_wait:
			return
		_take_line(who, to, line)
	if not Talk.reply(who, to, _scene, got):
		_seal_scene("")


## 貼る手で、文面がまだ無ければ訊く。**返るまでは true**（まだ貼らない）。
## 会話の1行目と同じく、手を選んだあとで言葉だけを訊く
func _write_tick() -> bool:
	if String(current_action.get("kind", "")) != "talk" \
			or String(current_action.get("target", "")) != "post" \
			or String(current_action.get("言うこと", "")) != "":
		return false
	if not _wrote:
		_wrote = true
		var mine: Dictionary = current_action
		var got := func(text: String) -> void:
			if not is_instance_valid(self) or not is_same(current_action, mine) \
					or not _writing:
				return
			_writing = false
			current_action["言うこと"] = text
		_writing = Post.write(self, got)
	# 返事が返らないときの歯止め。そのときは書かずに帰る（`_do_post` が空振りにする）
	if _writing and act_timer < TALK_MAX:
		return true
	_writing = false
	return false


## ひと言が返ってきた。**空は沈黙**で、そこで場面が終わる
func _take_line(who, to, line: String) -> void:
	_scene_wait = false
	if line == "" or not is_instance_valid(who) or not is_instance_valid(to):
		_seal_scene("%s は黙っていた" % (who.vname if is_instance_valid(who) else "相手"))
		return
	_scene.append({"who": who.vname, "words": line})
	who.memory.record("%sに「%s」と言った" % [to.vname, line])
	to.memory.record("%sに「%s」と言われた" % [who.vname, line])
	who.say("talk", "talk", TALK_BEAT + 0.6)
	_beat = TALK_BEAT


## 場面を綴じる。**一往復ずつ離れて並ぶと、神の目に会話として映らない**ので、
## 場面ぜんぶで1件にする（一言ずつ改行）
func _seal_scene(note: String) -> void:
	if _scene.size() >= 2:
		var parts := PackedStringArray()
		var marks := {}
		for e in _scene:
			parts.append("%s「%s」" % [String(e["who"]), String(e["words"])])
		var other = current_action.get("obj", null)
		marks[vname] = "v:%d" % id
		if other != null and is_instance_valid(other):
			marks[other.vname] = "v:%d" % other.id
		EventLog.social("\n".join(parts), marks)
	if note != "":
		memory.record(note)
		EventLog.mind(vname, note)
	_close_act()


## 型 × 対象ごとに、世界で何が起きるかだけを決める。
## その結果パラメータがどう動くかはここには書かれていない（AIの担当）。
##
## 手に入れる・建てるは、手に入れかた（`Schema.inputs_of`）のとおりに払う。
## 使うは、`current_action` に乗った持ち物の動き（本人の答え、`Brain._decide_how`）を適用するだけ。
func _complete_action() -> void:
	var kind := String(current_action.get("kind", "move"))
	var target := String(current_action.get("target", ""))
	var obj = current_action.get("obj", null)
	var done := true

	match kind:
		"use":
			done = _do_use(target, obj)
		"make":
			done = _do_make(target)
		"talk":
			match target:
				"talk":
					done = obj != null and is_instance_valid(obj) and _do_talk(obj)
				"post":
					done = _do_post()
				"read":
					_do_read_board()

	# 使うのは空振りすることがあり（手に無かった・建物が無くなっていた）、
	# 作るのは払えないことがある。実際に起きたときだけ世界の上に見せる。
	if done:
		say(kind, target)
		EventLog.mind(vname, "した：%s" % action_label())
	else:
		# **空振りも身に起きたこと。** 世界は理由まで知っている（居なかった、
		# 残っていなかった、払えなかった）ので、そこまで書く——
		# 行動の名前をもう一度書いても、何があったかを言ったことにならない
		var why: String = _miss if _miss != "" else "%s（できなかった）" % action_label()
		_miss = ""
		memory.record(why)
		EventLog.mind(vname, "空振り：%s" % why)


## 使うぶん（`Brain._how_much`）を、そのまま世界に映す。
##
## **量については何も見ない。** いくつ使うかはその人の答えで、上限もどこにも無い。
## プログラムが見るのは**無いものは払えない**——減らせるのは、持っているぶんまで。
##
## **使うだけでは何も増えない。** 物が手に入るのは「手に入れる」の手だけで、
## 何がどこでいくつの材料で手に入るかは、Jev が組んだ手に入れかたにある（`_do_make`）。
## 手の中のものを使うだけで物が増えるなら、手に入れかたという枝が要らなくなる。
func _apply(want: Dictionary) -> Dictionary:
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
		# 1つ手に入れたことは、行動の名前（〜を手に入れる）がもう言っている。
		# 増えるのは手に入れた物そのものだけ（`Schema.make_move`）
		if n > 1:
			got.append("%dつ手に入れた" % n)

	var parts: Array = []
	if not paid.is_empty():
		parts.append(" ".join(paid))
	parts.append_array(got)
	return "" if parts.is_empty() else "（%s）" % "、".join(parts)


## 手に入れかたのとおりに、材料が減って、手の中の1つになるか、世界の上に建つ。
## 採るのも作るのもここ（材料が空なら採る、というだけ）。
##
## **材料は数だけそろっていないと払わない。** 半分だけ減って何もできないのは、
## 手に入れかたを決めた世界の側の言い分にならない。
## 歩いているあいだに他の手で減らしていたら、着いた先で足りないことがある。
##
## 何軒建つかは誰も決めていない。見るのは置ける場所が空いているかだけで、
## 建てはじめてから建て終わるまでにそこが埋まっていれば、その人は建てられなかった。
func _do_make(target: String) -> bool:
	if Schema.thing_def(target) == null:
		return false
	var building := Schema.is_building(target)
	var name_text := Schema.target_label("make", target)
	var inputs := Schema.inputs_of(target)
	for x in inputs:
		if item_count(String(x)) < int(inputs[x]):
			_miss = "%s を手に入れようとしたが、%sが足りなかった" % [name_text,
				Schema.item_label(String(x))]
			return false
	var place := Schema.place_of(target)
	if place != "":
		var at = current_action.get("obj", null)
		if at == null or not is_instance_valid(at):
			_miss = "%s で %s を手に入れようとしたが、もう無かった" % [
				Schema.place_label(place), name_text]
			return false
	var c: Vector2i = current_action.get("build_cell", Vector2i(-1, -1))
	if building and (c.x < 0 or not world._can_build_at(c)):
		_miss = "%s を建てようとしたが、置ける場所が無かった" % name_text
		return false

	var moved := {}
	for x in inputs:
		add_item(String(x), -int(inputs[x]))
		moved[String(x)] = -int(inputs[x])
	if not building:
		add_item(target, 1)
		moved[target] = 1
		memory.record("入手：%s%s" % [action_label(), _moved_text(moved, target)])
		return true

	var s: Structure = world.add_structure(target, c, id, color)
	memory.record("建築：%s%s" % [action_label(), _moved_text(moved, target)])
	EventLog.notable("%s が%sを建てた" % [vname, s.label()],
		{vname: "v:%d" % id, s.label(): "s:%d" % s.id})
	return true


## 使う。何をしたか（食べる／祈る）は本人の言葉（`Brain._name_act`）で、
## 世界の側で起きるのは「どこにあるものを使ったか」だけで決まる。
##   手の中のもの … 本人が決めたぶん減る
##   建物         … 何も減らない（置いていくなら減る）。何も手に入らない
func _do_use(target: String, obj) -> bool:
	var where := String(current_action.get("where", "hand"))
	if where == "building" and (obj == null or not is_instance_valid(obj)):
		_miss = "%s へ着いたが、もう無かった" % Schema.target_label("use", target)
		return false
	var moved := _apply(current_action.get("move", {}))
	# 建物に入るように、持ち物が何も動かない使い方もある。それは空振りではない。
	if where != "building" and moved.is_empty():
		_miss = "%s を使おうとしたが、手に無かった" % Schema.item_label(target)
		return false
	memory.record("使用：%s%s" % [action_label(), _moved_text(moved, target)])
	return true


## 会話。言った言葉を双方の帳面に残す。
## 【AI差し替え口】何を話すかは本人の言葉（1行目も場面の続きも `villager/talk.gd` が訊く。
## 文章の相手に手を訊いたときだけ、手と一緒に返る「言うこと」が1行目になる）。相手をどう思うようになったかは、次の問いで相手ごとの値として
## 本人が答える（`Brain._read_jev`）。
## 追っても届かなかった、は空振り。**歩くあいだ相手も歩いている**ので、
## 見えなくなるまで離れられたり、道が無かったりすれば届かない
## （世界の間合いは規則として残っている）
func _do_talk(other) -> bool:
	var way = Schema.target_def("talk", "talk")
	var reach: float = float(way["reach"]) if way != null else 2.2
	if cell.distance_to(other.cell) > Rules.SIGHT:
		_miss = "%s を追ったが、見失った" % other.vname
		return false
	if cell.distance_to(other.cell) > reach:
		_miss = "%s のところへ着いたが、もう間合いに居なかった" % other.vname
		return false
	# 手と一緒に「言うこと」が返っていればそれが1行目（文章の相手に訊いたとき）。
	# 無ければ `Talk` が1行目から訊く。世界が運ぶのは言葉そのものだけ
	var words := String(current_action.get("言うこと", ""))
	# 会ったことがあるという事実だけ、相手ごとの入れ物を作って残す
	pair_to(other.id)
	other.pair_to(id)
	memory.last_talk_day[other.id] = SimClock.day
	other.memory.last_talk_day[id] = SimClock.day
	# **相手の手は止めない。** 話しかけられても、いましていることは続く——
	# 返すのは言葉だけで、それは相手の一手を消費しない。
	# 記録には残るので、相手が次に考えるときにはちゃんと目に入る
	_talking = true
	_scene = []
	# **手を選んだのが Jev なら、言葉はまだ無い。** その1行目も `Talk` に訊く
	# （場面が空のまま始まって、最初に口を開くのはこちら）
	if words == "":
		return true
	# 言葉は鉤括弧で囲む。村の記録・帳面・問いの紙で同じ書き方にする
	memory.record("%sに「%s」と言った" % [other.vname, words])
	other.memory.record("%sに「%s」と言われた" % [vname, words])
	_scene.append({"who": vname, "words": words})
	say("talk", "talk", TALK_BEAT + 0.6)
	return true


## 掲示板に貼る。貼るのは本人の言葉——文章の相手が手を選んだなら手と一緒に
## 返った「言うこと」、Jev が選んだなら板の前で訊いた文（`_write_tick` / `Post`）。
## 【AI差し替え口】何をどう書くかは本人の言葉で、世界は文面を作らない。
func _do_post() -> bool:
	var board = world.board
	if board == null:
		return false
	# **何を書くかは本人。** 書かなかったなら、貼らずに帰る——
	# 世界が代わりに文面を作ると、そこだけ神でも村人でもない誰かの言葉になる
	var text := String(current_action.get("言うこと", ""))
	if text == "":
		_miss = "掲示板の前まで来たが、何も書かなかった"
		return false
	for e in board.posts:
		if int(e["author_id"]) == id and String(e["text"]) == text:
			_miss = "掲示板に、同じことを書いた紙がもう貼ってあった"
			return false
	board.post(id, vname, text)
	memory.record("書き込み（%s）を掲示板に貼った" % text)
	return true


## 掲示板を読む。世界がするのは、読んだ紙を帳面に残すところまで。
## 【AI差し替え口】どう受け取ったかは別に訊かない。この一行が次の問いに
## 「前に考えてから起きたこと」として渡り、手・自分の値・書いた相手への値に効く
## （`Brain._read_jev`）。神の紙は差出人不明なので、相手への値には行き先がない。
func _do_read_board() -> void:
	var board = world.board
	if board == null:
		return
	var unread: Array = board.unread_for(memory)
	if unread.is_empty():
		return
	for e in unread:
		memory.mark_post_read(int(e["id"]))
		# 誰の紙かより、何が書いてあったかが記憶に残る
		memory.record("%sの書き込み（%s）を読んだ"
			% [String(e["author_name"]), String(e["text"])])


# ---------------------------------------------------------------------------
# 夜
# ---------------------------------------------------------------------------

## 一日を畳む。**何を覚えていて何を忘れるかは本人**（`villager/recall.gd`）。
## 繋がっていなければ、数えただけの一行が穴を埋める
func on_night() -> void:
	Recall.ask(self, SimClock.day)


## 帳面を閉じる。**判断の側が見ている位置も一緒にずらす**——
## 出来事の位置で「前に考えてから」を覚えているので、頭から落とすとずれる
func fold_day(n: int) -> void:
	var dropped: int = memory.fold(n)
	if _brain != null:
		_brain.forget_before(dropped)


# ---------------------------------------------------------------------------
# ヘルパ
# ---------------------------------------------------------------------------

func action_label() -> String:
	# 考えているあいだは手が空いている。**「待機」ではない**——
	# 世界の上では頭の粒で、紙ではこの一行で、同じことを言う
	if action_phase == "think":
		return "考えている"
	return String(current_action.get("label", "待機"))


# ---------------------------------------------------------------------------
# 描画
# ---------------------------------------------------------------------------

func _draw() -> void:
	var font: Font = SimConfig.ui_font if SimConfig.ui_font != null else ThemeDB.fallback_font
	# 歩いているときは大きく、立っているときは小さく。考えているときはその間——
	# 息はしているが、足は出ていない
	var sway := 1.6 if action_phase == "move" else (0.9 if action_phase == "think" else 0.4)
	var lift := sin(_bob) * sway
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
	# 近くに誰かいるときは段をずらす。
	var crowd: int = world.neighbors_within(cell, 2.2, id).size()
	var tier := float(id % 3) * 9.0 if crowd > 0 else 0.0

	# **考えている印。** 止まっている理由が読めないと、生きているのではなく
	# 壊れて見える。内側を代弁してはいない——「次の考えがまだ届いていない」は
	# 世界が知っている事実で、神がAIの遅さを読むためのものでもある。
	# 字ではなく粒で描く（フォント任せの記号は意味が引けない）
	if action_phase == "think":
		var at := Vector2(0, -46 - lift - tier)
		var beat := fmod(_bob * 0.5, 3.0)
		for i in range(3):
			var on: bool = float(i) <= beat
			draw_circle(at + Vector2(float(i - 1) * 6.0, 0.0), 2.0,
				Color(0.99, 0.98, 0.94, 0.85 if on else 0.28))

	for i in range(_bubbles.size()):
		_bubbles[i].draw_on(self, Vector2(0, -48 - lift - tier - float(i) * 18.0))

	# 名前はかざしたときと選んでいるときだけ
	if selected or hovered:
		_label(font, vname, Vector2(-40, -30 - lift - tier), 80, 11, Color(1, 1, 1, 0.95))


## 世界の上に置く文字。縁取りがないと昼は白飛び、夜は沈んで読めない。
func _label(font: Font, text: String, at: Vector2, w: int, size: int, col: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 4,
		Color(0.05, 0.06, 0.09, 0.75))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
