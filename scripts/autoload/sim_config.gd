extends Node
## 世界そのもののルール値。
##
## 【前提】判断はAIが行う。
## ここにあるのは物理と時間だけで、キャラクターの判断に関わる係数は一つもない。
## 記憶まわりは【要検討】で、扱いが決まるまでの暫定値。

signal param_changed(key: String, value: float)

## key -> [既定値, 最小, 最大, 説明]
const PARAM_DEF := {
	"day_length_sec": [90.0, 20.0, 600.0, "1日の長さ（秒）"],
	"night_fraction": [0.35, 0.0, 0.8, "夜が占める割合"],
	"decision_interval": [1.1, 0.2, 6.0, "行動を選び直す間隔（秒）"],
	"move_speed": [1.9, 0.2, 12.0, "移動速度（マス/秒）"],

	"summaries_kept": [5.0, 1.0, 30.0, "保持する過去日数"],
}

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
