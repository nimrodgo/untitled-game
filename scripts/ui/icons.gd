class_name Icons
extends RefCounted
## Inline icons for game text. Designers write 🪙 (coin), 🂠 (card) and 🗲 or ⚡
## (instant) in card text; these are drawn as small images instead of relying
## on emoji fonts (web builds have none). Icons are built at runtime from SVG,
## so no import step is needed.

const COIN := "🪙"
const CARD := "🂠"
const BOLT := "⚡"
const BUY := "🛍"   ## marks "when bought" effects
const DISCARD := "⤵"
const COST := "➡"    ## separates a cost from what it pays for
const DESTROY := "🔥"
const REMOVE := "🗑"
const REFRESH := "↺"
const RETAIN := "📌"   ## keep a card in hand at the end of the turn
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
	"🛍": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<path d="M11 11 V8.5 a5 5 0 0 1 10 0 V11" fill="none" stroke="#a87412" stroke-width="2.5" stroke-linecap="round"/>
		<path d="M6 11 H26 L24.5 28 H7.5 Z" fill="#ffd166" stroke="#a87412" stroke-width="2.2" stroke-linejoin="round"/>
		<circle cx="12" cy="15" r="1.4" fill="#a87412"/><circle cx="20" cy="15" r="1.4" fill="#a87412"/></svg>""",
	"⤵": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<path d="M5 22 H27 V28 H5 Z" fill="#3a5a6e" stroke="#9fc3cf" stroke-width="1.8" stroke-linejoin="round"/>
		<path d="M8 4 C18 4 21 8 21 16" fill="none" stroke="#ff9f7a" stroke-width="3.2" stroke-linecap="round"/>
		<path d="M15.5 13 L21 19.5 L26.5 13" fill="none" stroke="#ff9f7a" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/></svg>""",
	"➡": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<path d="M4 16 H24" stroke="#e8f4f5" stroke-width="3.6" stroke-linecap="round"/>
		<path d="M17 8 L26 16 L17 24" fill="none" stroke="#e8f4f5" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round"/></svg>""",
	"🔥": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<path d="M16 2 C18 9 26 12 26 20 A10 10 0 0 1 6 20 C6 14 10 12 11 7 C13 10 13 12 14 13 C15 9 15 6 16 2 Z"
		fill="#ff6a3d" stroke="#8a2a10" stroke-width="2" stroke-linejoin="round"/>
		<path d="M16 15 C17 19 21 20 21 24 A5 5 0 0 1 11 24 C11 21 14 19 16 15 Z" fill="#ffd166"/></svg>""",
	"🗑": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<path d="M6 8 H26" stroke="#9fc3cf" stroke-width="2.6" stroke-linecap="round"/>
		<path d="M12 8 V5 H20 V8" fill="none" stroke="#9fc3cf" stroke-width="2.2" stroke-linejoin="round"/>
		<path d="M8 11 H24 L22.5 28 H9.5 Z" fill="#6f8f9c" stroke="#243c48" stroke-width="2" stroke-linejoin="round"/>
		<path d="M13 14 V25 M16 14 V25 M19 14 V25" stroke="#243c48" stroke-width="1.6"/></svg>""",
	"📌": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<path d="M11 4 H21 L20 13 L25 19 H7 L12 13 Z" fill="#ff9f7a" stroke="#8a2a10" stroke-width="2.2" stroke-linejoin="round"/>
		<path d="M16 19 V29" stroke="#8a2a10" stroke-width="2.8" stroke-linecap="round"/></svg>""",
	"↺": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
		<path d="M11.8 6.9 A10 10 0 1 0 21.7 7.8" fill="none" stroke="#7fe3d0" stroke-width="3.4" stroke-linecap="round"/>
		<path d="M18.5 5.5 L25.1 4.7 L20 12.1 Z" fill="#7fe3d0" stroke="#7fe3d0" stroke-width="2" stroke-linejoin="round"/></svg>""",
}

## What each icon means (shown as a hover pop-up).
const TIPS := {
	"🪙": "Coins", "🂠": "Card — draw", "⚡": "Instant — free action, doesn't end your turn",
	"🛍": "On buy — happens when you buy it", "⤵": "Discard", "➡": "Pay what's on the left to get what's on the right",
	"🔥": "Destroy — gone for good", "🗑": "Remove — gone for this encounter", "↺": "Refresh", "📌": "Retain — keep the card in your hand at the end of the turn",
}

static var _cache := {}


## Amount + icon for card-ish verbs: 1 is implied ("⤵", "3⤵").
static func n(amount: int, icon: String) -> String:
	return icon if amount == 1 else "%d%s" % [amount, icon]


## The distinct icons used in `text` (after symbolizing), in order of appearance.
static func icons_in(text: String) -> Array:
	var out: Array = []
	for ch in text:
		var t: String = ALIASES.get(ch, ch)
		if TIPS.has(t) and not out.has(t):
			out.append(t)
	return out


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
			r.add_image(texture(ch), icon_size, icon_size, Color.WHITE, INLINE_ALIGNMENT_CENTER,
				Rect2(), null, false, "")
		else:
			buf += ch
	if buf != "":
		r.append_text(buf)


## Plain-text fallback (for Labels/buttons): replaces icons with words.
static func plain(text: String) -> String:
	return text.replace(COIN, "coin").replace(CARD, "card").replace(BOLT, "").replace("🗲", "") \
		.replace(DISCARD, "").replace(COST, "->").replace(DESTROY, "").replace(REMOVE, "").replace(REFRESH, "") \
		.replace("️", "").replace("  ", " ").strip_edges()


## A RichTextLabel set up for game text.
static func rich_label(text: String, font_size: int, color: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_PASS   # lets icon tooltips show; clicks still reach the parent
	r.selection_enabled = false
	r.context_menu_enabled = false
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(key, font_size)
	r.add_theme_color_override("default_color", color)
	append(r, text, int(font_size * 1.15))
	return r
