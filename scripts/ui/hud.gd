extends CanvasLayer
## 上部バー（時計・速度）、イベントログ、掲示板パネル。

var world = null

var _clock_label: Label
var _pop_label: Label
var _log: RichTextLabel
var _board_list: VBoxContainer
var _post_text: LineEdit
var _post_kind: OptionButton
var _post_target: OptionButton
var _board_panel: PanelContainer
var _top_bar: PanelContainer
var _pause_btn: Button
var _log_panel: PanelContainer

var matrix_panel = null
var rules_panel = null
var debug_panel = null


func setup(p_world) -> void:
	world = p_world
	_build_top_bar()
	_build_log()
	_build_board_panel()
	EventLog.entry_added.connect(_on_log_entry)
	if world.board:
		world.board.posts_changed.connect(_refresh_board)
	_refresh_board()


func _process(_delta: float) -> void:
	if _clock_label:
		var phase := "夜" if SimClock.is_night else "昼"
		_clock_label.text = "%d日目  %s  %s" % [SimClock.day, SimClock.clock_text(), phase]
	if _pop_label and world:
		_pop_label.text = "村人 %d" % world.villagers.size()


# ---------------------------------------------------------------------------

## 開始前は世界を止めているので、遊ぶための面をまとめて隠す
func set_play_ui_visible(on: bool) -> void:
	if _top_bar != null:
		_top_bar.visible = on
	if _log_panel != null:
		_log_panel.visible = on
	if _board_panel != null and not on:
		_board_panel.visible = false
	if matrix_panel != null and not on:
		matrix_panel.visible = false
	if debug_panel != null and not on:
		debug_panel.visible = false


func _build_top_bar() -> void:
	var panel := UIKit.panel()
	_top_bar = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	_clock_label = UIKit.label("1日目", 14)
	_clock_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(_clock_label)

	_pop_label = UIKit.label("村人 0", 12, UIKit.TEXT_DIM)
	_pop_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(_pop_label)

	row.add_child(VSeparator.new())

	_pause_btn = UIKit.icon_button(row, "❚❚", "一時停止", _toggle_pause, 34, 24, 12)
	for s in [1.0, 2.0, 4.0, 8.0, 16.0, 32.0]:
		var sp: float = s
		var b := UIKit.button(row, "%dx" % int(sp), _set_speed.bind(sp))
		b.custom_minimum_size = Vector2(34, 24)

	row.add_child(VSeparator.new())
	UIKit.icon_button(row, "▤", "掲示板", _toggle_board)
	UIKit.icon_button(row, "▦", "関係マトリクス", _toggle_matrix)
	UIKit.icon_button(row, "⚙", "設定", _toggle_rules)
	UIKit.icon_button(row, "☰", "デバッグ", _toggle_debug)


func _toggle_pause() -> void:
	SimClock.paused = not SimClock.paused
	_refresh_pause_btn()


func _refresh_pause_btn() -> void:
	if _pause_btn == null:
		return
	_pause_btn.text = "▶" if SimClock.paused else "❚❚"
	_pause_btn.tooltip_text = "再開" if SimClock.paused else "一時停止"


func _set_speed(sp: float) -> void:
	SimClock.paused = false
	SimClock.speed = sp
	_refresh_pause_btn()


## 大きい窓は一度に1枚だけ。世界が見えなくなるのを防ぐ。
func _show_only(target) -> void:
	var want: bool = target != null and not target.visible
	for p in [_board_panel, matrix_panel, rules_panel, debug_panel]:
		if p != null:
			p.visible = (p == target) and want


func close_panels() -> void:
	_show_only(null)


func _toggle_board() -> void:
	_show_only(_board_panel)


func _toggle_matrix() -> void:
	_show_only(matrix_panel)


func _toggle_rules() -> void:
	_show_only(rules_panel)


func _toggle_debug() -> void:
	_show_only(debug_panel)


func _build_log() -> void:
	var panel := UIKit.panel()
	_log_panel = panel
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 12
	panel.offset_right = 420
	panel.offset_top = -164
	panel.offset_bottom = -12
	add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UIKit.label("村の記録", 11, Color(0.72, 0.78, 0.9)))

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 11)
	box.add_child(_log)


func _on_log_entry(text: String, color: Color) -> void:
	if _log:
		_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])


func _build_board_panel() -> void:
	_board_panel = UIKit.panel()
	_board_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_board_panel.offset_left = 12
	_board_panel.offset_right = 472
	_board_panel.offset_top = 64
	_board_panel.offset_bottom = 400
	add_child(_board_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.GAP_S)
	_board_panel.add_child(box)
	UIKit.window_header(box, "掲示板", _toggle_board, Color(0.95, 0.86, 0.6))
	UIKit.wrapped(box, "貼り紙は差出人不明として扱われる。", 10)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_board_list = VBoxContainer.new()
	_board_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_board_list)

	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", 4)
	box.add_child(form)

	var kinds := [BulletinBoard.KIND_INFO, BulletinBoard.KIND_CLAIM,
		BulletinBoard.KIND_ACCUSE, BulletinBoard.KIND_OFFER]
	_post_kind = UIKit.dropdown(kinds, kinds, String(kinds[0]))
	form.add_child(_post_kind)

	_post_target = UIKit.dropdown([], [], "")
	form.add_child(_post_target)

	_post_text = LineEdit.new()
	_post_text.placeholder_text = "貼り紙の文面"
	_post_text.add_theme_font_size_override("font_size", 11)
	_post_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_post_text)

	var submit := UIKit.button(form, "貼る", _submit_post)
	submit.custom_minimum_size = Vector2(48, 24)
	_refresh_targets()


func _refresh_targets() -> void:
	if _post_target == null or world == null:
		return
	var prev := _post_target.selected
	_post_target.clear()
	_post_target.add_item("対象なし")
	_post_target.set_item_metadata(0, -1)
	var pop := _post_target.get_popup()
	pop.set_item_as_radio_checkable(0, false)
	pop.set_item_as_checkable(0, false)
	var i := 1
	for v in world.villagers:
		_post_target.add_item(v.vname)
		_post_target.set_item_metadata(i, v.id)
		pop.set_item_as_radio_checkable(i, false)
		pop.set_item_as_checkable(i, false)
		i += 1
	_post_target.select(clampi(prev, 0, _post_target.item_count - 1))


func _submit_post() -> void:
	if world == null or world.board == null:
		return
	var text := _post_text.text.strip_edges()
	if text == "":
		return
	var kind: String = _post_kind.get_item_text(_post_kind.selected)
	var tid: int = -1
	if _post_target.selected > 0:
		tid = int(_post_target.get_item_metadata(_post_target.selected))
	var payload := {}
	match kind:
		BulletinBoard.KIND_ACCUSE:
			payload = {"about": tid, "grudge_kind": "中傷", "severity": 40.0}
		BulletinBoard.KIND_CLAIM:
			payload = {"claimant": tid}
		BulletinBoard.KIND_OFFER:
			payload = {"giver": tid}
	world.board.post(-1, "差出人不明", kind, text, payload)
	_post_text.text = ""


func _refresh_board() -> void:
	if _board_list == null:
		return
	for c in _board_list.get_children():
		c.queue_free()
	_refresh_targets()
	if world == null or world.board == null:
		return
	if world.board.posts.is_empty():
		_board_list.add_child(UIKit.label("（まだ何も貼られていない）", 11, UIKit.TEXT_DIM))
		return
	var posts: Array = world.board.posts
	for i in range(posts.size() - 1, -1, -1):
		var e: Dictionary = posts[i]
		var col := Color(0.99, 0.86, 0.55) if int(e["author_id"]) == -1 else Color(0.85, 0.88, 0.94)
		var readers := 0
		for v in world.villagers:
			if v.memory.has_read_post(int(e["id"])):
				readers += 1
		UIKit.wrapped(_board_list, "[%s] %s：「%s」　%d日目・既読%d人"
			% [String(e["kind"]), String(e["author_name"]), String(e["text"]), int(e["day"]), readers], 11, col)
