extends Node
## 村で起きたことの記録。プレイヤーが観察するための唯一の外部視点。

## 記録は「いつ・何が」で持つ。文の中に時刻を埋め込むと、見せ方を変えられなくなる。
signal entry_added(entry: Dictionary)

const MAX_ENTRIES := 300

## 場所を持たない出来事（夜になった、など）
const NOWHERE := Vector2(INF, INF)

var _next_id := 1

var entries: Array = []

## ヘッドレスで挙動を観察するとき用。`godot -- --echo-log` で標準出力にも流す。
var echo: bool = false


func _ready() -> void:
	echo = OS.get_cmdline_user_args().has("--echo-log")


## at / who は「その出来事が世界のどこで、誰に起きたか」。
## これが無いと、記録を読んでから世界を探すことになり、観察する遊びとして順序が逆になる。
func add(text: String, color: Color = Color(0.28, 0.24, 0.19),
		at: Vector2 = NOWHERE, who: int = -1) -> void:
	var e := {
		"id": _next_id, "day": SimClock.day, "time": SimClock.clock_text(),
		"text": text, "color": color, "at": at, "who": who,
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
func notable(text: String, at: Vector2 = NOWHERE, who: int = -1) -> void:
	add(text, Color(0.72, 0.44, 0.10), at, who)


## 村人どうしのあいだで起きた出来事
func social(text: String, at: Vector2 = NOWHERE, who: int = -1) -> void:
	add(text, Color(0.18, 0.44, 0.58), at, who)


## その出来事に行き先があるか
static func has_place(e: Dictionary) -> bool:
	return int(e.get("who", -1)) >= 0 or Vector2(e.get("at", NOWHERE)).x != INF


## 記録は古いものから捨てるので、並び位置ではなく id で引く
func by_id(id: int) -> Dictionary:
	for e in entries:
		if int(e["id"]) == id:
			return e
	return {}
