extends Node
## AIへの口。**世界の外にいる相手に一行だけ訊く**ための1本道。
##
## この作品の一線は「世界で何が起きたかはプログラム、それをどう受け取るかはAI」
## （DESIGN.md §2）。ここはその後ろ半分を運ぶだけの管で、判断は何も持たない。
## 何を訊くかは呼ぶ側（`villager/feeling.gd` など）が組む。
##
## **繋がっていなくても世界は動く。** 鍵が無ければ `available()` が false になり、
## 呼び側は何も出さないだけ。時間も村人も止めない——AIは世界の部品ではなく、
## 村人の内側を答える相手なので、居ないなら内側が読めないだけで済む。
##
## GDScript には公式SDKが無いので、素の HTTP（`HTTPRequest`）で叩く。
## 相手は OpenAI の chat completions——**受け答えの形がいちばん素直**で、
## 返るのが `choices[0].message.content` の1本だけなので、管が薄く保てる。

## 鍵の置き場。**リポジトリには入れない**（`.gitignore`）。
## 遊ぶ側の鍵は `user://` に置く（書き出した本体からも読める）。
## `res://` のほうは作りながら試すためのもので、書き出すと中に入ってしまうので、
## 配るときは置かない。
const KEY_FILE := "user://openai.key"
const DEV_KEY_FILE := "res://.openai-key"
const ENV_KEY := "OPENAI_API_KEY"

const URL := "https://api.openai.com/v1/chat/completions"

## どのモデルに訊くか。**ここ1行を変えれば替わる。**
const MODEL := "gpt-4o-mini"

## 思考の深さ。**gpt-4o 系には無い口**（o系・gpt-5 だけ）なので空にしてある。
## 考えるモデルに替えるときは "low" などを入れる
const REASONING := ""

## 出力の上限。欲しいのは一行なので細くていい。
## ただし**考えるモデルでは思考ぶんも同じ枠から出る**ので、
## そちらに替えるときは 700 ほどまで広げる（細いと思考で使い切って空が返る）
const MAX_OUT := 200

## 待たせる数の上限。溢れたぶんは捨てる——古い問いの答えが今の話に合わない
const QUEUE_MAX := 4

## 訊けるようになった／なくなった
signal ready_changed(ok: bool)

var model := MODEL
## 最後に失敗した理由。出すのは検証用（`--echo-log`）だけで、紙には出さない
var last_error := ""
## 最後に使った量。**費用の見当を立てるため**だけに持つ（紙には出さない）
var last_usage := {}

var _key := ""
var _queue: Array = []   ## [{system, prompt, max, on_done}]
var _job: Dictionary = {}
var _http: HTTPRequest = null


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	add_child(_http)
	_http.request_completed.connect(_on_done)
	_key = _find_key()


## 訊ける状態か。鍵が無ければ false
func available() -> bool:
	return _key != ""


## 一行訊く。`on_done` は文字列1つを受ける（失敗したら空文字）。
## 返り値は「受け付けたか」——鍵が無い・溢れたときは false
func ask(prompt: String, system_text: String, on_done: Callable,
		max_out: int = MAX_OUT) -> bool:
	if not available() or prompt == "":
		return false
	if _queue.size() >= QUEUE_MAX:
		return false
	_queue.append({
		"prompt": prompt,
		"system": system_text,
		"max": max_out,
		"on_done": on_done,
	})
	_next()
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


func _next() -> void:
	if not _job.is_empty() or _queue.is_empty():
		return
	_job = _queue.pop_front()

	var msgs: Array = []
	if String(_job["system"]) != "":
		msgs.append({"role": "system", "content": String(_job["system"])})
	msgs.append({"role": "user", "content": String(_job["prompt"])})

	var body := {
		"model": model,
		"messages": msgs,
		# 考えるモデルでは、この枠から思考ぶんも出る
		"max_completion_tokens": int(_job["max"]),
	}
	if REASONING != "":
		body["reasoning_effort"] = REASONING

	var headers := [
		"content-type: application/json",
		"authorization: Bearer %s" % _key,
	]
	var err := _http.request(URL, headers, HTTPClient.METHOD_POST,
		JSON.stringify(body))
	if err != OK:
		_fail("繋げなかった（%d）" % err)


func _on_done(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("応答が来なかった（%d）" % result)
		return
	var got = JSON.parse_string(body.get_string_from_utf8())
	if typeof(got) != TYPE_DICTIONARY:
		_fail("読めない応答")
		return
	if code != 200:
		var e = got.get("error", {})
		_fail("%d %s" % [code,
			String(e.get("message", "")) if typeof(e) == TYPE_DICTIONARY else ""])
		return
	var u = got.get("usage", {})
	if typeof(u) == TYPE_DICTIONARY:
		last_usage = u
	var text := _first_text(got)
	if text == "":
		# 枠を思考で使い切ると、200 のまま空が返る
		_fail("空の応答（%s）" % _stop_of(got))
		return
	_finish(text)


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


func _fail(why: String) -> void:
	last_error = why
	if EventLog.echo:
		print("[AI] %s" % why)
	_finish("")


func _finish(text: String) -> void:
	var job := _job
	_job = {}
	if not job.is_empty():
		var cb: Callable = job["on_done"]
		if cb.is_valid():
			cb.call(text)
	_next()
