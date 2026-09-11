extends PanelContainer
## 個体インスペクタ。選んだ村人の内側を見る面。

signal select_requested(v)

## どのパラメータが並ぶかは Schema が決めるので、パラメータを足せばここにも自動で出る。

## **面は作り直さない。値だけを入れ替える。**
##
## 以前は 0.12 秒ごとに中身を全部捨てて組み直していた。値は動くのだから、と。
## だが「?」も相手の名前も押せるものなので、**カーソルの下で消えて生まれ直す**。
## 点滅して押せない。組み立て（`rebuild`）と、値の入れ替え（`_refresh`）を分ける。
##
## 作り直すのは形が変わったときだけ——選んだ人が変わった、言葉が増えた、
## 会ったことのある相手が増えた、持ち物の品目が変わった、今日の出来事が増えた。

var world = null
var subject = null

var _body: VBoxContainer
var _head: VBoxContainer
## 章の目次。設計図と同じ部品（`chapter_index.gd`）
var _index: ChapterIndex
var _opened := {}  ## other_id -> 畳んでいないか
var _refresh_accum := 0.0

# 値を差し替えるために持っておくもの
var _have: HFlowContainer
var _have_sig := ""
var _have_ready := false
var _now: Label
var _feel: Label
var _self_bars := {}     ## param id -> PipBar
var _pair_bars := {}     ## other_id -> { param id -> PipBar }
var _summary: Label
var _eps_box: VBoxContainer
var _eps_count := -1
var _known_pairs := -1
var _pair_cards := {}    ## other_id -> {card, body, fold, name}（表から送られてきたとき用）
var _pending_pair := -1


func _ready() -> void:
	custom_minimum_size = Vector2(384, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIKit.GAP)
	UIKit.paper_sheet(self).add_child(root)

	# 名前はこの紙の題。**送っても動かない**——誰の紙を読んでいるかは、
	# どこまで送っても見えていないといけない
	_head = VBoxContainer.new()
	_head.add_theme_constant_override("separation", 0)
	root.add_child(_head)

	_index = ChapterIndex.new()
	root.add_child(_index)

	# 一枚の巻物。章はこの中に平らに並ぶ（設計図と同じ形）
	_body = UIKit.scroll_body(root, UIKit.BG)
	_index.follow(_body)

	Schema.parameters_changed.connect(rebuild)
	rebuild()


func set_subject(v) -> void:
	subject = v
	rebuild()


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum < 0.12:
		return
	_refresh_accum = 0.0

	if subject == null or not is_instance_valid(subject):
		if visible:
			rebuild()
		return

	# 相手が増えたときだけ組み直す。値が動いただけなら差し替えで足りる。
	if subject.pairs.size() != _known_pairs:
		rebuild()
		return

	_refresh()


# ---------------------------------------------------------------------------
# 組み立て（形が変わったときだけ）
# ---------------------------------------------------------------------------

func rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	for c in _head.get_children():
		_head.remove_child(c)
		c.queue_free()
	_index.clear()
	_self_bars.clear()
	_pair_bars.clear()
	_pair_cards.clear()
	_have = null
	_have_sig = ""
	_have_ready = false
	_now = null
	_feel = null
	_summary = null
	_eps_box = null
	_eps_count = -1

	# 見せるものが無いときはパネルごと消す
	visible = subject != null and is_instance_valid(subject)
	if not visible:
		_known_pairs = -1
		return

	_known_pairs = subject.pairs.size()
	_build_header()
	_build_now()
	_build_personality()
	_build_self_params()
	_build_pairs()
	_build_memory()
	_index.rebuild()
	_refresh()
	if _pending_pair >= 0:
		_open_pair.call_deferred(_pending_pair)
		_pending_pair = -1


func _build_header() -> void:
	UIKit.title(_head, subject.vname, subject.color.darkened(0.35))
	_head.add_child(UIKit.label(subject.personality.quirk, UIKit.FS_NOTE, UIKit.TEXT_DIM))


## この村人について分単位で変わるのはこの章だけなので、いちばん上に置く。
func _build_now() -> void:
	_index.chapter(_body, "いま",
		"この人がしている事と、手に持っているもの。
ここだけが分単位で変わる。")

	# **強さは字の段が担う。** 面で囲って地の色を変えていたが、
	# 囲いは「紙の上に別の物体が乗っている」ことを言う形で、
	# ここで言いたいのは「いちばん読んでほしい一言」だった。
	# 【AI差し替え口】いまの気持ちの一言（`villager/feeling.gd`）。
	# **こちらを先に、大きく。** いちばん読んでほしいのは何をしているかではなく、
	# その人がいまどう感じているか。していることは、その下の小さい行で足りる。
	# **傾けない。** 傾いた書体を持っていないので、同じ字を歪ませることになる。
	# 気持ちと行動は、**順番と字の段**で分かれていれば足りる。
	# AIに繋がっていなければ行ごと出ない（規則で作った嘘を置くより、無いほうがいい）
	_feel = UIKit.wrapped(_body, "", UIKit.FS_HEAD, UIKit.TEXT)
	_feel.visible = false

	_now = UIKit.wrapped(_body, "", UIKit.FS_BODY, UIKit.TEXT)

	# 持ち物は絵と名前を対で出す。絵だけだと、神がつけた名前の物が何なのか読めない。
	UIKit.spacer(_body, UIKit.GAP)
	_body.add_child(UIKit.label("もちもの", UIKit.FS_NOTE, UIKit.TEXT_DIM))
	_have = HFlowContainer.new()
	_have.add_theme_constant_override("h_separation", UIKit.GAP)
	_have.add_theme_constant_override("v_separation", UIKit.GAP_S)
	_body.add_child(_have)


## 性格は始まりに決まったまま動かないので、組み立てるだけで差し替えは要らない。
##
## **同じ紙の中は同じ文法で並べる。** 章（見出し）→ 罫で区切った行、で全部揃える。
## 面で囲うのは「紙の上に別の物体が乗っている」ときだけ。
func _build_personality() -> void:
	_index.chapter(_body, "性格",
		"MBTIの4軸。ここから振る舞いは導かれない。\nこの人はこういう人だ、と渡すための素。")
	var rows := UIKit.rows(_body)

	var first := true
	for a in Personality.AXES:
		if not first:
			UIKit.hairline(rows)
		first = false
		# どちらへ寄っているかは、ゲージの両端に言葉を置けば読める
		UIKit.pole_row(UIKit.row_pad(rows), String(a[2]), String(a[3]),
			subject.personality.axis(String(a[0])))


## 束は、開始前に言葉を決めた紙と同じ形で見せる。
## 名前を1字ぶん下げただけの行では、値の行と同じ強さの注記に見えてしまう。
func _build_self_params() -> void:
	_index.chapter(_body, String(Schema.SCOPE_LABEL[Schema.SCOPE_SELF]),
		"一人につき1つ持つ言葉。0〜100。\n並びは設計図で決めたまま。")
	if Schema.self_params().is_empty():
		_body.add_child(UIKit.label("定義されていない", UIKit.FS_NOTE, UIKit.TEXT_DIM))
		return
	var rows := UIKit.rows(_body)
	var first := true
	for d in Schema.self_params():
		if not first:
			UIKit.hairline(rows)
		first = false
		var pid := String(d["id"])
		_self_bars[pid] = UIKit.bar_row(UIKit.row_pad(rows), String(d["label"]),
			subject.params.get_v(pid),
			float(d["min"]), float(d["max"]), Schema.param_color(pid))


func _build_pairs() -> void:
	_index.chapter(_body, String(Schema.SCOPE_LABEL[Schema.SCOPE_PAIR]),
		"相手ひとりごとに持つ値。−100〜100。\n会ったことのある相手だけが並ぶ。",
		subject.pairs.is_empty())

	if subject.pairs.is_empty():
		_body.add_child(UIKit.label("まだ誰とも会っていない", UIKit.FS_NOTE, UIKit.TEXT_DIM))
		return

	var first := true
	for oid in subject.pairs.keys():
		var target_id := int(oid)
		var other = world.villager_by_id(target_id)
		if other == null:
			continue

		# 相手ごとに囲わない。**折りたたみの見出し行そのものが区切り**になる。
		if not first:
			UIKit.hairline(_body)
		first = false

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", UIKit.GAP_S)
		_body.add_child(head)

		# 人数ぶん並ぶと長いので、相手ごとに畳んでおく
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 0)
		body.visible = _opened.get(target_id, false)

		var fold := Button.new()
		fold.text = ("▼ " if body.visible else "▶ ") + String(other.vname)
		fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
		fold.flat = true
		fold.add_theme_font_size_override("font_size", UIKit.FS_SUB)
		fold.add_theme_color_override("font_color", other.color.darkened(0.38))
		fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fold.custom_minimum_size = Vector2(0, UIKit.ROW_H)
		head.add_child(fold)
		fold.pressed.connect(_toggle_pair.bind(target_id, body, fold, String(other.vname)))

		var jump := EyeButton.new()
		jump.tooltip_text = "%s を見る" % other.vname
		head.add_child(jump)
		jump.pressed.connect(_jump_to.bind(target_id))
		_pair_cards[target_id] = {
			"card": head, "body": body, "fold": fold, "name": String(other.vname),
		}

		_body.add_child(body)
		var bars := {}
		var frow := true
		for d in Schema.pair_params():
			if not frow:
				UIKit.hairline(body)
			frow = false
			var pid := String(d["id"])
			bars[pid] = UIKit.bar_row(UIKit.row_pad(body), String(d["label"]),
				subject.pair_to(target_id).get_v(pid),
				float(d["min"]), float(d["max"]), Schema.param_color(pid))
		_pair_bars[target_id] = bars


func _build_memory() -> void:
	_index.chapter(_body, "記憶",
		"夜になると、その日の出来事が1行に畳まれる。\n覚えていられる日数は「この世界の言葉」の世界で決める。")
	_summary = UIKit.note(_body, "")

	_body.add_child(UIKit.label("今日の出来事", UIKit.FS_NOTE, UIKit.TEXT_DIM))
	_eps_box = VBoxContainer.new()
	_eps_box.add_theme_constant_override("separation", UIKit.HAIR)
	_body.add_child(_eps_box)
	UIKit.spacer(_body, UIKit.PAD)


# ---------------------------------------------------------------------------
# 値の入れ替え（形は触らない）
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if subject == null or not is_instance_valid(subject):
		return

	if _now != null:
		_now.text = subject.action_label()
	_refresh_feeling()

	_refresh_have()

	for pid in _self_bars:
		var d = Schema.param_def(String(pid))
		if d == null:
			continue
		var bar: PipBar = _self_bars[pid]
		if is_instance_valid(bar):
			bar.setup(subject.params.get_v(String(pid)),
				float(d["min"]), float(d["max"]), Schema.param_color(String(pid)))

	for oid in _pair_bars:
		var pp = subject.pair_peek(int(oid))
		if pp == null:
			continue
		var bars: Dictionary = _pair_bars[oid]
		for pid in bars:
			var d = Schema.param_def(String(pid))
			if d == null:
				continue
			var bar: PipBar = bars[pid]
			if is_instance_valid(bar):
				bar.setup(pp.get_v(String(pid)),
					float(d["min"]), float(d["max"]), Schema.param_color(String(pid)))

	if _summary != null:
		_summary.text = subject.memory.recent_summary(2)
	_refresh_episodes()


## 気持ちの一言。**訊くのは神がいま見ている人だけ**——8人ぶんを常に訊くと、
## 誰も読まない一言のために毎分お金が出ていく。
## 返ってくるまでは行が無いので、紙は繋がっていないときと同じ形で出る。
func _refresh_feeling() -> void:
	if _feel == null:
		return
	var line := String(subject.feeling)
	_feel.visible = line != ""
	if line != "":
		_feel.text = line
	Feeling.ask(subject)


## 品目が変わったときだけ並べ直す。数だけなら札の字を書き換える。
func _refresh_have() -> void:
	if _have == null:
		return
	var sig := ""
	var counts := {}
	for item in Schema.all_items():
		var iid := String(item)
		var n: int = subject.item_count(iid)
		if n <= 0:
			continue
		counts[iid] = n
		sig += iid + "|"
	# 手ぶらのときの sig は空。組み立て直後と見分けるために、組んだかどうかも持つ
	if not _have_ready or sig != _have_sig:
		_have_ready = true
		_have_sig = sig
		for c in _have.get_children():
			_have.remove_child(c)
			c.queue_free()
		if counts.is_empty():
			_have.add_child(UIKit.label("手ぶら", UIKit.FS_NOTE, UIKit.TEXT_DIM))
		for iid in counts:
			var chip := UIKit.item_chip(_have, String(iid),
				Schema.item_label(String(iid)), str(int(counts[iid])))
			chip.name = "chip_%s" % String(iid)
		return
	# 品目は同じなので、数の字だけ差し替える
	for iid in counts:
		var chip := _have.get_node_or_null("chip_%s" % String(iid))
		if chip == null:
			continue
		var last := chip.get_child(chip.get_child_count() - 1)
		if last is Label:
			(last as Label).text = str(int(counts[iid]))


## 出来事が増えたときだけ並べ直す
func _refresh_episodes() -> void:
	if _eps_box == null:
		return
	var eps: Array = subject.memory.episodes
	if eps.size() == _eps_count:
		return
	_eps_count = eps.size()
	for c in _eps_box.get_children():
		_eps_box.remove_child(c)
		c.queue_free()
	var tail: Array = eps.slice(maxi(0, eps.size() - 8))
	if tail.is_empty():
		_eps_box.add_child(UIKit.label("（まだ何もない）", UIKit.FS_NOTE, UIKit.TEXT_DIM))
		return
	for e in tail:
		UIKit.note(_eps_box, "・" + String(e))


# ---------------------------------------------------------------------------

## 畳んだ状態は村人を選び直しても覚えておく
func _toggle_pair(target_id: int, body: VBoxContainer, fold: Button, oname: String) -> void:
	var open := not body.visible
	body.visible = open
	_opened[target_id] = open
	fold.text = ("▼ " if open else "▶ ") + oname


func _jump_to(target_id: int) -> void:
	var v = world.villager_by_id(target_id)
	if v != null:
		select_requested.emit(v)


## 関係の表から送られてきたとき。その相手のところを開いて、そこまで送る。
## 表は眺めるための面なので、値はこちらで読ませる。
func focus_pair(other_id: int) -> void:
	_opened[other_id] = true
	if _pair_cards.has(other_id):
		_open_pair(other_id)
	else:
		# まだ組み立てていない（村人を選び直した直後）ので、出来上がってから
		_pending_pair = other_id


func _open_pair(other_id: int) -> void:
	var parts: Dictionary = _pair_cards.get(other_id, {})
	if parts.is_empty() or not is_instance_valid(parts["card"]):
		return
	var body: VBoxContainer = parts["body"]
	var fold: Button = parts["fold"]
	if not body.visible:
		body.visible = true
		fold.text = "▼ " + String(parts["name"])
	var sc = _body.get_meta("scroll", null)
	if sc != null and is_instance_valid(sc):
		sc.ensure_control_visible(parts["card"])
