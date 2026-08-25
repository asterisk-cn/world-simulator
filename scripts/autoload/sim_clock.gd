extends Node
## 昼夜と日数。夜になると村人は「記憶の整理」を行う。

signal day_changed(day: int)
signal night_started(day: int)
signal morning_started(day: int)

var day: int = 1
var time_of_day: float = 0.25  ## 0.0=夜明け前 .. 1.0
var is_night: bool = false
var speed: float = 1.0
var paused: bool = false


func _process(delta: float) -> void:
	if paused:
		return
	var day_len := maxf(SimConfig.p("day_length_sec"), 1.0)
	time_of_day += (delta * speed) / day_len
	while time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		day_changed.emit(day)

	var night_start := 1.0 - SimConfig.p("night_fraction")
	var now_night := time_of_day >= night_start
	if now_night != is_night:
		is_night = now_night
		if is_night:
			night_started.emit(day)
		else:
			morning_started.emit(day)


## 0.0(真昼) .. 1.0(真夜中) の暗さ
func darkness() -> float:
	var night_start := 1.0 - SimConfig.p("night_fraction")
	if time_of_day < night_start:
		var t := time_of_day / maxf(night_start, 0.001)
		return clampf(1.0 - sin(t * PI), 0.0, 1.0) * 0.45
	var t2 := (time_of_day - night_start) / maxf(1.0 - night_start, 0.001)
	return clampf(0.5 + sin(t2 * PI) * 0.5, 0.0, 1.0)


func clock_text() -> String:
	var total_min := int(time_of_day * 24.0 * 60.0)
	return "%02d:%02d" % [total_min / 60, total_min % 60]
