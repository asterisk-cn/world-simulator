class_name PaperFly
extends Node2D
## 神が放った紙が、世界の掲示板まで飛んでいく。
##
## 押した瞬間に一覧へ行が増えるだけだと、神が紙を落とした感じにならない。
## 干渉は世界の上で起こす（頭上の吹き出しと同じ考え方）。
##
## ---------------------------------------------------------------------------
## **上へスライドして、世界の上から降ってくる。**
##
## 筒の表面を1周なぞる形をしばらく追ったが、いちばんよく起こる場合——
## カメラが板を捉えていて始点と終点が 36px しか離れない——でどうしても壊れた。
## 道が短いと進む向きが定まらず、輪の面も向きも安定しない。やめて、
## 誰が見ても分かる形にした。**画面の上へ抜けて、板の真上から降ってくる。**
##
## 途中は画面の外なので、上がる道と降りる道は繋がっていなくていい。
##
## ---------------------------------------------------------------------------
## **動きは `Tween` で組む。** この作品の演出はぜんぶそう（封蝋の一拍、
## 世界が目を覚ます `wake`、目次の送り）。一度これだけ場面と `AnimationPlayer` に
## 分けたが、動きが「上へ抜けて降りる」だけになったので大げさだった。
##
## 下の値は Tween が動かす。`_apply` がそれを道と合わせて姿にする。
## timing は `_play` の1か所にまとまっている
## ---------------------------------------------------------------------------

signal landed

## 降りに入った。**ここから紙は世界のもの**——世界の光（日夜の色）を受ける。
## 上がるあいだは神の手のものなので受けない（`main._on_god_posted`）
signal entered_world

# ---------------------------------------------------------------------------
# アニメーションが動かす値。**ここを直接いじらない**——`paper_fly.tscn` を直す。
# ---------------------------------------------------------------------------

## 上への抜け。0 = 手元、1 = 画面の外。**上がるあいだは縮まない**——
## 書いた紙の大きさのまま真上へ行く
var slide := 0.0

## 降り。0 = 板の真上（画面の外）、1 = 板。
## **`slide` が 1 になってから動かす**——途中は画面の外なので、
## 上がる道と降りる道は繋がっていなくていい
var drop := 0.0

## 大きさの送り。0 = 書いた紙のまま、1 = 板の貼り紙。
##
## **画面の外にいるあいだに全部済ませる。** 上がるあいだも降りるあいだも
## 大きさは変えない——この写しに透視は無いので（`world/iso.gd`）、
## 動きの途中で縮むのは嘘になる。
## 引き換えに、降りてくる紙は板の貼り紙と同じ 12.8px（小さい）
var shrink := 0.0

## 板の面の姿へどれだけ寄ったか。0 = 軸に沿った紙、1 = 板の手前の面
var settle := 0.0

## デフォルメ。0 = 書いた紙（欄とボタンごと）、1 = 積み木の世界の紙
var melt := 0.0

## 放つ前の持ち上がり。0〜1
var rise := 0.0


# ---------------------------------------------------------------------------
# 道の形。エディタの Inspector で直せる
# ---------------------------------------------------------------------------

## 飛んでいる時間。遠いときは伸ばす
const FLIGHT := 1.55
const FLIGHT_FAR := 0.35
const FAR_SPAN := 1400.0

## 画面の何倍まで上へ抜けるか。1.0 で画面のちょうど外。
## 少し余らせて、紙の丈ぶんも越えさせる
const OUT_OF_VIEW := 0.62

## 降りはじめる高さ（画面の何倍ぶん上か）
const FALL_FROM := 0.62

## 放つ前にその場で持ち上がる量（px）
const HOLD_RISE := 12.0

# ---------------------------------------------------------------------------
# 着く姿は**平らではない**。
#
# 着く先は水平の地面ではなく、掲示板の**手前の面**。等角では縦の面は潰れず、
# 水平辺だけが 1:2 で右下がりになる（`bulletin_board.gd` の `_draw_paper`）。
# 軸に沿った長方形で着くと、板の側の描画に入れ替わった瞬間に形が跳ぶ。
#
# ---------------------------------------------------------------------------
const FACE := 0.4636476   ## atan(0.5)

## 手元の紙は生成り、板の紙は黄。着くまでに移す
const PAPER_HAND := Color(0.99, 0.97, 0.92)

## 板の貼り紙と同じ寸法。
## **枡の x 方向の広がりではなく、辺の長さ**を採る——局所の横軸は板の面に沿って
## 倒れているので、倒した後の長さが板の紙の横辺（12.84）と一致しなければならない
const HW := 6.42
const HH := 4.455

## 板の貼り紙の角の丸み（`bulletin_board.gd` の `_draw_paper`）。
## 大きさに比例させるので、着いた瞬間にあちらと同じ丸みになる
const SLIP_ROUND := 1.6

## ちぎれが読める大きさ（半幅）。**ロール紙のちぎれは 5px 固定**なので、
## 紙が小さくなると幅の何割にもなって、紙ではなく星形に見える。
## この幅を下回るあいだに、板の貼り紙（角丸）へ移す
const ROLL_FULL := 90.0
const ROLL_MIN := 34.0

## 紙を渡されなかったときの寸法（`main` から直に呼んだときの逃げ道）。
## **書く紙の値を引かない**——世界の節点が UI を参照する向きになる
const BARE_W := 560.0
const BARE_H := 180.0


var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO

## 画面の高さ（世界の尺）。**カメラを知っている側が渡す**——
## 紙は層を分けて置かれているので、自分の変換から測ると倍率が二重にかかる
var reach := 1080.0

## 書いていた紙そのもの（`write_popup.gd` の `take_sheet`）。
## これを子に付けて一緒に運び、飛ぶあいだに貼り紙へ溶かす
var _sheet: Control = null
var _start_hw := BARE_W * 0.5
var _start_hh := BARE_H * 0.5
var _hw := 0.0
var _hh := 0.0

## デフォルメの紙はロール紙。角丸のべた塗りだと、
## 紙ではなく**昔の UI の面**に見える（この世界の紙は全部ロール紙から切った一枚）
var _roll: RollPaper = null

## 降りに入ったか（`entered_world` を一度だけ出すため）
var _in_world := false


# ---------------------------------------------------------------------------
# 間合い。**ここが動きの形の全部**。
#
# 溜め（`HOLD`）のうち `MELT_END` までにデフォルメになり、`LIFT_FROM` から持ち上がる。
# 飛行（`FLIGHT`）のうち `SLIDE_END` までに画面の外へ抜け、
# そこから `GAP_END` までの**画面の外にいるあいだ**に縮み、残りで降りる。
# ---------------------------------------------------------------------------
## 放つ前の一拍。**距離で伸ばさない**——手を離す間合いは距離と関係ない。
## この一拍には二つ仕事がある。まずその場でデフォルメになり、それから持ち上がる。
## フォームのまま飛ばすと、欄とボタンが——つまり UI が——世界を横切ることになる
const HOLD := 0.34
const MELT_END := 0.72
const LIFT_FROM := 0.60
const SLIDE_END := 0.42
const GAP_END := 0.52

## 降りは加速して、着く手前だけ緩める。ここまでを加速で送る
const DROP_HARD := 0.88
const SETTLE_FROM := 0.86


func _ready() -> void:
	_roll = RollPaper.new()
	# ちぎれるのは上下（書いていた紙と同じ向き）。粒は紙自身が持つ
	_roll.setup(PAPER_HAND, 0.0, false, UIKit.grain_texture())
	_hw = _start_hw
	_hh = _start_hh
	_apply()


## `sheet` は書いていた紙そのもの。渡されると、それを運んで貼り紙へ溶かす
func setup(p_from: Vector2, p_to: Vector2, sheet: Control = null,
		p_reach: float = 1080.0) -> void:
	from = p_from
	to = p_to
	reach = p_reach
	position = from
	z_index = 900
	if sheet != null:
		_sheet = sheet
		_start_hw = sheet.size.x * 0.5
		_start_hh = sheet.size.y * 0.5
		add_child(sheet)
	_hw = _start_hw
	_hh = _start_hh
	_play()


## 動きを1本の `Tween` に組む。**溜めは距離で伸ばさない**——
## 神が手を離す間合いは、板までの距離と関係ない
func _play() -> void:
	var dur := FLIGHT + FLIGHT_FAR * clampf(
		(to - from).length() / FAR_SPAN, 0.0, 1.0)
	var t := create_tween().set_parallel(true)

	# 一拍：その場でデフォルメになり、変わりきってから持ち上がる
	t.tween_property(self, "melt", 1.0, HOLD * MELT_END) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "rise", 1.0, HOLD * (1.0 - LIFT_FROM)) \
		.set_delay(HOLD * LIFT_FROM) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 上へ抜ける。**放たれてから速くなる**ので加速
	t.tween_property(self, "slide", 1.0, dur * SLIDE_END).set_delay(HOLD) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 縮みは画面の外にいるあいだだけ（`shrink` の注）
	t.tween_property(self, "shrink", 1.0, dur * (GAP_END - SLIDE_END)) \
		.set_delay(HOLD + dur * SLIDE_END) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 降りは加速して……
	t.tween_property(self, "drop", DROP_HARD, dur * (DROP_HARD - GAP_END)) \
		.set_delay(HOLD + dur * GAP_END) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# ……着く手前だけ緩める。緩めないと板に叩きつける
	t.tween_property(self, "drop", 1.0, dur * (1.0 - DROP_HARD)) \
		.set_delay(HOLD + dur * DROP_HARD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 終いに板の手前の面の姿へ
	t.tween_property(self, "settle", 1.0, dur * (1.0 - SETTLE_FROM)) \
		.set_delay(HOLD + dur * SETTLE_FROM) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	t.chain().tween_callback(_land)


func _process(_delta: float) -> void:
	_apply()


## いま溜めの一拍か。上がりはじめたら飛行
func _is_hold() -> bool:
	return slide <= 0.0


## 着いた瞬間は板の上の姿に寄せる。Tween の刻みの都合で
## 1 に届かないまま終わることがあるので、紙が板からずれないように
func _land() -> void:
	slide = 1.0
	drop = 1.0
	settle = 1.0
	shrink = 1.0
	melt = 1.0
	_apply()
	set_process(false)
	landed.emit()
	queue_free()


func _apply() -> void:
	# **上がる道と降りる道は繋がっていなくていい**（途中は画面の外）。
	# 上は手元から真上へ、降りは板の真上から板へ
	var up_end := from - Vector2(0, reach * OUT_OF_VIEW + _hh * 2.0)
	var sky := to - Vector2(0, reach * FALL_FROM)
	var at: Vector2
	if _is_hold():
		at = from - Vector2(0, HOLD_RISE * rise)
	elif drop <= 0.001:
		at = from.lerp(up_end, slide) - Vector2(0, HOLD_RISE * (1.0 - slide))
	else:
		at = sky.lerp(to, drop)
		if not _in_world:
			_in_world = true
			entered_world.emit()

	# 姿。終いは板の手前の面へ——x 軸だけ 1:2 に倒し、縦辺は垂直に戻す
	rotation = FACE * settle
	skew = -FACE * settle
	scale = Vector2.ONE

	# **大きさは掛け算で送る。** 書いた紙（560px）から貼り紙（12.8px）まで
	# 44 倍落ちるので、足し算で送ると半分の時間でまだ 16 倍のままで、
	# 遠ざかる速さが一定に見えない。
	# 幅と丈を別に送るのは**縦横比が違うから**——書いた紙は 3.1:1、貼り紙は 1.44:1。
	# こうすると書いた紙が貼り紙の形へ絞られていく（別の紙に入れ替わらない）
	_hw = _geo(_start_hw, HW, shrink)
	_hh = _geo(_start_hh, HH, shrink)
	position = at
	_place_sheet()
	queue_redraw()


## 書いた紙を、いま描いている貼り紙とぴたり重ねる。
## 幅と丈を別に縮めるので、紙の側も別々に縮める（`Control.scale` は Vector2）。
## 左上を原点に拡縮するので、中心へ寄せるには半分ずらす
func _place_sheet() -> void:
	if _sheet == null:
		return
	if melt >= 1.0:
		# もう溶けきっている。**節点ごと捨てる**——残しておくと、
		# 見えない欄が飛んでいくあいだずっと世界の上に居る
		_sheet.queue_free()
		_sheet = null
		return
	_sheet.scale = Vector2(_hw / _start_hw, _hh / _start_hh)
	_sheet.position = Vector2(-_hw, -_hh)
	_sheet.modulate.a = 1.0 - melt


## 掛け算で送る。両端が正なら 0 を跨がない
func _geo(a: float, b: float, u: float) -> float:
	return a * pow(b / a, clampf(u, 0.0, 1.0))


func _draw() -> void:
	# 板に貼られた紙と**同じ姿**。着いた瞬間に別の紙へ入れ替わって見えないように、
	# 横長・罫2本・縁なしで、色は手元の生成りから板の黄へ移す。
	# **書いた紙が溶けきるまでは透かしておく**——下に本物の紙が乗っている
	var col := PAPER_HAND.lerp(BulletinBoard.GOD_SLIP, shrink)
	col.a *= melt
	if col.a <= 0.0:
		return
	# 大きいあいだは**ロール紙**——ちぎれた縁と粒を持った一枚。
	# 小さくなるにつれ板の貼り紙（角丸）へ移す。ちぎれが 5px 固定なので、
	# 小さいまま描くと縁の欠けが幅を食って星形に見える
	var roll := smoothstep(ROLL_MIN, ROLL_FULL, _hw)
	var rect := Rect2(-_hw, -_hh, _hw * 2.0, _hh * 2.0)
	if roll > 0.0:
		_roll.bg = Color(col.r, col.g, col.b, col.a * roll)
		_roll.draw(get_canvas_item(), rect)
	if roll < 1.0:
		# **角の半径は板の紙から比例で出す**（あちらは 1.6 固定）。
		# `ItemIcon.blk` は半径を `max(幅, 丈)` から出すので、フォームのような
		# 横長では丈の半分を超えて、紙ではなく座薬の形になる
		var r: float = SLIP_ROUND * _hh / HH
		draw_colored_polygon(Iso.rounded(PackedVector2Array([
			Vector2(-_hw, -_hh), Vector2(_hw, -_hh),
			Vector2(_hw, _hh), Vector2(-_hw, _hh),
		]), r), Color(col.r, col.g, col.b, col.a * (1.0 - roll)))
	var ink: float = 0.8 * col.a
	if ink <= 0.0:
		return
	# 比例させると大きいときに帯になって「昔の UI」に見える。
	# 0.55 乗で寄せると、大きいときは字の太さ、小さいときは板の紙と同じ
	var lw: float = maxf(1.0, pow(_hh / HH, 0.55))
	# 板の紙と同じ割り付け（下から 0.34 と 0.67、左右は 0.04 ぶん内側）
	for k in range(2):
		var y := (0.16 - float(k) * 0.33) * _hh * 2.0
		var half := _hw * 0.652
		draw_line(Vector2(-half, y), Vector2(half, y),
			Color(0.45, 0.45, 0.45, ink), lw)
