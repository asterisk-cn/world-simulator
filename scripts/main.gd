extends Node2D
## 起動処理。世界を作り、村人を置き、カメラと UI を繋ぐ。

var world: World
var camera: Camera2D
var modulate_node: CanvasModulate
var hud = null

## 神の紙を置く層。世界の日夜の色を受けない（`_setup_ui`）
var god_layer: CanvasLayer = null
var inspector = null
var selected = null

## いま見ている建物。村人と同時には選べない（見ているものは1つ）
var selected_building: Structure = null

var rules_panel = null
var started := false

var _panning := false
var _cam_tween: Tween

## 世界の目覚め。0＝まだ言葉を持たない青、1＝動いている世界
var wake := 0.0
var _starting := false
var _ending := false
var _next_id := 1


func _ready() -> void:
	randomize()
	_setup_font()

	world = World.new()
	world.name = "World"
	add_child(world)

	modulate_node = CanvasModulate.new()
	add_child(modulate_node)

	# 島の外側も世界の一部として扱う
	var sky = preload("res://scripts/world/sky.gd").new()
	sky.name = "Sky"
	add_child(sky)

	_setup_camera()
	_setup_ui()

	SimClock.night_started.connect(_on_night)

	# 開始前は世界を止めて、定義だけを編集できるようにしておく
	SimClock.paused = true
	rules_panel.set_editable(true)
	_show_setup(true)

	# ヘッドレス観察用。既定の定義のまま即座に始める（儀式は飛ばす）
	if OS.get_cmdline_user_args().has("--autostart"):
		wake = 1.0
		_start_world.call_deferred()



## 「この世界を始める」を押してから、実際に時間が動き出すまでの一拍。
##
## 確認のダイアログは挟まない（「間違えないか」の話になってしまう）。
## 紙に封蝋が押され、青く沈んでいた世界が目を覚ます、それだけを見せる。
func _begin_ritual() -> void:
	if started or _starting:
		return
	_starting = true

	var seal = preload("res://scripts/ui/seal.gd").new()
	seal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(seal)

	var tw := create_tween()
	tw.tween_property(seal, "pop", 1.0, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.30)
	tw.tween_property(rules_panel, "modulate:a", 0.0, 0.40)
	tw.parallel().tween_property(seal, "modulate:a", 0.0, 0.55)
	tw.tween_callback(_start_world)
	# 世界が目を覚ます。青く沈めていた色をここで解く
	tw.tween_property(self, "wake", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(seal.queue_free)


## 定義が確定したら村人を置いて世界を動かす。以降、定義は閲覧のみ。
func _start_world() -> void:
	if started:
		return
	started = true
	_show_setup(false)
	rules_panel.modulate.a = 1.0  # 儀式で薄くした紙は、閲覧用の窓として戻ってくる
	rules_panel.set_editable(false)
	_spawn_villagers()
	SimClock.paused = false
	EventLog.add("村が始まった。%d人。" % world.villagers.size(), Color(0.30, 0.36, 0.52))


## 取り返しがつかないので、終える前に一度だけ訊く。
## 訊いているあいだは時間を止める。答える前に村が変わってしまうのはおかしい。
func _ask_end() -> void:
	if not started or _ending:
		return
	var was_paused := SimClock.paused
	SimClock.paused = true
	var ask = preload("res://scripts/ui/confirm_popup.gd").new()
	ask.setup("本当に終了しますか？",
		"この村はここで終わり、設計図のところへ戻る。記録も関係も残らない。", "終了する")
	# 実行中に足す面なので、テーマは自分で持たせる（CanvasLayer は伝えてくれない）
	ask.theme = SimConfig.ui_theme
	hud.add_child(ask)
	ask.confirmed.connect(_end_ritual)
	ask.canceled.connect(func() -> void: SimClock.paused = was_paused)


## 「この世界を終える」を押してから、言葉のところへ戻るまでの一拍。
##
## 始める一拍の逆をたどる。時間が止まり、目を覚ましていた世界が青へ沈み、
## 決めた言葉の紙が戻ってくる。
func _end_ritual() -> void:
	if not started or _ending:
		return
	_ending = true
	SimClock.paused = true
	hud.close_panels()
	_select(null)

	var tw := create_tween()
	tw.tween_property(self, "wake", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_reset_world)
	tw.tween_property(rules_panel, "modulate:a", 1.0, 0.45)


## 村を畳んで、言葉のところへ戻す。島も資源も新しくなる。
## 神が決めた言葉と顔ぶれ（Schema）はそのまま残るので、書き足してまた始められる。
func _reset_world() -> void:
	started = false
	_starting = false
	_ending = false
	_next_id = 1

	world.regenerate()
	hud.on_world_reset()
	EventLog.clear()
	SimClock.reset()
	camera.position = Iso.cell_to_world(Vector2(World.GRID_W / 2.0, World.GRID_H / 2.0))
	camera.zoom = Vector2(0.85, 0.85)

	rules_panel.modulate.a = 0.0
	rules_panel.set_editable(true)
	_show_setup(true)


## セットアップ中は定義パネルを大きく中央に出し、他の面を隠す
func _show_setup(on: bool) -> void:
	rules_panel.visible = on
	if on:
		rules_panel.set_anchors_preset(Control.PRESET_CENTER)
		rules_panel.offset_left = -360
		rules_panel.offset_right = 360
		rules_panel.offset_top = -400
		rules_panel.offset_bottom = 400
	else:
		rules_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		rules_panel.offset_left = 12
		rules_panel.offset_right = 576
		rules_panel.offset_top = 88
		rules_panel.offset_bottom = 800
	hud.set_play_ui_visible(not on)


func _setup_font() -> void:
	var sf := SystemFont.new()
	# 角丸のブロックと紙の世界なので、字も丸みのあるものを先に探す
	sf.font_names = PackedStringArray([
		"Hiragino Maru Gothic ProN", "Hiragino Maru Gothic Pro",
		"YuGothic", "Hiragino Sans", "Noto Sans CJK JP", "Meiryo", "Sans-Serif",
	])
	sf.allow_system_fallback = true
	SimConfig.ui_font = sf

	SimConfig.ui_theme = UIKit.build_theme(sf)
	get_window().theme = SimConfig.ui_theme


## 開始前に「ひと」で決めた顔ぶれを、そのまま世界へ置く。
func _spawn_villagers() -> void:
	var center := Vector2(World.GRID_W / 2.0, World.GRID_H / 2.0)
	var n: int = Schema.villagers.size()
	for i in range(n):
		var h: Dictionary = Schema.villagers[i]
		var a := TAU * float(i) / float(maxi(n, 1))
		var c := center + Vector2(cos(a), sin(a)) * randf_range(3.0, 6.0)
		c.x = clampf(c.x, 1.0, World.GRID_W - 2.0)
		c.y = clampf(c.y, 1.0, World.GRID_H - 2.0)

		var v := Villager.new()
		v.setup(world, _next_id, String(h["name"]), Color(h["color"]), c)
		v.personality.quirk = String(h["quirk"])
		for key in h["axes"]:
			v.personality.set_axis(String(key), float(h["axes"][key]))
		for item in h["items"]:
			v.add_item(String(item), int(h["items"][item]))
		_next_id += 1
		world.register_villager(v)


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.position = Iso.cell_to_world(Vector2(World.GRID_W / 2.0, World.GRID_H / 2.0))
	camera.zoom = Vector2(0.85, 0.85)
	add_child(camera)
	camera.make_current()


func _setup_ui() -> void:
	# **神の紙は世界の光の下にない。** 世界に置くと日夜の色（`modulate_node`）が
	# 乗って、飛んでいる紙が青くなる。層を分けて、位置だけ世界に合わせる
	# （`_process` で `transform` にカメラの写しを入れる）。
	# HUD より先に足すので、上部バーは紙の上に残る
	god_layer = CanvasLayer.new()
	add_child(god_layer)

	hud = preload("res://scripts/ui/hud.gd").new()
	add_child(hud)
	hud.setup(world)
	hud.jump_requested.connect(_on_jump)
	hud.god_posted.connect(_on_god_posted)

	inspector = preload("res://scripts/ui/inspector.gd").new()
	inspector.world = world
	inspector.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	inspector.offset_left = -396
	inspector.offset_right = -12
	inspector.offset_top = 12
	inspector.offset_bottom = -12
	hud.add_child(inspector)
	inspector.select_requested.connect(func(v) -> void: _select(v, true))

	var roster = preload("res://scripts/ui/roster_panel.gd").new()
	roster.world = world
	roster.set_anchors_preset(Control.PRESET_TOP_LEFT)
	roster.offset_left = 12
	# 持ち物の列に名前が入るので、品目が増えても「いま何をしているか」が潰れない幅
	roster.offset_right = 620
	roster.offset_top = 88
	roster.offset_bottom = 540
	roster.visible = false
	hud.add_child(roster)
	hud.roster_panel = roster
	roster.closed.connect(hud.close_panels)
	roster.select_requested.connect(func(v) -> void: _select(v, true))

	var matrix = preload("res://scripts/ui/matrix_panel.gd").new()
	matrix.world = world
	matrix.set_anchors_preset(Control.PRESET_TOP_LEFT)
	matrix.offset_left = 12
	matrix.offset_right = 716
	matrix.offset_top = 88
	matrix.offset_bottom = 82
	matrix.closed.connect(hud.close_panels)
	# 表のマスは個人UIへの入口。値はあちらで読ませる（表は眺めるための面）
	matrix.pair_requested.connect(func(from_id: int, to_id: int) -> void:
		var v = world.villager_by_id(from_id)
		if v == null:
			return
		_select(v, true)
		inspector.focus_pair(to_id))
	matrix.visible = false
	hud.add_child(matrix)
	hud.matrix_panel = matrix

	var rules = preload("res://scripts/ui/rules_panel.gd").new()
	rules.world = world
	rules.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	rules.offset_left = 12
	rules.offset_right = 560
	rules.offset_top = -380
	rules.offset_bottom = 380
	var dbg = preload("res://scripts/ui/debug_panel.gd").new()
	dbg.world = world
	dbg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dbg.offset_left = 12
	dbg.offset_right = 452
	dbg.offset_top = 88
	# 丈は中身が決める。枠を先に決めると、下に用のない余白が残る
	dbg.offset_bottom = 88
	dbg.closed.connect(hud.close_panels)
	dbg.visible = false
	hud.add_child(dbg)
	hud.debug_panel = dbg

	var opt = preload("res://scripts/ui/option_panel.gd").new()
	opt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	opt.offset_left = 12
	opt.offset_right = 540
	opt.offset_top = 88
	opt.offset_bottom = 88
	opt.closed.connect(hud.close_panels)
	opt.end_requested.connect(_ask_end)
	opt.visible = false
	hud.add_child(opt)
	hud.option_panel = opt

	hud.add_child(rules)
	hud.rules_panel = rules
	rules_panel = rules
	rules.started.connect(_begin_ritual)
	rules.closed.connect(hud.close_panels)

	# CanvasLayer は Control ではないのでテーマが伝わらない。各パネルに直接あてる。
	for c in hud.get_children():
		if c is Control:
			(c as Control).theme = SimConfig.ui_theme


func _process(_delta: float) -> void:
	# 神の紙の層は、位置だけ世界に合わせる（色は受けない）
	if god_layer != null:
		god_layer.transform = get_canvas_transform()

	# 夜は「暗い昼」ではなく色を青紫へ寄せる。暗くしすぎると角丸ブロックの色が濁る
	var d := SimClock.darkness()
	var night := Color(0.30, 0.36, 0.72)
	modulate_node.color = Color.WHITE.lerp(night, d * 0.82)

	# 始まる前の世界は、まだ言葉を持たない場所として沈めておく
	if wake < 1.0:
		modulate_node.color = modulate_node.color.lerp(Color(0.44, 0.48, 0.62), 1.0 - wake)

	# 紙のUIは夜でも明るいままだと、観察したい世界より前に出てしまう。
	# 透明度はその部品自身のもの（儀式の淡出しなど）なので触らない。
	var dim := Color.WHITE.lerp(Color(0.80, 0.81, 0.88), d)
	for c in hud.get_children():
		if c is Control:
			var ctl := c as Control
			ctl.modulate = Color(dim.r, dim.g, dim.b, ctl.modulate.a)


func _on_night(_day: int) -> void:
	for v in world.villagers:
		v.on_night()
	EventLog.add("夜になった。村人たちは記憶を整理している。", Color(0.30, 0.36, 0.58))


# ---------------------------------------------------------------------------
# 入力
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom(1.12)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom(1.0 / 1.12)
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_panning = event.pressed
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_try_select(get_global_mouse_position())

	elif event is InputEventMouseMotion:
		if _panning:
			camera.position -= event.relative / camera.zoom.x
		else:
			_hover_at(get_global_mouse_position())

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			SimClock.paused = not SimClock.paused


func _zoom(f: float) -> void:
	var z := clampf(camera.zoom.x * f, 0.35, 3.0)
	camera.zoom = Vector2(z, z)


func _try_select(world_pos: Vector2) -> void:
	# 掲示板は神が触れる唯一の場所なので、村人より先に拾う
	if world.board != null:
		var bp: Vector2 = world.board.position + Vector2(0, -30)
		if world_pos.distance_to(bp) < 46.0:
			hud.open_board()
			return

	var v = _villager_at(world_pos)
	if v != null:
		_select(v)
		return
	# 村人が居なければ建物。**建物にも寄れる**（記録の行から飛ぶ先になる）
	_select_building(world.building_at(_cell_at(world_pos)))


func _cell_at(world_pos: Vector2) -> Vector2i:
	var c := Iso.world_to_cell(world_pos)
	return Vector2i(roundi(c.x), roundi(c.y))


func _villager_at(world_pos: Vector2):
	var best = null
	var best_d := 40.0
	for v in world.villagers:
		var p: Vector2 = v.position
		# 体は足元より上に伸びているので、当たり判定も上にずらす
		var d := world_pos.distance_to(p + Vector2(0, -22))
		if d < best_d:
			best_d = d
			best = v
	return best


## カーソルの下のものに名前を出させる。**名前は常には出ていない。**
func _hover_at(world_pos: Vector2) -> void:
	var v = _villager_at(world_pos)
	var s: Structure = null
	if v == null:
		s = world.building_at(_cell_at(world_pos))
	for other in world.villagers:
		other.hovered = other == v
	for st in world.structures:
		st.hovered = st == s


## 一覧や関係の表から選んだときは、世界の側でもその村人へ寄る。
## パネルの数字と世界の姿が繋がらないと、観察する遊びの回路が切れる。
func _select(v, focus: bool = false) -> void:
	if selected != null and is_instance_valid(selected):
		selected.selected = false
	selected = v
	if selected != null:
		selected.selected = true
		if focus:
			_focus_on(selected)
	if v != null:
		_select_building(null)
	inspector.set_subject(selected)


## 建物を選ぶ。**出るのは名前だけ**——建物は中に値を持たないので、
## インスペクタに出すものが無い。輪と札で「これを見ている」だけを言う。
func _select_building(s: Structure, focus: bool = false) -> void:
	if selected_building != null and is_instance_valid(selected_building):
		selected_building.selected = false
	selected_building = s
	if s != null:
		s.selected = true
		if focus:
			_focus_at(s.position)
		# 村人と建物は同時に選べない。見ているものは1つ
		_select(null)


## 記録の中の名前から、その名前のものへ。
## 村人なら選んで寄り、建物なら選んで寄り、掲示板なら板を開く。
func _on_jump(target: String) -> void:
	if target == "board":
		if world.board != null:
			_focus_at(world.board.position)
		hud.open_board()
		return
	var parts := target.split(":")
	if parts.size() != 2:
		return
	var tid := int(parts[1])
	if parts[0] == "v":
		var v = world.villager_by_id(tid)
		if v != null:
			_select(v, true)
	elif parts[0] == "s":
		for s in world.structures:
			if s.id == tid:
				_select_building(s, true)
				return


## 神が放った紙を世界へ飛ばす。板に着いたところで初めて貼られる。
func _on_god_posted(from_screen: Vector2, text: String, sheet: Control) -> void:
	if world.board == null:
		return
	var paper = preload("res://scripts/world/paper_fly.gd").new()
	god_layer.add_child(paper)
	# 板の中心ではなく、**その紙が実際に貼られる枡**へ落とす
	var to: Vector2 = world.board.position + world.board.next_slip_point()
	# 書いていた紙そのものを運ばせる（`ui/write_popup.gd` の `take_sheet`）
	# 画面の高さを世界の尺で渡す。紙はこれを使って画面の外まで抜ける
	var reach: float = get_viewport_rect().size.y / maxf(camera.zoom.y, 0.01)
	paper.setup(get_canvas_transform().affine_inverse() * from_screen, to, sheet, reach)
	# **降りに入ったら世界のものになる。** 上がるあいだは神の手のものなので
	# 世界の光を受けないが、空から降りてくる紙は受けたほうが世界に居て見える
	paper.entered_world.connect(func() -> void:
		var at: Vector2 = paper.position
		god_layer.remove_child(paper)
		add_child(paper)
		paper.position = at)
	paper.landed.connect(func() -> void:
		world.board.post(-1, "差出人不明", text))


func _focus_on(v) -> void:
	_focus_at(v.position)


func _focus_at(at: Vector2) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(camera, "position", at, 0.45)
