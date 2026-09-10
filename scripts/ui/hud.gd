extends CanvasLayer
## 上部バー（時計・速度）、イベントログ、掲示板パネル。

## 記録の中の名前が押された。「v:村人のid」「s:建物のid」「board」のいずれか。
signal jump_requested(target: String)

## この世界を終えて、言葉のところへ戻る。
signal end_requested

## 神が紙を放った。画面上のどこから飛び出すかを添える。
## `sheet` は**書いていた紙そのもの**。飛ばす側が子に付けて運ぶ（`paper_fly.gd`）
signal god_posted(from_screen: Vector2, text: String, sheet: Control)

var world = null

var _clock_label: Label
var _pop_label: Label
var _log: RichTextLabel
var _board_list: VBoxContainer
var _board_panel: PanelContainer
var _write_btn: Button

## 紙が飛び出す元。「神のお告げ」を押した場所を覚えておく
var _write_from := Vector2.ZERO
var _top_bar: PanelContainer
var _pause_btn: Button
var _speed_btns: Array = []
var _win_btns := {}

## 上部バーは読む紙ではなく、**常に画面の端にいる操作の帯**。
## 紙の段（`PAD` / `ROW_H`）を上げても、ここの高さは上げない——
## 帯が太くなったぶん、そのまま世界が削れる。
## 帯の中は帯の都合で決める（DESIGN.md §9「紙が違えば揃えなくてよい」）。
## 帯は**横に引き出した紙**（ちぎれ目は左右）なので、丈はちぎれに食われない。
const BAR_PAD := 14
const BAR_ROW_H := 27

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
var option_panel = null


func setup(p_world) -> void:
	world = p_world
	_build_top_bar()
	_build_log()
	_build_board_panel()
	EventLog.entry_added.connect(_on_log_entry)
	if world.board:
		world.board.posts_changed.connect(_refresh_board)
	_refresh_board()


## 世界が作り直されたとき。記録の紙を替え、掲示板を新しい板に繋ぎ直す。
func on_world_reset() -> void:
	_log_day = -1
	if _log != null:
		_log.clear()
	if world != null and world.board != null:
		world.board.posts_changed.connect(_refresh_board)
	_refresh_board()
	# 誰がいるかも何を思っているかも入れ替わるので、窓の中身は作り直す
	if matrix_panel != null:
		matrix_panel.on_world_reset()
	if roster_panel != null:
		roster_panel.on_world_reset()


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
	if option_panel != null and not on:
		option_panel.visible = false


func _build_top_bar() -> void:
	# 横長の帯なので、ちぎれ目は短い辺——左右に来る（`across`）
	var panel := UIKit.panel(UIKit.BG, 10, BAR_PAD, true)
	_top_bar = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.GAP)
	UIKit.body_of(panel).add_child(row)

	_clock_label = UIKit.label("1日目", UIKit.FS_HEAD)
	_clock_label.custom_minimum_size = Vector2(180, 0)
	row.add_child(_clock_label)

	_pop_label = UIKit.label("村人 0", UIKit.FS_NOTE, UIKit.TEXT_DIM)
	_pop_label.custom_minimum_size = Vector2(78, 0)
	row.add_child(_pop_label)

	row.add_child(VSeparator.new())

	_pause_btn = UIKit.toggle_button(row, "❚❚", "一時停止", _toggle_pause, 40)
	for i in range(SPEEDS.size()):
		var sp: float = SPEEDS[i]
		_speed_btns.append(UIKit.toggle_button(row, SPEED_GLYPH[i], SPEED_TIP[i],
			_set_speed.bind(sp), 30 + i * 15))

	row.add_child(VSeparator.new())
	# 窓は名前で呼ぶ。記号のグリフだと、何が開くのか押すまで分からない。
	_win_btns = {
		"roster": UIKit.toggle_button(row, "村人", "誰がいま何をしているか", _toggle_roster, 62),
		"board": UIKit.toggle_button(row, "掲示板", "貼り紙を落とす", _toggle_board, 74),
		"matrix": UIKit.toggle_button(row, "関係", "誰が誰をどう見ているか", _toggle_matrix, 62),
		"rules": UIKit.toggle_button(row, "言葉", "この世界の言葉", _toggle_rules, 62),
		"debug": UIKit.toggle_button(row, "デバッグ", "世界の外から手を入れる（開発用）", _toggle_debug, 88),
		# 世界の中の話ではないので、見る窓のあとに置く
		"option": UIKit.toggle_button(row, "オプション", "この世界を終える", _toggle_option, 102),
	}
	# 神の窓と同格に見せない。これは世界の外側の道具。
	(_win_btns["debug"] as Button).modulate = Color(1, 1, 1, 0.55)

	# 札はどれも帯の高さに揃える（`toggle_button` は紙の段 ROW_H で作る）
	for b in [_pause_btn] + _speed_btns + _win_btns.values():
		(b as Button).custom_minimum_size.y = BAR_ROW_H

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
		"rules": rules_panel, "debug": debug_panel, "option": option_panel,
	}
	for key in _win_btns:
		var p = panels.get(key, null)
		(_win_btns[key] as Button).set_pressed_no_signal(p != null and p.visible)


## 大きい窓は一度に1枚だけ。世界が見えなくなるのを防ぐ。
func _show_only(target) -> void:
	var want: bool = target != null and not target.visible
	for p in [roster_panel, _board_panel, matrix_panel, rules_panel, debug_panel,
			option_panel]:
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


func _toggle_option() -> void:
	_show_only(option_panel)


func _build_log() -> void:
	var panel := UIKit.panel()
	_log_panel = panel
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 12
	panel.offset_right = 480
	panel.offset_top = -190
	panel.offset_bottom = -12
	add_child(panel)

	var box := VBoxContainer.new()
	UIKit.body_of(panel).add_child(box)
	box.add_child(UIKit.label("村の記録", UIKit.FS_NOTE, Color(0.34, 0.28, 0.20)))

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", UIKit.FS_BODY)
	# 下線は「ここには行き先がある」の印。全行に付けないので飾りにならない。
	_log.meta_underlined = true
	box.add_child(_log)
	_log.meta_clicked.connect(_on_log_meta)
	_log.meta_hover_started.connect(_on_meta_hover)
	_log.meta_hover_ended.connect(_on_meta_unhover)


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
			col.to_html(false), _link_names(String(e["text"]), e.get("marks", {}))])


## **行き先になるのは名前と建物だけ。** 行をまるごとリンクにしていたので、
## 「誰が何をした」の全部に下線が付き、下線が飾りになっていた。
## 名前を押せば、その名前のものへ行く——文の中のどこを押せるかが、そのまま行き先を言う。
##
## どの言葉が何を指すかは、**記録を書いた側が言う**（`marks`）。
## 読む側が名前から探すと、同じ名前の家が6軒あるとき、どれでもない家に飛ぶ。
func _link_names(body: String, marks: Dictionary) -> String:
	if marks.is_empty():
		return body
	# 長い名前から先に当てる。短い名前が長い名前の中を切らないように
	var words: Array = marks.keys()
	words.sort_custom(func(a, b) -> bool: return String(a).length() > String(b).length())

	var out := ""
	var i := 0
	while i < body.length():
		var hit := false
		for w in words:
			var word := String(w)
			if word == "" or body.substr(i, word.length()) != word:
				continue
			out += "[url=%s]%s[/url]" % [String(marks[word]), word]
			i += word.length()
			hit = true
			break
		if not hit:
			out += body[i]
			i += 1
	return out


## 記録の中の名前を押したら、その名前のものへ
func _on_log_meta(meta: Variant) -> void:
	jump_requested.emit(String(meta))


func _on_meta_hover(_meta: Variant) -> void:
	_log.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_meta_unhover(_meta: Variant) -> void:
	_log.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _build_board_panel() -> void:
	_board_panel = UIKit.panel()
	_board_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_board_panel.offset_left = 12
	_board_panel.offset_right = 544
	_board_panel.offset_top = 88
	_board_panel.offset_bottom = 470
	add_child(_board_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.GAP_S)
	UIKit.body_of(_board_panel).add_child(box)
	# 題は他の窓と同じ墨色。1枚だけ色が違うと、そこだけ別の種類の窓に見える
	UIKit.window_header(box, "掲示板", _toggle_board, UIKit.HEAD,
		"村で唯一の、書いて残す場所。\n神が貼った紙は差出人不明として扱われる。")

	# --- 神が村に言葉を落とす ---
	# 書く欄をこの窓に置いていたが、**板の上に空の紙が1枚常に貼ってある**ように見えた。
	# 貼るものが無いときも場所を取り、下に並ぶ紙と文法も割れていた。
	# 書くのは押したときだけ、幕を張った紙の上で（`write_popup.gd`）。
	#
	# 橙はこの窓で神の手が届く1か所（DESIGN.md §9）。**幅いっぱいに広げる。**
	# 村への唯一の干渉手段なので、この窓でいちばん強い要素でいい。
	_write_btn = UIKit.accent_button(box, "神のお告げ", _open_write)
	_write_btn.custom_minimum_size = Vector2(0, UIKit.ROW_H + UIKit.GAP_S)

	# --- いま貼られているもの ---
	# 見出しは置かない。板の上に紙が並んでいるのだから、「貼られているもの」と
	# 書き添える必要がない。
	UIKit.spacer(box, UIKit.GAP)
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
	# 上下は左右（PAD_S）より詰める。横長の紙に見せる
	sb.content_margin_top = UIKit.GAP_S
	sb.content_margin_bottom = UIKit.GAP_S
	sb.shadow_color = Color(0, 0, 0, 0.10)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(1, 2)
	return sb


## 書く紙を1枚出す。幕を張るので、窓ではなくこの層の上に置く。
func _open_write() -> void:
	if world == null or world.board == null:
		return
	# 紙が飛び出す元は、**書いた紙のあった場所**——画面の真ん中。
	# 行き先と重なることがあるが、軌跡の側で読ませる（`paper_fly.gd`）。
	_write_from = get_viewport().get_visible_rect().size * 0.5
	var pop = preload("res://scripts/ui/write_popup.gd").new()
	# 差出人不明になることは窓の「?」が言っている。欄に書き添えると2回言うことになる
	pop.setup("神のお告げ", [{"label": "", "text": ""}], "貼る", true)
	add_child(pop)
	pop.submitted.connect(_submit_post)


## 押した瞬間に貼られると、神が紙を落とした感じにならない。
## 紙を世界へ放って、板に着いたところで貼られる（main が受ける）。
func _submit_post(values: PackedStringArray) -> void:
	if world == null or world.board == null or values.is_empty():
		return
	var text := String(values[0]).strip_edges()
	if text == "":
		return
	# **書いていた紙を取り上げてから窓を閉じる。** 別の紙を描いて飛ばすと、
	# 決めた瞬間にフォームが消えて別の形の紙が現れる（`write_popup.take_sheet`）
	var sheet: Control = null
	for c in get_children():
		if c is WritePopup:
			sheet = (c as WritePopup).take_sheet()
			break
	# 窓を閉じて、紙が板に着くところを世界の上で見せる
	_show_only(null)
	god_posted.emit(_write_from, text, sheet)


func _refresh_board() -> void:
	if _board_list == null:
		return
	# `queue_free` は次のフレームまで効かない。外さずに足すと、
	# 同じフレームで2度並べ直したときに紙が重なる（重なると地合いも二重に乗る）
	for c in _board_list.get_children():
		_board_list.remove_child(c)
		c.queue_free()
	if world == null or world.board == null:
		return
	if world.board.posts.is_empty():
		_board_list.add_child(UIKit.label("（まだ何も貼られていない）", UIKit.FS_NOTE, UIKit.TEXT_DIM))
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
	# 地合いの層は敷かない。**この紙はもう地合いのある紙の上に乗っている**ので、
	# 自分の粒は見えないのに、余白の帯だけ粒が乗らず縁が浮いて見える
	# （四角い層は器の内側の矩形にしか敷けない）

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.HAIR)
	paper.add_child(box)
	UIKit.wrapped(box, String(e["text"]))

	# 差出人と日付は紙の隅に小さく
	var foot := HBoxContainer.new()
	box.add_child(foot)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	var who := "差出人不明" if by_god else String(e["author_name"])
	foot.add_child(UIKit.label("%s　%s" % [_days_ago(int(e["day"])), who], UIKit.FS_NOTE,
		Color(0.46, 0.41, 0.34, 0.85)))


## 貼られてからの古さ。「3日目」だと、いまが何日目かを覚えていないと古さが読めない。
func _days_ago(day: int) -> String:
	var d: int = SimClock.day - day
	if d <= 0:
		return "今日"
	if d == 1:
		return "昨日"
	return "%d日前" % d
