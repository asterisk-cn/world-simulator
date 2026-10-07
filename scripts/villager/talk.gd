class_name Talk
## 【AI差し替え口】会話のひと言。
##
## 会話は**2往復で1つの場面**。話しかけた人の手として始まり、そこで終わる
## （DESIGN.md §3 の「手」——場面ぜんぶで一手）。
##
## **相手の手は止めない。** 相手はいましていることを続けたまま、言葉だけ返す。
## 話しかけられるたびに予定が白紙になっていた頃は、会話が村を支配して
## 一日の手の97%が「話す」になった。**無視も返しのうち**で、それは世界の上の
## 行動ではなく、この場面の中の言葉として出る。
##
## ここで訊くのは**言葉だけ**。何をするかは訊かない——手を選ぶのは Jev の
## 仕事で、会話はその手の中身。だから返事を待つあいだ相手は止まらない。

## ひと言の長さ。世界の上の吹き出しにも記録にも収まるところまで
const MAX_CHARS := 40

## 出力の上限。一行しか要らないので細い
const MAX_OUT := 150


## その人に、次のひと言を訊く。返ったら `on_done` に渡す。
## 繋がっていなければ false（場面はそこで畳まれる）
static func reply(speaker, other, scene: Array, on_done: Callable) -> bool:
	if speaker == null or not is_instance_valid(speaker) or not AI.available():
		return false
	var id: int = speaker.id
	var take := func(text: String) -> void:
		if not is_instance_valid(speaker) or speaker.id != id:
			return
		on_done.call(_one_line(text))
	return AI.ask(prompt(speaker, other, scene), system(), take, MAX_OUT, false, -1)


## 世界の決めごと。**同じ行を二度言わせない**のがここの仕事——
## 渡しているのが「直近に起きたこと」だけだった頃、二人が一時間、
## 相手の台詞をそのまま返し合って、中身を一つも言わないことがあった。
##
## 逆に「話を先へ進める」と強く言うと、無いものを作る方へ効いた
## （アオバナ・小川・ウサギ——どれもこの村に無い）。いまは**新しい名前**の
## ほうを締めている。世界に何が在るかの一覧は渡していないので、
## 縛るなら名前の数を絞るほうが、嘘の少ない縛りかたになる
static func system() -> String:
	return """あなたは、ある村に住む一人の人間です。
いま目の前の人と話しています。**返す言葉だけ**を書きます。

- %d字以内で会話をする。
- 相手が言ったことを言い換えて返さない。同じことを二度言わない
- 新しい名前はあまり出さないようにする
- 返したくないことは書かなくていい。**黙るのも返事のうち**で、
  そのときは何も書かずに空で返す
- 鍵括弧や引用符で囲まない。説明も理由も書かない""" % MAX_CHARS


## 訊くときに渡すもの。姿は `Inner` が作る（気持ちも次の手も同じ姿を見る）。
## **いまの会話は、出来事の列とは別に並べる**——帳面に混ざっていると
## どこからが今の話か分からず、毎回ほぼ同じ紙が届いて同じ答えが返る
static func prompt(speaker, other, scene: Array) -> String:
	var out := PackedStringArray()
	out.append(Inner.of(speaker))
	out.append("")
	out.append("# いま %s と話している" % other.vname)
	for e in scene:
		out.append("・%s——%s" % [String(e["who"]), String(e["words"])])
	out.append("")
	out.append("何と返す？")
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
