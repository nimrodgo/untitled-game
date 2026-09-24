class_name Icons
extends RefCounted
## Inline icons for game text. Designers write 🪙 (coin), 🂠 (card) and 🗲 or ⚡
## (instant) in card text; these are drawn as small images instead of relying
## on emoji fonts (web builds have none). Icons are built at runtime from SVG,
## so no import step is needed.

const COIN := "🪙"
const CARD := "🂠"
const BOLT := "⚡"
## Alternative spellings that draw the same icon.
const ALIASES := {"🗲": "⚡"}

const SVG := {
	"🪙": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<circle cx="16" cy="16" r="14" fill="#ffd166" stroke="#a87412" stroke-width="2.5"/>
		<circle cx="16" cy="16" r="8.5" fill="none" stroke="#a87412" stroke-width="2"/></svg>""",
	"🂠": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<rect x="7" y="3" width="18" height="26" rx="3.5" fill="#9ad7ff" stroke="#123e5a" stroke-width="2.5"/>
		<rect x="11.5" y="8" width="9" height="16" rx="1.5" fill="none" stroke="#123e5a" stroke-width="1.8"/></svg>""",
	"⚡": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<path d="M19 2 L6 18 H14.5 L12 30 L26 12.5 H17.5 Z" fill="#ffe066" stroke="#a87412"
		stroke-width="2" stroke-linejoin="round"/></svg>""",
}

static var _cache := {}


static func texture(token: String) -> Texture2D:
	token = ALIASES.get(token, token)
	if not _cache.has(token):
		var img := Image.new()
		img.load_svg_from_string(SVG[token], 3.0)
		_cache[token] = ImageTexture.create_from_image(img)
	return _cache[token]


## Appends BBCode `text` to `r`, drawing icon tokens as inline images.
static func append(r: RichTextLabel, text: String, icon_size: int) -> void:
	var buf := ""
	for ch in text:
		if ch == "️":   # emoji variation selector
			continue
		if SVG.has(ch) or ALIASES.has(ch):
			if buf.ends_with(" "):
				buf = buf.left(-1) + "\u00A0"   # keep "Gain 1" and its icon together
			if buf != "":
				r.append_text(buf)
				buf = ""
			r.add_image(texture(ch), icon_size, icon_size, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		else:
			buf += ch
	if buf != "":
		r.append_text(buf)


## Plain-text fallback (for Labels/buttons): replaces icons with words.
static func plain(text: String) -> String:
	return text.replace(COIN, "coin").replace(CARD, "card").replace(BOLT, "").replace("🗲", "").replace("️", "")


## A RichTextLabel set up for game text.
static func rich_label(text: String, font_size: int, color: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(key, font_size)
	r.add_theme_color_override("default_color", color)
	append(r, text, int(font_size * 1.15))
	return r
