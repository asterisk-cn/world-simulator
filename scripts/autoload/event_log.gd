extends Node
## 村で起きたことの記録。プレイヤーが観察するための唯一の外部視点。

## 記録は「いつ・何が」で持つ。文の中に時刻を埋め込むと、見せ方を変えられなくなる。
signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 300

var entries: Array = []

## ヘッドレスで挙動を観察するとき用。`godot -- --echo-log` で標準出力にも流す。
var echo: bool = false


func _ready() -> void:
	echo = OS.get_cmdline_user_args().has("--echo-log")


func add(text: String, color: Color = Color(0.28, 0.24, 0.19)) -> void:
	var e := {
		"day": SimClock.day, "time": SimClock.clock_text(),
		"text": text, "color": color,
	}
	if echo:
		print("[%d日 %s] %s" % [e["day"], e["time"], text])
	entries.append(e)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(e)


## 村の姿が変わった出来事（家が建った、など）
func notable(text: String) -> void:
	add(text, Color(0.72, 0.44, 0.10))


## 村人どうしのあいだで起きた出来事
func social(text: String) -> void:
	add(text, Color(0.18, 0.44, 0.58))
