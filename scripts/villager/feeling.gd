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

## 一言の長さ。紙の幅（384px）と字の段（`FS_HEAD`）で、2行に収まるところまで。
## それ以上伸ばすと段落になって、「一言」ではなくなる
const MAX_CHARS := 32

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


## 訊くときに渡すもの。姿は `Inner` が作る（気持ちも次の手も同じ姿を見る）
static func prompt(v) -> String:
	return Inner.of(v) + "\n\nいまの気持ちを一行で。"


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
