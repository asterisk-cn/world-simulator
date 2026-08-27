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

## 速さは3段。「1x 2x 4x 8x 16x 32x」の6連は再生プレイヤーの記号で、
## 画面の上端に常駐すると、そこだけ動画編集ソフトになる。
const SPEEDS := [1.0, 4.0, 16.0]
const SPEED_GLYPH := ["▶", "▶▶", "▶▶▶"]
const SPEED_TIP := ["ふつうの速さ", "速く", "とても速く"]
var _log_panel: PanelContainer
var _log_day := -1

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
	for i in range(SPEEDS.size()):
		var sp: float = SPEEDS[i]
		_speed_btns.append(UIKit.toggle_button(row, SPEED_GLYPH[i], SPEED_TIP[i],
			_set_speed.bind(sp), 24 + i * 12, 11))

	row.add_child(VSeparator.new())
	# 窓は名前で呼ぶ。記号のグリフだと、何が開くのか押すまで分からない。
	_win_btns = {
		"roster": UIKit.toggle_button(row, "村人", "誰がいま何をしているか", _toggle_roster, 52),
		"board": UIKit.toggle_button(row, "掲示板", "貼り紙を落とす", _toggle_board, 60),
		"matrix": UIKit.toggle_button(row, "間柄", "誰が誰をどう見ているか", _toggle_matrix, 52),
		"rules": UIKit.toggle_button(row, "言葉", "この世界の言葉", _toggle_rules, 52),
		"debug": UIKit.toggle_button(row, "デバッグ", "世界の外から手を入れる（開発用）", _toggle_debug, 64, 10),
	}
	# 神の窓と同格に見せない。これは世界の外側の道具。
	(_win_btns["debug"] as Button).modulate = Color(1, 1, 1, 0.55)
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


## 角括弧のタイムスタンプはサーバーログの記法で、「村の記録」の名前と衝突する。
## 日付は変わったときに1度だけ区切りとして出し、時刻は行頭に淡く置く。
func _on_log_entry(e: Dictionary) -> void:
	if _log == null:
		return
	var day := int(e["day"])
	if day != _log_day:
		_log_day = day
		_log.append_text("[color=#%s]──　%d日目　──[/color]\n"
			% [Color(0.46, 0.41, 0.34, 0.75).to_html(true), day])
	var col: Color = e["color"]
	_log.append_text("[color=#%s]%s[/color]  [color=#%s]%s[/color]\n"
		% [Color(0.46, 0.41, 0.34, 0.70).to_html(true), String(e["time"]),
			col.to_html(false), String(e["text"])])


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
	# 書く場所も紙。入力欄の顔をしていると、下に貼られた紙と文法が割れる。
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", _paper_style(true))
	box.add_child(sheet)
	var form_box := VBoxContainer.new()
	form_box.add_theme_constant_override("separation", UIKit.GAP_S)
	sheet.add_child(form_box)
	form_box.add_child(UIKit.label("神のお告げ", 11, UIKit.ACCENT))

	_post_text = LineEdit.new()
	_post_text.placeholder_text = "ここに書いたものが、差出人不明の貼り紙になる"
	_post_text.add_theme_font_size_override("font_size", 13)
	_post_text.custom_minimum_size = Vector2(0, UIKit.ROW_H + 6)
	# 紙の上に直接書くので、欄そのものは地のまま
	_post_text.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_post_text.add_theme_stylebox_override("focus", UIKit.ruled_style(0.0, 1))
	form_box.add_child(_post_text)
	_post_text.text_submitted.connect(func(_t: String) -> void: _submit_post())

	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", UIKit.GAP_S)
	form_box.add_child(form)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(gap)
	var submit := UIKit.accent_button(form, "貼る", _submit_post)
	submit.custom_minimum_size = Vector2(96, UIKit.ROW_H)

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



## 掲示板の紙。書く紙も貼られた紙も同じ形にして、書いたものがそのまま下へ加わって見えるように。
func _paper_style(by_god: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.92)
	sb.set_corner_radius_all(2)
	sb.border_color = Color(0.46, 0.33, 0.21, 0.28)
	sb.set_border_width_all(1)
	# 神が落とした紙だけ、縁に色が差す
	if by_god:
		sb.border_color = Color(0.86, 0.60, 0.18, 0.75)
		sb.border_width_left = 3
	sb.content_margin_left = UIKit.PAD_S
	sb.content_margin_right = UIKit.PAD_S
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	sb.shadow_color = Color(0, 0, 0, 0.10)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(1, 2)
	return sb


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
		_slip(posts[i])


## 貼られたものは1行のテキストではなく紙片で見せる。
## 世界の板に貼ってあるのは紙であって、一覧の行ではない。
func _slip(e: Dictionary) -> void:
	var by_god: bool = int(e["author_id"]) == -1
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _paper_style(by_god))
	_board_list.add_child(paper)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	paper.add_child(box)
	UIKit.wrapped(box, String(e["text"]), 12, UIKit.TEXT)

	# 差出人と日付は紙の隅に小さく
	var foot := HBoxContainer.new()
	box.add_child(foot)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	var who := "差出人不明" if by_god else String(e["author_name"])
	foot.add_child(UIKit.label("%d日目　%s" % [int(e["day"]), who], 10,
		Color(0.46, 0.41, 0.34, 0.85)))
