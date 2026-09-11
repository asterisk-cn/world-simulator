class_name ChapterIndex
extends HBoxContainer

## 巻物の目次。**箱でも札でもなく、1行の字**にする。
##
## 下線も枠も影も持たない。いま見ている章だけ見出しと同じ色になるので、
## 目次と本文が繋がる。まだ何も書かれていない章は淡く出す
## （「手つかずの値は薄く見せる」を章の名前にも通す。DESIGN.md §9）。
##
## **「・」で繋がない。** 名詞を「・」で繋いだ1行は日本語では列挙——
## 題のすぐ下にあると、押せる行き先ではなく紙の副題として読まれる。
## 語のあいだは余白（`GAP`）で空ける。
##
## 設計図と村人の紙が同じ形を要るので、ここに1つだけ置く——
## **同じ紙の中は同じ文法で並べる**（DESIGN.md §9）。
## 章が1つしか無い紙では自分から隠れるので、呼ぶ側は数を気にしなくていい。

## 章まで送るのにかける間
const GLIDE := 0.25

var _scroll: ScrollContainer
## 章の見出し行。目次の行き先と、いまどの章を見ているかの判定に使う
var _chapters: Array = []      ## [{name, row}]
var _btns: Array = []
var _here := 0
var _glide: Tween = null
## 送っているあいだ。**押した章が勝つ**ので、紙の位置から読み直さない
var _sending := false


func _init() -> void:
	add_theme_constant_override("separation", UIKit.GAP)


## 送る先の巻物（`UIKit.scroll_body` の返り）を教える。1度でいい
func follow(body: VBoxContainer) -> void:
	if body == null or not body.has_meta("scroll"):
		return
	_scroll = body.get_meta("scroll")
	_scroll.get_v_scroll_bar().value_changed.connect(
		func(_v: float) -> void: mark_here())


## 組み直しの前に。行はもう消えているので、覚えも捨てる
func clear() -> void:
	_chapters.clear()


## 章の見出しを立て、目次の行き先としても覚える。
## 見出しの形は `UIKit.heading` そのまま——目次のために章の見え方を変えない
## `empty` はまだ何も書かれていない章。目次では淡く出す
func chapter(body: Node, name_text: String, tip: String = "",
		empty: bool = false) -> HBoxContainer:
	var row := UIKit.heading(body, name_text, tip)
	remember(name_text, row, empty)
	return row


## 見出しを自分で立てた章（畳める章など）を、目次にだけ加える
func remember(name_text: String, row: Control, empty: bool = false) -> void:
	_chapters.append({"name": name_text, "row": row, "empty": empty})


## 章を並べ終えたら呼ぶ
func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_btns.clear()
	if _chapters.size() <= 1:
		visible = false
		return
	visible = true
	for i in range(_chapters.size()):
		var b := Button.new()
		b.text = String(_chapters[i]["name"])
		# **章の名前は章の名前の顔で出す。** 本文の段（`FS_BODY`）で注の色だと、
		# 目次が「注」として読まれる。見出し（18）の一段下（`FS_SUB`）に置く
		b.add_theme_font_size_override("font_size", UIKit.FS_SUB)
		# 押せる箱ではなく、字そのもの。下地も枠も持たない
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.add_theme_color_override("font_hover_color", UIKit.TEXT)
		add_child(b)
		b.pressed.connect(glide_to.bind(i))
		_btns.append(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(gap)
	mark_here.call_deferred()


## その章まで送る。**するすると動かす**——即座に飛ぶと、
## 紙を送ったのではなく面が入れ替わったように見える。
func glide_to(i: int) -> void:
	if i < 0 or i >= _chapters.size() or _scroll == null:
		return
	var row: Control = _chapters[i]["row"]
	if not is_instance_valid(row):
		return
	# **押した指が勝つ。** 送り終わりの位置から読み直すと、
	# 送りきれない短い巻物では別の章が光る（押した章と目次が食い違う）
	_here = i
	_paint()
	_sending = true
	# 章の上の余白（`PAD`）は残して止める
	var to: float = maxf(row.position.y - float(UIKit.PAD), 0.0)
	if _glide != null and _glide.is_valid():
		_glide.kill()
	_glide = create_tween()
	_glide.tween_property(_scroll, "scroll_vertical", int(to), GLIDE) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 神が自分で送り始めたら、また紙の位置から読む
	_glide.tween_callback(func() -> void: _sending = false)


## いま読んでいる章。見出しが紙の上端を越えた最後のものがそれ。
func mark_here() -> void:
	if _scroll == null or _btns.is_empty() or _sending:
		return
	var at := float(_scroll.scroll_vertical) + float(UIKit.PAD) + 1.0
	var found := 0
	for i in range(_chapters.size()):
		var row: Control = _chapters[i]["row"]
		if is_instance_valid(row) and row.position.y <= at:
			found = i
	# 最後の章は、その下に送るぶんの紙が無いので上端を越えられない。
	# 終わりまで送ったら最後の章に居る、と決める。
	var bar := _scroll.get_v_scroll_bar()
	if bar.max_value - bar.page - bar.value <= 1.0:
		found = _chapters.size() - 1
	_here = found
	_paint()


## いまどの章に居るかを字の色で言う。
##
## **色は見出しの家系（`HEAD`）のまま薄める。** 注の色（`TEXT_DIM`）に落とすと、
## 章の名前ではなく紙の注釈になる。いまの章が濃く、まだ読んでいない章が薄く、
## 手つかずの章はさらに薄い——神が何を決め残しているかが目次だけで読める
const DIM := 0.55    ## いま居ない章
const UNWRIT := 0.30 ## まだ何も書かれていない章

func _paint() -> void:
	for i in range(_btns.size()):
		var a := DIM
		if i == _here:
			a = 1.0
		elif bool(_chapters[i].get("empty", false)):
			a = UNWRIT
		_btns[i].add_theme_color_override("font_color",
			Color(UIKit.HEAD.r, UIKit.HEAD.g, UIKit.HEAD.b, a))
