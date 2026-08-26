extends PanelContainer
## 個体インスペクタ。選んだ村人の内側を見る面。

signal select_requested(v)

## どのパラメータが並ぶかは Schema が決めるので、パラメータを足せばここにも自動で出る。

var world = null
var subject = null

var _body: VBoxContainer
var _known_count := -1
var _opened := {}  ## other_id -> 畳んでいないか
var _refresh_accum := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(334, 0)
	add_theme_stylebox_override("panel", UIKit.panel_style())

	_body = UIKit.scroll_body(self)

	Schema.parameters_changed.connect(rebuild)
	rebuild()


func set_subject(v) -> void:
	subject = v
	_known_count = -1
	rebuild()


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum < 0.12:
		return
	_refresh_accum = 0.0

	if subject != null and is_instance_valid(subject) and subject.pairs.size() != _known_count:
		rebuild()
		return

	rebuild()


func rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

	# 見せるものが無いときはパネルごと消す
	visible = subject != null and is_instance_valid(subject)
	if not visible:
		return

	_known_count = subject.pairs.size()
	_build_header()
	_build_personality()
	_build_self_params()
	_build_pairs()
	_build_memory()


# ---------------------------------------------------------------------------

func _build_header() -> void:
	_body.add_child(UIKit.label(subject.vname, 17, subject.color.darkened(0.35)))
	_body.add_child(UIKit.label(subject.personality.quirk, 11, UIKit.TEXT_DIM))
	UIKit.spacer(_body, 2)

	var carried := ""
	for item in Schema.all_items():
		var n: int = subject.item_count(String(item))
		if n <= 0:
			continue
		if carried != "":
			carried += " / "
		carried += "%s %d" % [Schema.item_label(String(item)), n]
	if carried == "":
		carried = "手ぶら"
	_body.add_child(UIKit.label("%s　%s"
		% [carried, "家なし" if subject.home == null else "家あり"], 11, UIKit.TEXT_DIM))
	# この村人について分単位で変わるのはここだけ。パネルで一番強くする。
	UIKit.spacer(_body, 2)
	var now := UIKit.card(Color(0.87, 0.81, 0.68), UIKit.GAP_S)
	_body.add_child(now)
	var now_box := VBoxContainer.new()
	now_box.add_theme_constant_override("separation", 1)
	now.add_child(now_box)
	now_box.add_child(UIKit.label("いま", 10, UIKit.TEXT_DIM))
	UIKit.wrapped(now_box, subject.action_label(), 14, UIKit.TEXT)


func _build_self_params() -> void:
	UIKit.section(_body, "胸のうち")
	if Schema.self_params().is_empty():
		_body.add_child(UIKit.label("　定義されていない", 11, UIKit.TEXT_DIM))
		return
	for cat in Schema.categories_in(Schema.SCOPE_SELF):
		_body.add_child(UIKit.label("　" + String(cat), 11, _category_color(String(cat)).darkened(0.30)))
		for d in Schema.self_params():
			if String(d["category"]) != String(cat):
				continue
			UIKit.bar_row(_body, String(d["label"]), subject.params.get_v(String(d["id"])),
				float(d["min"]), float(d["max"]), Schema.param_color(String(d["id"])))


func _category_color(cat: String) -> Color:
	return Schema.category_color(cat)


# ---------------------------------------------------------------------------

func _build_personality() -> void:
	UIKit.section(_body, "性格")
	# どちらへ寄っているかは、ゲージの両端に言葉を置けば読める
	for a in Personality.AXES:
		UIKit.pole_row(_body, String(a[2]), String(a[3]),
			subject.personality.axis(String(a[0])))


# ---------------------------------------------------------------------------

func _build_pairs() -> void:
	UIKit.section(_body, "間柄")

	if subject.pairs.is_empty():
		_body.add_child(UIKit.label("　まだ誰とも会っていない", 11, UIKit.TEXT_DIM))
		return

	for oid in subject.pairs.keys():
		var target_id := int(oid)
		var other = world.villager_by_id(target_id)
		if other == null:
			continue

		var card := UIKit.card()
		_body.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", UIKit.GAP_S)
		card.add_child(box)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		box.add_child(head)

		# 人数ぶん並ぶと長いので、相手ごとに畳んでおく
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 2)
		body.visible = _opened.get(target_id, false)

		var fold := Button.new()
		fold.text = ("▼ " if body.visible else "▶ ") + String(other.vname)
		fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
		fold.flat = true
		fold.add_theme_font_size_override("font_size", 12)
		fold.add_theme_color_override("font_color", other.color.darkened(0.38))
		fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fold.custom_minimum_size = Vector2(0, UIKit.ROW_H)
		head.add_child(fold)
		fold.pressed.connect(_toggle_pair.bind(target_id, body, fold, String(other.vname)))

		var jump := EyeButton.new()
		jump.tooltip_text = "%s を見る" % other.vname
		head.add_child(jump)
		jump.pressed.connect(_jump_to.bind(target_id))

		box.add_child(body)
		for d in Schema.pair_params():
			UIKit.bar_row(body, String(d["label"]),
				subject.pair_to(target_id).get_v(String(d["id"])),
				float(d["min"]), float(d["max"]), Schema.param_color(String(d["id"])))



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


func _build_memory() -> void:
	UIKit.section(_body, "記憶")
	UIKit.wrapped(_body, subject.memory.recent_summary(2), 10, UIKit.TEXT_DIM)

	_body.add_child(UIKit.label("　今日の出来事", 10, UIKit.TEXT_DIM))
	var eps: Array = subject.memory.episodes
	var tail: Array = eps.slice(maxi(0, eps.size() - 8))
	if tail.is_empty():
		_body.add_child(UIKit.label("　（まだ何もない）", 10, UIKit.TEXT_DIM))
	for e in tail:
		UIKit.wrapped(_body, "　・" + String(e), 10, UIKit.TEXT_DIM)
	UIKit.spacer(_body, 14)

