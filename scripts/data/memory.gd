class_name Memory
extends RefCounted
## 記憶。夜になると生の履歴が要約に畳まれる。
##
## 【要検討】扱いは未決。DESIGN.md §6 を参照。

## 移動はその日を語る材料にならない。どこへ歩いたかではなく、何をしたかを残す。
const NOT_A_DEED := "移動"

var episodes: Array = []      ## 今日の生の出来事（文字列）
var summaries: Array = []     ## 過去の日ごとの要約
var read_posts := {}          ## post_id -> {"day": int, "belief": float}
var last_talk_day := {}       ## villager_id -> day


func record(text: String) -> void:
	episodes.append(text)
	if episodes.size() > 60:
		episodes.pop_front()


func mark_post_read(post_id: int, belief: float) -> void:
	read_posts[post_id] = {"day": SimClock.day, "belief": clampf(belief, 0.0, 2.0)}


func has_read_post(post_id: int) -> bool:
	return read_posts.has(post_id)


## 【AI差し替え口】本来はその日の出来事を渡して、
## 何を覚えていて何を忘れるか・どう要約するかをAIが決める。
func nightly_compress(owner_name: String, day: int) -> String:
	var summary := _summarize(owner_name, day)
	if summary != "":
		summaries.append(summary)
	var keep := int(SimConfig.p("summaries_kept"))
	while summaries.size() > keep:
		summaries.pop_front()
	episodes.clear()
	return summary


func _summarize(owner_name: String, day: int) -> String:
	if episodes.is_empty():
		return "%d日目：特に何もなかった。" % day
	var counts := {}
	var deeds := 0
	for e in episodes:
		var head: String = String(e).split("：")[0]
		if head == NOT_A_DEED:
			continue
		deeds += 1
		counts[head] = int(counts.get(head, 0)) + 1
	if deeds == 0:
		return "%d日目：%s は歩き回っていた。" % [day, owner_name]
	var busiest := ""
	var best := 0
	for k in counts:
		if counts[k] > best:
			best = counts[k]
			busiest = k
	# 出来事そのものは「今日の出来事」に並ぶので、要約は一行に留める
	return "%d日目：%s は %s が多い一日だった（%d件）" % [day, owner_name, busiest, deeds]


func recent_summary(n: int = 2) -> String:
	if summaries.is_empty():
		return "（覚えている過去はない）"
	return "\n".join(summaries.slice(maxi(0, summaries.size() - n)))
