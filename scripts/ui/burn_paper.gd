class_name BurnPaper
extends Control
## 紙が下から焼けていく。世界を始める儀式（`main._begin_ritual`）で使う。
##
## 封蝋を押していたのをやめて、これにした。神が書いた言葉が焼けて、
## その下から世界が現れる——押した印より、書いたものが消える絵のほうが強い。
##
## ---------------------------------------------------------------------------
## **焼け口そのものを波打たせる。**
##
## `clip_contents`（矩形の切り取り）でやると、紙が消える境界が幅いっぱいの
## 完全な水平直線になる。焦げでどれだけ飾っても、直線は直線として読めてしまう。
##
## 代わりに `clip_children = CLIP_CHILDREN_ONLY` を使う。これは親が**描いた形**で
## 子をマスクするので、`_clip` に「まだ焼けていない紙の形」——上は矩形、
## 下端は波打った形——を描かせれば、切り取り線が波になる。
##
## 火は下から上へ。実際の紙もそう燃えるし、切り取りの下端を上げるだけなので
## 中の紙を動かさずに済む（上へずらすと、燃えるのではなく巻き上がって見える）。
##
## **層は下から順に「炎 → 焦げ → 熱 → 褐色 → 紙」。** 赤がいちばん下に来る。
## 赤を焦げの上（紙の側）に置くと上下が逆になって、火ではなく夕焼けの帯に見える。
##
## 帯は列に刻んで塗るが、**上下の縁は両端の値を渡して台形で繋ぐ**。
## 左右で高さを共通にすると、乱れが列ごとに飛んで縁が階段になる。
## ---------------------------------------------------------------------------

## 0 = まだ焼けていない、1 = 焼け落ちた
var burn := 0.0:
	set(v):
		burn = clampf(v, 0.0, 1.0)
		_lay()
		if _ink != null:
			_ink.queue_redraw()
		if _clip != null:
			_clip.queue_redraw()

# ---------------------------------------------------------------------------
# 焼け口の形。低い波と細かい乱れを重ねる。
# 低い波だけだと布の裾に見え、細かい乱れだけだと直線にギザギザを付けただけに見える。
# ---------------------------------------------------------------------------
const WAVE := 14.0        ## 低い波の振れ（px）
const WAVE_LEN := 125.0   ## 低い波の波長（px）
const COL := 9.0          ## 列の幅。マスクと帯をこの幅で刻む
const RAG := 6.0          ## 列ごとの細かい乱れの深さ

## 波の振れの合計（`WAVE + WAVE*0.6 + RAG` ＝ 28.4）に少し足した値。
## 焼け口の行程をこのぶん外へ延ばす——**延ばさないと `burn = 1` でも
## 山の列に紙が残る**（基準線が 0 のとき、山は紙の側にある）
const MARGIN := 30.0

# ---------------------------------------------------------------------------
# 色。**いちばん強いのは炎**だが、面は狭く保つ。
# 熱の帯は面が広いので、神の橙 (0.86, 0.52, 0.18) の家系に寄せる——
# ここが橙より強いと、世界でいちばん強い面が「焼け」になってしまう。
# ---------------------------------------------------------------------------

## 焦げ。**真っ黒にはしない**——この作品でいちばん暗いのは島の外周
## (0.15, 0.18, 0.15) で、それより濃い面を作ると絵から浮く
const CHAR := Color(0.24, 0.19, 0.15)

## 炎。焦げのいちばん下
const EMBER := Color(0.96, 0.45, 0.10)

## 紙を透かして灼ける熱。焦げのすぐ上に薄くだけ
const GLOW := Color(0.93, 0.55, 0.22)

## 焦げる手前の褐色
const SCORCH := Color(0.55, 0.36, 0.18)

## 焦げの厚み。**紙に対して細く**——分厚いと焼け口ではなく炭の山脈に見える。
##
## **濃いのは芯だけ。** 帯を丸ごと濃くすると、絵の中でいちばん重い面が
## 「焼け」になる。芯は切り取りの境界を埋めるだけの細さに留めて
## （ここが薄いと紙の切り口が1本の線として出る）、上下へは薄れながら伸ばす。
const CHAR_A := 0.86        ## 芯の濃さ。切り口を隠すのに要るぶんだけ
const CHAR_CORE := 2.0      ## 芯が紙の側へ食い込む厚み
const CHAR_CORE_DOWN := 2.5 ## 芯が焼け落ちた側へ垂れる厚み
const CHAR_UP := 7.0        ## 芯の上へ、薄れながら伸びる厚み
const CHAR_DOWN := 4.0      ## 芯の下へ、炎に溶けながら伸びる厚み
const CHAR_BANDS := 3

## 炎は**細く、明るく**。同じ重さを面に広げると、火ではなく汚れた縁になる——
## 焼け落ちた側は島（暗い緑）なので、薄い橙を広く敷くと濁った緑に転ぶ
const FLAME_H := 9.0      ## 炎の丈。焦げの下へ垂れる
const FLAME_A := 0.72
const FLAME_BANDS := 4

## 熱はここを厚くすると、火が紙の上側にあるように見える
const GLOW_H := 11.0
const GLOW_A := 0.26
const GLOW_BANDS := 3

const SCORCH_H := 16.0
const SCORCH_A := 0.17
const SCORCH_BANDS := 3   ## 褐色も刻む。1枚だと紙との境がもう1本の波線に見える

const ASH := 20           ## 火の粉
const ASH_RISE := 130.0


var _clip: Control = null

## 焦げを描く面。**節点は自分の絵を子より下に描く**ので、
## ここに分けないと焦げが紙の裏に隠れる
var _ink: Control = null

var _sheet: Control = null
var _full := 0.0      ## 焼ける前の紙の丈
var _seed := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed = randf() * 100.0

	_clip = Control.new()
	_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_clip.draw.connect(_draw_mask)

	_ink = Control.new()
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ink)
	_ink.draw.connect(_draw_burn)


## 紙を預かる。以降この節点が紙の置き場になるので、
## 位置ぎめ（`main._show_setup`）はこちらに向ける
func hold(sheet: Control) -> void:
	_sheet = sheet
	if sheet.get_parent() != null:
		sheet.get_parent().remove_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip.add_child(sheet)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_lay()
		if _ink != null:
			_ink.queue_redraw()
		if _clip != null:
			_clip.queue_redraw()


func _lay() -> void:
	if _clip == null:
		return
	if burn <= 0.0:
		# まだ焼けていない。マスクは要らないので普通の入れ物に戻す
		_clip.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		_clip.visible = true
		_full = size.y
	elif burn >= 1.0:
		# **焼け切ったら器ごと隠す。** マスクが空になると「切り取らない」として
		# 扱われて、子が素通しになる——紙が丸ごと戻ってしまう
		_clip.visible = false
	else:
		# 親が描いた形で子を切り取る（親自身は描かれない）
		_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		_clip.visible = true


## 位置から決まる乱れ。毎フレーム同じ形になる
func _jag(i: float) -> float:
	var h := sin(i * 12.9898 + _seed * 78.233) * 43758.5453
	return h - floor(h)


## 列のあいだを繋いだ乱れ。**列ごとに一定の値を使うと帯の縁が階段になる**
func _wob(x: float) -> float:
	var i: float = floor(x / COL)
	var t: float = x / COL - i
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(_jag(i * COL), _jag((i + 1.0) * COL), t)


## 焼け口の高さ。**列ごとに違う**——ここが波打つことで、
## 紙が消える境界そのものが波になる
func _fire_y(x: float) -> float:
	# 行程を波のぶん外へ延ばす（上の `MARGIN`）。
	# `burn = 0` で谷が紙の下端より下、`burn = 1` で山が上端より上に出る
	var base: float = (_full + MARGIN) * (1.0 - burn) - MARGIN
	# 波は `burn` で少しずらす。止まった波形は型押しに見える
	var low := sin(x * TAU / WAVE_LEN + burn * 3.4) * WAVE
	var slow := sin(x * TAU / (WAVE_LEN * 2.7) - burn * 2.1) * WAVE * 0.6
	var fine := (_wob(x) - 0.5) * 2.0 * RAG
	return base + low + slow + fine


## その列がどれだけ先に進んでいるか（0.35〜1）。山ほど明るく灼ける
func _ahead(x: float) -> float:
	var base: float = (_full + MARGIN) * (1.0 - burn) - MARGIN
	var d := (base - _fire_y(x)) / (WAVE * 1.6)
	return 0.35 + 0.65 * clampf(d * 0.5 + 0.5, 0.0, 1.0)


## 上下それぞれの縁が左右で違う四角を1枚塗る。
## **高さを左右で共通にすると縁が階段になる**——乱れは列ごとに違うので、
## 上も下も両端の値を渡して台形で繋ぐ
func _quad(x: float, w: float, tl: float, tr: float, bl: float, br: float,
		col: Color) -> void:
	if maxf(bl, br) <= 0.0:
		return
	_ink.draw_colored_polygon(PackedVector2Array([
		Vector2(x, maxf(tl, 0.0)), Vector2(x + w, maxf(tr, 0.0)),
		Vector2(x + w, maxf(br, 0.0)), Vector2(x, maxf(bl, 0.0)),
	]), col)


## まだ焼けていない紙の形。これが切り取りのマスクになる。
## 列ごとの**台形**で塗る——四角で刻むと段々になって階段に見える
func _draw_mask() -> void:
	if burn <= 0.0:
		return
	var x := 0.0
	while x < size.x:
		var w: float = minf(COL, size.x - x)
		var y0: float = maxf(_fire_y(x), 0.0)
		var y1: float = maxf(_fire_y(x + w), 0.0)
		if y0 > 0.0 or y1 > 0.0:
			_clip.draw_colored_polygon(PackedVector2Array([
				Vector2(x, 0.0), Vector2(x + w, 0.0),
				Vector2(x + w, y1), Vector2(x, y0),
			]), Color.WHITE)
		x += w


func _draw_burn() -> void:
	if burn <= 0.0 or burn >= 1.0:
		return
	var x := 0.0
	while x < size.x:
		var w: float = minf(COL, size.x - x)
		var yl := _fire_y(x)
		var yr := _fire_y(x + w)
		var lit := _ahead(x + w * 0.5)
		# 乱れは**両端で採る**。片方だけだと帯の縁が階段になる
		var cul := CHAR_CORE + _wob(x) * RAG * 0.25
		var cur := CHAR_CORE + _wob(x + w) * RAG * 0.25
		var cdl := CHAR_CORE_DOWN * (0.6 + _wob(x + 7.0) * 0.4)
		var cdr := CHAR_CORE_DOWN * (0.6 + _wob(x + w + 7.0) * 0.4)
		# 芯の上へ薄れながら伸びるぶん。ここが焦げの見かけの厚みになる
		var sul := CHAR_UP * (0.55 + 0.45 * _wob(x + 19.0))
		var sur := CHAR_UP * (0.55 + 0.45 * _wob(x + w + 19.0))
		var fhl := FLAME_H * (0.45 + 0.55 * _wob(x + 31.0))
		var fhr := FLAME_H * (0.45 + 0.55 * _wob(x + w + 31.0))
		# 焦げの上端。熱と褐色はここから上へ積む
		var tl := yl - cul - sul
		var tr := yr - cur - sur

		# 焦げる手前の褐色。焼ける前から紙は色を変える。
		# **上へ溶かす**——1枚のべた塗りだと、紙との境がもう1本の波線に見える
		for k in range(SCORCH_BANDS):
			var s0 := float(k) / float(SCORCH_BANDS)
			var s1 := float(k + 1) / float(SCORCH_BANDS)
			_quad(x, w,
				tl - GLOW_H - SCORCH_H * s1, tr - GLOW_H - SCORCH_H * s1,
				tl - GLOW_H - SCORCH_H * s0, tr - GLOW_H - SCORCH_H * s0,
				Color(SCORCH.r, SCORCH.g, SCORCH.b, SCORCH_A * (1.0 - s1) * lit))

		# 紙を透かして灼ける熱。焦げのすぐ上に薄くだけ
		for k in range(GLOW_BANDS):
			var a0 := float(k) / float(GLOW_BANDS)
			var a1 := float(k + 1) / float(GLOW_BANDS)
			_quad(x, w,
				tl - GLOW_H * a1, tr - GLOW_H * a1,
				tl - GLOW_H * a0, tr - GLOW_H * a0,
				Color(GLOW.r, GLOW.g, GLOW.b, GLOW_A * pow(1.0 - a1, 1.8) * lit))

		# 焦げ、紙の側へ。芯から離れるほど薄れて紙に溶ける
		for k in range(CHAR_BANDS):
			var u0 := float(k) / float(CHAR_BANDS)
			var u1 := float(k + 1) / float(CHAR_BANDS)
			_quad(x, w,
				yl - cul - sul * u1, yr - cur - sur * u1,
				yl - cul - sul * u0, yr - cur - sur * u0,
				Color(CHAR.r, CHAR.g, CHAR.b, CHAR_A * 0.8 * pow(1.0 - u1, 1.3)))

		# 焦げの芯。**焼け口を跨ぐ**ので、切り取りの境界が帯の中に埋まる。
		# **濃さは列で変えない**——形は滑らかでも濃さが列ごとに飛ぶと、
		# 列の境が縦の段として出る（むらは厚みの揺れが担う）
		_quad(x, w, yl - cul, yr - cur, yl + cdl, yr + cdr,
			Color(CHAR.r, CHAR.g, CHAR.b, CHAR_A))

		# 焦げ、焼け落ちた側へ。こちらは炎に溶ける
		for k in range(CHAR_BANDS):
			var d0 := float(k) / float(CHAR_BANDS)
			var d1 := float(k + 1) / float(CHAR_BANDS)
			_quad(x, w,
				yl + cdl + CHAR_DOWN * d0, yr + cdr + CHAR_DOWN * d0,
				yl + cdl + CHAR_DOWN * d1, yr + cdr + CHAR_DOWN * d1,
				Color(CHAR.r, CHAR.g, CHAR.b, CHAR_A * 0.7 * (1.0 - d1)))

		# 炎。**焦げの芯にくっつける**。薄れていく焦げのぶんだけ下げると、
		# そこは下地（島）が透けるので、火の筋が焦げから切り離れて見える
		for k in range(FLAME_BANDS):
			var b0 := float(k) / float(FLAME_BANDS)
			var b1 := float(k + 1) / float(FLAME_BANDS)
			_quad(x, w,
				yl + cdl + fhl * b0, yr + cdr + fhr * b0,
				yl + cdl + fhl * b1, yr + cdr + fhr * b1,
				Color(EMBER.r, EMBER.g, EMBER.b,
					FLAME_A * pow(1.0 - b1, 1.6) * (0.45 + 0.55 * lit)))
		x += w

	# 火の粉。**山から出す**——全幅にばらまくと火の位置と関係がなくなる。
	# 終いは昇らずに落ちる（灰が落ちた所から島が崩れる、へ繋ぐ）。
	# 落ちる粒は**数を絞って短く**——広くばらまくと、紙より広い範囲に
	# 焦げが散って、紙が燃えたのではなく何かが降ってきたように見える
	var falling := burn > 0.70
	for k in range(ASH):
		var f := float(k) / float(ASH)
		var life: float = clampf(burn * 2.2 - f, 0.0, 1.0)
		if life <= 0.0:
			continue
		var ax: float = fmod(_jag(f * 31.7 + 1.0) * size.x, size.x)
		ax += sin(ax * TAU / WAVE_LEN + burn * 3.4) * 18.0
		var up := ASH_RISE * (0.25 + 0.75 * _jag(f * 17.3 + 2.0))
		var ay: float = _fire_y(ax) - CHAR_UP - up * life
		if falling and f > 0.86:
			ay = _fire_y(ax) + up * life * 0.30   # 落ちる灰。近くに短く
		if ay <= 0.0:
			continue
		var r: float = 1.2 + 2.2 * _jag(f * 7.1 + 3.0)
		# 近いうちは赤く、離れるほど灰になって薄れる
		var col := EMBER.lerp(CHAR, clampf(life * 1.4, 0.0, 1.0))
		_ink.draw_circle(Vector2(ax, ay), r,
			Color(col.r, col.g, col.b, 0.8 * (1.0 - life)))
