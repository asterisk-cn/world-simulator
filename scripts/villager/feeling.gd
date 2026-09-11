class_name Feeling
## 【AI差し替え口】村人の「いまの気持ち」を一行だけ訊く。
##
## **規則では作れない。** 言葉（パラメータ）の名前は神が自由に付けるので、
## 「空腹 が 72」を「腹が減った」と言い換える辞書をプログラムは持てない。
## 世界が知っているのは何が起きたかだけで、それをどう感じているかはAIの担当
## （DESIGN.md §2）。だから仕様もここをAI生成としている。
##
## 訊くのは**神がいま見ている村人だけ**。8人ぶんを常に訊くと、
## 誰も読まない一言のために毎分お金が出ていく。
##
## 繋がっていなければ何も起きない（`AI.available()` が false）。
## 紙は一言の行が無いまま出る——嘘の一言を規則で埋めるより、無いほうがいい。

## 一行の長さ。長いと紙の上で2行になって「一言」でなくなる
const MAX_CHARS := 24

## 同じ人に訊き直さない間（実時間の秒）。
## していることが変わったら訊き直すが、それが速いときの底になる
const COOL := 6.0

## 出力の上限。一行しか要らないので細い（`AI.MAX_OUT` の但し書きに注意——
## 考えるモデルに替えるなら、思考ぶんのぶん広げる）
const MAX_OUT := 200


## その村人に訊く。返ったら `v.feeling` に入る（呼び側は次の差し替えで拾う）
static func ask(v) -> void:
	if v == null or not is_instance_valid(v) or not AI.available():
		return
	var act := String(v.action_label())
	var now := float(Time.get_ticks_msec()) / 1000.0
	# していることが同じなら、気持ちも同じでいい
	if v.feeling != "" and v.feeling_for == act:
		return
	if now - v.feeling_at < COOL:
		return
	v.feeling_at = now
	v.feeling_for = act
	# 返るまでに選び直されている／死んでいることがあるので、本人か確かめる
	var id: int = v.id
	var take := func(text: String) -> void:
		if is_instance_valid(v) and v.id == id and text != "":
			v.feeling = _one_line(text)
	AI.ask(prompt(v), system(), take, MAX_OUT)


## 世界の決めごと。**神が与えた言葉の外へ出さない**のがここの仕事
static func system() -> String:
	return """あなたは、ある村に住む一人の人間です。
渡された言葉と数字だけを使って、その人が「いま何を感じているか」を書きます。

- %d字以内の一行。句点は付けない
- 数字をそのまま言わない（「空腹 72」ではなく「腹が減った」）
- 渡されていないものを持ち出さない。この世界にあるのは、
  渡した言葉・持ち物・相手の名前だけ
- 説明も理由も書かない。心の中の声そのものを書く
- 鍵括弧や引用符で囲まない""" % MAX_CHARS


## 訊くときに渡すもの。**神が付けた名前のまま**渡す——言い換えると、
## 神がこの世界に置いた言葉ではないものが村人の口から出る
static func prompt(v) -> String:
	var out := PackedStringArray()
	out.append("# あなた")
	out.append("名前：%s" % v.vname)
	out.append("ひとことで言うと：%s" % v.personality.quirk)
	var axes := PackedStringArray()
	for a in Personality.AXES:
		var x: float = v.personality.axis(String(a[0]))
		axes.append(String(a[3]) if x >= 0.5 else String(a[2]))
	out.append("気質：%s" % ", ".join(axes))

	var mine := PackedStringArray()
	for d in Schema.self_params():
		mine.append("%s %d" % [String(d["label"]),
			int(round(v.params.get_v(String(d["id"]))))])
	if mine.size() > 0:
		out.append("")
		out.append("# あなたの中にあるもの（0〜100）")
		out.append(" / ".join(mine))

	var others := PackedStringArray()
	for oid in v.pairs.keys():
		var pp = v.pair_peek(int(oid))
		var other = v.world.villager_by_id(int(oid)) if v.world != null else null
		if pp == null or other == null:
			continue
		var vals := PackedStringArray()
		for d in Schema.pair_params():
			vals.append("%s %d" % [String(d["label"]),
				int(round(pp.get_v(String(d["id"]))))])
		others.append("%s：%s" % [String(other.vname), " / ".join(vals)])
	if others.size() > 0:
		out.append("")
		out.append("# 知っている相手（−100〜100）")
		out.append_array(others)

	# **名前で渡す。** `wood` のような中の呼び名を渡すと、
	# この世界に無い言葉が村人の口から出る（神が付けたのは「木」のほう）
	var hands := PackedStringArray()
	for item in Schema.all_items():
		var iid := String(item)
		var n: int = v.item_count(iid)
		if n > 0:
			hands.append("%s %d" % [Schema.item_label(iid), n])
	out.append("")
	out.append("# 持っているもの")
	out.append(" / ".join(hands) if hands.size() > 0 else "手ぶら")

	out.append("")
	out.append("# していること")
	out.append(v.action_label())

	if not v.memory.episodes.is_empty():
		out.append("")
		out.append("# 今日あったこと")
		for e in v.memory.episodes.slice(maxi(v.memory.episodes.size() - 8, 0)):
			out.append("・%s" % String(e))

	var past := String(v.memory.recent_summary(2))
	if past != "":
		out.append("")
		out.append("# 覚えていること")
		out.append(past)

	out.append("")
	out.append("# いま")
	out.append("%d日目 %s" % [SimClock.day, SimClock.clock_text()])
	out.append("")
	out.append("いまの気持ちを一行で。")
	return "\n".join(out)


## 一行に詰める。囲みを取り、長すぎたら切る
static func _one_line(text: String) -> String:
	var s := text.strip_edges()
	var nl := s.find("\n")
	if nl >= 0:
		s = s.substr(0, nl).strip_edges()
	for pair in [["「", "」"], ["\"", "\""], ["'", "'"]]:
		if s.begins_with(String(pair[0])) and s.ends_with(String(pair[1])):
			s = s.substr(1, s.length() - 2).strip_edges()
	if s.length() > MAX_CHARS:
		s = s.substr(0, MAX_CHARS)
	return s
