class_name Recall
## 【AI差し替え口】夜、覚えていることを書き直す。
##
## 渡すのは「これまで覚えていた文章」と「その日あったこと」、返るのは新しい文章1つ
## （100字以内、`Memory.STORY_MAX`）。日ごとの行を並べるのではなく、毎晩まるごと書き直す。
##
## **何を覚えていて何を忘れるかは、本人が決める**（DESIGN.md §6）。
## プログラムがやれるのは「どの型の出来事が何件あったか」を数えることだけで、
## それは要約ではなく集計になる——`歩き回っていた`『使用 が多い一日だった』は、
## 何が起きたかを一つも語っていない。
##
## 訊くのは1日1回・一人ぶんなので、判断の問い（毎分8回）に比べれば無視できる。
## 返事を待つあいだ村人は止まらない——夜は勝手に明けるし、
## 返事が届くまでは、覚えていることは昨日のまま。

## 頼む長さの目安。上限（`Memory.STORY_MAX`）ちょうどを頼むと張り付いて、
## 超えたぶんが文の途中で切れる（実測16件中3件）。8割を頼み、上限は切る位置として残す
const AIM := Memory.STORY_MAX * 8 / 10

## 出力の上限。100字の文章1つしか要らないので細い
const MAX_OUT := 300


## その日を畳む。**繋がっていなければ規則のまま**（穴は穴として残す）
static func ask(v, day: int) -> void:
	if v == null or not is_instance_valid(v):
		return
	if not AI.available() or v.memory.episodes.is_empty():
		v.memory.nightly_compress(v.vname, day)
		return

	var said := prompt(v, day)
	var id: int = v.id
	# **畳むのは返事が来てから。** 先に空けると、一往復のあいだ本人は
	# 今日の帳面も今日のぶんの記憶も持たない（外で2秒、この機械の中で12秒）。
	# 落とすのは訊いた時点にあったぶんだけ——待つあいだに起きたことは明日のもの
	var had: int = v.memory.episodes.size()
	var take := func(text: String) -> void:
		if not is_instance_valid(v) or v.id != id:
			return
		var story := _one_text(text)
		if story == "":
			v.memory.append_tally(v.memory.tally(v.vname, day))
		else:
			v.memory.rewrite(story)
		v.fold_day(had)
		EventLog.mind(v.vname, "覚えた：%s" % v.memory.story)
	if not AI.ask(said, system(), take, MAX_OUT, false, -1):
		v.memory.append_tally(v.memory.tally(v.vname, day))
		v.fold_day(had)


static func system() -> String:
	return """あなたは、ある村に住む一人の人間です。
一日の終わりに、これまで覚えていたことと今日あったことから、
覚えていることを**文章1つ**に書き直します。

- %d字くらい。改行しない
- **覚えておきたいことだけ**を書く
- 前から覚えていたことも、まだ覚えていたければ残す。要らなければ落とす
- 時刻や数は、覚えておきたいときだけ書く
- 渡されていないものを持ち出さない
- 説明も理由も書かない""" % AIM


static func prompt(v, _day: int) -> String:
	var out := PackedStringArray()
	# 姿は `Inner` を使わないが、**言葉は同じものを初めに**（どの問いも同じ言葉の上で答える）
	out.append(Inner.words(v.world))
	out.append("")
	out.append("# あなた")
	out.append("名前：%s" % v.vname)
	out.append("性格：%s" % v.personality.quirk)

	# **持っているぶんは全部渡す。** 書き直すのは本人なので、
	# 前の文章を見ないと「まだ覚えていたい」を残せない
	out.append("")
	out.append("# これまで覚えていること")
	out.append(v.memory.story if v.memory.story != "" else "（まだ何もない）")

	out.append("")
	out.append("# 今日あったこと")
	for e in v.memory.episodes:
		out.append("・%s" % String(e))

	return "\n".join(out)


## 改行は詰めて1つの文章にする。長すぎるぶんは `Memory.rewrite` が切る
static func _one_text(text: String) -> String:
	var parts := PackedStringArray()
	for l in text.strip_edges().split("\n", false):
		var t := String(l).strip_edges()
		if t != "":
			parts.append(t)
	return "".join(parts)
