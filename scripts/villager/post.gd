class_name Post
## 【AI差し替え口】掲示板に書く文。
##
## 手を選ぶのは Jev で、Jev は言葉を返さない（`Brain._read_jev`）。
## 会話の1行目を `Talk` に訊くのと同じく、**貼ると決まってから文面だけを訊く。**
## 何をするかは訊かない——ここで訊くのは紙に書く文そのもの。
##
## 訊くのは板の前に着いてから。書いているあいだ本人は板の前に立っていて、
## 返ったところで貼る（`Villager._write_tick`）。

## 文の長さ。手と一緒に返る「言うこと」・会話のひと言と揃える
## （切るのは `Talk._one_line` と同じ長さ）
const MAX_CHARS := Talk.MAX_CHARS

## 出力の上限。一行しか要らないので細い
const MAX_OUT := 150


## その人に、紙に書く文を訊く。返ったら `on_done` に渡す（空なら書かなかった）。
## 繋がっていなければ false
static func write(v, on_done: Callable) -> bool:
	if v == null or not is_instance_valid(v) or not AI.available():
		return false
	var id: int = v.id
	var take := func(text: String) -> void:
		if not is_instance_valid(v) or v.id != id:
			return
		on_done.call(Talk._one_line(text))
	return AI.ask(prompt(v), system(), take, MAX_OUT, false, -1)


## 世界の決めごと。**これからすることの説明を書かせない**——
## 「お知らせを貼ろう」は紙に書く文ではない（文章の問いでも同じ縛りをしている）
static func system() -> String:
	return """あなたは、ある村に住む一人の人間です。
いま村の掲示板の前にいて、紙を1枚貼ります。**紙に書く文だけ**を書きます。

- %d字以内。読むのは、通りかかった村の誰か
- 「何か伝えたい」「お知らせを貼ろう」のような、これからすることの説明を書かない
- もう貼ってある紙と同じことは書かない
- 書きたいことが無ければ、何も書かずに空で返す
- 鍵括弧や引用符で囲まない。説明も理由も書かない""" % MAX_CHARS


## 訊くときに渡すもの。姿は `Inner` が作る（手も会話も同じ姿を見る）。
## **板にいま貼ってある紙も並べる**——目の前にあるものなので、本人に見えている
static func prompt(v) -> String:
	var out := PackedStringArray()
	out.append(Inner.of(v))
	out.append("")
	out.append("# 掲示板にいま貼ってある紙")
	var board = v.world.board if v.world != null else null
	if board == null or board.posts.is_empty():
		out.append("・（何も貼られていない）")
	else:
		for e in board.posts:
			out.append("・（%s）%s" % [String(e["author_name"]), String(e["text"])])
	out.append("")
	out.append("紙に何と書く？")
	return "\n".join(out)
