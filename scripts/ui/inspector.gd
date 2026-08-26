extends PanelContainer
## 個体インスペクタ。神が一人の村人の内側を直接いじる面。
## どのパラメータが並ぶかは Schema が決めるので、パラメータを足せばここにも自動で出る。

var world = null
var subject = null

var _body: VBoxContainer
var _live := {}
var _dragging := {}
var _known_count := -1
var _refresh_accum := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(334, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.BG
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 6
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	add_theme_stylebox_override("panel", sb)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	scroll.add_child(_body)

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

	for key in _live:
		if _dragging.get(key, false):
			continue
		var entry: Dictionary = _live[key]
		var s: HSlider = entry["slider"]
		if not is_instance_valid(s):
			continue
		var nv: float = float(entry["get"].call())
		if absf(s.value - nv) > 0.005:
			s.set_value_no_signal(nv)
			var lbl = entry.get("label", null)
			if lbl != null and is_instance_valid(lbl):
				lbl.text = UIKit._fmt(nv, s.step)


func rebuild() -> void:
	_live.clear()
	_dragging.clear()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

	# 見せるものが無いときはパネルごと消す
	visible = subject != null and is_instance_valid(subject)
	if not visible:
		return

	_known_count = subject.pairs.size()
	_build_header()
	_build_self_params()
	_build_personality()
	_build_pairs()
	_build_memory()


func _live_slider(
	parent: Node, key: String, name_text: String, getter: Callable, setter: Callable,
	vmin: float, vmax: float, step: float, col: Color, name_width: int = 62
) -> void:
	var s := UIKit.slider_row(parent, name_text, float(getter.call()), vmin, vmax, step,
		setter, col, name_width)
	var val_label = s.get_parent().get_child(2)
	_live[key] = {"slider": s, "get": getter, "label": val_label}
	s.drag_started.connect(_on_drag_started.bind(key))
	s.drag_ended.connect(_on_drag_ended.bind(key))


func _on_drag_started(key: String) -> void:
	_dragging[key] = true


func _on_drag_ended(_changed: bool, key: String) -> void:
	_dragging[key] = false


# ---------------------------------------------------------------------------

func _build_header() -> void:
	_body.add_child(UIKit.label(subject.vname, 17, subject.color.lightened(0.25)))
	_body.add_child(UIKit.label(subject.personality.describe(), 11, UIKit.TEXT_DIM))

	var inv: Dictionary = subject.inventory
	var home_text := "　家なし" if subject.home == null else "　家あり"
	_body.add_child(UIKit.label("食料 %d / 木材 %d / 石材 %d%s"
		% [inv["food"], inv["wood"], inv["stone"], home_text], 11, UIKit.TEXT_DIM))
	UIKit.wrapped(_body, "いま：%s" % subject.action_label(), 11, Color(0.85, 0.9, 0.95))

	_body.add_child(UIKit.label("できること %d通り" % subject.feasible_actions().size(),
		11, UIKit.TEXT_DIM))


func _build_self_params() -> void:
	UIKit.section(_body, "個人パラメータ")
	if Schema.self_params().is_empty():
		_body.add_child(UIKit.label("　定義されていない", 11, UIKit.TEXT_DIM))
		return
	for cat in Schema.categories_in(Schema.SCOPE_SELF):
		_body.add_child(UIKit.label("　" + String(cat), 10, _category_color(String(cat))))
		for d in Schema.self_params():
			if String(d["category"]) != String(cat):
				continue
			UIKit.bar_row(_body, String(d["label"]),
				subject.params.get_v(String(d["id"])) - float(d["min"]),
				maxf(float(d["max"]) - float(d["min"]), 1.0), Color(d["color"]))


func _category_color(cat: String) -> Color:
	for d in Schema.self_params():
		if String(d["category"]) == cat:
			return Color(d["color"])
	return Color.WHITE


# ---------------------------------------------------------------------------

func _build_personality() -> void:
	UIKit.section(_body, "性格")
	for a in Personality.AXES:
		UIKit.bar_row(_body, String(a[1]),
			subject.personality.axis(String(a[0])) * 100.0, 100.0, Color(0.75, 0.65, 0.95))
	_body.add_child(UIKit.label("　一言個性　%s" % subject.personality.quirk, 11, UIKit.TEXT_DIM))


# ---------------------------------------------------------------------------

func _build_pairs() -> void:
	UIKit.section(_body, "関係パラメータ")

	if subject.pairs.is_empty():
		_body.add_child(UIKit.label("　まだ誰とも接していない", 11, UIKit.TEXT_DIM))
		return

	for oid in subject.pairs.keys():
		var target_id := int(oid)
		var other = world.villager_by_id(target_id)
		if other == null:
			continue

		var card := UIKit.panel(UIKit.BG_SOFT, 6)
		_body.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)

		var head := HBoxContainer.new()
		box.add_child(head)
		head.add_child(UIKit.label("→ " + String(other.vname), 12, other.color.lightened(0.3)))
		head.add_child(UIKit.label("　接触 %d回" % subject.pair_to(target_id).contacts,
			10, UIKit.TEXT_DIM))

		for d in Schema.pair_params():
			UIKit.bar_row(box, String(d["label"]),
				subject.pair_to(target_id).get_v(String(d["id"])) - float(d["min"]),
				maxf(float(d["max"]) - float(d["min"]), 1.0), Color(d["color"]))

		if other.knows(subject.id):
			var line := ""
			for d2 in Schema.pair_params():
				line += "%s%d  " % [String(d2["label"]),
					int(other.pair_to(subject.id).get_v(String(d2["id"])))]
			UIKit.wrapped(box, "　← %s から見た %s：%s" % [other.vname, subject.vname, line],
				10, Color(0.66, 0.70, 0.78))


func _build_memory() -> void:
	UIKit.section(_body, "記憶")
	UIKit.wrapped(_body, subject.memory.recent_summary(2), 10, Color(0.72, 0.76, 0.84))

	_body.add_child(UIKit.label("　今日の出来事", 10, UIKit.TEXT_DIM))
	var eps: Array = subject.memory.episodes
	var tail: Array = eps.slice(maxi(0, eps.size() - 8))
	if tail.is_empty():
		_body.add_child(UIKit.label("　（まだ何もない）", 10, UIKit.TEXT_DIM))
	for e in tail:
		UIKit.wrapped(_body, "　・" + String(e), 10, Color(0.66, 0.70, 0.78))
	UIKit.spacer(_body, 14)

