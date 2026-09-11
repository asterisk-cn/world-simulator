class_name Inner
## 村人の内側を言葉にする。AIに渡すのはここが作った1枚だけ。
##
## 気持ちの一言（`feeling.gd`）も、次に何をするか（`brain.gd`）も、
## 同じ姿を見て答える——**同じ人を二度違う形で語らない**ために1か所にまとめてある。
##
## 渡すのは世界が知っていることだけ（DESIGN.md §1）。
## それをどう受け取るかは書かない。


## その人の姿を言葉にする。**神が付けた名前のまま**渡す——言い換えると、
## 神がこの世界に置いた言葉ではないものが村人の口から出る。
## 何を訊くか（気持ちか、次の手か）は呼ぶ側が後ろに足す
static func of(v) -> String:
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
	return "\n".join(out)
