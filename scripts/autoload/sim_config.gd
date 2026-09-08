extends Node
## 世界そのもののルール値。
##
## 【前提】判断はAIが行う。
## ここにあるのは物理と時間だけで、キャラクターの判断に関わる係数は一つもない。
## 記憶まわりは【要検討】で、扱いが決まるまでの暫定値。

signal param_changed(key: String, value: float)

## key -> [既定値, 最小, 最大, 説明, きざみ]
##
## **きざみは、幅をちょうど10で割った値にする。** つまみは積み木10個で描かれるので、
## 途中の値を取れると、積み木の切れ目と値がずれて「どこにいるのか」が読めない。
## 幅の端も既定値も、きざみの上に乗る数だけを選んである。
const PARAM_DEF := {
	"day_length_sec": [90.0, 30.0, 330.0, "1日の長さ", 30.0],
	"night_starts_at": [20.0, 14.0, 24.0, "夜になる時刻", 1.0],
	"decision_interval": [1.0, 0.2, 2.2, "考え直す間合い", 0.2],
	"move_speed": [2.0, 0.5, 5.5, "歩く速さ", 0.5],

	"summaries_kept": [5.0, 1.0, 11.0, "覚えていられる日数", 1.0],
}


## その目盛りのきざみ
func step_of(key: String) -> float:
	if not PARAM_DEF.has(key):
		return 1.0
	return float(PARAM_DEF[key][4])

var params := {}

## 日本語表示用フォント（main が起動時にセットする）
var ui_font: Font = null

## UI全体の見た目。CanvasLayer は Control ではないので Window のテーマが伝わらず、
## 各パネルに直接あてる必要がある。
var ui_theme: Theme = null


func _ready() -> void:
	for k in PARAM_DEF:
		params[k] = float(PARAM_DEF[k][0])


func p(key: String) -> float:
	return params.get(key, 0.0)


func set_param(key: String, value: float) -> void:
	if not PARAM_DEF.has(key):
		return
	var d = PARAM_DEF[key]
	params[key] = clampf(value, float(d[1]), float(d[2]))
	param_changed.emit(key, params[key])


func reset_params() -> void:
	for k in PARAM_DEF:
		params[k] = float(PARAM_DEF[k][0])
		param_changed.emit(k, params[k])
