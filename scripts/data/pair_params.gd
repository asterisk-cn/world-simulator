class_name PairParams
extends RefCounted
## 相手スコープのパラメータ値。「自分から見たある相手」ぶん。
##
## 自分スコープのものと構造は同じで、相手ごとに1セット持つところだけが違う。
## n人いれば n×n のグリッドになる。
## 相手が自分に対して持つ PairParams とは別のオブジェクトで、同期はされない。

var target_id: int = -1
var values := {}

var contacts: int = 0
var first_met_day: int = 1


func _init(p_target_id: int = -1) -> void:
	target_id = p_target_id
	for d in Schema.pair_params():
		values[String(d["id"])] = 0.0
	first_met_day = SimClock.day


func get_v(key: String) -> float:
	return float(values.get(key, 0.0))


func set_v(key: String, v: float) -> void:
	values[key] = clampf(v, Schema.param_min(key), Schema.param_max(key))


func offset(key: String, delta: float) -> void:
	set_v(key, get_v(key) + delta)
