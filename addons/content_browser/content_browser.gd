@tool
extends VBoxContainer
## Content browser: the "Content" tab at the top of the Godot editor.
##
## Shows every piece of content under content/test/ as tiles (one tab per kind), and edits
## the selected one in the right-hand panel. Every change is written to its .tres file about
## half a second after you stop typing, so there is no Save button; use git to undo.
##
## Editing is generic: the panel is built from each resource's exported properties, so new
## fields and new effect types show up here without touching this script. Arrays of effects
## (and trinket levels, enemy intents...) are edited inline; arrays of cards / charms / ...
## that live in their own files (decks, pools) are edited as reference lists with counts.
##
## The content scripts are not @tool, so in the editor their methods can't run (Godot gives
## them placeholder instances). This script therefore only reads and writes properties, and
## builds its own "auto:" text for anything without custom text.

const ROOT := "res://content/test/"
const CATS := [
	{"name": "Cards", "one": "Card", "dir": "cards", "script": "res://scripts/data/card_data.gd"},
	{"name": "Curses", "one": "Curse", "dir": "curses", "script": "res://scripts/data/card_data.gd"},
	{"name": "Charms", "one": "Charm", "dir": "charms", "script": "res://scripts/data/charm_data.gd"},
	{"name": "Trinkets", "one": "Trinket", "dir": "trinkets", "script": "res://scripts/data/trinket_data.gd"},
	{"name": "Enhancements", "one": "Enhancement", "dir": "enhancements", "script": "res://scripts/data/enhancement_data.gd"},
	{"name": "Enemies", "one": "Enemy", "dir": "enemies", "script": "res://scripts/data/enemy_data.gd"},
	{"name": "Enemy charms", "one": "Enemy charm", "dir": "enemy_charms", "script": "res://scripts/data/charm_data.gd"},
	{"name": "Encounters", "one": "Encounter", "dir": "encounters", "script": "res://scripts/data/encounter_data.gd"},
	{"name": "Loadouts", "one": "Loadout", "dir": "loadouts", "script": "res://scripts/data/loadout_data.gd"},
	# Not resources: the card sets themselves, stored in scripts/data/card_sets.gd.
	{"name": "Sets", "one": "Set", "dir": "", "script": ""},
]
## Scripts that use CardSets.Id in their exports: recompiled after a set is added so the
## Inspector's set menus list it too.
const SET_USERS := ["res://scripts/data/card_data.gd", "res://scripts/data/charm_data.gd",
	"res://scripts/data/trinket_data.gd", "res://scripts/data/enhancement_data.gd",
	"res://scripts/data/encounter_data.gd"]
const SetsFile := preload("res://addons/content_browser/card_sets_file.gd")
## Classes whose resources live in their own files. A property of one of these types is a
## reference (picked from the library); anything else is an owned sub-resource edited inline.
const REF_DIRS := {
	"CardData": ["cards", "curses"],
	"CharmData": ["charms", "enemy_charms"],
	"TrinketData": ["trinkets"],
	"EnhancementData": ["enhancements"],
	"EnemyData": ["enemies"],
	"EncounterData": ["encounters"],
}
## Shown first in the edit panel, in this order. Then other fields, then lists.
const FIRST := ["display_name", "id", "cost", "card_set", "trigger", "kind", "upgrade_cost",
	"on_play_text", "on_buy_text", "text", "description", "flavor_text"]
const HIDDEN := ["tags"]
const AUTO := "[color=#9fc3cf][i]auto:[/i][/color] "
const TILE_W := 168.0
const SAVE_DELAY := 0.6

## EditorInterface (null when this runs as a plain scene, e.g. for testing).
var ei: Object = null

var _s := 1.0
var _cat := 0
var _lib := {}            # dir -> Array of resources (sorted by file name)
var _mtimes := {}         # path -> modified time when we last loaded / saved it
var _pending := {}        # resource -> true, waiting to be saved
var _selected: Resource
var _tiles := {}          # resource -> tile Control in the grid
var _tex := {}
var _prop_cache := {}
var _classes := {}        # global class name -> {"base", "path"}
var _last_text: Control
var _rebuild_queued := false
var _grid_queued := false
var _panel_edit := false
var _built := false
var _del_target: Resource
var _sets_file = SetsFile.new()
var _sets_dirty := false
var _sets_mtime := 0
var _sel_set := -1        # selected set id on the Sets tab (-1 = none)

var _tabs: TabBar
var _search: LineEdit
var _set_filter: OptionButton
var _sort: OptionButton
var _zoom: HSlider
var _count: Label
var _grid_box: VBoxContainer
var _right_scroll: ScrollContainer
var _detail: VBoxContainer
var _title: Label
var _preview_holder: CenterContainer
var _fields_box: VBoxContainer
var _status: Label
var _save_timer: Timer
var _new_dialog: ConfirmationDialog
var _new_name: LineEdit
var _del_dialog: ConfirmationDialog
var _inspector_sync: CheckBox


func setup(editor_interface: Object) -> void:
	ei = editor_interface


func _ready() -> void:
	if _built:
		return
	_built = true
	if ei:
		_s = ei.get_editor_scale()
		ei.get_inspector().property_edited.connect(_on_inspector_edited)
		ei.get_resource_filesystem().filesystem_changed.connect(_check_disk)
	_scan_classes()
	_load_sets()
	_build_ui()
	_load_all()
	_refresh_grid()
	_build_detail()


func _exit_tree() -> void:
	flush()


func on_shown() -> void:
	if _built:
		_check_disk()


# ------------------------------------------------------------------------------ layout

func _build_ui() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", int(6 * _s))

	_tabs = TabBar.new()
	for c in CATS:
		_tabs.add_tab(c["name"])
	_tabs.tab_changed.connect(_on_cat)
	add_child(_tabs)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(8 * _s))
	add_child(bar)
	_search = LineEdit.new()
	_search.placeholder_text = "Search names and text…"
	_search.clear_button_enabled = true
	_search.custom_minimum_size.x = 240 * _s
	_search.text_changed.connect(func(_t: String): _refresh_grid())
	bar.add_child(_search)
	_set_filter = OptionButton.new()
	_rebuild_set_filter()
	_set_filter.item_selected.connect(func(_i: int): _refresh_grid())
	bar.add_child(_set_filter)
	_sort = OptionButton.new()
	for t in ["Group by set", "Sort by cost", "Sort by name"]:
		_sort.add_item(t)
	_sort.item_selected.connect(func(_i: int): _refresh_grid())
	bar.add_child(_sort)
	var zl := Label.new()
	zl.text = "Size"
	bar.add_child(zl)
	_zoom = HSlider.new()
	_zoom.min_value = 0.7
	_zoom.max_value = 1.8
	_zoom.step = 0.05
	_zoom.value = 1.0
	_zoom.custom_minimum_size.x = 110 * _s
	_zoom.size_flags_vertical = SIZE_SHRINK_CENTER
	_zoom.value_changed.connect(func(_v: float): _queue_grid())
	bar.add_child(_zoom)
	_count = _muted("")
	_count.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(_count)
	if ei:
		_inspector_sync = CheckBox.new()
		_inspector_sync.text = "Inspector follows selection"
		_inspector_sync.button_pressed = true
		bar.add_child(_inspector_sync)
	_btn(bar, "New…", _ask_new)
	_btn(bar, "Reload from disk", func(): _check_disk(true))

	var split := HSplitContainer.new()
	split.size_flags_horizontal = SIZE_EXPAND_FILL
	split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(split)
	var left := ScrollContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(left)
	_grid_box = VBoxContainer.new()
	_grid_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_grid_box.add_theme_constant_override("separation", int(8 * _s))
	left.add_child(_grid_box)
	_right_scroll = ScrollContainer.new()
	_right_scroll.custom_minimum_size.x = 430 * _s
	_right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(_right_scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", int(8 * _s))
	m.add_theme_constant_override("margin_right", int(10 * _s))
	_right_scroll.add_child(m)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", int(6 * _s))
	m.add_child(_detail)

	_status = _muted("Edits save to the .tres files automatically.")
	add_child(_status)

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(flush)
	add_child(_save_timer)

	_new_dialog = ConfirmationDialog.new()
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "Name"
	_new_name.text_submitted.connect(func(_t: String):
		_new_dialog.hide()
		_on_new_confirmed())
	_new_dialog.add_child(_new_name)
	_new_dialog.confirmed.connect(_on_new_confirmed)
	add_child(_new_dialog)

	_del_dialog = ConfirmationDialog.new()
	_del_dialog.title = "Delete"
	_del_dialog.ok_button_text = "Move to recycle bin"
	_del_dialog.confirmed.connect(func(): _delete(_del_target))
	add_child(_del_dialog)


func _on_cat(i: int) -> void:
	_cat = i
	_refresh_grid()


# ------------------------------------------------------------------------------ library

func _scan_classes() -> void:
	_classes.clear()
	for d in ProjectSettings.get_global_class_list():
		_classes[String(d["class"])] = {"base": String(d["base"]), "path": String(d["path"])}


func _load_all() -> void:
	_lib.clear()
	for c in CATS:
		if c["dir"] != "" and not _lib.has(c["dir"]):
			_lib[c["dir"]] = _load_dir(c["dir"])


func _files_in(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var full := ROOT + dir
	if not DirAccess.dir_exists_absolute(full):
		return out
	for f in DirAccess.get_files_at(full):
		if f.ends_with(".tres"):
			out.append(full + "/" + f)
	out.sort()
	return out


func _load_dir(dir: String) -> Array:
	var out := []
	for p in _files_in(dir):
		var r = load(p)
		if r is Resource:
			out.append(r)
			_mtimes[p] = FileAccess.get_modified_time(p)
	return out


## Picks up files added, removed or changed outside this panel (text editor, git, scripts).
func _check_disk(force := false) -> void:
	if not _built:
		return
	if force:
		_prop_cache.clear()
		_scan_classes()
	var changed := false
	var sm := FileAccess.get_modified_time(SetsFile.PATH)
	if (force or sm != _sets_mtime) and not _sets_dirty:
		_load_sets()
		_rebuild_set_filter()
		changed = true
	for dir in _lib.keys():
		var files := _files_in(dir)
		var known := PackedStringArray()
		for r in _lib[dir]:
			known.append(r.resource_path)
		known.sort()
		if files != known:
			_lib[dir] = _load_dir(dir)
			changed = true
		for r in _lib[dir]:
			var p: String = r.resource_path
			var m := FileAccess.get_modified_time(p)
			if (force or m != int(_mtimes.get(p, m))) and not _pending.has(r):
				ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE)
				_mtimes[p] = m
				changed = true
	if changed:
		if _selected and not _in_lib(_selected):
			_selected = null
		_refresh_grid()
		_build_detail.call_deferred()
		_set_status("Reloaded from disk.")


func _in_lib(r: Object) -> bool:
	if not (r is Resource):
		return false
	for d in _lib:
		if _lib[d].has(r):
			return true
	return false


func _lib_for(cls: String) -> Array:
	var out := []
	for d in REF_DIRS.get(cls, []):
		out.append_array(_lib.get(d, []))
	return out


# ------------------------------------------------------------------------------ saving

func _touch(top_res: Resource, from_panel := true) -> void:
	if top_res == null:
		return
	_pending[top_res] = true
	_panel_edit = _panel_edit or from_panel
	if _save_timer and _save_timer.is_inside_tree():
		_save_timer.start()
	_refresh_tile(top_res)
	if top_res == _selected:
		_refresh_preview()


## Writes every pending edit to disk now.
func flush() -> void:
	if _sets_dirty:
		_save_sets()
	if _pending.is_empty():
		return
	var saved := PackedStringArray()
	for r in _pending.keys():
		var p: String = r.resource_path
		if p == "" or p.contains("::"):
			continue
		var err := ResourceSaver.save(r, p)
		if err == OK:
			_mtimes[p] = FileAccess.get_modified_time(p)
			saved.append(p.get_file())
		else:
			_set_status("Could not save %s (error %d)" % [p.get_file(), err])
	_pending.clear()
	if not saved.is_empty():
		_set_status("Saved " + ", ".join(saved))
	# Edits made here: refresh the Inspector if it shows the same resource.
	if _panel_edit and ei and _selected and ei.get_inspector().get_edited_object() == _selected:
		_selected.notify_property_list_changed()
	_panel_edit = false


## Edits made in the regular Inspector: save them too, and refresh this panel.
func _on_inspector_edited(_prop: String) -> void:
	var o = ei.get_inspector().get_edited_object()
	if not (o is Resource):
		return
	var top_res: Resource = o if _in_lib(o) else _selected
	if top_res == null:
		return
	_touch(top_res, false)
	if top_res == _selected:
		_queue_rebuild()


func _assign(obj: Object, n: String, val, top_res: Resource, structural := false) -> void:
	obj.set(n, val)
	_touch(top_res)
	if structural:
		_queue_rebuild()
	if n == "card_set" and obj == top_res:
		_queue_grid()


# ------------------------------------------------------------------------------ grid

func _queue_grid() -> void:
	if not _grid_queued:
		_grid_queued = true
		_refresh_grid.call_deferred()


func _refresh_grid() -> void:
	_grid_queued = false
	if not _grid_box:
		return
	_clear(_grid_box)
	_tiles.clear()
	if _is_sets_tab():
		_refresh_sets_grid()
		return
	var all: Array = _lib.get(CATS[_cat]["dir"], [])
	var list := _visible(all)
	_count.text = "%d of %d" % [list.size(), all.size()]
	var w := TILE_W * _s * _zoom.value
	if list.is_empty():
		_grid_box.add_child(_muted("Nothing here yet. Use New… to add one." if all.is_empty() else "No matches."))
		return
	if _sort.selected == 0 and _has(list[0], "card_set"):
		var groups := {}
		for r in list:
			var id := int(r.get("card_set"))
			if not groups.has(id):
				groups[id] = []
			groups[id].append(r)
		var ids := groups.keys()
		ids.sort()
		for id in ids:
			_grid_box.add_child(_set_header(id, groups[id].size()))
			var flow := _flow()
			for r in groups[id]:
				_add_tile(flow, r, w)
			_grid_box.add_child(flow)
	else:
		var flow := _flow()
		for r in list:
			_add_tile(flow, r, w)
		_grid_box.add_child(flow)


func _visible(all: Array) -> Array:
	var q := _search.text.strip_edges().to_lower()
	var sf := _set_filter.get_selected_id()
	var out := []
	for r in all:
		if sf > 0 and _has(r, "card_set") and int(r.get("card_set")) != sf:
			continue
		if q != "" and _blob(r).find(q) < 0:
			continue
		out.append(r)
	if _sort.selected == 2:
		out.sort_custom(func(a, b): return _name(a).naturalnocasecmp_to(_name(b)) < 0)
	else:
		out.sort_custom(_by_cost)
	return out


func _by_cost(a, b) -> bool:
	var ca := _cost(a)
	var cb := _cost(b)
	if ca != cb:
		return ca < cb
	return _name(a).naturalnocasecmp_to(_name(b)) < 0


func _blob(r: Resource) -> String:
	var d := _parts(r)
	return _join([d["title"], d["tag"], d["body"], d["buy"], d["footer"], r.resource_path.get_file()], " ").to_lower()


func _add_tile(flow: Control, r: Resource, w: float) -> void:
	var t := _make_tile(r, w, false)
	flow.add_child(t)
	_tiles[r] = t


func _refresh_tile(r: Resource) -> void:
	if not _tiles.has(r) or not is_instance_valid(_tiles[r]):
		return
	var old: Control = _tiles[r]
	var parent := old.get_parent()
	if parent == null:
		return
	var t := _make_tile(r, old.custom_minimum_size.x, false)
	parent.add_child(t)
	parent.move_child(t, old.get_index())
	parent.remove_child(old)
	old.queue_free()
	_tiles[r] = t


func _on_tile_input(ev: InputEvent, r: Resource) -> void:
	var mb := ev as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_select(r)


func _select(r: Resource) -> void:
	flush()
	if _sel_set >= 0:
		_sel_set = -1
		_queue_grid()
	var prev := _selected
	_selected = r
	for x in [prev, r]:
		if x and _tiles.has(x) and is_instance_valid(_tiles[x]):
			_restyle(_tiles[x], x == _selected)
	_build_detail.call_deferred()
	if ei and r and _inspector_sync and _inspector_sync.button_pressed:
		ei.edit_resource(r)


## Jumps to a resource from a reference (deck entry, pool entry, encounter enemy...).
func _goto(r: Resource) -> void:
	if r == null:
		return
	var dir := r.resource_path.get_base_dir().get_file()
	for i in CATS.size():
		if CATS[i]["dir"] == dir and i != _cat:
			_tabs.current_tab = i
			break
	_select(r)


func _set_header(id: int, count: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(8 * _s))
	var sw := ColorRect.new()
	sw.color = _set_color(id).lightened(0.15)
	sw.custom_minimum_size = Vector2(14, 14) * _s
	sw.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(sw)
	var l := Label.new()
	l.text = "%s  ·  %d" % [_set_name(id), count]
	l.add_theme_font_size_override("font_size", int(16 * _s))
	h.add_child(l)
	return h


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.size_flags_horizontal = SIZE_EXPAND_FILL
	f.add_theme_constant_override("h_separation", int(10 * _s))
	f.add_theme_constant_override("v_separation", int(10 * _s))
	return f


# ------------------------------------------------------------------------------ tiles

func _make_tile(r: Resource, w: float, big: bool) -> Control:
	var panel := _tile_from(_parts(r), w, big, r == _selected and not big, r.resource_path.get_file())
	if not big:
		panel.gui_input.connect(_on_tile_input.bind(r))
	return panel


## A tile from _parts()-style data (title, cost, tag, body, buy, footer, flavor, bg, badge).
func _tile_from(d: Dictionary, w: float, big: bool, selected: bool, tip: String) -> Control:
	# Text scale follows the tile width; the big preview keeps text readable, not huge.
	var k := minf(w / TILE_W, 1.3 * _s) if big else w / TILE_W
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, 0.0 if big else w * 1.4)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = tip
	panel.set_meta("bg", d["bg"])
	panel.set_meta("k", k)
	_restyle(panel, selected)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", int(4 * k))
	panel.add_child(vb)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	var badge: String = d["badge"]
	if badge != "" and Icons.SVG.has(Icons.ALIASES.get(badge, badge)):
		top.add_child(_icon_rect(badge, 20 * k))
	var title := Label.new()
	title.text = d["title"]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", int(15 * k))
	title.add_theme_color_override("font_color", Palette.FOAM)
	top.add_child(title)
	if int(d["cost"]) >= 0:
		var coin := PanelContainer.new()
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.custom_minimum_size = Vector2(26, 26) * k
		coin.size_flags_vertical = SIZE_SHRINK_BEGIN
		coin.add_theme_stylebox_override("panel", _box(Palette.GOLD, Color.TRANSPARENT, int(13 * k), 0, 0))
		var cl := Label.new()
		cl.text = str(d["cost"])
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_theme_font_size_override("font_size", int(16 * k))
		cl.add_theme_color_override("font_color", Palette.ABYSS)
		coin.add_child(cl)
		top.add_child(coin)

	if d["tag"] != "":
		vb.add_child(_rich(d["tag"], 11 * k, Palette.KELP, true))
	var body := _rich(d["body"], 13 * k, Palette.FOAM.darkened(0.05), big)
	if not big:
		body.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(body)
	if d["footer"] != "":
		vb.add_child(_rich(d["footer"], 11 * k, Palette.CORAL, true))
	if d["buy"] != "":
		vb.add_child(_buy_strip(d["buy"], k))
	if big and d["flavor"] != "":
		vb.add_child(_rich("[i]%s[/i]" % d["flavor"], 12 * k, Palette.MUTED, true))
	return panel


func _restyle(panel: Control, selected: bool) -> void:
	var bg: Color = panel.get_meta("bg")
	var k: float = panel.get_meta("k")
	var border := Palette.GOLD if selected else bg.lightened(0.25)
	panel.add_theme_stylebox_override("panel", _box(bg, border, int(10 * k), 3 if selected else 1, int(8 * k)))


func _buy_strip(text: String, k: float) -> Control:
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", _box(Palette.GOLD.darkened(0.55), Palette.GOLD.darkened(0.15), int(7 * k), 1, int(4 * k)))
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(hb)
	hb.add_child(_icon_rect(Icons.BUY, 16 * k))
	var t := _rich(text, 12 * k, Palette.FOAM, true)
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	t.size_flags_vertical = SIZE_SHRINK_CENTER
	hb.add_child(t)
	return strip


## What a tile shows, per kind of resource.
func _parts(r: Resource) -> Dictionary:
	var d := {"title": _name(r), "cost": -1, "tag": "", "body": "", "buy": "", "footer": "",
		"flavor": "", "bg": Palette.PANEL, "badge": ""}
	var s = r.get_script()
	var cls := String(s.get_global_name()) if s else ""
	match cls:
		"CardData": _card_parts(r, d)
		"CharmData": _charm_parts(r, d)
		"TrinketData": _trinket_parts(r, d)
		"EnhancementData": _enh_parts(r, d)
		"EnemyData": _enemy_parts(r, d)
		"EncounterData": _encounter_parts(r, d)
		"LoadoutData": _loadout_parts(r, d)
		_: d["body"] = _auto(_effect_text(r))
	return d


func _card_parts(r: Resource, d: Dictionary) -> void:
	var curse := bool(_g(r, "curse", false))
	var tags := []
	if _g(r, "instant", false):
		tags.append("⚡ Instant")
	if not _g(r, "playable", true):
		tags.append("Unplayable")
	if curse:
		tags.append("☠ Curse")
	if _g(r, "permanent", false):
		tags.append("Permanent")
	if _g(r, "unlimited_enhancements", false):
		tags.append("Any number of enhancements")
	d["tag"] = _join(tags, " · ")
	d["cost"] = _cost(r)
	var t := str(_g(r, "on_play_text", ""))
	if t == "":
		var parts := []
		for pair in [["on_play", ""], ["on_discard", "When discarded: "], ["on_destroy", "When destroyed: "],
				["on_remove", "When removed: "], ["on_turn_end_in_hand", "End of turn, if in hand: "]]:
			var fx = _g(r, pair[0], [])
			if fx is Array and not fx.is_empty():
				parts.append(pair[1] + _effects_text(fx))
		t = _auto(_join(parts, ". "))
	d["body"] = t
	var b := str(_g(r, "on_buy_text", ""))
	if b == "":
		var fx = _g(r, "on_buy", [])
		if fx is Array and not fx.is_empty():
			b = _auto(_effects_text(fx))
		elif not curse:
			b = "[color=#ff7f6a]No on-buy yet[/color]"
	d["buy"] = b
	d["flavor"] = str(_g(r, "flavor_text", ""))
	d["bg"] = Palette.CARD_CURSE if curse else _bg_for_set(r, Palette.CARD)


func _charm_parts(r: Resource, d: Dictionary) -> void:
	d["cost"] = _cost(r)
	var bits := [_enum_label(r, "trigger")]
	var lpe := int(_g(r, "limit_per_encounter", 0))
	var lpr := int(_g(r, "limit_per_round", 0))
	if lpe > 0:
		bits.append("%d× per encounter" % lpe)
	if lpr > 0:
		bits.append("%d× per round" % lpr)
	d["tag"] = _join(bits, " · ")
	var desc := str(_g(r, "description", ""))
	d["body"] = desc if desc != "" else _auto(_effects_text(_g(r, "effects", [])))
	var flags := []
	var po := int(_g(r, "shop_price_override", -1))
	if po >= 0:
		flags.append("Market prices → %d" % po)
	if _g(r, "restock_bought_cards", false):
		flags.append("Restocks bought slots")
	var cb := int(_g(r, "coin_gain_bonus", 0))
	if cb != 0:
		flags.append("+%d 🪙 on every gain" % cb)
	d["footer"] = _join(flags, " · ")
	d["bg"] = _bg_for_set(r, Palette.CARD_CHARM)


func _trinket_parts(r: Resource, d: Dictionary) -> void:
	d["cost"] = _cost(r)
	var levels = _g(r, "levels", [])
	var lines := []
	var desc := str(_g(r, "description", ""))
	if desc != "":
		lines.append(desc)
	if levels is Array:
		for i in levels.size():
			var lvl = levels[i]
			if lvl == null:
				continue
			var txt := str(lvl.get("text"))
			if txt == "":
				txt = _auto(_effects_text(lvl.get("effects")))
			var prefix := ""
			if levels.size() > 1:
				prefix = "[b]Lv%d[/b] " % (i + 1)
				if i > 0:
					prefix += "[color=#ffd166](+%d 🪙)[/color] " % int(lvl.get("upgrade_cost"))
			lines.append(prefix + txt)
		if levels.size() > 1:
			d["tag"] = "%d levels" % levels.size()
	d["body"] = _join(lines, "\n")
	d["bg"] = _bg_for_set(r, Palette.CARD_TRINKET)


func _enh_parts(r: Resource, d: Dictionary) -> void:
	d["cost"] = _cost(r)
	d["badge"] = str(_g(r, "icon", ""))
	var tags := []
	if _g(r, "make_instant", false):
		tags.append("⚡ Makes instant")
	if _g(r, "retain", false):
		tags.append("📌 Retain")
	if _g(r, "destroy_on_apply", false):
		tags.append("🔥 Destroys the card")
	if _g(r, "counts_as_curse", false):
		tags.append("☠ Counts as curse")
	d["tag"] = _join(tags, " · ")
	var desc := str(_g(r, "description", ""))
	if desc == "":
		var parts := []
		var fx = _g(r, "extra_on_play", [])
		if fx is Array and not fx.is_empty():
			parts.append("On play: " + _effects_text(fx))
		fx = _g(r, "on_discard", [])
		if fx is Array and not fx.is_empty():
			parts.append("When discarded: " + _effects_text(fx))
		desc = _auto(_join(parts, ". "))
	d["body"] = desc
	d["bg"] = _bg_for_set(r, Palette.CARD_ENH)


func _enemy_parts(r: Resource, d: Dictionary) -> void:
	d["tag"] = "Starts with %d 🪙 · %d actions / round" % [int(_g(r, "starting_coins", 0)), int(_g(r, "actions_per_round", 0))]
	var lines := []
	var intents = _g(r, "intents", [])
	var start := int(_g(r, "start_intent", 0))
	if intents is Array:
		for i in intents.size():
			var it = intents[i]
			if it == null:
				continue
			var desc := str(it.get("description"))
			if desc == "":
				desc = _auto(_effects_text(it.get("effects")))
			lines.append("%s[b]%s[/b] [color=#9fc3cf]%s[/color]  %s" % [
				"▶ " if i == start else "", it.get("display_name"), _enum_label(it, "kind"), desc])
	d["body"] = _join(lines, "\n")
	var charms = _g(r, "charms", [])
	if charms is Array and not charms.is_empty():
		d["footer"] = "Charms: " + _names(charms)
	var c = _g(r, "color", Palette.CORAL)
	d["bg"] = c.darkened(0.55) if c is Color else Palette.PANEL


func _encounter_parts(r: Resource, d: Dictionary) -> void:
	d["tag"] = "%d rounds · target %d 🪙" % [int(_g(r, "rounds", 0)), int(_g(r, "coin_target", 0))]
	var lines := []
	var enemy = _g(r, "enemy", null)
	lines.append("Enemy: [b]%s[/b]" % (_name(enemy) if enemy else "none"))
	var sets = _g(r, "card_sets", [])
	if sets is Array and not sets.is_empty():
		var names := []
		for id in sets:
			names.append(_set_name(int(id)))
		lines.append("Sets: %s [color=#9fc3cf](+ Utility, Coins)[/color]" % _join(names, ", "))
	else:
		lines.append("Sets: none (pools only)")
	lines.append("Market: %d cards · %d charms · %d trinkets · %d upgrades" % [
		int(_g(r, "card_slots", 0)), int(_g(r, "charm_slots", 0)), int(_g(r, "trinket_slots", 0)), int(_g(r, "enhancement_slots", 0))])
	for pool in ["card_pool", "charm_pool", "trinket_pool", "enhancement_pool"]:
		var arr = _g(r, pool, [])
		if arr is Array and not arr.is_empty():
			lines.append("%s: %s" % [pool.capitalize(), _names(arr)])
	if _g(r, "refill_card_slots", false):
		lines.append("Refills card slots right away")
	d["body"] = _join(lines, "\n")
	var rng := int(_g(r, "rng_seed", 0))
	if rng != 0:
		d["footer"] = "Fixed seed %d" % rng
	d["bg"] = Palette.PANEL


func _loadout_parts(r: Resource, d: Dictionary) -> void:
	var deck = _g(r, "starting_deck", [])
	var n: int = deck.size() if deck is Array else 0
	d["tag"] = "%d cards · start with %d 🪙" % [n, int(_g(r, "starting_coins", 0))]
	var lines := []
	if deck is Array:
		lines.append(_counted(deck))
	for key in ["charms", "trinkets"]:
		var arr = _g(r, key, [])
		if arr is Array and not arr.is_empty():
			lines.append("%s: %s" % [key.capitalize(), _names(arr)])
	d["body"] = _join(lines, "\n")
	d["bg"] = Palette.DEEP.lightened(0.08)


# ------------------------------------------------------------------------------ detail panel

func _build_detail() -> void:
	if not _detail:
		return
	_clear(_detail)
	_last_text = null
	_fields_box = null
	_preview_holder = null
	_title = null
	if _sel_set >= 0:
		_build_set_detail()
		return
	var r := _selected
	if r == null:
		_detail.add_child(_muted("Click a tile to see it here and edit it.\n\nEvery change is saved to its .tres file right away (use git to undo)."))
		return
	_title = Label.new()
	_title.text = _name(r)
	_title.add_theme_font_size_override("font_size", int(20 * _s))
	_detail.add_child(_title)
	_detail.add_child(_muted(r.resource_path))

	var btns := HFlowContainer.new()
	if ei:
		_btn(btns, "Inspector", _inspect.bind(r))
		_btn(btns, "Show file", _show_file.bind(r))
	_btn(btns, "Duplicate", _duplicate.bind(r))
	_btn(btns, "Delete…", _ask_delete.bind(r))
	_detail.add_child(btns)

	_preview_holder = CenterContainer.new()
	_detail.add_child(_preview_holder)
	_refresh_preview()

	var icons := HFlowContainer.new()
	var il := _muted("Insert icon:")
	il.autowrap_mode = TextServer.AUTOWRAP_OFF
	il.size_flags_vertical = SIZE_SHRINK_CENTER
	icons.add_child(il)
	for tok in Icons.SVG.keys():
		var b := Button.new()
		b.icon = _icon(tok)
		b.expand_icon = true
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(28, 28) * _s
		b.tooltip_text = "%s  %s" % [tok, Icons.TIPS.get(tok, "")]
		b.pressed.connect(_insert.bind(tok))
		icons.add_child(b)
	_detail.add_child(icons)
	_detail.add_child(HSeparator.new())

	_fields_box = VBoxContainer.new()
	_fields_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_fields_box.add_theme_constant_override("separation", int(4 * _s))
	_detail.add_child(_fields_box)
	_build_fields(r, _fields_box, r, 0)


func _refresh_preview() -> void:
	if _preview_holder == null or not is_instance_valid(_preview_holder):
		return
	if _sel_set >= 0:
		var st = _sets_file.find_id(_sel_set)
		if st:
			_clear(_preview_holder)
			_preview_holder.add_child(_make_set_tile(st, 300 * _s, true))
			if _title and is_instance_valid(_title):
				_title.text = st["name"]
		return
	if _selected == null:
		return
	_clear(_preview_holder)
	_preview_holder.add_child(_make_tile(_selected, 300 * _s, true))
	if _title and is_instance_valid(_title):
		_title.text = _name(_selected)


func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild_fields.call_deferred()


func _rebuild_fields() -> void:
	_rebuild_queued = false
	if _selected == null or _fields_box == null or not is_instance_valid(_fields_box):
		return
	var sv := _right_scroll.scroll_vertical
	_clear(_fields_box)
	_last_text = null
	_build_fields(_selected, _fields_box, _selected, 0)
	_refresh_preview()
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
		_right_scroll.scroll_vertical = sv


func _inspect(r: Resource) -> void:
	if ei:
		ei.edit_resource(r)


func _show_file(r: Resource) -> void:
	if ei:
		ei.select_file(r.resource_path)


func _insert(tok: String) -> void:
	var c := _last_text
	if c == null or not is_instance_valid(c):
		_set_status("Click into a text field first, then pick an icon.")
		return
	if c is LineEdit:
		(c as LineEdit).insert_text_at_caret(tok)
	elif c is TextEdit:
		(c as TextEdit).insert_text_at_caret(tok)
	if c.has_meta("commit"):
		var cb: Callable = c.get_meta("commit")
		cb.call(c.get("text"))
	c.grab_focus()


# ------------------------------------------------------------------------------ fields

func _build_fields(obj: Object, box: VBoxContainer, top_res: Resource, depth: int) -> void:
	if obj == null or depth > 8:
		return
	for p in _sorted_props(obj):
		var n: String = p["name"]
		if n in HIDDEN:
			continue
		var v = obj.get(n)
		match int(p["type"]):
			TYPE_BOOL:
				var cb := CheckBox.new()
				cb.button_pressed = bool(v)
				cb.toggled.connect(func(on: bool): _assign(obj, n, on, top_res))
				_row(box, n, cb)
			TYPE_INT:
				_int_field(obj, p, v, box, top_res)
			TYPE_FLOAT:
				var sp := _spin(float(v), 0.05)
				sp.value_changed.connect(func(x: float): _assign(obj, n, x, top_res))
				_row(box, n, sp)
			TYPE_STRING, TYPE_STRING_NAME:
				_text_field(obj, p, v, box, top_res)
			TYPE_COLOR:
				var cp := ColorPickerButton.new()
				cp.color = v
				cp.custom_minimum_size.y = 24 * _s
				cp.color_changed.connect(func(c: Color): _assign(obj, n, c, top_res))
				_row(box, n, cp)
			TYPE_OBJECT:
				_object_field(obj, p, v, box, top_res, depth)
			TYPE_ARRAY:
				_array_field(obj, p, v, box, top_res, depth)


func _int_field(obj: Object, p: Dictionary, v, box: VBoxContainer, top_res: Resource) -> void:
	var n: String = p["name"]
	var hint := int(p["hint"])
	if hint == PROPERTY_HINT_ENUM:
		var opt := OptionButton.new()
		for e in (_set_items() if n == "card_set" else _enum_items(p["hint_string"])):
			opt.add_item(e[0], e[1])
		var idx := opt.get_item_index(int(v))
		if idx >= 0:
			opt.select(idx)
		opt.item_selected.connect(func(i: int): _assign(obj, n, opt.get_item_id(i), top_res))
		_row(box, n, opt)
	elif hint == PROPERTY_HINT_FLAGS:
		var flow := HFlowContainer.new()
		for e in _flag_items(p["hint_string"]):
			var cb := CheckBox.new()
			cb.text = e[0]
			var bit: int = e[1]
			cb.button_pressed = (int(v) & bit) != 0
			cb.toggled.connect(_toggle_flag.bind(obj, n, bit, top_res))
			flow.add_child(cb)
		_row(box, n, flow)
	else:
		var sp := _spin(int(v), 1)
		sp.value_changed.connect(func(x: float): _assign(obj, n, int(x), top_res))
		_row(box, n, sp)


func _toggle_flag(on: bool, obj: Object, n: String, bit: int, top_res: Resource) -> void:
	var cur := int(obj.get(n))
	_assign(obj, n, (cur | bit) if on else (cur & ~bit), top_res)


func _text_field(obj: Object, p: Dictionary, v, box: VBoxContainer, top_res: Resource) -> void:
	var n: String = p["name"]
	var is_name := int(p["type"]) == TYPE_STRING_NAME
	var commit := func(t: String): _assign(obj, n, StringName(t) if is_name else t, top_res)
	if int(p["hint"]) == PROPERTY_HINT_MULTILINE_TEXT:
		var te := TextEdit.new()
		te.text = str(v)
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.scroll_fit_content_height = true
		te.custom_minimum_size.y = 34 * _s
		te.size_flags_horizontal = SIZE_EXPAND_FILL
		te.set_meta("commit", commit)
		te.text_changed.connect(func(): commit.call(te.text))
		te.focus_entered.connect(func(): _last_text = te)
		box.add_child(_field_label(n))
		box.add_child(te)
	else:
		var le := LineEdit.new()
		le.text = str(v)
		le.set_meta("commit", commit)
		le.text_changed.connect(func(t: String): commit.call(t))
		le.focus_entered.connect(func(): _last_text = le)
		_row(box, n, le)


func _object_field(obj: Object, p: Dictionary, v, box: VBoxContainer, top_res: Resource, depth: int) -> void:
	var n: String = p["name"]
	var cls: String = p["hint_string"]
	if REF_DIRS.has(cls):
		var choices := _lib_for(cls)
		var opt := OptionButton.new()
		opt.add_item("(none)", 0)
		for i in choices.size():
			opt.add_item(_label_for(choices[i]), i + 1)
		opt.select(choices.find(v) + 1)
		opt.size_flags_horizontal = SIZE_EXPAND_FILL
		opt.item_selected.connect(func(i: int): _assign(obj, n, choices[i - 1] if i > 0 else null, top_res, true))
		var h := HBoxContainer.new()
		h.add_child(opt)
		if v is Resource:
			_small_btn(h, "Open", _goto.bind(v)).tooltip_text = "Jump to %s" % _name(v)
		_row(box, n, h)
	elif v is Resource and not _is_file_res(v):
		var inner := _group(box, "%s: %s" % [n.capitalize(), _class_title(v)])
		_build_fields(v, inner, top_res, depth + 1)


func _array_field(obj: Object, p: Dictionary, v, box: VBoxContainer, top_res: Resource, depth: int) -> void:
	var n: String = p["name"]
	var hs: String = p["hint_string"]
	var et := -1
	var eh := 0
	var ecls := ""
	if int(p["hint"]) == PROPERTY_HINT_ARRAY_TYPE:
		et = TYPE_OBJECT
		ecls = hs
	else:
		var colon := hs.find(":")
		if colon < 0:
			return
		var head := hs.substr(0, colon).split("/")
		et = int(head[0])
		if head.size() > 1:
			eh = int(head[1])
		ecls = hs.substr(colon + 1)
	var arr: Array = v if v is Array else []
	if et == TYPE_INT and eh == PROPERTY_HINT_ENUM:
		var flow := HFlowContainer.new()
		for e in (_set_items() if n == "card_sets" else _enum_items(ecls)):
			if String(e[0]).to_upper() == "NONE" or (n == "card_sets" and int(e[1]) == 0):
				continue
			var cb := CheckBox.new()
			cb.text = e[0]
			cb.button_pressed = arr.has(e[1])
			cb.toggled.connect(_toggle_in_array.bind(obj, n, int(e[1]), top_res))
			flow.add_child(cb)
		_row(box, n, flow)
	elif et == TYPE_OBJECT and REF_DIRS.has(ecls):
		_ref_list(obj, n, arr, ecls, box, top_res)
	elif et == TYPE_OBJECT and _classes.has(ecls):
		_sub_list(obj, n, arr, ecls, box, top_res, depth)


func _toggle_in_array(on: bool, obj: Object, n: String, val: int, top_res: Resource) -> void:
	var a: Array = (obj.get(n) as Array).duplicate()
	if on and not a.has(val):
		a.append(val)
	elif not on:
		a.erase(val)
	a.sort()
	_assign(obj, n, a, top_res)


## A list of references to library resources (a deck, a pool...), shown with counts.
func _ref_list(obj: Object, n: String, arr: Array, cls: String, box: VBoxContainer, top_res: Resource) -> void:
	var inner := _group(box, "%s  (%d)" % [n.capitalize(), arr.size()])
	var order := []
	var counts := {}
	for r in arr:
		if r == null:
			continue
		if not counts.has(r):
			order.append(r)
			counts[r] = 0
		counts[r] += 1
	for r in order:
		var h := HBoxContainer.new()
		var link := LinkButton.new()
		link.text = _label_for(r)
		link.size_flags_horizontal = SIZE_EXPAND_FILL
		link.tooltip_text = "Jump to %s" % _name(r)
		link.pressed.connect(_goto.bind(r))
		h.add_child(link)
		var c := Label.new()
		c.text = "×%d" % counts[r]
		h.add_child(c)
		_small_btn(h, "−", _ref_remove.bind(obj, n, r, top_res))
		_small_btn(h, "+", _ref_add.bind(obj, n, r, top_res))
		inner.add_child(h)
	var choices := _lib_for(cls)
	var add := OptionButton.new()
	add.add_item("+ Add…", 0)
	for i in choices.size():
		add.add_item(_label_for(choices[i]), i + 1)
	add.item_selected.connect(func(i: int):
		if i > 0:
			_ref_add(obj, n, choices[i - 1], top_res))
	inner.add_child(add)


func _ref_add(obj: Object, n: String, r: Resource, top_res: Resource) -> void:
	var a: Array = (obj.get(n) as Array).duplicate()
	var at := a.rfind(r)
	if at < 0:
		a.append(r)
	else:
		a.insert(at + 1, r)
	_assign(obj, n, a, top_res, true)


func _ref_remove(obj: Object, n: String, r: Resource, top_res: Resource) -> void:
	var a: Array = (obj.get(n) as Array).duplicate()
	var at := a.rfind(r)
	if at >= 0:
		a.remove_at(at)
	_assign(obj, n, a, top_res, true)


## A list of owned sub-resources (effects, trinket levels, intents...), each edited inline.
func _sub_list(obj: Object, n: String, arr: Array, cls: String, box: VBoxContainer, top_res: Resource, depth: int) -> void:
	var inner := _group(box, "%s  (%d)" % [n.capitalize(), arr.size()])
	for i in arr.size():
		var e = arr[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.2), Color(1, 1, 1, 0.08), 6, 1, int(6 * _s)))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", int(3 * _s))
		card.add_child(vb)
		var head := HBoxContainer.new()
		var t := Label.new()
		t.text = ("%d. " % (i + 1)) + (_class_title(e) if e else "(empty)")
		t.size_flags_horizontal = SIZE_EXPAND_FILL
		t.add_theme_color_override("font_color", Palette.GOLD)
		head.add_child(t)
		var up := _small_btn(head, "▲", _move_item.bind(obj, n, i, -1, top_res))
		up.disabled = i == 0
		up.tooltip_text = "Move up"
		var down := _small_btn(head, "▼", _move_item.bind(obj, n, i, 1, top_res))
		down.disabled = i == arr.size() - 1
		down.tooltip_text = "Move down"
		_small_btn(head, "✕", _remove_item.bind(obj, n, i, top_res)).tooltip_text = "Remove"
		vb.add_child(head)
		if e:
			_build_fields(e, vb, top_res, depth + 1)
		inner.add_child(card)
	var kinds := _subclasses(cls)
	if kinds.size() == 1:
		var b := Button.new()
		b.text = "+ Add %s" % _pretty_class(kinds[0])
		b.pressed.connect(_add_item.bind(obj, n, kinds[0], top_res))
		inner.add_child(b)
	elif kinds.size() > 1:
		var opt := OptionButton.new()
		opt.add_item("+ Add %s…" % _pretty_class(cls).to_lower(), 0)
		for i in kinds.size():
			opt.add_item(_pretty_class(kinds[i]), i + 1)
		opt.item_selected.connect(func(i: int):
			if i > 0:
				_add_item(obj, n, kinds[i - 1], top_res))
		inner.add_child(opt)


func _move_item(obj: Object, n: String, i: int, dir: int, top_res: Resource) -> void:
	var a: Array = (obj.get(n) as Array).duplicate()
	var j := i + dir
	if j < 0 or j >= a.size():
		return
	var tmp = a[i]
	a[i] = a[j]
	a[j] = tmp
	_assign(obj, n, a, top_res, true)


func _remove_item(obj: Object, n: String, i: int, top_res: Resource) -> void:
	var a: Array = (obj.get(n) as Array).duplicate()
	if i < a.size():
		a.remove_at(i)
	_assign(obj, n, a, top_res, true)


func _add_item(obj: Object, n: String, cls: String, top_res: Resource) -> void:
	var r := _new_instance(cls)
	if r == null:
		return
	var a: Array = (obj.get(n) as Array).duplicate()
	a.append(r)
	_assign(obj, n, a, top_res, true)


func _new_instance(cls: String) -> Resource:
	if not _classes.has(cls):
		return null
	var r := Resource.new()
	r.set_script(load(_classes[cls]["path"]))
	return r


func _subclasses(base: String) -> Array:
	var out := []
	for c in _classes.keys():
		if c != "Effect" and _inherits(c, base):
			out.append(c)
	out.sort_custom(func(a, b): return _pretty_class(a) < _pretty_class(b))
	return out


func _inherits(c: String, base: String) -> bool:
	var cur := c
	for _i in 20:
		if cur == base:
			return true
		if not _classes.has(cur):
			return false
		cur = _classes[cur]["base"]
	return false


# ------------------------------------------------------------------------------ new / duplicate / delete

func _ask_new() -> void:
	var c: Dictionary = CATS[_cat]
	_new_dialog.title = "New %s" % c["one"].to_lower()
	_new_name.text = ""
	_new_dialog.popup_centered(Vector2i(int(360 * _s), 0))
	_new_name.grab_focus.call_deferred()


func _on_new_confirmed() -> void:
	var nm := _new_name.text.strip_edges()
	if nm == "":
		return
	if _is_sets_tab():
		_add_set(nm)
		return
	var c: Dictionary = CATS[_cat]
	var r := Resource.new()
	r.set_script(load(c["script"]))
	var slug := _slug(nm)
	if _has(r, "display_name"):
		r.set("display_name", nm)
	if _has(r, "id"):
		r.set("id", StringName(slug))
	if c["dir"] == "curses":
		r.set("curse", true)
		r.set("playable", false)
		r.set("cost", 0)
		r.set("card_set", 1)
	else:
		if _has(r, "card_set") and _set_filter.get_selected_id() > 0:
			r.set("card_set", _set_filter.get_selected_id())
		if c["dir"] == "cards":
			r.set("on_buy_text", "TBD")
	_save_new(r, c["dir"], slug)


func _duplicate(r: Resource) -> void:
	flush()
	var dup: Resource = r.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	var nm := _name(r) + " Copy"
	var slug := _slug(nm)
	if _has(dup, "display_name"):
		dup.set("display_name", nm)
	if _has(dup, "id"):
		dup.set("id", StringName(slug))
	_save_new(dup, r.resource_path.get_base_dir().get_file(), slug)


func _save_new(r: Resource, dir: String, slug: String) -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + dir)
	var path := ROOT + dir + "/" + slug + ".tres"
	var i := 2
	while FileAccess.file_exists(path):
		path = "%s%s/%s_%d.tres" % [ROOT, dir, slug, i]
		i += 1
	var err := ResourceSaver.save(r, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		_set_status("Could not create %s (error %d)" % [path, err])
		return
	var loaded = load(path)
	if not (loaded is Resource):
		loaded = r
	_mtimes[path] = FileAccess.get_modified_time(path)
	if not _lib.has(dir):
		_lib[dir] = []
	_lib[dir].append(loaded)
	_lib[dir].sort_custom(func(a, b): return a.resource_path < b.resource_path)
	if ei:
		ei.get_resource_filesystem().update_file(path)
	_refresh_grid()
	_select(loaded)
	_set_status("Created " + path)


func _ask_delete(r: Resource) -> void:
	_del_target = r
	var msg := "Move %s to the recycle bin?" % r.resource_path.get_file()
	var refs := _refs_to(r)
	if not refs.is_empty():
		msg += "\n\nIt is still used by: %s\nThose references will break." % ", ".join(refs)
	_del_dialog.dialog_text = msg
	_del_dialog.popup_centered()


func _refs_to(r: Resource) -> PackedStringArray:
	var out := PackedStringArray()
	var files := ["res://scenes/main.tscn"]
	for d in _lib:
		for o in _lib[d]:
			if o != r:
				files.append(o.resource_path)
	var needle := '"%s"' % r.resource_path
	for f in files:
		if FileAccess.file_exists(f) and FileAccess.get_file_as_string(f).contains(needle):
			out.append(String(f).get_file())
	return out


func _delete(r: Resource) -> void:
	if r == null:
		return
	var p := r.resource_path
	_pending.erase(r)
	var err := OS.move_to_trash(ProjectSettings.globalize_path(p))
	if err != OK:
		_set_status("Could not delete %s (error %d)" % [p.get_file(), err])
		return
	for d in _lib:
		_lib[d].erase(r)
	_mtimes.erase(p)
	if _selected == r:
		_selected = null
		_build_detail.call_deferred()
	if ei:
		ei.get_resource_filesystem().scan()
	_refresh_grid()
	_set_status("Moved %s to the recycle bin." % p.get_file())


# ------------------------------------------------------------------------------ card sets

func _is_sets_tab() -> bool:
	return CATS[_cat]["dir"] == ""


func _load_sets() -> void:
	if _sets_file.load_file():
		_sets_mtime = FileAccess.get_modified_time(SetsFile.PATH)
	else:
		_set_status(_sets_file.error)


func _save_sets() -> void:
	_sets_dirty = false
	var text: String = _sets_file.save_file()
	if text == "":
		_set_status(_sets_file.error)
		return
	_sets_mtime = FileAccess.get_modified_time(SetsFile.PATH)
	if ei:
		# Recompile CardSets (and the scripts whose exports use it) in the editor.
		var sc = load(SetsFile.PATH)
		if sc is Script:
			sc.source_code = text
			sc.reload(true)
		for path in SET_USERS:
			var u = load(path)
			if u is Script:
				u.reload(true)
		_prop_cache.clear()
		ei.get_resource_filesystem().update_file(SetsFile.PATH)
	_set_status("Saved card_sets.gd")


func _rebuild_set_filter() -> void:
	var cur := _set_filter.get_selected_id() if _set_filter.item_count > 0 else 0
	_set_filter.clear()
	_set_filter.add_item("All sets", 0)
	for id in _set_ids():
		_set_filter.add_item(_set_name(id), id)
	_set_filter.select(maxi(_set_filter.get_item_index(cur), 0))


func _sets_changed() -> void:
	_sets_dirty = true
	if _save_timer and _save_timer.is_inside_tree():
		_save_timer.start()
	_rebuild_set_filter()
	_refresh_preview()
	_queue_grid()


func _add_set(nm: String) -> void:
	var st: Dictionary = _sets_file.add(nm)
	_save_sets()
	_rebuild_set_filter()
	_selected = null
	_sel_set = int(st["id"])
	_refresh_grid()
	_build_detail.call_deferred()
	_set_status("Added set %s (CardSets.Id.%s = %d)" % [st["name"], st["key"], st["id"]])


func _refresh_sets_grid() -> void:
	var q := _search.text.strip_edges().to_lower()
	var flow := _flow()
	var n := 0
	for st in _sets_file.sets:
		if int(st["id"]) == 0:
			continue
		if q != "" and ("%s %s %s" % [st["name"], st["note"], st["key"]]).to_lower().find(q) < 0:
			continue
		var t := _make_set_tile(st, TILE_W * _s * _zoom.value, false)
		t.gui_input.connect(_on_set_tile_input.bind(int(st["id"])))
		flow.add_child(t)
		n += 1
	_count.text = "%d sets" % n
	_grid_box.add_child(flow)
	_grid_box.add_child(_muted("New… adds a set. Sets can't be deleted, because their numbers are stored in the content files: rename or reuse one instead."))


## How many pieces of each kind are in set `id`, and which encounters sell it.
func _set_usage(id: int) -> Dictionary:
	var out := {}
	for dir in ["cards", "curses", "charms", "trinkets", "enhancements"]:
		var n := 0
		for r in _lib.get(dir, []):
			if int(_g(r, "card_set", 0)) == id:
				n += 1
		out[dir] = n
	var encs := []
	for r in _lib.get("encounters", []):
		var cs = _g(r, "card_sets", [])
		if cs is Array and cs.has(id):
			encs.append(_name(r))
	out["encounters"] = encs
	return out


func _make_set_tile(st: Dictionary, w: float, big: bool) -> Control:
	var id := int(st["id"])
	var u := _set_usage(id)
	var lines := []
	if String(st["note"]) != "":
		lines.append(st["note"])
	var counts := []
	for pair in [["cards", "card"], ["curses", "curse"], ["charms", "charm"], ["trinkets", "trinket"], ["enhancements", "upgrade"]]:
		var c: int = u[pair[0]]
		if c > 0:
			counts.append("%d %s%s" % [c, pair[1], "" if c == 1 else "s"])
	lines.append("[b]%s[/b]" % (_join(counts, " · ") if not counts.is_empty() else "Empty"))
	var always: bool = _sets_file.always.has(st["key"])
	if always:
		lines.append("Sold in every encounter that lists sets")
	elif not u["encounters"].is_empty():
		lines.append("Sold in: " + _join(u["encounters"], ", "))
	else:
		lines.append("[color=#9fc3cf]No encounter sells it yet[/color]")
	var d := {"title": st["name"], "cost": -1, "tag": "Always sold" if always else "",
		"body": _join(lines, "\n"), "buy": "", "footer": "", "flavor": "", "bg": st["color"], "badge": ""}
	return _tile_from(d, w, big, id == _sel_set and not big, "CardSets.Id.%s = %d" % [st["key"], id])


func _on_set_tile_input(ev: InputEvent, id: int) -> void:
	var mb := ev as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		flush()
		_selected = null
		_sel_set = id
		_queue_grid()
		_build_detail.call_deferred()


func _build_set_detail() -> void:
	var st = _sets_file.find_id(_sel_set)
	if st == null:
		_detail.add_child(_muted("That set no longer exists."))
		return
	var id := int(st["id"])
	_title = Label.new()
	_title.text = st["name"]
	_title.add_theme_font_size_override("font_size", int(20 * _s))
	_detail.add_child(_title)
	_detail.add_child(_muted("CardSets.Id.%s  ·  stored as %d in the content files" % [st["key"], id]))
	var btns := HFlowContainer.new()
	_btn(btns, "Show its cards", _show_set_pieces.bind(id, 0))
	_btn(btns, "Charms", _show_set_pieces.bind(id, 2))
	_btn(btns, "Trinkets", _show_set_pieces.bind(id, 3))
	_btn(btns, "Enhancements", _show_set_pieces.bind(id, 4))
	_detail.add_child(btns)
	_preview_holder = CenterContainer.new()
	_detail.add_child(_preview_holder)
	_refresh_preview()
	_detail.add_child(HSeparator.new())
	_fields_box = VBoxContainer.new()
	_fields_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_fields_box.add_theme_constant_override("separation", int(4 * _s))
	_detail.add_child(_fields_box)

	var name_le := LineEdit.new()
	name_le.text = st["name"]
	name_le.text_changed.connect(func(t: String):
		st["name"] = t
		_sets_changed())
	_row(_fields_box, "display_name", name_le)
	var cp := ColorPickerButton.new()
	cp.color = st["color"]
	cp.edit_alpha = false
	cp.custom_minimum_size.y = 24 * _s
	cp.color_changed.connect(func(c: Color):
		st["color"] = c
		_sets_changed())
	_row(_fields_box, "color", cp)
	var note_le := LineEdit.new()
	note_le.text = st["note"]
	note_le.placeholder_text = "What the set is about (a comment in card_sets.gd)"
	note_le.text_changed.connect(func(t: String):
		st["note"] = t.replace("\n", " ").strip_edges()
		_sets_changed())
	_row(_fields_box, "description", note_le)
	var al := CheckBox.new()
	al.text = "Sold in every encounter (like Utility and Coins)"
	al.button_pressed = _sets_file.always.has(st["key"])
	al.toggled.connect(func(on: bool):
		if on and not _sets_file.always.has(st["key"]):
			_sets_file.always.append(st["key"])
		elif not on:
			_sets_file.always.erase(st["key"])
		_sets_changed())
	_fields_box.add_child(al)
	_fields_box.add_child(_muted("To put a piece in this set, pick it in that piece's Card Set field. To sell the set, tick it in an encounter's Card Sets."))


func _show_set_pieces(id: int, tab: int) -> void:
	_set_filter.select(maxi(_set_filter.get_item_index(id), 0))
	_sel_set = -1
	if _cat == tab:
		_refresh_grid()
	else:
		_tabs.current_tab = tab
	_build_detail.call_deferred()


# ------------------------------------------------------------------------------ text helpers

## Readable text for one effect (or any sub-resource): its type plus the values that
## differ from the defaults, e.g. "Draw Cards (amount 2)".
func _effect_text(e, depth := 0) -> String:
	if e == null:
		return "(empty)"
	var s = e.get_script()
	var args := []
	for p in _props(e):
		var n: String = p["name"]
		var v = e.get(n)
		var dv = s.get_property_default_value(n) if s else null
		if typeof(v) == typeof(dv) and v == dv:
			continue
		var label := n.replace("_", " ")
		if typeof(v) == TYPE_BOOL:
			args.append(label if v else "not " + label)
		elif typeof(v) == TYPE_ARRAY and (v as Array).is_empty():
			continue
		else:
			args.append("%s %s" % [label, _fmt(p, v, depth)])
	var title := _class_title(e)
	return title if args.is_empty() else "%s (%s)" % [title, _join(args, ", ")]


func _effects_text(fx) -> String:
	var out := []
	if fx is Array:
		for e in fx:
			if e:
				out.append(_effect_text(e))
	return _join(out, ". ")


func _fmt(p: Dictionary, v, depth: int) -> String:
	match typeof(v):
		TYPE_INT:
			var h := int(p.get("hint", 0))
			if h == PROPERTY_HINT_ENUM:
				return _enum_name(p["hint_string"], v)
			if h == PROPERTY_HINT_FLAGS:
				var names := []
				for e in _flag_items(p["hint_string"]):
					if int(v) & int(e[1]):
						names.append(e[0])
				return _join(names, "+") if not names.is_empty() else "none"
			return str(v)
		TYPE_FLOAT:
			return str(snappedf(v, 0.01))
		TYPE_OBJECT:
			return _obj_text(v, depth)
		TYPE_ARRAY:
			var bits := []
			for x in v:
				bits.append(_obj_text(x, depth) if typeof(x) == TYPE_OBJECT else str(x))
			return "(" + _join(bits, "; ") + ")"
		TYPE_STRING, TYPE_STRING_NAME:
			return "“%s”" % v
	return str(v)


func _obj_text(x, depth: int) -> String:
	if x == null:
		return "none"
	if _is_file_res(x):
		return _name(x)
	if depth > 4:
		return "…"
	return "{" + _effect_text(x, depth + 1) + "}"


func _auto(t: String) -> String:
	return AUTO + t if t != "" else "[color=#9fc3cf][i]No text or effects yet[/i][/color]"


func _counted(arr: Array) -> String:
	var order := []
	var counts := {}
	for r in arr:
		if r == null:
			continue
		if not counts.has(r):
			order.append(r)
			counts[r] = 0
		counts[r] += 1
	var lines := []
	for r in order:
		lines.append("%d× %s" % [counts[r], _name(r)])
	return _join(lines, "\n")


func _names(arr: Array) -> String:
	var out := []
	for x in arr:
		out.append(_name(x) if x else "none")
	return _join(out, ", ")


func _join(arr: Array, sep: String) -> String:
	var p := PackedStringArray()
	for x in arr:
		p.append(str(x))
	return sep.join(p)


func _enum_items(hs: String) -> Array:
	var out := []
	var nxt := 0
	for part in hs.split(","):
		var nm: String = part
		var val: int = nxt
		if part.contains(":"):
			nm = part.get_slice(":", 0)
			val = int(part.get_slice(":", 1))
		out.append([nm.strip_edges().capitalize(), val])
		nxt = val + 1
	return out


func _flag_items(hs: String) -> Array:
	var out := []
	var i := 0
	for part in hs.split(","):
		var nm: String = part
		var val: int = 1 << i
		if part.contains(":"):
			nm = part.get_slice(":", 0)
			val = int(part.get_slice(":", 1))
		out.append([nm.strip_edges().capitalize(), val])
		i += 1
	return out


func _enum_name(hs: String, v) -> String:
	for e in _enum_items(hs):
		if e[1] == int(v):
			return e[0]
	return str(v)


func _enum_label(obj: Object, n: String) -> String:
	for p in _props(obj):
		if p["name"] == n:
			return _enum_name(p["hint_string"], obj.get(n))
	return ""


func _class_title(e) -> String:
	if e == null:
		return "(empty)"
	var s = e.get_script()
	if s == null:
		return e.get_class()
	var g := String(s.get_global_name())
	if g != "":
		return _pretty_class(g)
	return s.resource_path.get_file().get_basename().trim_suffix("_effect").capitalize()


func _pretty_class(cls: String) -> String:
	var t := cls.trim_suffix("Effect")
	return (t if t != "" else cls).capitalize()


func _slug(s: String) -> String:
	var re := RegEx.create_from_string("[^a-z0-9]+")
	var out := re.sub(s.strip_edges().to_lower(), "_", true)
	while out.begins_with("_"):
		out = out.substr(1)
	while out.ends_with("_"):
		out = out.left(-1)
	return out if out != "" else "new"


# ------------------------------------------------------------------------------ resource helpers

func _props(obj: Object) -> Array:
	if obj == null:
		return []
	var s = obj.get_script()
	if s == null:
		return []
	var key: String = s.resource_path
	if _prop_cache.has(key):
		return _prop_cache[key]
	var out := []
	for p in s.get_script_property_list():
		if int(p["type"]) == TYPE_NIL:
			continue
		if not (int(p["usage"]) & PROPERTY_USAGE_EDITOR):
			continue
		out.append(p)
	_prop_cache[key] = out
	return out


func _sorted_props(obj: Object) -> Array:
	var props := _props(obj)
	var first := []
	var rest := []
	var lists := []
	for n in FIRST:
		for p in props:
			if p["name"] == n:
				first.append(p)
	for p in props:
		if p["name"] in FIRST:
			continue
		if int(p["type"]) == TYPE_ARRAY:
			lists.append(p)
		else:
			rest.append(p)
	return first + rest + lists


func _has(obj: Object, n: String) -> bool:
	for p in _props(obj):
		if p["name"] == n:
			return true
	return false


func _g(obj: Object, n: String, fallback = null):
	return obj.get(n) if _has(obj, n) else fallback


func _name(r) -> String:
	if r == null:
		return "none"
	var n = _g(r, "display_name", "")
	if n != null and str(n) != "":
		return str(n)
	return r.resource_path.get_file().get_basename()


func _label_for(r: Resource) -> String:
	if _has(r, "card_set") and int(r.get("card_set")) != 0:
		return "%s  · %s" % [_name(r), _set_name(int(r.get("card_set")))]
	return _name(r)


func _cost(r) -> int:
	return int(_g(r, "cost", 0))


func _is_file_res(x) -> bool:
	return x is Resource and x.resource_path != "" and not x.resource_path.contains("::")


## Set ids, names and colors come from card_sets.gd as last read / written by this
## panel (so a set added here shows up at once), falling back to CardSets.
func _set_ids() -> Array:
	var out := []
	for st in _sets_file.sets:
		if int(st["id"]) != 0:
			out.append(int(st["id"]))
	if out.is_empty():
		for v in CardSets.Id.values():
			if int(v) != 0:
				out.append(int(v))
	return out


func _set_items() -> Array:
	var out := [["No set", 0]]
	for id in _set_ids():
		out.append([_set_name(id), id])
	return out


func _set_name(id: int) -> String:
	var st = _sets_file.find_id(id)
	if st:
		return st["name"]
	var info = CardSets._INFO.get(id)
	return info[0] if info else "Set %d" % id


func _set_color(id: int) -> Color:
	var st = _sets_file.find_id(id)
	if st:
		return st["color"]
	var info = CardSets._INFO.get(id)
	return info[1] if info else Palette.PANEL


func _bg_for_set(r: Resource, fallback: Color) -> Color:
	var id := int(_g(r, "card_set", 0))
	return _set_color(id) if id != 0 else fallback


# ------------------------------------------------------------------------------ widgets

func _rich(text: String, fs: float, color: Color, fit: bool) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = fit
	rt.scroll_active = false
	rt.clip_contents = true
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		rt.add_theme_font_size_override(key, int(fs))
	rt.add_theme_color_override("default_color", color)
	_append(rt, text, int(fs * 1.15))
	return rt


## Same as Icons.append: BBCode text with the icon characters drawn as images.
func _append(r: RichTextLabel, text: String, icon_size: int) -> void:
	var buf := ""
	for ch in text:
		if ch == "️":
			continue
		if Icons.SVG.has(ch) or Icons.ALIASES.has(ch):
			if buf.ends_with(" "):
				buf = buf.left(-1) + " "
			if buf != "":
				r.append_text(buf)
				buf = ""
			r.add_image(_icon(ch), icon_size, icon_size, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		else:
			buf += ch
	if buf != "":
		r.append_text(buf)


func _icon(tok: String) -> Texture2D:
	tok = Icons.ALIASES.get(tok, tok)
	if not _tex.has(tok):
		var img := Image.new()
		img.load_svg_from_string(Icons.SVG[tok], 3.0)
		_tex[tok] = ImageTexture.create_from_image(img)
	return _tex[tok]


func _icon_rect(tok: String, sz: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _icon(tok)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(sz, sz)
	t.size_flags_vertical = SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _group(box: VBoxContainer, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.08), 6, 1, int(6 * _s)))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(4 * _s))
	panel.add_child(vb)
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Palette.KELP)
	vb.add_child(l)
	box.add_child(panel)
	return vb


func _row(box: VBoxContainer, n: String, ctrl: Control) -> void:
	var h := HBoxContainer.new()
	var l := _field_label(n)
	l.custom_minimum_size.x = 130 * _s
	h.add_child(l)
	ctrl.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(ctrl)
	box.add_child(h)


func _field_label(n: String) -> Label:
	var l := Label.new()
	l.text = n.capitalize()
	l.add_theme_color_override("font_color", Palette.MUTED)
	return l


func _spin(v: float, step: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = -9999
	sp.max_value = 9999
	sp.step = step
	sp.rounded = step >= 1.0
	sp.allow_greater = true
	sp.allow_lesser = true
	sp.value = v
	sp.select_all_on_focus = true
	sp.gui_input.connect(_spin_wheel.bind(sp))
	return sp


## The mouse wheel over a number field scrolls the panel instead of changing the value
## (unless you're typing in that field), so scrolling can't edit content by accident.
func _spin_wheel(ev: InputEvent, sp: SpinBox) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or sp.get_line_edit().has_focus():
		return
	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	sp.accept_event()
	if mb.pressed and _right_scroll:
		var dir := -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		_right_scroll.scroll_vertical += dir * int(48 * _s * maxf(mb.factor, 1.0))


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _small_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _muted(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Palette.MUTED)
	return l


func _box(bg: Color, border: Color, radius: int, border_w: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w if border.a > 0 else 0)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


func _clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


func _set_status(t: String) -> void:
	if _status:
		_status.text = t
