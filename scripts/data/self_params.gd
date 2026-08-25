class_name SelfParams
extends RefCounted
## 自分スコープのパラメータ値。一人につき1セット。
##
## どんなパラメータが存在するかは Schema が決めるので、実行中に増減しても壊れない。
## 値がどう動くかはここには書かれていない。動かすのは判断（Brain）だけ。

var values := {}


func _init() -> void:
	for d in Schema.self_params():
		values[String(d["id"])] = 0.0


func get_v(key: String) -> float:
	return float(values.get(key, 0.0))


func set_v(key: String, v: float) -> void:
	values[key] = clampf(v, Schema.param_min(key), Schema.param_max(key))


func offset(key: String, delta: float) -> void:
	set_v(key, get_v(key) + delta)
