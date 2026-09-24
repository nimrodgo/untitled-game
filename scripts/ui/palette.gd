class_name Palette
extends RefCounted
## Placeholder aquatic palette. Swap freely.

const ABYSS := Color("041a2b")
const DEEP := Color("08304a")
const PANEL := Color("0c3d5c")
const CARD := Color("11587a")
const CARD_ITEM := Color("15604f")
const CARD_TRINKET := Color("5a4a1e")
const CARD_ENH := Color("4b2f63")
const FOAM := Color("e8f4f5")
const MUTED := Color("9fc3cf")
const TEAL := Color("3fc1c9")
const CORAL := Color("ff7f6a")
const GOLD := Color("ffd166")
const KELP := Color("7fe3d0")


static func box(bg: Color, border: Color = Color.TRANSPARENT, radius := 8, border_w := 2, pad := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w if border.a > 0 else 0)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb
