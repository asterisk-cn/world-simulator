class_name Inner
## 村人の内側を言葉にする。AIに渡すのはここが作った1枚だけ。
##
## 気持ちの一言（`feeling.gd`）も、次に何をするか（`brain.gd`）も、
## 同じ姿を見て答える——**同じ人を二度違う形で語らない**ために1か所にまとめてある。
##
## 渡すのは世界が知っていることだけ（DESIGN.md §1）。
## それをどう受け取るかは書かない。


## 言葉の幅。**書かずに読む**——幅は神が決めるものなので、
## 幅を決め打ちで書くと、変えた瞬間に嘘になる（実際 100 から 10 に変えた）。
## 全部同じ幅なら見出しに一度だけ、違うなら行ごとに添える
static func _span(defs: Array) -> String:
	if defs.is_empty():
		return ""
	var lo := float(defs[0]["min"])
	var hi := float(defs[0]["max"])
	for d in defs:
		if float(d["min"]) != lo or float(d["max"]) != hi:
			return ""   # 揃っていない。行ごとに出す
	return "（%d〜%d）" % [int(lo), int(hi)]


## 前に考えてから増えた行に付ける印。**別枠に分けない**——分けると
## 今日の流れが二つに割れて、どちらが先に起きたかが紙から読めなくなる
const NEW := "★"


## 今日あったこと。**間引かない。** 8行に詰めていた頃は、どの行を落とすかを
## こちらが決めていた（同じ型は半分まで）——それは何が大事かの判断で、
## 帳面は薄めないという決めごと（DESIGN.md §6）にも外れる。
## 一日は 60〜70 手ほどなので、全部渡しても紙に収まる
static func _today(rows: Array, since: int) -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(rows.size()):
		out.append("%s%s" % [NEW if since >= 0 and i >= since else "・", String(rows[i])])
	return out


## この世界の言葉。**神が置いた言葉を、全部、名前のまま。**
## 渡していなかった頃は、AIは自分の値・持ち物・会った相手からしか
## この世界を知らず、無いもの（小川・ウサギ）を作り、在るもの（まだ会っていない
## 村人、まだ建っていない建物）は知らなかった。どれをどう使うかは言わない
static func words(world) -> String:
	var out := PackedStringArray()
	out.append("# この世界の言葉")
	out.append("じぶん：%s" % "・".join(_labels(Schema.self_params())))
	out.append("あいて：%s" % "・".join(_labels(Schema.pair_params())))
	var items := PackedStringArray()
	for item in Schema.all_items():
		items.append(Schema.item_label(String(item)))
	out.append("もちもの：%s" % "・".join(items))
	var builds := PackedStringArray()
	for b in Schema.buildings:
		builds.append(String(b["label"]))
	out.append("たてもの：%s" % "・".join(builds))
	var names := PackedStringArray()
	if world != null:
		for v in world.villagers:
			if is_instance_valid(v):
				names.append(String(v.vname))
	out.append("村人：%s" % "・".join(names))
	return "\n".join(out)


static func _labels(defs: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for d in defs:
		out.append(String(d["label"]))
	return out


## その人の姿を言葉にする。**神が付けた名前のまま**渡す——言い換えると、
## 神がこの世界に置いた言葉ではないものが村人の口から出る。
## 何を訊くか（気持ちか、次の手か）は呼ぶ側が後ろに足す。
## **初めはこの世界の言葉**（`words`）——どの問いも同じ言葉の上で答える。
## `since` は前に考えたときの帳面の位置。そこから先の行に印が付く（判断の問いだけ。
## 気持ちや会話の問いには「前に考えた」が無いので -1 のまま）
static func of(v, since: int = -1) -> String:
	var out := PackedStringArray()
	out.append(words(v.world))
	out.append("")
	out.append("# あなた")
	out.append("名前：%s" % v.vname)
	out.append("性格：%s" % v.personality.quirk)
	var axes := PackedStringArray()
	for a in Personality.AXES:
		var x: float = v.personality.axis(String(a[0]))
		axes.append(String(a[3]) if x >= 0.5 else String(a[2]))
	out.append("気質：%s" % ", ".join(axes))

	var mine := PackedStringArray()
	for d in Schema.self_params():
		var one := "%s %d" % [String(d["label"]),
			int(round(v.params.get_v(String(d["id"]))))]
		if _span(Schema.self_params()) == "":
			one += "（%d〜%d）" % [int(d["min"]), int(d["max"])]
		mine.append(one)
	if mine.size() > 0:
		out.append("")
		out.append("# あなたの感情%s" % _span(Schema.self_params()))
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
		out.append("# 知っている相手%s" % _span(Schema.pair_params()))
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

	# 【AI差し替え口】本人がいま感じていること（`villager/feeling.gd`）。
	# **世界の事実ではないが、本人のもの**なので渡す——渡さないと、
	# 20秒ごとの一言が毎回ゼロから作られて、心が続いているように見えない
	if String(v.feeling) != "":
		out.append("")
		out.append("# 今感じていること")
		out.append(String(v.feeling))

	var rows: Array = v.memory.episodes
	if not rows.is_empty():
		out.append("")
		if since >= 0 and since < rows.size():
			out.append("# 今日あったこと（%s は前に考えてから増えたこと）" % NEW)
		else:
			out.append("# 今日あったこと")
		out.append_array(_today(rows, since))

	if String(v.memory.story) != "":
		out.append("")
		out.append("# 覚えていること")
		out.append(String(v.memory.story))

	# 行き先は座標で渡している（`Brain._at`）ので、**起点もここに要る**。
	# 遠いか近いかを刻むのは世界の仕事ではない——引き算は読む側がやる
	out.append("")
	out.append("# いま")
	out.append("%d日目 %s" % [SimClock.day, SimClock.clock_text()])
	out.append("いるところ（%d, %d）" % [int(round(v.cell.x)), int(round(v.cell.y))])
	return "\n".join(out)
