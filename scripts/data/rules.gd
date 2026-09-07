class_name Rules
extends RefCounted
## 固定ルール定数。Villager と Brain が相互参照して循環しないよう、ここに分離している。
##
## 建築コストはここに無い。何をどれだけ使うかは、作る人が持ち物を見て決める。

const SIGHT := 9.0
