class_name CheckRun
extends Node
## **実機テスト**（検証用）。既定の単発シナリオと流れのシナリオを、本物の Jev に順に投げて
## `期待` を判定する。1本でも失敗があれば終わりのコードを1にする。
##
##   godot --headless --path . -- --check [--repeat=10] [--only=単発|流れ|名前の頭] [--with-text]
##
## 1本ずつ**別のプロセス**で流す（`--jev-scenarios --judge`、`--flow=… --judge`）。
## 単発も流れも Schema・時計・目盛りを書き換えるので、同じプロセスで続けると前の話が残る。
## 子は判定を `user://jev_bench/check/*.json` に残し、ここはそれを読んで並べる。
##
## 文章の相手は既定で止める（子にそのまま渡す）。判断は Jev（安い）だけ。

const CHECK_DIR := "user://jev_bench/check"

var repeat := 10
var only := ""
var with_text := false

var _jobs: Array = []    ## [{id, label, args}]
var _at := -1
var _pid := -1
var _results: Array = []  ## [{label, code, rows, report}]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--repeat="):
			repeat = int(s.get_slice("=", 1))
		elif s.begins_with("--only="):
			only = s.get_slice("=", 1)
		elif s == "--with-text":
			with_text = true
	var extra: Array = ["--with-text"] if with_text else []
	if only == "" or only == "単発":
		_jobs.append({"id": "scenarios", "label": "単発",
			"args": ["--jev-scenarios", "--judge", "--repeat=%d" % repeat] + extra})
	elif only != "流れ" and _has_scenario(only):
		_jobs.append({"id": "scenarios", "label": "単発 %s" % only,
			"args": ["--jev-scenarios", "--judge", "--repeat=%d" % repeat,
				"--only=%s" % only] + extra})
	if only != "単発":
		for f in _files(FlowRun.DIR):
			if only != "" and only != "流れ" and not f.begins_with(only):
				continue
			var name: String = f.get_basename()
			_jobs.append({"id": "flow-%s" % name, "label": "流れ %s" % name,
				"args": ["--flow=%s" % name, "--judge"] + extra})
	if _jobs.is_empty():
		print("[実機テスト] 流すものが無い（--only=%s）" % only)
		get_tree().quit(1)
		return
	print("[実機テスト] %d本を順に流す" % _jobs.size())
	_next()


func _process(_delta: float) -> void:
	if _pid < 0 or OS.is_process_running(_pid):
		return
	var job: Dictionary = _jobs[_at]
	var code := OS.get_process_exit_code(_pid)
	_pid = -1
	var got = JSON.parse_string(FileAccess.get_file_as_string(
		"%s/%s.json" % [CHECK_DIR, job["id"]]))
	_results.append({"label": job["label"], "code": code,
		"rows": got.get("rows", []) if typeof(got) == TYPE_DICTIONARY else [],
		"report": got.get("report", "") if typeof(got) == TYPE_DICTIONARY else ""})
	_next()


func _next() -> void:
	_at += 1
	if _at >= _jobs.size():
		_finish()
		return
	var job: Dictionary = _jobs[_at]
	# 前の回の判定が残っていると、子が書けずに終わったときに古いものを読んでしまう
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		"%s/%s.json" % [CHECK_DIR, job["id"]]))
	var args: Array = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--"]
	args.append_array(job["args"])
	print("\n[実機テスト] (%d/%d) %s" % [_at + 1, _jobs.size(), job["label"]])
	_pid = OS.create_process(OS.get_executable_path(), PackedStringArray(args))
	if _pid < 0:
		_results.append({"label": job["label"], "code": -1, "rows": [], "report": ""})
		_next()


func _finish() -> void:
	var out := PackedStringArray()
	out.append("# 実機テスト（%s）" % Time.get_datetime_string_from_system(false, true))
	out.append("")
	out.append("- 単発は1本につき %d回。文章の相手は%s" % [repeat, "使った" if with_text else "止めた"])
	out.append("")
	out.append("| 何を | 結果 | 失敗 | 警告 |")
	out.append("|---|---|---:|---:|")
	var failed := false
	var details := PackedStringArray()
	for r in _results:
		for one in r["rows"]:
			var fails := 0
			var warns := 0
			for v in one["rows"]:
				if v["verdict"] == Expect.FAIL:
					fails += 1
				elif v["verdict"] == Expect.WARN:
					warns += 1
			out.append("| %s：%s | %s | %d | %d |" % [r["label"], one["name"], one["verdict"],
				fails, warns])
			if one["verdict"] != Expect.PASS:
				details.append("")
				details.append("## %s：%s" % [r["label"], one["name"]])
				details.append("")
				details.append_array(Expect.table(one["rows"].filter(
					func(v): return v["verdict"] != Expect.PASS)))
		# 判定が残っていない＝子が途中で落ちた。終わりのコードだけで失敗とする
		if r["rows"].is_empty():
			out.append("| %s | %s | - | - |" % [r["label"],
				"失敗（終わりのコード %d、判定が残っていない）" % r["code"]])
			failed = true
		elif int(r["code"]) != 0:
			failed = true
	out.append_array(details)
	out.append("")
	out.append("表と答えそのもの：")
	for r in _results:
		if String(r["report"]) != "":
			out.append("- %s：%s" % [r["label"], r["report"]])
	var md := "\n".join(out)
	print("\n" + md)
	var dir := "user://jev_bench"
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	var f := FileAccess.open("%s/check-%s.md" % [dir, stamp], FileAccess.WRITE)
	if f != null:
		f.store_string(md)
		f.close()
	print("[実機テスト] %s。書き出した：%s/check-%s.md" % ["失敗あり" if failed else "すべて通った",
		ProjectSettings.globalize_path(dir), stamp])
	get_tree().quit(1 if failed else 0)


static func _files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if String(f).ends_with(".json"):
			out.append(String(f))
	out.sort()
	return out


static func _has_scenario(head: String) -> bool:
	for f in _files(JevScenarios.DIR):
		if f.begins_with(head):
			return true
	return false
