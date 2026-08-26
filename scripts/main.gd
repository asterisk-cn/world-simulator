extends Node2D
## 起動処理。世界を作り、村人を置き、カメラと UI を繋ぐ。

const VILLAGER_COUNT := 8

const NAMES := ["ハル", "ミナ", "ソウ", "リク", "ノア", "カイ", "ユキ", "トウ", "レン", "サキ", "ジン", "アオ"]

const PALETTE := [
	Color(0.90, 0.45, 0.40), Color(0.40, 0.65, 0.92), Color(0.55, 0.80, 0.45),
	Color(0.93, 0.75, 0.35), Color(0.72, 0.55, 0.92), Color(0.40, 0.82, 0.80),
	Color(0.92, 0.58, 0.75), Color(0.65, 0.70, 0.45), Color(0.85, 0.60, 0.35),
	Color(0.50, 0.55, 0.85), Color(0.70, 0.85, 0.60), Color(0.88, 0.50, 0.55),
]

var world: World
var camera: Camera2D
var modulate_node: CanvasModulate
var hud = null
var inspector = null
var selected = null

var rules_panel = null
var started := false

var _panning := false
var _next_id := 1


func _ready() -> void:
	randomize()
	_setup_font()

	world = World.new()
	world.name = "World"
	add_child(world)

	modulate_node = CanvasModulate.new()
	add_child(modulate_node)

	_setup_camera()
	_setup_ui()

	SimClock.night_started.connect(_on_night)

	# 開始前は世界を止めて、定義だけを編集できるようにしておく
	SimClock.paused = true
	rules_panel.set_editable(true)
	_show_setup(true)

	# ヘッドレス観察用。既定の定義のまま即座に始める
	if OS.get_cmdline_user_args().has("--autostart"):
		_start_world.call_deferred()


## 定義が確定したら村人を置いて世界を動かす。以降、定義は閲覧のみ。
func _start_world() -> void:
	if started:
		return
	started = true
	_show_setup(false)
	rules_panel.set_editable(false)
	_spawn_villagers()
	SimClock.paused = false
	EventLog.add("村が始まった。%d人。" % VILLAGER_COUNT, Color(0.8, 0.9, 1.0))


## セットアップ中は定義パネルを大きく中央に出し、他の面を隠す
func _show_setup(on: bool) -> void:
	rules_panel.visible = on
	if on:
		rules_panel.set_anchors_preset(Control.PRESET_CENTER)
		rules_panel.offset_left = -270
		rules_panel.offset_right = 270
		rules_panel.offset_top = -360
		rules_panel.offset_bottom = 360
	else:
		rules_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		rules_panel.offset_left = 12
		rules_panel.offset_right = 484
		rules_panel.offset_top = -330
		rules_panel.offset_bottom = 330
	hud.set_play_ui_visible(not on)


func _setup_font() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Hiragino Sans", "Hiragino Kaku Gothic ProN", "Yu Gothic",
		"Noto Sans CJK JP", "Meiryo", "Sans-Serif",
	])
	sf.allow_system_fallback = true
	SimConfig.ui_font = sf

	var th := Theme.new()
	th.default_font = sf
	th.default_font_size = 12
	get_window().theme = th


func _spawn_villagers() -> void:
	var center := Vector2(World.GRID_W / 2.0, World.GRID_H / 2.0)
	for i in range(VILLAGER_COUNT):
		var a := TAU * float(i) / float(VILLAGER_COUNT)
		var c := center + Vector2(cos(a), sin(a)) * randf_range(3.0, 6.0)
		c.x = clampf(c.x, 1.0, World.GRID_W - 2.0)
		c.y = clampf(c.y, 1.0, World.GRID_H - 2.0)

		var v := Villager.new()
		v.setup(world, _next_id, NAMES[i % NAMES.size()], PALETTE[i % PALETTE.size()], c)
		v.inventory["food"] = randi_range(0, 2)
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

	inspector = preload("res://scripts/ui/inspector.gd").new()
	inspector.world = world
	inspector.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	inspector.offset_left = -346
	inspector.offset_right = -12
	inspector.offset_top = 12
	inspector.offset_bottom = -12
	hud.add_child(inspector)

	var matrix = preload("res://scripts/ui/matrix_panel.gd").new()
	matrix.world = world
	matrix.set_anchors_preset(Control.PRESET_CENTER_TOP)
	matrix.offset_left = -300
	matrix.offset_right = 300
	matrix.offset_top = 64
	matrix.offset_bottom = 500
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
	dbg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dbg.offset_left = -700
	dbg.offset_right = -360
	dbg.offset_top = 64
	dbg.offset_bottom = 320
	dbg.visible = false
	hud.add_child(dbg)
	hud.debug_panel = dbg

	hud.add_child(rules)
	hud.rules_panel = rules
	rules_panel = rules
	rules.started.connect(_start_world)


func _process(_delta: float) -> void:
	var d := SimClock.darkness()
	var night := Color(0.34, 0.40, 0.62)
	modulate_node.color = Color.WHITE.lerp(night, d * 0.85)


func _on_night(_day: int) -> void:
	for v in world.villagers:
		v.on_night()
	EventLog.add("夜になった。村人たちは記憶を整理している。", Color(0.6, 0.7, 0.95))


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


func _select(v) -> void:
	if selected != null and is_instance_valid(selected):
		selected.selected = false
	selected = v
	if selected != null:
		selected.selected = true
	inspector.set_subject(selected)
