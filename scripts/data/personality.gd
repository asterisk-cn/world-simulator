class_name Personality
extends RefCounted
## 性格。MBTIの4軸を連続値で持つのと、一言個性だけ。
##
## 【前提】判断はAIが行う。
## ここから行動への影響は一切導出されない。派生特性も係数も持たない。
## これはAIに「この人はこういう人だ」と渡すための素の記述であって、
## プログラムが読んで何かを決めるためのものではない。

const AXES := [
	["ei", "内向-外向", "内向", "外向"],
	["sn", "感覚-直観", "感覚", "直観"],
	["tf", "思考-感情", "思考", "感情"],
	["jp", "判断-知覚", "判断", "知覚"],
]

const QUIRKS := [
	"お調子者", "臆病", "見栄っ張り", "面倒くさがり", "世話好き",
	"働き者", "疑い深い", "気前がいい", "独り好き", "口が軽い",
	"筋を通す", "抜け目ない",
]

var ei := 0.5
var sn := 0.5
var tf := 0.5
var jp := 0.5
var quirk := "お調子者"


static func random() -> Personality:
	var p := Personality.new()
	p.ei = randf()
	p.sn = randf()
	p.tf = randf()
	p.jp = randf()
	p.quirk = QUIRKS[randi() % QUIRKS.size()]
	return p


func axis(key: String) -> float:
	match key:
		"ei": return ei
		"sn": return sn
		"tf": return tf
		"jp": return jp
	return 0.5


func set_axis(key: String, x: float) -> void:
	match key:
		"ei": ei = x
		"sn": sn = x
		"tf": tf = x
		"jp": jp = x


## 4軸を離散化した MBTI 表記。表示とAIへの受け渡しに使う。
func mbti() -> String:
	return "%s%s%s%s" % [
		"E" if ei >= 0.5 else "I",
		"N" if sn >= 0.5 else "S",
		"F" if tf >= 0.5 else "T",
		"P" if jp >= 0.5 else "J",
	]


func describe() -> String:
	return "%s・%s" % [mbti(), quirk]
