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


## その人の姿を言葉にする。**神が付けた名前のまま**渡す——言い換えると、
## 神がこの世界に置いた言葉ではないものが村人の口から出る。
## 何を訊くか（気持ちか、次の手か）は呼ぶ側が後ろに足す
## `skip_tail` は**呼ぶ側が別に見せるぶん**。判断の問いは「前に考えてから
## 起きたこと」を自分で並べるので、そのぶんをここで出すと**同じ行を二度渡す**ことになる
static func of(v, skip_tail: int = 0) -> String:
	var out := PackedStringArray()
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

	if v.memory.episodes.size() > skip_tail:
		out.append("")
		out.append("# 今日あったこと")
		var upto: int = maxi(v.memory.episodes.size() - skip_tail, 0)
		for e in v.memory.episodes.slice(maxi(upto - 8, 0), upto):
			out.append("・%s" % String(e))

	var past := String(v.memory.recent_summary(2))
	if past != "":
		out.append("")
		out.append("# 覚えていること")
		out.append(past)

	# 行き先は座標で渡している（`Brain._at`）ので、**起点もここに要る**。
	# 遠いか近いかを刻むのは世界の仕事ではない——引き算は読む側がやる
	out.append("")
	out.append("# いま")
	out.append("%d日目 %s" % [SimClock.day, SimClock.clock_text()])
	out.append("いるところ（%d, %d）" % [int(round(v.cell.x)), int(round(v.cell.y))])
	return "\n".join(out)
