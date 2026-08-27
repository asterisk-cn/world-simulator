extends Node2D
## 起動処理。世界を作り、村人を置き、カメラと UI を繋ぐ。

var world: World
var camera: Camera2D
var modulate_node: CanvasModulate
var hud = null
var inspector = null
var selected = null

var rules_panel = null
var started := false

var _panning := false
var _cam_tween: Tween

## 世界の目覚め。0＝まだ言葉を持たない青、1＝動いている世界
var wake := 0.0
var _starting := false
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


## セットアップ中は定義パネルを大きく中央に出し、他の面を隠す
func _show_setup(on: bool) -> void:
	rules_panel.visible = on
	if on:
		rules_panel.set_anchors_preset(Control.PRESET_CENTER)
		rules_panel.offset_left = -310
		rules_panel.offset_right = 310
		rules_panel.offset_top = -360
		rules_panel.offset_bottom = 360
	else:
		rules_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		rules_panel.offset_left = 12
		rules_panel.offset_right = 500
		rules_panel.offset_top = 78
		rules_panel.offset_bottom = 714
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
	hud = preload("res://scripts/ui/hud.gd").new()
	add_child(hud)
	hud.setup(world)
	hud.jump_requested.connect(_on_jump)
	hud.god_posted.connect(_on_god_posted)

	inspector = preload("res://scripts/ui/inspector.gd").new()
	inspector.world = world
	inspector.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	inspector.offset_left = -346
	inspector.offset_right = -12
	inspector.offset_top = 12
	inspector.offset_bottom = -12
	hud.add_child(inspector)
	inspector.select_requested.connect(func(v) -> void: _select(v, true))

	var roster = preload("res://scripts/ui/roster_panel.gd").new()
	roster.world = world
	roster.set_anchors_preset(Control.PRESET_TOP_LEFT)
	roster.offset_left = 12
	roster.offset_right = 452
	roster.offset_top = 78
	roster.offset_bottom = 474
	roster.visible = false
	hud.add_child(roster)
	hud.roster_panel = roster
	roster.closed.connect(hud.close_panels)
	roster.select_requested.connect(func(v) -> void: _select(v, true))

	var matrix = preload("res://scripts/ui/matrix_panel.gd").new()
	matrix.world = world
	matrix.set_anchors_preset(Control.PRESET_TOP_LEFT)
	matrix.offset_left = 12
	matrix.offset_right = 620
	matrix.offset_top = 78
	matrix.offset_bottom = 72
	matrix.closed.connect(hud.close_panels)
	matrix.visible = false
	hud.add_child(matrix)
	hud.matrix_panel = matrix

	var rules = preload("res://scripts/ui/rules_panel.gd").new()
	rules.world = world
	rules.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	rules.offset_left = 12
	rules.offset_right = 484
	rules.offset_top = -330
	rules.offset_bottom = 330
	var dbg = preload("res://scripts/ui/debug_panel.gd").new()
	dbg.world = world
	dbg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dbg.offset_left = 12
	dbg.offset_right = 392
	dbg.offset_top = 78
	dbg.offset_bottom = 394
	dbg.closed.connect(hud.close_panels)
	dbg.visible = false
	hud.add_child(dbg)
	hud.debug_panel = dbg

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

	elif event is InputEventMouseMotion and _panning:
		camera.position -= event.relative / camera.zoom.x

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

	var best = null
	var best_d := 40.0
	for v in world.villagers:
		var p: Vector2 = v.position
		# 体は足元より上に伸びているので、当たり判定も上にずらす
		var d := world_pos.distance_to(p + Vector2(0, -22))
		if d < best_d:
			best_d = d
			best = v
	_select(best)


## 一覧や間柄から選んだときは、世界の側でもその村人へ寄る。
## パネルの数字と世界の姿が繋がらないと、観察する遊びの回路が切れる。
func _select(v, focus: bool = false) -> void:
	if selected != null and is_instance_valid(selected):
		selected.selected = false
	selected = v
	if selected != null:
		selected.selected = true
		if focus:
			_focus_on(selected)
	inspector.set_subject(selected)


## 記録の行から、その出来事が起きた場所へ。
## 相手が分かっていればその村人を選び、場所しか無ければそこへ寄る。
func _on_jump(at: Vector2, who: int) -> void:
	if who >= 0:
		var v = world.villager_by_id(who)
		if v != null:
			_select(v, true)
			return
	if at.x != INF:
		_focus_at(at)


## 神が放った紙を世界へ飛ばす。板に着いたところで初めて貼られる。
func _on_god_posted(from_screen: Vector2, text: String) -> void:
	if world.board == null:
		return
	var paper = preload("res://scripts/world/paper_fly.gd").new()
	add_child(paper)
	var to: Vector2 = world.board.position + Vector2(0, -26)
	paper.setup(get_canvas_transform().affine_inverse() * from_screen, to)
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
