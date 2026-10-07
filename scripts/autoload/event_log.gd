extends Node
## 村で起きたことの記録。プレイヤーが観察するための唯一の外部視点。

## 記録は「いつ・何が」で持つ。文の中に時刻を埋め込むと、見せ方を変えられなくなる。
signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 300

var _next_id := 1

var entries: Array = []

## ヘッドレスで挙動を観察するとき用。`godot -- --echo-log` で標準出力にも流す。
var echo: bool = false

## **一人ずつの内側**も流す（`--echo-mind`）。
## 村の記録は「何が起きたか」しか持たない（それが正しい——神が見るのはそこまで）。
## 作っている側は「なぜそうしたか」を見たいので、そこだけ別の口にする。
## 標準出力は Godot がそのまま
## `~/Library/Application Support/Godot/app_userdata/World Simulator/logs/` に残す。
var echo_mind: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	echo = args.has("--echo-log") or args.has("--echo-mind")
	echo_mind = args.has("--echo-mind")


## 村人ひとりの内側。誰の話かが先頭に来るように揃える
func mind(who: String, text: String) -> void:
	if echo_mind:
		print("[%s %s] %s" % [SimClock.clock_text(), who, text])


## **行き先は文の中の名前が持つ。** 以前は「どこで・誰に」を添えて行をまるごと
## 押せるようにしていたが、行に下線が付くと下線が飾りになった。
##
## `marks` は「文の中のこの言葉は、これを指す」。`{"ハル": "v:3", "家": "s:7"}` の形。
## **書いた側が指し先を言う。** 読む側が名前から探すと、
## 同じ名前の家が6軒あるとき、どれでもない家に飛ぶ。
func add(text: String, color: Color = Color(0.28, 0.24, 0.19),
		marks: Dictionary = {}) -> void:
	var e := {
		"id": _next_id, "day": SimClock.day, "time": SimClock.clock_text(),
		"text": text, "color": color, "marks": marks,
	}
	_next_id += 1
	if echo:
		print("[%d日 %s] %s" % [e["day"], e["time"], text])
	entries.append(e)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(e)


## 前の村の記録は次の村へ持ち越さない。同じ紙に続けて書くと、
## 別の世界の出来事が地続きに読めてしまう。
func clear() -> void:
	entries.clear()
	_next_id = 1


## 村の姿が変わった出来事（家が建った、など）
func notable(text: String, marks: Dictionary = {}) -> void:
	add(text, Color(0.72, 0.44, 0.10), marks)


## 村人どうしのあいだで起きた出来事
func social(text: String, marks: Dictionary = {}) -> void:
	add(text, Color(0.18, 0.44, 0.58), marks)
