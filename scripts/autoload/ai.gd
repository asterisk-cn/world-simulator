extends Node
## AIへの口。**世界の外にいる相手に一行だけ訊く**ための1本道。
##
## この作品の一線は「世界で何が起きたかはプログラム、それをどう受け取るかはAI」
## （DESIGN.md §2）。ここはその後ろ半分を運ぶだけの管で、判断は何も持たない。
## 何を訊くかは呼ぶ側（`villager/brain.gd`・`villager/feeling.gd`）が組む。
##
## **繋がっていなくても世界は動く。** 鍵が無ければ `available()` が false になり、
## 呼び側は自分で決めるか、何も出さないかを選ぶ。時間も村人も止めない——
## AIは世界の部品ではなく、村人の内側を答える相手なので、
## 居ないなら内側が読めないだけで済む。
##
## GDScript には公式SDKが無いので、素の HTTP（`HTTPRequest`）で叩く。
## 相手は OpenAI の chat completions——**受け答えの形がいちばん素直**で、
## 返るのが `choices[0].message.content` の1本だけなので、管が薄く保てる。

## **どこに訊くか。** 預け先（OpenAI）と、この機械の中（ollama）の2つ。
## ollama も同じ形で受けるので、変わるのは宛先と鍵の要不要だけ。
##
## **普段は預け先。この機械の中は検証用。** 8B で1つの答えに12秒かかり、
## 村が要る速さ（毎秒2.5手）に4〜5倍届かない——鍵を使わずに一通り動かしたいときと、
## 問いの形を確かめたいときのためのもの（実測は LOG.md）。
##
## 選び方は起動時に決まる（`_find_where`）。
##   `OLLAMA_MODEL`（または `res://.ollama-model`）が置いてあれば、この機械の中へ
##   そうでなければ預け先へ。鍵が無ければ訊けない
## **どちらも無ければ、世界は穴のまま自分で決めて動く。**
const OPENAI_URL := "https://api.openai.com/v1/chat/completions"
const OLLAMA_URL := "http://localhost:11434/v1/chat/completions"
const ENV_OLLAMA_MODEL := "OLLAMA_MODEL"
const ENV_OLLAMA_URL := "OLLAMA_URL"     ## 別の機械に置いてあるとき
const OLLAMA_FILE := "res://.ollama-model"  ## 作りながら試すとき用

## 鍵の置き場。**リポジトリには入れない**（`.gitignore`）。
## 遊ぶ側の鍵は `user://` に置く（書き出した本体からも読める）。
## `res://` のほうは作りながら試すためのもので、書き出すと中に入ってしまうので、
## 配るときは置かない。
const KEY_FILE := "user://openai.key"
const DEV_KEY_FILE := "res://.openai-key"
const ENV_KEY := "OPENAI_API_KEY"

## どのモデルに訊くか。**ここ1行を変えれば替わる。**
## （この機械の中に訊くときは `OLLAMA_MODEL` のほうが使われる）
const MODEL := "gpt-4o-mini"

## 思考の深さ。**gpt-4o 系には無い口**（o系・gpt-5 だけ）なので空にしてある。
## 考えるモデルに替えるときは "low" などを入れる
const REASONING := ""

## この機械の中のモデルへの「考えるな」。**これが効かないと使い物にならない。**
## qwen3 は既定で考えるうえ、思考は `content` ではなく別の欄（`reasoning`）に出る。
## つまり枠 200 を思考で使い切って、**中身は空のまま 200 が返る**
## （こちらでは失敗として扱われ、村人は自分で決めてしまう）。
## 試したうち効いたのはこれだけ——`/no_think` も `think: false` も無視された。
## 欲しいのは番号1つと短い呼び名なので、考えてもらう必要がない
const LOCAL_REASONING := "none"

## 出力の上限。欲しいのは短い答えなので細くていい。
## ただし**考えるモデルでは思考ぶんも同じ枠から出る**ので、
## そちらに替えるときは 700 ほどまで広げる（細いと思考で使い切って空が返る）
const MAX_OUT := 200

## 同時に投げる数。**宛先で分ける。**
## 外は待っているだけなので、村人の数ぶん並べても費用は変わらない。
## この機械の中も、1本より4本のほうが速い——**実測**（qwen3:1.7b で 45秒に
## 56件→92件、qwen3:8b で 19件→24件）。1台のGPUでも、まとめて流すぶん総量が増える。
## ただし ollama 側の `OLLAMA_NUM_PARALLEL` が1だと意味がないので、そちらも4に。
const LANES := 8       ## 用意する口の数
const LANES_OUT := 8   ## 外に同時に投げる数（待っているだけなので費用は変わらない）
const LANES_LOCAL := 4 ## この機械の中に同時に投げる数

## 待たせるのは**一人につき1枠**。同じ人の新しい問いは古い問いを置き換える——
## 古い問いの答えは、返ってきた時点の話に合わない（村人はもう別の場所に居る）。
## 枠が人数ぶんあるので**溢れという事象が無い**。溢れて当てずっぽうに落ちるのは、
## こちらが訊きすぎただけなのに村人のせいにすることだった

## 待たせる時間の上限。
## 外は速いので短くていい。**この機械の中は長く待つ**——3手ぶんの答えは長く、
## 4本が同時に流れるので、15秒では全部時間切れになった（実測：1件も通らない）。
## 古びた問いは待ち時間ではなく、**一人1枠の置き換え**で捨てる
const WAIT_OUT := 10.0
const WAIT_LOCAL := 40.0   ## 検証用。この機械の中は遅いので、切らずに待つ

## 運びが失敗したときの間。3回めで諦める
const RETRY := [1.0, 4.0]
## 諦めたあと「居ない」ことにしておく間。そのあいだの当てずっぽうは嘘ではない
const DOWN := 30.0

## 訊けるようになった／なくなった
signal ready_changed(ok: bool)
## 選べるものの一覧が変わった（この機械の中に何が入っているかを訊き直したとき）
signal choices_changed

## 外に置いておくもの。鍵があるときだけ並ぶ
const OPENAI_MODELS := ["gpt-4o-mini", "gpt-4o"]

var model := MODEL
var url := OPENAI_URL
## この機械の中（ollama）に訊いているか。鍵の要不要と、枠の言い方が変わる
var local := false
## 最後に失敗した理由。出すのは検証用（`--echo-log`）だけで、紙には出さない
var last_error := ""
## 最後に使った量。**費用の見当を立てるため**だけに持つ（紙には出さない）
var last_usage := {}
## 投げた数・失敗した数・捨てた数。同じく見当のため
var sent := 0
var failed := 0
var dropped := 0
## 運びが続けて失敗した回数と、諦めた時刻（`DOWN` のあいだ「居ない」）
var _misses := 0
var _down_at := -1.0

## 返せた時刻。**いまの速さ**を出すために、直近だけ持つ
var _answers: Array = []
const RATE_SPAN := 20.0

var _key := ""
var _queue: Array = []   ## [{system, prompt, max, json, on_done}]
var _lanes: Array = []   ## [{http, job}]

## 選べるもの。[{name, local, model, url}]。最後は必ず「AIを使わない」
var _choices: Array = []
var _here := 0
## この機械の中に何が入っているかを訊くための口（`_lanes` は塞がっているので別に持つ）
var _tagger: HTTPRequest = null
var _tagging := false   ## 訊いている最中（口は1本なので重ねられない）
var _tagged := false    ## 一度訊いた。紙を開くたびに訊き直さない
## AIを使わない。**穴のままの世界**を見るための、検証用の選択肢
var off := false


func _ready() -> void:
	_find_where()
	_tagger = HTTPRequest.new()
	_tagger.timeout = 5.0
	add_child(_tagger)
	_tagger.request_completed.connect(_on_tags)
	for i in range(LANES):
		var h := HTTPRequest.new()
		h.timeout = 30.0
		add_child(h)
		h.request_completed.connect(_on_done.bind(i))
		_lanes.append({"http": h, "job": {}})


## 訊ける状態か。**この機械の中に訊くなら鍵は要らない**。
## 運びが続けて駄目だったあいだは「居ない」——世界は今までどおり穴として動く
func available() -> bool:
	if off or (not local and _key == ""):
		return false
	return not down()


## 返事が来ないので、しばらく居ないことにしている
func down() -> bool:
	if _down_at < 0.0:
		return false
	if _now() - _down_at < DOWN:
		return true
	_down_at = -1.0
	_misses = 0
	return false


static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


# ---------------------------------------------------------------------------
# どれを使うか選ぶ（オプションと設計図の紙から）
# ---------------------------------------------------------------------------

## 選べるものの一覧。呼ぶたびに組み直さず、`refresh_choices()` で更新する
func choices() -> Array:
	if _choices.is_empty():
		_build_choices([])
	return _choices


func here() -> int:
	return _here


## いま使っているものの名前。紙に出すのはこれ
func here_name() -> String:
	var c := choices()
	return String(c[_here]["name"]) if _here < c.size() else "—"


## 次へ送る（**押すたびに次へ**——姿や色と同じ送り方）
func next_choice() -> void:
	var c := choices()
	if c.is_empty():
		return
	use(( _here + 1) % c.size())


func use(i: int) -> void:
	var c := choices()
	if i < 0 or i >= c.size():
		return
	_here = i
	var was := available()
	var pick: Dictionary = c[i]
	off = bool(pick.get("off", false))
	local = bool(pick.get("local", false))
	model = String(pick.get("model", MODEL))
	url = String(pick.get("url", OPENAI_URL))
	if was != available():
		ready_changed.emit(available())


## この機械の中に何が入っているかを訊き直す。返ったら `choices_changed`。
## **紙は2枚ある**（設計図とオプション）ので、開くたびに訊きに行かない
func refresh_choices(force: bool = false) -> void:
	if _tagger == null or _tagging:
		return
	if _tagged and not force:
		choices_changed.emit()
		return
	var base := url if local else OLLAMA_URL
	var root := base.substr(0, base.find("/v1/"))
	_tagging = true
	var err := _tagger.request(root + "/api/tags")
	if err != OK:
		_tagging = false
		_tagged = true
		_build_choices([])
		choices_changed.emit()


func _on_tags(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_tagging = false
	_tagged = true
	var names: Array = []
	if code == 200:
		var got = JSON.parse_string(body.get_string_from_utf8())
		if typeof(got) == TYPE_DICTIONARY and typeof(got.get("models", null)) == TYPE_ARRAY:
			for m in got["models"]:
				if typeof(m) == TYPE_DICTIONARY:
					names.append(String(m.get("name", "")))
	_build_choices(names)
	choices_changed.emit()


## 一覧を組む。この機械に入っているものと、鍵があるなら預け先のものを並べる。
## 最後の「使わない」は検証用——穴のままの世界を見るためのもの
func _build_choices(local_names: Array) -> void:
	var out: Array = []
	if _key != "":
		for m in OPENAI_MODELS:
			out.append({"name": String(m), "local": false,
				"model": String(m), "url": OPENAI_URL})
	for n in local_names:
		if String(n) == "":
			continue
		out.append({"name": String(n), "local": true, "model": String(n),
			"url": OLLAMA_URL})
	out.append({"name": "使わない（検証用）", "off": true})
	_choices = out
	# いま使っているものが一覧にあれば、そこを指しておく
	for i in range(out.size()):
		var c: Dictionary = out[i]
		if not bool(c.get("off", false)) and String(c["model"]) == model \
				and bool(c["local"]) == local:
			_here = i
			return
	_here = out.size() - 1 if off else 0


## 宛先を決める。この機械の中にモデルが置いてあれば、そちらが勝つ
func _find_where() -> void:
	# **鍵は宛先と関係なく読む。** 中に訊いていても、
	# オプションの紙には外の相手も並べたい（押すたびに次へ送れるように）
	_key = _find_key()
	var m := OS.get_environment(ENV_OLLAMA_MODEL).strip_edges()
	if m == "" and FileAccess.file_exists(OLLAMA_FILE):
		var f := FileAccess.open(OLLAMA_FILE, FileAccess.READ)
		if f != null:
			m = f.get_as_text().strip_edges()
	if m == "":
		return
	local = true
	model = m
	var u := OS.get_environment(ENV_OLLAMA_URL).strip_edges()
	url = u if u != "" else OLLAMA_URL


## 訊く。`on_done` は文字列1つを受ける（失敗したら空文字）。
## `want_json` を立てると、返るのが JSON の物1つになる。
## 返り値は「受け付けたか」——鍵が無い・溢れたときは false
## `who` はこの問いの主（村人のid）。**同じ主の古い問いは置き換える**
func ask(prompt: String, system_text: String, on_done: Callable,
		max_out: int = MAX_OUT, want_json: bool = false, who: int = -1) -> bool:
	if not available() or prompt == "":
		return false
	var job := {
		"prompt": prompt,
		"system": system_text,
		"max": max_out,
		"json": want_json,
		"on_done": on_done,
		"who": who,
		"tries": 0,
	}
	if who >= 0:
		for i in range(_queue.size()):
			if int(_queue[i]["who"]) == who:
				dropped += 1
				_queue[i] = job   # 古い問いは捨てる。答えはもう合わない
				_pump()
				return true
	_queue.append(job)
	_pump()
	return true


## 鍵を差し替える（遊ぶ側が入れる口。いまは呼ぶ場所が無い）
func set_key(key: String) -> void:
	var was := available()
	_key = key.strip_edges()
	if was != available():
		ready_changed.emit(available())


func _find_key() -> String:
	var env := OS.get_environment(ENV_KEY).strip_edges()
	if env != "":
		return env
	for path in [KEY_FILE, DEV_KEY_FILE]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				var k := f.get_as_text().strip_edges()
				if k != "":
					return k
	return ""


## いま同時に投げていい数
func _width() -> int:
	return LANES_LOCAL if local else LANES_OUT


## 空いている口へ、待っているものを流す
func _pump() -> void:
	var busy := 0
	for l in _lanes:
		if not l["job"].is_empty():
			busy += 1
	for i in range(mini(_lanes.size(), _width())):
		if busy >= _width():
			return
		if _queue.is_empty():
			return
		if _lanes[i]["job"].is_empty():
			_send(i, _queue.pop_front())
			busy += 1


func _send(lane: int, job: Dictionary) -> void:
	_lanes[lane]["job"] = job
	_lanes[lane]["http"].timeout = WAIT_LOCAL if local else WAIT_OUT

	var msgs: Array = []
	if String(job["system"]) != "":
		msgs.append({"role": "system", "content": String(job["system"])})
	msgs.append({"role": "user", "content": String(job["prompt"])})

	var body := {
		"model": model,
		"messages": msgs,
	}
	# 考えるモデルでは、この枠から思考ぶんも出る。
	# 言い方が2つあるので、宛先に合わせる（ollama は古いほうで受ける）
	body["max_tokens" if local else "max_completion_tokens"] = int(job["max"])
	var effort := LOCAL_REASONING if local else REASONING
	if effort != "":
		body["reasoning_effort"] = effort
	if bool(job["json"]):
		body["response_format"] = {"type": "json_object"}

	var headers := ["content-type: application/json"]
	if _key != "":
		headers.append("authorization: Bearer %s" % _key)
	sent += 1
	var err: int = _lanes[lane]["http"].request(url, headers,
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_fail(lane, "繋げなかった（%d）" % err)


func _on_done(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, lane: int) -> void:
	if _lanes[lane]["job"].is_empty():
		return
	# **運びの失敗**（繋げない・時間切れ）は、間を置いて投げ直す。
	# 相手が落ちているときに4本で叩き直すと、事態を悪くするだけ
	if result != HTTPRequest.RESULT_SUCCESS:
		_again(lane, "応答が来なかった（%d）" % result)
		return
	var got = JSON.parse_string(body.get_string_from_utf8())
	if typeof(got) != TYPE_DICTIONARY:
		_fail(lane, "読めない応答")
		return
	if code != 200:
		var e = got.get("error", {})
		var why := "%d %s" % [code,
			String(e.get("message", "")) if typeof(e) == TYPE_DICTIONARY else ""]
		# 相手の側の不調（5xx・混雑）は運びの失敗と同じ。
		# 問いが悪い（4xx）のは投げ直しても同じなので、そのまま返す
		if code >= 500 or code == 429:
			_again(lane, why)
		else:
			_fail(lane, why)
		return
	var u = got.get("usage", {})
	if typeof(u) == TYPE_DICTIONARY:
		last_usage = u
	_misses = 0
	var text := _first_text(got)
	if text == "":
		# 枠を思考で使い切ると、200 のまま空が返る
		_fail(lane, "空の応答（%s）" % _stop_of(got))
		return
	_finish(lane, text)


func _first_text(got: Dictionary) -> String:
	var choices = got.get("choices", [])
	if typeof(choices) != TYPE_ARRAY or choices.is_empty():
		return ""
	var first = choices[0]
	if typeof(first) != TYPE_DICTIONARY:
		return ""
	var msg = first.get("message", {})
	if typeof(msg) != TYPE_DICTIONARY:
		return ""
	return String(msg.get("content", "")).strip_edges()


## なぜ切れたか（`length` なら枠が足りない、`content_filter` なら断られた）
func _stop_of(got: Dictionary) -> String:
	var choices = got.get("choices", [])
	if typeof(choices) == TYPE_ARRAY and not choices.is_empty() \
			and typeof(choices[0]) == TYPE_DICTIONARY:
		return String(choices[0].get("finish_reason", "?"))
	return "?"


## 運びが駄目だった。間を置いて投げ直し、3回めで諦める
func _again(lane: int, why: String) -> void:
	var job: Dictionary = _lanes[lane]["job"]
	_lanes[lane]["job"] = {}
	var tries := int(job.get("tries", 0))
	if tries < RETRY.size():
		job["tries"] = tries + 1
		last_error = why
		if EventLog.echo:
			print("[AI] %s（%d回め、%.0f秒後に投げ直す）" % [why, tries + 1, RETRY[tries]])
		get_tree().create_timer(float(RETRY[tries])).timeout.connect(
			func() -> void:
				_queue.push_front(job)
				_pump())
		_pump()
		return
	_misses += 1
	if _misses >= 1:
		_down_at = _now()
		ready_changed.emit(false)
	_fail(lane, why + "（諦めた）")


func _fail(lane: int, why: String) -> void:
	last_error = why
	failed += 1
	if EventLog.echo:
		print("[AI] %s" % why)
	_finish(lane, "")


## いま毎秒いくつ返せているか。0 なら、まだ測れていない
func rate() -> float:
	var now := _now()
	while not _answers.is_empty() and now - float(_answers[0]) > RATE_SPAN:
		_answers.pop_front()
	if _answers.size() < 2:
		return 0.0
	var span: float = maxf(now - float(_answers[0]), 0.001)
	return float(_answers.size()) / span


func _finish(lane: int, text: String) -> void:
	var job: Dictionary = _lanes[lane]["job"]
	_lanes[lane]["job"] = {}
	if text != "":
		_answers.append(_now())
	if not job.is_empty():
		var cb: Callable = job["on_done"]
		if cb.is_valid():
			cb.call(text)
	_pump()
