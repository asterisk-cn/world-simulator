extends Node
## 村で起きたことの記録。プレイヤーが観察するための唯一の外部視点。

signal entry_added(text: String, color: Color)

const MAX_ENTRIES := 300

var entries: Array = []

## ヘッドレスで挙動を観察するとき用。`godot -- --echo-log` で標準出力にも流す。
var echo: bool = false


func _ready() -> void:
	echo = OS.get_cmdline_user_args().has("--echo-log")


func add(text: String, color: Color = Color(0.85, 0.85, 0.88)) -> void:
	var line := "[%d日 %s] %s" % [SimClock.day, SimClock.clock_text(), text]
	if echo:
		print(line)
	entries.append({"text": line, "color": color})
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(line, color)


## 村の姿が変わった出来事（家が建った、など）
func notable(text: String) -> void:
	add(text, Color(1.0, 0.78, 0.35))


## 村人どうしのあいだで起きた出来事
func social(text: String) -> void:
	add(text, Color(0.55, 0.85, 0.95))
