class_name Recall
## 【AI差し替え口】夜、その日を一行に畳む。
##
## **何を覚えていて何を忘れるかは、本人が決める**（DESIGN.md §6）。
## プログラムがやれるのは「どの型の出来事が何件あったか」を数えることだけで、
## それは要約ではなく集計になる——`歩き回っていた`『使用 が多い一日だった』は、
## 何が起きたかを一つも語っていない。
##
## 訊くのは1日1回・一人ぶんなので、判断の問い（毎分8回）に比べれば無視できる。
## 返事を待つあいだ村人は止まらない——夜は勝手に明けるし、
## 要約が無い日は「覚えている過去」にその日が出ないだけ。

## 一行の長さ。読むのは本人（次の日の問いに出る）と神（紙）の両方
const MAX_CHARS := 48

## 出力の上限。一行しか要らないので細い
const MAX_OUT := 200


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
	# 今日の帳面も今日の一行も持たない（外で2秒、この機械の中で12秒）。
	# 落とすのは訊いた時点にあったぶんだけ——待つあいだに起きたことは明日のもの
	var had: int = v.memory.episodes.size()
	var take := func(text: String) -> void:
		if not is_instance_valid(v) or v.id != id:
			return
		var line := _one_line(text)
		if line == "":
			line = v.memory.tally(v.vname, day)
		v.memory.remember(line)
		v.fold_day(had)
		EventLog.mind(v.vname, "覚えた：%s" % line)
	if not AI.ask(said, system(), take, MAX_OUT, false, -1):
		v.memory.remember(v.memory.tally(v.vname, day))
		v.fold_day(had)


static func system() -> String:
	return """あなたは、ある村に住む一人の人間です。
一日の終わりに、その日を**一行**で思い返します。

- %d字以内。日付から始める（「3日目：」のように）
- **覚えておきたいことだけ**を書く。全部を並べない——
  忘れることを選ぶのも、思い出すことの一部
- 渡されていないものを持ち出さない
- 説明も理由も書かない""" % MAX_CHARS


static func prompt(v, day: int) -> String:
	var out := PackedStringArray()
	out.append("# あなた")
	out.append("名前：%s" % v.vname)
	out.append("ひとことで言うと：%s" % v.personality.quirk)

	# **持っているぶんは全部渡す。** 落ちる寸前の一行を本人が見ないなら、
	# 「まだ覚えていたい」を今日の一行に書き直すこともできない
	var past := String(v.memory.recent_summary(99))
	if past != "":
		out.append("")
		out.append("# これまで覚えていること")
		out.append(past)

	out.append("")
	out.append("# %d日目にあったこと" % day)
	for e in v.memory.episodes:
		out.append("・%s" % String(e))

	out.append("")
	out.append("この一日を、一行で。")
	return "\n".join(out)


static func _one_line(text: String) -> String:
	var s := text.strip_edges()
	var nl := s.find("\n")
	if nl >= 0:
		s = s.substr(0, nl).strip_edges()
	if s.length() > MAX_CHARS:
		s = s.substr(0, MAX_CHARS)
	return s
