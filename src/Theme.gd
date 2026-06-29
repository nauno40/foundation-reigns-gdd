class_name Pal

# Palette du prototype (HTML :root). Couleurs ressources = oklch → sRGB exact.

const BG        = Color("#05070d")
const BG_2      = Color("#080c16")
const PANEL     = Color("#0c1322")
const PANEL_2   = Color("#0f1828")
const INK       = Color("#e7edf6")
const INK_DIM   = Color("#93a0b6")
const INK_FAINT = Color("#54607a")
const LINE      = Color(0.471, 0.588, 0.745, 0.14)
const LINE_2    = Color(0.471, 0.588, 0.745, 0.08)
const ACCENT    = Color("#4fd6e8")
const AMBER     = Color("#e8b65a")
const DANGER    = Color("#d96a5a")

# ressources (oklch du prototype, converties)
const MILITARY  = Color("#df6862")  # oklch(.66 .15 25)
const RELIGION  = Color("#9281e1")  # oklch(.66 .14 290)
const COMMERCE  = Color("#4cb587")  # oklch(.70 .12 162)
const POLITICS  = Color("#d3a23b")  # oklch(.74 .13 82)

static func mono_spaced(base: Font, spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.spacing_glyph = spacing
	return f

static func res_color(key: String) -> Color:
	match key:
		"military": return MILITARY
		"religion": return RELIGION
		"commerce": return COMMERCE
		"politics": return POLITICS
	return INK_DIM
