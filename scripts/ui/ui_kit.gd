class_name UIKit
extends RefCounted
## コードから UI を組み立てるための小さなヘルパ群。
##
## **ここが作る部品（`PipBar` / `BlockSlider` / `TrashIcon`）は、UIKit を参照しない。**
## 参照すると UIKit → 部品 → UIKit の輪になり、UIKit に関数を1つ足したときに
## エディタが古い UIKit を見たまま依存側を読み直して
## 「Static function ... not found in base UIKit」で止まる。
## 部品の大きさと色は、作るこちら側が渡す。
## （`EyeButton` はパネルが作るので輪にならない）

# ---------------------------------------------------------------------------
# 紙と木。
#
# 神は紙に書いて板に貼る。世界はパステルの積み木でできている。
# UIを無彩色のダークスレートにすると、そこだけ開発ツールになってしまうので、
# 世界と同じ素材で作る。
# ---------------------------------------------------------------------------

const BG := Color(0.95, 0.91, 0.82)       ## 紙
const BG_SOFT := Color(0.90, 0.85, 0.74)  ## 紙の上に置く紙
const TEXT := Color(0.20, 0.17, 0.13)     ## 墨
const TEXT_DIM := Color(0.46, 0.41, 0.34)
const PAGE := Color(0.98, 0.95, 0.89)
const WOOD := Color(0.46, 0.33, 0.21)     ## 枠
const HEAD := Color(0.36, 0.26, 0.16)     ## 見出し
const INK := Color(0.30, 0.22, 0.14, 0.10)   ## 押せるものの下地
const INK_HOVER := Color(0.30, 0.22, 0.14, 0.18)
const INK_ACTIVE := Color(0.30, 0.22, 0.14, 0.28)
const SUNK := Color(0.30, 0.22, 0.14, 0.13)  ## 入力欄のくぼみ
const ACCENT := Color(0.86, 0.52, 0.18)   ## 神の手が届くところ。ここぞという1か所にだけ

## 日本語は英字より行が高い。入力欄やボタンをこれより低くすると文字の上下が切れる。
const ROW_H := 32

## 読み取り専用バーの寸法。場所によって変わらないよう1か所で決める。
const BAR_W := 104
const BAR_H := 12

## 値を決めるつまみの寸法。行より少しだけ低くする。
const SLIDER_W := 132

## 縦スクロールする中身は、スクロールバーとこれだけ離す。
const SCROLL_GUTTER := 14

# ---------------------------------------------------------------------------
# 字の段。ここ以外の数字を font_size に書かない。
#
# **小さくして弱めない。弱めるなら TEXT_DIM で薄くする。**
# 画面は 1920 を基準に拡縮するので、ノートの窓では 10px は物理 7.5px になり、
# 「関係」程度の画数でも潰れる。日本語の下限は 11。
#
# 迷ったときは色で決まる。**TEXT なら本文、TEXT_DIM なら注。**
# ---------------------------------------------------------------------------

## 段差は2ずつ。13/14/16/18/24 で、隣の段と必ず見分けがつく。
const FS_TITLE := 24  ## 題。その紙の名前。1枚に1つだけ
const FS_HEAD := 18   ## 見出し。窓の題名・区分・章
const FS_SUB := 16    ## 小見出し。名前を書く欄・✕ の字
const FS_BODY := 14   ## 本文。行の字・入力欄・ボタン。テーマの既定もこれ
const FS_NOTE := 13   ## 注。値・両極の言葉・日付・要約。色は常に TEXT_DIM

## 折り返す文の行間。1行で終わる字には付けない（行送りだけ広い1行になる）
const LINE_WRAP := 4

# ---------------------------------------------------------------------------
# 余白の段。ここ以外に数字を置かない。
# ---------------------------------------------------------------------------

const HAIR := 4      ## 行の内側の上下。行と罫が触れていると帳簿の罫線に見える
const GAP_S := 8     ## 並んだ行どうし、1行の中の部品どうし
const GAP := 12      ## まとまりどうしの間、1行の中のラベルと中身の間
const PAD_S := 12    ## パネルの中に置く面の内側（GAP と同値。内か間かで名を分ける）
const PAD := 18      ## パネルの内側、章見出しの上

## 章と章の間。**箱をやめたぶん、区切りは余白が担う。**
## 見出しの罫だけでは、上の章の終わりと次の章の始まりが同じ強さで並んでしまう。
const PAD_L := 28

## 一覧の1行の先頭に置く欄の幅。点・姿の絵・色見本のどれが来ても、
## 本文の左端が同じところに来る（`list_row`）。正方なので何を入れても座る。
const LEAD_W := ROW_H

## 罫線の欄（`ruled_style`）が字を字下げしているぶん。
## 読み取り専用の行も同じだけ下げないと、始まる前と後で字が横に動く。
const FIELD_INSET := 7

## 行の名前の欄。ここが揃っていないと、同じ紙の中で積み木の始まりがずれる。
const NAME_W := 76

## 両極の行で、積み木の向こう側に置く言葉の欄
const POLE_W := 56


## UI全体の見た目を1か所で決める。
## これを敷かないと、ボタンや入力欄だけがエンジン既定の暗い箱を持ってしまい、
## そこだけ影が差したように見える。
static func build_theme(font: Font) -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = FS_BODY

	var flat := func(col: Color, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(radius)
		sb.content_margin_left = pad_x
		sb.content_margin_right = pad_x
		sb.content_margin_top = pad_y
		sb.content_margin_bottom = pad_y
		return sb

	for t in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
		th.set_stylebox("normal", t, flat.call(INK, 6, 10, 5))
		th.set_stylebox("hover", t, flat.call(INK_HOVER, 6, 10, 5))
		th.set_stylebox("pressed", t, flat.call(INK_ACTIVE, 6, 10, 5))
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
		th.set_stylebox("disabled", t, flat.call(Color(0.30, 0.22, 0.14, 0.04), 6, 10, 5))
		th.set_color("font_color", t, TEXT)
		th.set_color("font_hover_color", t, Color(0.10, 0.08, 0.05))
		th.set_color("font_pressed_color", t, Color(0.10, 0.08, 0.05))
		th.set_color("font_disabled_color", t, Color(0.30, 0.26, 0.20, 0.4))
		th.set_font_size("font_size", t, FS_BODY)

	# 名前欄はインクの罫線。箱で塗ると「無効になった入力欄」に見えて、
	# 言葉を書き込む場所だと伝わらない。
	var ruled := func(alpha: float, width: int) -> StyleBoxFlat:
		return ruled_style(alpha, width)
	th.set_stylebox("normal", "LineEdit", ruled.call(0.04, 1))
	th.set_stylebox("focus", "LineEdit", ruled.call(0.10, 2))
	th.set_color("font_color", "LineEdit", TEXT)
	th.set_color("font_placeholder_color", "LineEdit", Color(0.30, 0.26, 0.20, 0.45))
	th.set_color("caret_color", "LineEdit", TEXT)
	th.set_font_size("font_size", "LineEdit", FS_BODY)

	# 選ぶ欄も、書く欄と同じ罫線にする。角丸の箱だけがOSの部品として残ると、
	# そこだけ設定画面の顔になる。
	for t2 in ["OptionButton", "MenuButton"]:
		th.set_stylebox("normal", t2, ruled.call(0.03, 1))
		th.set_stylebox("hover", t2, ruled.call(0.08, 1))
		th.set_stylebox("pressed", t2, ruled.call(0.12, 2))
		th.set_stylebox("focus", t2, StyleBoxEmpty.new())
	th.set_icon("arrow", "OptionButton", _ink_arrow())
	th.set_constant("arrow_margin", "OptionButton", 4)
	th.set_constant("modulate_arrow", "OptionButton", 1)

	th.set_stylebox("panel", "PopupMenu", flat.call(BG_SOFT, 8, 6, 6))
	th.set_color("font_color", "PopupMenu", TEXT)
	th.set_color("font_hover_color", "PopupMenu", Color(0.10, 0.08, 0.05))
	th.set_stylebox("hover", "PopupMenu", flat.call(INK_HOVER, 5, 6, 3))
	th.set_font_size("font_size", "PopupMenu", FS_BODY)

	# ツールチップも紙にする。エンジン既定の暗い箱が出ると、
	# 説明を「?」に逃がした先だけが開発ツールの顔になる。
	th.set_stylebox("panel", "TooltipPanel", tooltip_style())
	th.set_color("font_color", "TooltipLabel", TEXT)
	th.set_font_size("font_size", "TooltipLabel", FS_NOTE)

	th.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	# タブは紙の束の見出し。**選ばれている札は紙と同じ色**で、中身もこの紙そのもの。
	# 中身に別の面を敷くと、紙の上にもう1枚紙が乗る（§9「箱は物体のときだけ」）。
	# 奥の札だけを沈めて、後ろに重なっている紙として見せる。
	var tab_on := StyleBoxFlat.new()
	tab_on.bg_color = BG
	tab_on.corner_radius_top_left = 8
	tab_on.corner_radius_top_right = 8
	tab_on.corner_radius_bottom_left = 0
	tab_on.corner_radius_bottom_right = 0
	tab_on.content_margin_left = 18
	tab_on.content_margin_right = 18
	tab_on.content_margin_top = 10
	tab_on.content_margin_bottom = 7
	th.set_stylebox("tab_selected", "TabContainer", tab_on)

	# 奥の紙は色で沈める。高さを変えて逃がすと、紙どうしのあいだに隙間が空く
	var tab_off := StyleBoxFlat.new()
	tab_off.bg_color = Color(0.87, 0.82, 0.72)
	tab_off.corner_radius_top_left = 8
	tab_off.corner_radius_top_right = 8
	tab_off.content_margin_left = 18
	tab_off.content_margin_right = 18
	tab_off.content_margin_top = 10
	tab_off.content_margin_bottom = 7
	th.set_stylebox("tab_unselected", "TabContainer", tab_off)

	var tab_hover := tab_off.duplicate() as StyleBoxFlat
	tab_hover.bg_color = Color(0.91, 0.87, 0.77)
	th.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	th.set_color("font_selected_color", "TabContainer", HEAD)
	th.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	th.set_color("font_hovered_color", "TabContainer", TEXT)

	th.set_color("separator", "HSeparator", Color(0.30, 0.22, 0.14, 0.22))
	th.set_constant("separation", "HSeparator", GAP_S)

	# スクロールバー。既定のままだと紙の上で黒い棒に見える
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.30, 0.22, 0.14, 0.07)
	track.set_corner_radius_all(4)
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.46, 0.33, 0.21, 0.45)
	grab.set_corner_radius_all(4)
	var grab_on := StyleBoxFlat.new()
	grab_on.bg_color = Color(0.46, 0.33, 0.21, 0.70)
	grab_on.set_corner_radius_all(4)
	for t in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", t, track)
		th.set_stylebox("grabber", t, grab)
		th.set_stylebox("grabber_highlight", t, grab_on)
		th.set_stylebox("grabber_pressed", t, grab_on)
	return th


## かざしたときに出る言葉の紙。エンジンのツールチップと、自前の一枚（`help`）で共用する。
static func tooltip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_SOFT
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.46, 0.33, 0.21, 0.35)
	sb.set_border_width_all(1)
	sb.content_margin_left = GAP_S
	sb.content_margin_right = GAP_S
	sb.content_margin_top = HAIR + 1
	sb.content_margin_bottom = HAIR + 1
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


## インクの罫線。書く欄も選ぶ欄も、この一種類だけで作る。
static func ruled_style(alpha: float = 0.04, width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.22, 0.14, alpha)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.border_color = Color(0.46, 0.33, 0.21, 0.55)
	sb.border_width_bottom = width
	sb.content_margin_left = FIELD_INSET
	sb.content_margin_right = FIELD_INSET
	sb.content_margin_top = 4
	sb.content_margin_bottom = 3
	return sb


## ドロップダウンの印。エンジン既定の白い矢印は紙の上で浮く。
static func _ink_arrow() -> ImageTexture:
	var w := 9
	var h := 5
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		var half := int(round(float(w) * 0.5 * (1.0 - float(y) / float(h))))
		for x in range(w):
			if absi(x - w / 2) <= half - 1:
				img.set_pixel(x, y, Color(0.30, 0.22, 0.14, 0.75))
	return ImageTexture.create_from_image(img)


## 紙の地合い。**平らな塗りのままだと、箱をやめたあと画面がのっぺりする。**
##
## 世界のほうはパステルの積み木で平滑に保ちたいので、画面全面には被せない。
## **UIの面ひとつずつに敷く**（紙・カード・貼り紙・かざした一枚…）。
##
## 粒は2つの粗さを重ねる。**細かいノイズだけだとテレビの砂嵐に見えて、紙にならない。**
## 紙は繊維が塊で寄っているので、粗いムラ（16マスの格子を滑らかに繋いだもの）が要る。
## 強さは合わせて明度 −6%〜0%。髪の毛ほどの罫（α 0.13）より弱いので、罫が粒に負けない。
const GRAIN_PX := 128

## 粗いムラの格子。細かすぎると砂嵐に戻り、粗すぎると染みになる
const GRAIN_CELLS := 16

## 細かい粒と粗いムラの、それぞれの深さ（掛け算なので暗くする方向にだけ効く）
const GRAIN_FINE := 0.03
const GRAIN_MOTTLE := 0.03

static var _grain: ImageTexture = null


static func grain_texture() -> ImageTexture:
	if _grain != null:
		return _grain
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260908

	# 粗いムラ。格子の四隅を測って、あいだは滑らかに繋ぐ（端は巻いて継ぎ目を消す）
	var grid := []
	for gy in range(GRAIN_CELLS):
		var row := []
		for gx in range(GRAIN_CELLS):
			row.append(rng.randf())
		grid.append(row)

	var img := Image.create(GRAIN_PX, GRAIN_PX, false, Image.FORMAT_RGB8)
	var cell := float(GRAIN_PX) / float(GRAIN_CELLS)
	for y in range(GRAIN_PX):
		for x in range(GRAIN_PX):
			var fx := float(x) / cell
			var fy := float(y) / cell
			var x0 := int(floor(fx))
			var y0 := int(floor(fy))
			var tx := fx - float(x0)
			var ty := fy - float(y0)
			# 角を丸めた補間。直線に繋ぐと格子の筋が見える
			tx = tx * tx * (3.0 - 2.0 * tx)
			ty = ty * ty * (3.0 - 2.0 * ty)
			var x1 := (x0 + 1) % GRAIN_CELLS
			var y1 := (y0 + 1) % GRAIN_CELLS
			var top: float = lerpf(grid[y0][x0], grid[y0][x1], tx)
			var bot: float = lerpf(grid[y1][x0], grid[y1][x1], tx)
			var mottle: float = lerpf(top, bot, ty)
			var v := 1.0 - rng.randf() * GRAIN_FINE - mottle * GRAIN_MOTTLE
			img.set_pixel(x, y, Color(v, v, v))
	_grain = ImageTexture.create_from_image(img)
	return _grain


## 紙の上に粒を敷く。中身より先に置くので、字や絵の下に来る。
##
## **`EXPAND_IGNORE_SIZE` を忘れないこと。** TextureRect は既定で絵の大きさ（128px）を
## 最小の丈として主張するので、これを敷いた紙が全部 128px 以上に膨らむ。
## 上部バーが厚くなって世界が削れたのはこれだった。
##
## 敷くのは `sheet()` から。器の余白を stylebox に持たせたままだと、
## その帯にだけ粒が乗らない（縁が紙に見えない）。
static func paper_grain(parent: Control) -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = grain_texture()
	tex.stretch_mode = TextureRect.STRETCH_TILE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 掛け算で焼き込む。上に重ねて薄く塗ると、紙の色そのものが濁る
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	tex.material = mat
	parent.add_child(tex)
	return tex


## 紙の面の形。**ロール紙から切った一枚**（`RollPaper`）。
##
## 角丸の箱に木の枠を付けていたので、紙ではなく**額**に見えていた。
## ロール紙なら左右はロールの幅そのままでまっすぐ、上下は切り離した縁なのでちぎれている。
## `radius` はもう使わないが、呼ぶ側の形を変えずに済むよう受け取っておく。
## `across` を true にすると、横に引き出した紙（左右がちぎれる）になる。
## 上部の帯は横長なので、ちぎれ目は短い辺——つまり左右に来る。
static func panel_style(bg: Color = BG, _radius: int = 10, pad: int = PAD,
		across: bool = false) -> StyleBox:
	var sb := RollPaper.new()
	sb.setup(bg, float(pad), across, grain_texture())
	return sb


## パネルの中に置くカード。枠と影を持たせると、そこが一番強い要素になってしまう。
static func card(bg: Color = BG_SOFT, pad: int = PAD_S) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(7)
	sheet(p, sb, pad)
	return p


## 一覧を2列に割る。返るのは左右2つの「行を並べる箱」。
##
## 1列に積むと、9語のじぶんだけで紙の1画面が終わり、
## **この世界にどんな言葉があるかを一目で見られない**。
## 送りは新聞と同じ——左の列を上から下まで埋めてから、右の列へ。
## 行頭はどちらの列でも同じ欄（`list_row`）で揃うので、読み方は変わらない。
static func two_columns(parent: Node) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PAD_L)
	parent.add_child(row)
	var out: Array = []
	for _i in range(2):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_FILL
		row.add_child(col)
		out.append(col)
	return out


## 罫で区切った行を並べる箱。**角丸の面（箱）は持たない。**
##
## 束・村人・もちものの一覧・性格・あいての相手ごとを、どれも角丸の面で囲っていた。
## 紙の上に紙、その中に紙……と重なって、区分けのはずの面が物体として並んでいた。
## **箱は「紙の上に別の物体が乗っている」ときだけ**（貼り紙・入力の一枚・確認の一枚）。
## 同じ紙の上の区分けは、見出し（`heading`）と罫（`hairline`）と余白でやる。
static func rows(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	return box


## 罫で区切られた一覧の1行ぶんの器。行と罫が触れていると帳簿の罫線に見える。
static func row_pad(parent: Node) -> MarginContainer:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", HAIR)
	pad.add_theme_constant_override("margin_bottom", HAIR)
	parent.add_child(pad)
	return pad


## 一覧の1行。先頭に点・姿の絵・色見本のどれが来ても、
## 本文の左端は必ず LEAD_W + GAP_S に来る。
##
## 先頭の部品に本文を追従させていたので、「ことば」（●）と「つくりかた」（姿の絵）で
## 同じ一覧なのに行頭がずれていた。**先に欄を切って、そこへ入れる。**
##
## 使うのは**「この世界の言葉」の中だけ**。あの紙は同じ形の一覧が4枚並んでいて、
## タブを替えたときに字が横に動くのが読めない、という話だった。
## だから先頭に置くものが無いタブ（世界）でも欄は空けておく。
##
## **見る面（インスペクタ・村人一覧・関係）には敷かない。** 決める面と見る面は性質が違う。
## 先頭に置くものが無いところで空の欄を切ると、狭い紙の幅を削るだけになる。
## 罫で区切るだけなら `row_pad` を使う。
static func list_row(parent: Node, lead: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_S)
	row_pad(parent).add_child(row)
	var gutter := CenterContainer.new()
	gutter.custom_minimum_size = Vector2(LEAD_W, ROW_H)
	row.add_child(gutter)
	if lead != null:
		gutter.add_child(lead)
	return row


## 印の点（と、束の四角）。字の glyph ではなく塗った図形にする。
static func dot(col: Color, square: bool = false, px: int = 12) -> Control:
	var d := Panel.new()
	d.custom_minimum_size = Vector2(px, px)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(2 if square else int(px / 2.0))
	d.add_theme_stylebox_override("panel", sb)
	return d


## 読み取り専用の行の字。罫線の欄と同じだけ字下げする。
## これが無いと、世界が始まった瞬間に一覧の字が左へ 6px 飛ぶ。
static func read_only(text: String, size: int = FS_BODY, col: Color = TEXT) -> Control:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", FIELD_INSET)
	pad.add_child(label(text, size, col))
	return pad


## 持ち物の1つ。絵と名前と数を対で出す。
## 絵だけでは、神がつけた名前の物が何なのか読めない（ツールチップは触らないと出ない）。
static func item_chip(parent: Node, item_id: String, name_text: String,
		count_text: String = "", name_width: int = 0) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", HAIR)
	parent.add_child(cell)
	var icon := ItemIcon.of_item(item_id, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(icon)
	var nm := label(name_text, FS_NOTE, TEXT_DIM)
	if name_width > 0:
		# 折り返して並んだとき、名前の幅が揃っていないと右側の数がばらける
		nm.custom_minimum_size = Vector2(name_width, 0)
		nm.clip_text = true
	cell.add_child(nm)
	if count_text != "":
		cell.add_child(label(count_text, FS_BODY, TEXT))
	return cell


## 見出しの横の「?」。説明を紙に書き足すと、そこだけ設定画面の注記になる。
## 押しても世界は何も変わらないので、木色もアクセントも使わない。
## 置くのは見出しの字の直後だけ。行の中や入力欄の隣に置くと、フォームの注釈に見える。
##
## **押した色を持たせない。** ここは押すところではなく、かざすと言葉が出る印。
## 押した瞬間に色が沈むと、何かが起きたと読めてしまう（何も起きない）。
##
## **エンジンのツールチップも使わない。** エンジンは押した瞬間にツールチップを消すので、
## 何も起きない印なのに、押すと読んでいた言葉が消える。かざしているあいだは出したまま。
static func help(parent: Node, tip: String) -> Control:
	var mark := Panel.new()
	mark.custom_minimum_size = Vector2(22, 22)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_STOP
	mark.set_meta("note", tip)

	var mk := func(col: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(11)
		return sb
	var idle: StyleBoxFlat = mk.call(INK)
	var over: StyleBoxFlat = mk.call(INK_HOVER)
	mark.add_theme_stylebox_override("panel", idle)

	# 字は器の真ん中へ。Panel は文字を持たないので、上に載せる
	var glyph := label("?", FS_NOTE, TEXT_DIM)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	mark.mouse_entered.connect(func() -> void:
		mark.add_theme_stylebox_override("panel", over)
		_show_note(mark, String(mark.get_meta("note", ""))))
	mark.mouse_exited.connect(func() -> void:
		mark.add_theme_stylebox_override("panel", idle)
		_hide_note(mark))
	# 面が組み直されたときに、言葉だけ残らないように
	mark.tree_exiting.connect(func() -> void: _hide_note(mark))

	parent.add_child(mark)
	return mark


## 「?」の言葉を差し替える（開始前と進行中で言うことが変わる場所で使う）
static func set_help(mark: Control, tip: String) -> void:
	mark.set_meta("note", tip)


## かざしているあいだ出しておく一枚。どの窓よりも上の層に1枚だけ置いて使い回す。
static func _show_note(at: Control, text: String) -> void:
	if text == "" or not at.is_inside_tree():
		return
	var box := _note_box(at, true)
	if box == null:
		return
	(box.get_node("Text") as Label).text = text
	box.visible = true
	box.reset_size()

	# 印の下に出す。画面の外へ出るときは中へ寄せ、下が足りなければ上へ返す
	var r := at.get_global_rect()
	var vp := at.get_viewport_rect().size
	var p := r.position + Vector2(0, r.size.y + GAP_S)
	p.x = clampf(p.x, PAD, maxf(PAD, vp.x - box.size.x - PAD))
	if p.y + box.size.y > vp.y - PAD:
		p.y = r.position.y - box.size.y - GAP_S
	box.position = p


static func _hide_note(at: Control) -> void:
	var box := _note_box(at, false)
	if box != null:
		box.visible = false


static func _note_box(at: Control, make: bool) -> PanelContainer:
	if not at.is_inside_tree():
		return null
	var root := at.get_tree().root
	var layer := root.get_node_or_null("UIKitNote") as CanvasLayer
	if layer == null:
		if not make:
			return null
		layer = CanvasLayer.new()
		layer.name = "UIKitNote"
		layer.layer = 128  # どの窓よりも上
		root.add_child(layer)
	var box := layer.get_node_or_null("Note") as PanelContainer
	if box == null:
		if not make:
			return null
		box = PanelContainer.new()
		box.name = "Note"
		box.add_theme_stylebox_override("panel", tooltip_style())
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.theme = SimConfig.ui_theme
		paper_grain(box)
		var l := label("", FS_NOTE, TEXT)
		l.name = "Text"
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
		layer.add_child(box)
	return box


## 紙の面を仕立てる。**粒は紙いっぱいに敷き、余白は内側の器に持たせる。**
##
## `PanelContainer` は子を「内側の矩形」——stylebox の余白を除いた領域——に置く。
## だから余白を stylebox 側に持たせると、**縁のその帯にだけ粒が乗らない**。
## 紙の真ん中だけ質感があって縁が平ら、という妙な面になっていた。
## 余白は 0 にして、中身は余白を持つ器に入れる。
##
## 返るのは**中身を入れる器**。外側は呼ぶ側が持っている。
static func sheet(p: PanelContainer, sb: StyleBox, pad: int) -> MarginContainer:
	p.add_theme_stylebox_override("panel", sb)
	# ロール紙は粒を自分で持っている（ちぎれの帯にも乗せるため）。
	# 四角い面だけ、上に層を敷く
	if not (sb is RollPaper):
		paper_grain(p)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_top", pad)
	m.add_theme_constant_override("margin_bottom", pad)
	p.add_child(m)
	return m


## `self` が紙の面そのものであるパネル（インスペクタ・村人一覧…）用。
static func paper_sheet(p: PanelContainer, bg: Color = BG, radius: int = 10,
		pad: int = PAD, across: bool = false) -> MarginContainer:
	return sheet(p, panel_style(bg, radius, 0, across), pad)


## 中身を入れる器を、あとから引く（`panel()` で作った紙）
static func body_of(p: PanelContainer) -> MarginContainer:
	for c in p.get_children():
		if c is MarginContainer:
			return c
	return null


static func panel(bg: Color = BG, radius: int = 10, pad: int = PAD,
		across: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	paper_sheet(p, bg, radius, pad, across)
	return p


static func label(text: String, size: int = FS_BODY, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## その紙の題。1枚に1つだけ。
static func title(parent: Node, text: String, col: Color = HEAD) -> Label:
	var l := label(text, FS_TITLE, col)
	parent.add_child(l)
	return l


## 章・区分の見出し（強）。この下に束（中）、その下に行（弱）が来る。
##
## 罫は字の右へ引く。下に敷くと題と本文のあいだの区切り線に見えて、
## 見出しそのものが注記の書式になる。説明が要るときは字の直後に「?」を置く。
static func heading(parent: Node, text: String, tip: String = "",
		col: Color = HEAD) -> HBoxContainer:
	spacer(parent, PAD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_S)
	parent.add_child(row)
	row.add_child(label(text, FS_HEAD, col))
	if tip != "":
		help(row, tip)
	var rule := HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rule)
	spacer(parent, HAIR)
	return row


## 畳める章。**普段は要らないものだけ**をこれにする。
##
## 見出しの形は `heading` と同じ（同じ紙の中で章の見え方を変えない）。
## 違うのは名前の前に ▶ / ▼ が付いて、押すと開くこと。
## 返るのは中身を入れる箱で、畳んでいるあいだは隠れている。
static func fold_heading(parent: Node, text: String, tip: String = "",
		open: bool = false, on_toggle: Callable = Callable()) -> VBoxContainer:
	spacer(parent, PAD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_S)
	parent.add_child(row)

	var head := Button.new()
	head.text = ("▼ " if open else "▶ ") + text
	head.add_theme_font_size_override("font_size", FS_HEAD)
	head.add_theme_color_override("font_color", HEAD)
	head.add_theme_color_override("font_hover_color", TEXT)
	head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# 章の見出しは字。押せる箱にすると、そこだけ操作の並びに見える
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		head.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	row.add_child(head)

	if tip != "":
		help(row, tip)
	var rule := HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rule)
	spacer(parent, HAIR)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.visible = open
	parent.add_child(body)

	head.pressed.connect(func() -> void:
		body.visible = not body.visible
		head.text = ("▼ " if body.visible else "▶ ") + text
		if on_toggle.is_valid():
			on_toggle.call(body.visible))
	# 目次の行き先に使えるよう、見出しの行を添えておく
	body.set_meta("head_row", row)
	return body


## 折り返す本文。
static func wrapped(parent: Node, text: String, size: int = FS_BODY,
		col: Color = TEXT) -> Label:
	var l := label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("line_spacing", LINE_WRAP)
	l.custom_minimum_size = Vector2(0, 0)
	parent.add_child(l)
	return l


## 折り返す注。値でも見出しでもない、弱い一言はここ。
static func note(parent: Node, text: String) -> Label:
	return wrapped(parent, text, FS_NOTE, TEXT_DIM)


## ラベル + 積み木 + 数値。on_change(new_value) が呼ばれる。
static func slider_row(
	parent: Node, name_text: String, value: float,
	vmin: float, vmax: float, step: float,
	on_change: Callable, bar_color: Color = Color(0.55, 0.42, 0.26),
	name_width: int = NAME_W, fmt: Callable = Callable()
) -> BlockSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var nm := label(name_text, FS_BODY, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)

	var show := func(x: float) -> String:
		return String(fmt.call(x)) if fmt.is_valid() else _fmt(x, step)

	var val := label(show.call(value), FS_NOTE, TEXT_DIM)
	val.custom_minimum_size = Vector2(NAME_W, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

	var s := BlockSlider.new()
	s.custom_minimum_size = Vector2(SLIDER_W, ROW_H - GAP_S)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	s.setup(value, vmin, vmax, step, bar_color)

	s.changed.connect(func(x: float) -> void:
		val.text = show.call(x)
		on_change.call(x)
	)
	return s


## 両極の値。ゲージの左右に、どちらへ寄っているかの言葉を置く。
static func pole_row(parent: Node, left: String, right: String, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	# 名前は左寄せ。すぐ下に左寄せの一覧（じぶん）が続くので、
	# ここだけ右寄せにすると、同じ紙の中で2つの字下げができる
	var l := label(left, FS_NOTE, TEXT if value < 0.45 else TEXT_DIM)
	l.custom_minimum_size = Vector2(NAME_W, 0)
	row.add_child(l)

	var pips := PipBar.new()
	pips.custom_minimum_size = Vector2(BAR_W, BAR_H)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	pips.setup(value * 100.0, 0.0, 100.0, Color(0.48, 0.36, 0.66))

	var r := label(right, FS_NOTE, TEXT if value > 0.55 else TEXT_DIM)
	r.custom_minimum_size = Vector2(POLE_W, 0)
	row.add_child(r)


## 両極のあいだを決める。見る側（pole_row）と同じ積み木・同じ両端の言葉にする。
## 決める側と見る側で形が違うと、自分が決めたものが動いている繋がりが切れる。
static func pole_slider(parent: Node, left: String, right: String, value: float,
		on_change: Callable) -> BlockSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	parent.add_child(row)

	# 決める側と見る側で同じ形にする（`pole_row` と揃える）
	var l := label(left, FS_NOTE, TEXT_DIM)
	l.custom_minimum_size = Vector2(NAME_W, 0)
	row.add_child(l)

	var s := BlockSlider.new()
	s.custom_minimum_size = Vector2(SLIDER_W, ROW_H - GAP_S)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	s.setup(value * 100.0, 0.0, 100.0, 10.0, Color(0.48, 0.36, 0.66))

	var r := label(right, FS_NOTE, TEXT_DIM)
	r.custom_minimum_size = Vector2(POLE_W, 0)
	row.add_child(r)

	# どちらへ寄っているかは、両端の言葉の濃さでも読める
	var lean := func(v: float) -> void:
		l.add_theme_color_override("font_color", TEXT if v < 0.45 else TEXT_DIM)
		r.add_theme_color_override("font_color", TEXT if v > 0.55 else TEXT_DIM)
	lean.call(value)
	s.changed.connect(func(x: float) -> void:
		lean.call(x / 100.0)
		on_change.call(x / 100.0))
	return s


## 読み取り専用の値表示。積み木を並べて見せる。
static func bar_row(parent: Node, name_text: String, value: float,
		vmin: float, vmax: float, col: Color, idle: bool = false,
		neg: Color = Schema.PAIR_NEG) -> PipBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var nm := label(name_text, FS_BODY, TEXT_DIM if idle else TEXT)
	nm.custom_minimum_size = Vector2(NAME_W, 0)
	row.add_child(nm)
	var pips := PipBar.new()
	if idle:
		pips.modulate = Color(1, 1, 1, 0.5)
	pips.custom_minimum_size = Vector2(BAR_W, BAR_H)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	pips.neg = neg
	pips.setup(value, vmin, vmax, col)
	# 値だけを入れ替えたい呼び側（インスペクタ）が積み木を持てるように返す。
	# 面ごと作り直すと、押せるものがカーソルの下で消えて点滅する。
	return pips


static func button(parent: Node, text: String, on_press: Callable, size: int = FS_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, ROW_H)
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


## 「＋ なにか」の控えめな追加ボタン。幅いっぱいに伸ばさない。
static func add_button(parent: Node, text: String, on_press: Callable) -> Button:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var b := button(row, text, on_press, FS_BODY)
	b.custom_minimum_size = Vector2(0, ROW_H - HAIR)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


## タブの中身を一枚の紙として見せる。札（タブ）と紙が繋がって、
## めくって切り替えている感じになる。
static func page_style(pad: int = PAD_S) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAGE
	sb.set_corner_radius_all(8)
	# 左上はタブが乗る側。角を落として、見出しから紙へ繋げる
	sb.corner_radius_top_left = 0
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.border_color = Color(0.46, 0.33, 0.21, 0.30)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.10)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


## 一覧の行と行を分ける細い線
static func hairline(parent: Node) -> void:
	var l := ColorRect.new()
	l.color = Color(0.46, 0.33, 0.21, 0.13)
	l.custom_minimum_size = Vector2(0, 1)
	parent.add_child(l)


## 霞みの丈。中身に重なる帯
const HEM_H := 44


## 縦スクロールする中身を包み、スクロールバーとの余白を作る。
## 下端は紙へ溶かす。文字が水平に切られていると、続きの合図ではなく壊れて見える。
##
## **霞みは中身に重ねる。** 巻物の「下の行」として並べていたので、
## 字が薄れるのではなく、下に 64px の帯が1本足されるだけだった。
## しかもべた塗りで粒が無いので、霞みではなく**仕切り**に見えていた
## （`hem_fade.gd`）。重ねるための器を1枚挟んで、内側の下端に張る。
static func scroll_body(parent: Node, fade: Color = PAGE) -> VBoxContainer:
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(scroll)

	var hem := HemFade.new()
	hem.setup(fade, grain_texture())
	hem.anchor_left = 0.0
	hem.anchor_right = 1.0
	hem.anchor_top = 1.0
	hem.anchor_bottom = 1.0
	hem.offset_top = -float(HEM_H)
	hem.offset_bottom = 0.0
	holder.add_child(hem)

	# 溶かすのは「まだ下に続いている」あいだだけ。
	# 終わりまで送ったのに霞んだままだと、読み終えたのに読めていないように見える。
	var bar := scroll.get_v_scroll_bar()
	var follow := func() -> void:
		var left: float = bar.max_value - bar.page - bar.value
		hem.modulate.a = clampf(left / 20.0, 0.0, 1.0)
	bar.value_changed.connect(func(_v: float) -> void: follow.call())
	bar.changed.connect(follow)
	follow.call()

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_right", SCROLL_GUTTER)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", GAP)
	pad.add_child(box)
	# 中の1枚まで送りたい呼び側（インスペクタ）が、器を辿れるように
	box.set_meta("scroll", scroll)
	return box


## 浮いている窓の見出し。題名と閉じるボタンを揃える。
static func window_header(parent: Node, title_text: String, on_close: Callable,
		col: Color = HEAD, tip: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_S)
	parent.add_child(row)
	row.add_child(label(title_text, FS_HEAD, col))
	if tip != "":
		help(row, tip)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	icon_button(row, "✕", "閉じる", on_close, 30, ROW_H, FS_SUB)
	return row


## アイコンだけのボタン。何のボタンかはツールチップで補う。
static func icon_button(parent: Node, glyph: String, tip: String, on_press: Callable,
		w: int = 32, h: int = ROW_H, size: int = FS_SUB) -> Button:
	var b := Button.new()
	b.text = glyph
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(w, h)
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


## いま選ばれている／開いていることが見えるボタン。
## 押せるだけで状態が見えないと、速度も窓の開閉も確かめようがない。
static func toggle_button(parent: Node, text: String, tip: String, on_press: Callable,
		w: int = 34, size: int = FS_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(w, ROW_H)
	var on := StyleBoxFlat.new()
	on.bg_color = WOOD
	on.set_corner_radius_all(6)
	on.content_margin_left = 8
	on.content_margin_right = 8
	on.content_margin_top = 4
	on.content_margin_bottom = 4
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_pressed_color", Color(0.97, 0.94, 0.87))
	b.add_theme_color_override("font_hover_pressed_color", Color(1, 0.99, 0.95))
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


## 神が押す、いちばん強いボタン。画面に1つだけ置く。
static func accent_button(parent: Node, text: String, on_press: Callable,
		size: int = FS_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, ROW_H + 6)
	var mk := func(a: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(ACCENT.r * a, ACCENT.g * a, ACCENT.b * a)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		return sb
	b.add_theme_stylebox_override("normal", mk.call(0.86))
	b.add_theme_stylebox_override("hover", mk.call(1.0))
	b.add_theme_stylebox_override("pressed", mk.call(0.72))
	b.add_theme_color_override("font_color", Color(0.99, 0.96, 0.90))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.99, 0.96, 0.90))
	parent.add_child(b)
	b.pressed.connect(on_press)
	return b


## 「ここは書き直せる」の印。**名前の字の直後**に置く。
##
## 右端に揃えると鉛筆が一列の柱になり、そこだけ表計算の顔になる。
## 字の末尾に付ければ、名前の長さでばらけて柱にならず、余白の書き込み印に見える。
##
## 常に出す。かざしたときだけ現れる形にすると、
## 「書き直せる」を伝えるという目的そのものに反する。
static func pencil_button(parent: Node, tip: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(30, ROW_H)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", flat_ink(INK_HOVER))
	parent.add_child(b)

	var icon := PencilIcon.new()
	icon.tint = TEXT_DIM
	b.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# かざすと濃くなる。押せるものだと分かる合図
	b.mouse_entered.connect(func() -> void:
		icon.tint = TEXT
		icon.queue_redraw())
	b.mouse_exited.connect(func() -> void:
		icon.tint = TEXT_DIM
		icon.queue_redraw())

	b.pressed.connect(on_press)
	return b


## 削除モードの切り替え。× は「閉じる」に見えるのでゴミ箱を描く。
static func trash_toggle(parent: Node, tip: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(34, ROW_H)
	parent.add_child(b)
	var icon := TrashIcon.new()
	icon.tint = TEXT
	b.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return b


static func line_edit_row(parent: Node, name_text: String, value: String,
		on_change: Callable, name_width: int = NAME_W) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	parent.add_child(row)
	var nm := label(name_text, FS_BODY, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)
	var le := LineEdit.new()
	le.text = value
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(92, ROW_H)
	row.add_child(le)
	le.text_changed.connect(on_change)
	return le


## 選択肢のラジオ印は要らないので、項目をアイコンなしのチェック表示にする。
static func dropdown(keys: Array, labels: Array, current: String) -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(104, ROW_H)
	opt.fit_to_longest_item = false
	var pop := opt.get_popup()
	pop.hide_on_checkable_item_selection = true
	for i in range(keys.size()):
		opt.add_item(String(labels[i]), i)
		pop.set_item_as_radio_checkable(i, false)
		pop.set_item_as_checkable(i, false)
		if String(keys[i]) == current:
			opt.select(i)
	return opt


## 世界にある物を選ぶ欄。絵と語と印を1つの罫線に収めて、「🌲 木 ▾」で1語に見せる。
## 絵が欄の外にあると、左の罫線に付いた飾りに見えてしまう。
static func icon_dropdown(art: String, keys: Array, labels: Array,
		current: String) -> Array:
	var field := PanelContainer.new()
	field.add_theme_stylebox_override("panel", ruled_style(0.03, 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_S)
	field.add_child(row)

	var icon := ItemIcon.of_art(art, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var opt := dropdown(keys, labels, current)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 器がもう罫線なので、中の欄は地のまま
	opt.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	opt.add_theme_stylebox_override("hover", flat_ink(INK_HOVER))
	opt.add_theme_stylebox_override("pressed", flat_ink(INK_ACTIVE))
	row.add_child(opt)
	return [field, opt, icon]


static func flat_ink(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(4)
	return sb


## keys と labels は同じ長さ。選ばれた key が on_change に渡る。
static func option_row(parent: Node, name_text: String, keys: Array, labels: Array,
		current: String, on_change: Callable, name_width: int = NAME_W) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	parent.add_child(row)
	var nm := label(name_text, FS_BODY, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)
	var opt := dropdown(keys, labels, current)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(opt)
	opt.item_selected.connect(func(i: int) -> void: on_change.call(String(keys[i])))
	return opt


static func check_row(parent: Node, name_text: String, value: bool, on_toggle: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = name_text
	cb.button_pressed = value
	parent.add_child(cb)
	cb.toggled.connect(on_toggle)
	return cb


## 数を増減する丸い判。四角いボタンが並ぶとスピナーに見える。
static func _round_button(glyph: String) -> Button:
	var b := Button.new()
	b.text = glyph
	b.add_theme_font_size_override("font_size", FS_NOTE)
	b.custom_minimum_size = Vector2(26, 26)
	var mk := func(col: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(13)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		return sb
	b.add_theme_stylebox_override("normal", mk.call(INK))
	b.add_theme_stylebox_override("hover", mk.call(INK_HOVER))
	b.add_theme_stylebox_override("pressed", mk.call(INK_ACTIVE))
	return b


## ラベル + −/数/+ の行。on_change(new_count) が呼ばれる。
## item を渡すと、名前の前に世界にあるものの絵が入る。
static func stepper_row(parent: Node, name_text: String, value: int, vmax: int,
		on_change: Callable, name_width: int = NAME_W, item: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_S)
	parent.add_child(row)
	if item != "":
		row.add_child(ItemIcon.of_item(item, 22))
	var nm := label(name_text, FS_BODY, TEXT)
	nm.custom_minimum_size = Vector2(name_width, 0)
	row.add_child(nm)

	var minus := _round_button("−")
	row.add_child(minus)

	var val := label(str(value), FS_BODY, TEXT if value > 0 else TEXT_DIM)
	val.custom_minimum_size = Vector2(24, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)

	var plus := _round_button("＋")
	row.add_child(plus)

	var count := [value]
	var apply := func(d: int) -> void:
		count[0] = clampi(count[0] + d, 0, vmax)
		val.text = str(count[0])
		val.add_theme_color_override("font_color", TEXT if count[0] > 0 else TEXT_DIM)
		on_change.call(count[0])
	minus.pressed.connect(func() -> void: apply.call(-1))
	plus.pressed.connect(func() -> void: apply.call(1))
	return row


## 折りたたみ。中身を入れる VBoxContainer を返す。
static func collapsible(parent: Node, title: String, open: bool = false) -> VBoxContainer:
	var head := Button.new()
	head.text = ("▼ " if open else "▶ ") + title
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.custom_minimum_size = Vector2(0, ROW_H)
	parent.add_child(head)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", HAIR)
	body.visible = open
	parent.add_child(body)
	head.pressed.connect(func() -> void:
		body.visible = not body.visible
		head.text = ("▼ " if body.visible else "▶ ") + title
	)
	return body


## 間を空ける。h には余白の段（HAIR / GAP_S / GAP / PAD）だけを渡す。
static func spacer(parent: Node, h: int = GAP_S) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	parent.add_child(c)


static func _fmt(x: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(x))
	if step >= 0.1:
		return "%.1f" % x
	return "%.2f" % x
