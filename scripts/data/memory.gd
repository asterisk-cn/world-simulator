class_name Memory
extends RefCounted
## 記憶。夜になると生の履歴が要約に畳まれる。
##
## **持ち主は三者。** その日の帳面は世界、覚えていることは本人（夜に畳む、
## `villager/recall.gd`）、器の大きさは神（`覚えていられる日数`）。DESIGN.md §6。

## 移動はその日を語る材料にならない。どこへ歩いたかではなく、何をしたかを残す。
const NOT_A_DEED := "移動"

var episodes: Array = []      ## 今日の生の出来事（文字列）
var summaries: Array = []     ## 過去の日ごとの要約
## どの紙が目に入ったか。**世界の事実**（可視性の一部）なので、ここが持つ。
## どう受け取ったかは本人の話で、読んだことが出来事として次の問いに渡る
var read_posts := {}          ## post_id -> {"day": int}
var last_talk_day := {}       ## villager_id -> day


## その日の帳面に書く。**一日ぶんは全部持つ**——夜に本人が畳むまでに
## 世界が頭から捨てると、本人が見ていないものを世界が忘れさせたことになる。
## 上限は歯止めで、忘却ではない（1日は 60〜70 手ほど）
const KEEP := 300

func record(text: String) -> void:
	episodes.append(text)
	if episodes.size() > KEEP:
		episodes.pop_front()


## **信じた度合いは持たない。** それは判断で、世界の欄ではない
func mark_post_read(post_id: int) -> void:
	read_posts[post_id] = {"day": SimClock.day}


func has_read_post(post_id: int) -> bool:
	return read_posts.has(post_id)


## 【AI差し替え口】その日を畳むのは本人（`villager/recall.gd`）。
## **繋がっていないときだけ**、ここの集計が穴を埋める。
func nightly_compress(owner_name: String, day: int) -> String:
	var summary := tally(owner_name, day)
	remember(summary)
	fold(episodes.size())
	return summary


## 覚えておく一行を足す。覚えていられる日数を超えたぶんは、古いほうから落ちる
func remember(line: String) -> void:
	if line == "":
		return
	summaries.append(line)
	var keep := int(SimConfig.p("summaries_kept"))
	while summaries.size() > keep:
		summaries.pop_front()


## その日の帳面を閉じる。**畳んだあとは生の出来事を持たない**——
## 何を残すかは畳むときに決まっているので、両方持つと
## 「本人が忘れたもの」が残っていることになる。
##
## 落とすのは**訊いたときにあったぶんだけ**。返事を待つあいだに起きたことは
## 明日の帳面に残す（夜の一往復は、外で2秒・この機械の中で12秒かかる）
func fold(n: int) -> int:
	var drop: int = mini(n, episodes.size())
	for i in range(drop):
		episodes.pop_front()
	return drop


## 数えただけの一行。**要約ではない**（何が起きたかを一つも語っていない）。
## 判断する者が居ないときの穴埋めとして残してある
func tally(owner_name: String, day: int) -> String:
	return _summarize(owner_name, day)


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
