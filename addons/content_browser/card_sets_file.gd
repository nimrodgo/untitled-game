@tool
extends RefCounted
## Reads and rewrites scripts/data/card_sets.gd (the CardSets.Id enum, the name and
## color of each set, and ALWAYS_SOLD) so the Content tab can add and edit sets.
##
## Set numbers are stored in the .tres files, so this only ever appends new ids and
## never renames a key or removes a set. Everything else in the file is left as it is.

const PATH := "res://scripts/data/card_sets.gd"
const ENUM_OPEN := "enum Id {"
const INFO_OPEN := "const _INFO := {"
const ALWAYS_RE := "const ALWAYS_SOLD: Array\\[Id\\] = \\[([^\\]]*)\\]"

## [{"key": String, "id": int, "name": String, "color": Color, "note": String}], enum order.
var sets: Array = []
## Keys of the sets sold in every encounter (CardSets.ALWAYS_SOLD), in file order.
var always: Array = []
var error := ""


func load_file() -> bool:
	error = ""
	var text := FileAccess.get_file_as_string(PATH)
	if text == "":
		error = "Can't read " + PATH
		return false
	var enum_body := _body(text, ENUM_OPEN)
	var info_body := _body(text, INFO_OPEN)
	if enum_body == "" or info_body == "":
		error = "Can't find the enum / _INFO blocks in " + PATH
		return false
	var out := []
	var line_re := RegEx.create_from_string("^\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*(?:=\\s*(-?\\d+))?\\s*,?\\s*(?:##\\s*(.*))?$")
	var nxt := 0
	for line in enum_body.split("\n"):
		if line.strip_edges() == "":
			continue
		var m := line_re.search(line)
		if m == null:
			continue
		var id := nxt
		if m.get_string(2) != "":
			id = int(m.get_string(2))
		out.append({"key": m.get_string(1), "id": id, "name": m.get_string(1).capitalize(),
			"color": Color("4a5568"), "note": m.get_string(3).strip_edges()})
		nxt = id + 1
	var info_re := RegEx.create_from_string("Id\\.([A-Za-z0-9_]+)\\s*:\\s*\\[\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*,\\s*Color\\(\"([^\"]*)\"\\)")
	for m in info_re.search_all(info_body):
		for s in out:
			if s["key"] == m.get_string(1):
				s["name"] = m.get_string(2).c_unescape()
				s["color"] = Color(m.get_string(3))
	var al := []
	var am := RegEx.create_from_string(ALWAYS_RE).search(text)
	if am:
		for k in RegEx.create_from_string("Id\\.([A-Za-z0-9_]+)").search_all(am.get_string(1)):
			al.append(k.get_string(1))
	sets = out
	always = al
	return true


## Writes the current sets back into card_sets.gd. Returns the new file text ("" on error).
func save_file() -> String:
	error = ""
	var text := FileAccess.get_file_as_string(PATH)
	if _body(text, ENUM_OPEN) == "" or _body(text, INFO_OPEN) == "":
		error = "Can't find the enum / _INFO blocks in " + PATH
		return ""
	var width := 0
	for s in sets:
		width = maxi(width, String(s["key"]).length() + 1)
	var enum_lines := PackedStringArray()
	var info_lines := PackedStringArray()
	for s in sets:
		var line: String = "\t" + s["key"] + ","
		if String(s["note"]) != "":
			line = "\t" + (String(s["key"]) + ",").rpad(width) + " ## " + s["note"]
		enum_lines.append(line)
		var col: Color = s["color"]
		info_lines.append("\tId.%s: [\"%s\", Color(\"%s\")]," % [s["key"], String(s["name"]).c_escape(), col.to_html(false)])
	text = _replace_body(text, ENUM_OPEN, "\n".join(enum_lines))
	text = _replace_body(text, INFO_OPEN, "\n".join(info_lines))
	var keys := PackedStringArray()
	for k in always:
		keys.append("Id." + k)
	var re := RegEx.create_from_string(ALWAYS_RE)
	if re.search(text):
		text = re.sub(text, "const ALWAYS_SOLD: Array[Id] = [%s]" % ", ".join(keys))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		error = "Can't write " + PATH
		return ""
	f.store_string(text)
	f.close()
	return text


## Appends a new set and returns it. The key is made from the name (DEEP_SEA for "Deep Sea").
func add(name: String) -> Dictionary:
	var key := RegEx.create_from_string("[^A-Z0-9]+").sub(name.strip_edges().to_upper(), "_", true)
	while key.begins_with("_"):
		key = key.substr(1)
	while key.ends_with("_"):
		key = key.left(-1)
	if key == "" or key[0] in "0123456789":
		key = "SET_" + key
	var base := key
	var i := 2
	while find_key(key) != null:
		key = "%s_%d" % [base, i]
		i += 1
	var id := 0
	for s in sets:
		id = maxi(id, int(s["id"]) + 1)
	# A color well away from the existing ones (golden-ratio hue steps).
	var col := Color.from_hsv(fmod(0.13 + id * 0.618034, 1.0), 0.6, 0.48)
	var s := {"key": key, "id": id, "name": name.strip_edges(), "color": col, "note": ""}
	sets.append(s)
	return s


func find_key(key: String):
	for s in sets:
		if s["key"] == key:
			return s
	return null


func find_id(id: int):
	for s in sets:
		if int(s["id"]) == id:
			return s
	return null


func _body(text: String, open: String) -> String:
	var a := text.find(open)
	if a < 0:
		return ""
	var b := text.find("\n}", a)
	if b < 0:
		return ""
	return text.substr(a + open.length(), b - a - open.length())


func _replace_body(text: String, open: String, body: String) -> String:
	var a := text.find(open)
	var b := text.find("\n}", a)
	return text.substr(0, a + open.length()) + "\n" + body + text.substr(b)
