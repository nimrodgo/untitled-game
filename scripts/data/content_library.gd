class_name ContentLibrary
extends RefCounted
## Every card, item, trinket and enhancement under CONTENT_DIR, so an encounter only has to
## name its card sets (EncounterData.card_sets) instead of listing each piece.
## Curses (content/test/curses) are never sold, so they are not loaded here.

const CONTENT_DIR := "res://content/test/"

static var _cache := {}


static func cards() -> Array:
	return _load("cards")


static func items() -> Array:
	return _load("items")


static func trinkets() -> Array:
	return _load("trinkets")


static func enhancements() -> Array:
	return _load("enhancements")


## The pieces of `all` whose `card_set` is in `sets` (library order).
static func in_sets(all: Array, sets: Array) -> Array:
	var out := []
	for r in all:
		if sets.has(r.card_set):
			out.append(r)
	return out


static func _load(sub: String) -> Array:
	if _cache.has(sub):
		return _cache[sub]
	var out := []
	var files := DirAccess.get_files_at(CONTENT_DIR + sub)
	files.sort()
	for f in files:
		# Exported builds list resources as "x.tres.remap".
		var name := String(f).trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			out.append(load(CONTENT_DIR + sub + "/" + name))
	_cache[sub] = out
	return out
