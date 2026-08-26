extends CanvasLayer
## 上部バー（時計・速度）、イベントログ、掲示板パネル。

var world = null

var _clock_label: Label
var _pop_label: Label
var _log: RichTextLabel
var _board_list: VBoxContainer
var _post_text: LineEdit
var _board_panel: PanelContainer
var _top_bar: PanelContainer
var _pause_btn: Button
var _speed_btns: Array = []
var _win_btns := {}

const SPEEDS := [1.0, 2.0, 4.0, 8.0, 16.0, 32.0]
var _log_panel: PanelContainer

var roster_panel = null
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
	_refresh_state()


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
	if roster_panel != null and not on:
		roster_panel.visible = false
	if debug_panel != null and not on:
		debug_panel.visible = false


func _build_top_bar() -> void:
	var panel := UIKit.panel()
	_top_bar = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.GAP)
	panel.add_child(row)

	_clock_label = UIKit.label("1日目", 14)
	_clock_label.custom_minimum_size = Vector2(142, 0)
	row.add_child(_clock_label)

	_pop_label = UIKit.label("村人 0", 12, UIKit.TEXT_DIM)
	_pop_label.custom_minimum_size = Vector2(66, 0)
	row.add_child(_pop_label)

	row.add_child(VSeparator.new())

	_pause_btn = UIKit.toggle_button(row, "❚❚", "一時停止", _toggle_pause, 34, 12)
	for s in SPEEDS:
		var sp: float = s
		_speed_btns.append(UIKit.toggle_button(row, "%dx" % int(sp), "%d倍速" % int(sp),
			_set_speed.bind(sp)))

	row.add_child(VSeparator.new())
	_win_btns = {
		"roster": UIKit.toggle_button(row, "☷", "村人", _toggle_roster, 30, 15),
		"board": UIKit.toggle_button(row, "▤", "掲示板", _toggle_board, 30, 15),
		"matrix": UIKit.toggle_button(row, "▦", "関係マトリクス", _toggle_matrix, 30, 15),
		"rules": UIKit.toggle_button(row, "⚙", "この世界の言葉", _toggle_rules, 30, 15),
		"debug": UIKit.toggle_button(row, "☰", "デバッグ", _toggle_debug, 30, 15),
	}
	_refresh_state()


func _toggle_pause() -> void:
	SimClock.paused = not SimClock.paused
	_refresh_state()


func _set_speed(sp: float) -> void:
	SimClock.paused = false
	SimClock.speed = sp
	_refresh_state()


## いま止まっているか、何倍速か、どの窓が開いているかをボタンに映す
func _refresh_state() -> void:
	if _pause_btn != null:
		_pause_btn.set_pressed_no_signal(SimClock.paused)
		_pause_btn.text = "▶" if SimClock.paused else "❚❚"
		_pause_btn.tooltip_text = "再開" if SimClock.paused else "一時停止"
	for i in range(_speed_btns.size()):
		var b: Button = _speed_btns[i]
		b.set_pressed_no_signal(
			not SimClock.paused and is_equal_approx(SimClock.speed, float(SPEEDS[i])))
	var panels := {
		"roster": roster_panel, "board": _board_panel, "matrix": matrix_panel,
		"rules": rules_panel, "debug": debug_panel,
	}
	for key in _win_btns:
		var p = panels.get(key, null)
		(_win_btns[key] as Button).set_pressed_no_signal(p != null and p.visible)


## 大きい窓は一度に1枚だけ。世界が見えなくなるのを防ぐ。
func _show_only(target) -> void:
	var want: bool = target != null and not target.visible
	for p in [roster_panel, _board_panel, matrix_panel, rules_panel, debug_panel]:
		if p != null:
			p.visible = (p == target) and want
	_refresh_state()


func close_panels() -> void:
	_show_only(null)


## 世界の掲示板を押したときに開く
func open_board() -> void:
	if _board_panel != null and not _board_panel.visible:
		_show_only(_board_panel)
	_refresh_state()
	if _post_text != null:
		_post_text.grab_focus()


func _toggle_roster() -> void:
	_show_only(roster_panel)


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
	box.add_child(UIKit.label("村の記録", 11, Color(0.34, 0.28, 0.20)))

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
	_board_panel.offset_top = 78
	_board_panel.offset_bottom = 414
	add_child(_board_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.GAP_S)
	_board_panel.add_child(box)
	UIKit.window_header(box, "掲示板", _toggle_board, Color(0.62, 0.42, 0.14))

	# --- 神が村に言葉を落とす場所。この窓の主役なので先頭に置く ---
	var card := UIKit.panel(Color(0.87, 0.80, 0.64), 8, UIKit.PAD_S)
	box.add_child(card)
	var form_box := VBoxContainer.new()
	form_box.add_theme_constant_override("separation", UIKit.GAP_S)
	card.add_child(form_box)
	form_box.add_child(UIKit.label("村に言葉を落とす", 13, UIKit.ACCENT))

	_post_text = LineEdit.new()
	_post_text.placeholder_text = "貼り紙の文面"
	_post_text.add_theme_font_size_override("font_size", 12)
	_post_text.custom_minimum_size = Vector2(0, UIKit.ROW_H + 4)
	form_box.add_child(_post_text)
	_post_text.text_submitted.connect(func(_t: String) -> void: _submit_post())

	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", UIKit.GAP_S)
	form_box.add_child(form)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(gap)
	var submit := UIKit.accent_button(form, "貼る", _submit_post)
	submit.custom_minimum_size = Vector2(96, UIKit.ROW_H + 4)

	# --- いま貼られているもの ---
	UIKit.section(box, "貼られているもの")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_board_list = VBoxContainer.new()
	_board_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_list.add_theme_constant_override("separation", UIKit.GAP_S)
	scroll.add_child(_board_list)



func _submit_post() -> void:
	if world == null or world.board == null:
		return
	var text := _post_text.text.strip_edges()
	if text == "":
		return
	world.board.post(-1, "差出人不明", text)
	_post_text.text = ""


func _refresh_board() -> void:
	if _board_list == null:
		return
	for c in _board_list.get_children():
		c.queue_free()
	if world == null or world.board == null:
		return
	if world.board.posts.is_empty():
		_board_list.add_child(UIKit.label("（まだ何も貼られていない）", 11, UIKit.TEXT_DIM))
		return
	var posts: Array = world.board.posts
	for i in range(posts.size() - 1, -1, -1):
		var e: Dictionary = posts[i]
		# 日付・文面・（分かれば）書いた人。それ以上は紙に書いていない
		var by_god: bool = int(e["author_id"]) == -1
		var col := Color(0.86, 0.60, 0.18) if by_god else UIKit.TEXT
		var who := "" if by_god else "　—— %s" % String(e["author_name"])
		UIKit.wrapped(_board_list, "%d日目　「%s」%s"
			% [int(e["day"]), String(e["text"]), who], 11, col)
