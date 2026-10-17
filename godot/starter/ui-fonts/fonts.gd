extends RefCounted
## Starter UI fonts (all SIL OFL 1.1, licence text beside each file):
##   Manrope        variable sans, weight 200-800: everything the player reads (HUD numbers, labels, buttons).
##   Fraunces       variable display serif, weight 100-900, optical size 9-144: titles, names, verdicts.
##   Dela Gothic One  one heavy poster weight: arcade titles, "LEVEL UP!", big numbers.
## Usage:  const Fonts := preload("res://starter/ui-fonts/fonts.gd")
##         label.add_theme_font_override("font", Fonts.sans(800))
## Every call returns a cached FontVariation, so calling it per label is cheap.

const SANS_PATH := "res://starter/ui-fonts/Manrope.ttf"
const DISPLAY_PATH := "res://starter/ui-fonts/Fraunces.ttf"
const POSTER_PATH := "res://starter/ui-fonts/DelaGothicOne-Regular.ttf"
# OpenType variation axis tags.
const WGHT := 0x77676874
const OPSZ := 0x6f70737a
const SOFT := 0x534f4654

static var _files: Dictionary = {}
static var _cache: Dictionary = {}


## Imported FontFile when the project has imported it, else the raw .ttf bytes (works before an import pass).
static func file(path: String) -> Font:
	if _files.has(path):
		return _files[path]
	var font: Font = null
	if ResourceLoader.exists(path):
		font = load(path) as Font
	if font == null and FileAccess.file_exists(path):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(path)
		ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		ff.hinting = TextServer.HINTING_LIGHT
		font = ff
	if font == null:
		push_warning("ui-fonts: %s missing, using the fallback font" % path)
		font = ThemeDB.fallback_font
	_files[path] = font
	return font


static func _variation(path: String, coords: Dictionary, spacing: int, unique: bool = false) -> FontVariation:
	var key := "%s|%s|%d" % [path, str(coords), spacing]
	if not unique and _cache.has(key):
		return _cache[key]
	var fv := FontVariation.new()
	fv.base_font = file(path)
	fv.variation_opentype = coords
	fv.spacing_glyph = spacing
	if not unique:
		_cache[key] = fv
	return fv


## Manrope at a weight (200 thin .. 500 regular .. 800 extra bold). spacing = extra pixels between letters.
static func sans(weight: int = 500, spacing: int = 0) -> FontVariation:
	return _variation(SANS_PATH, {WGHT: clampi(weight, 200, 800)}, spacing)


## Fraunces at a weight (100..900). opsz 9..144: high values give fine display contrast for big type.
static func display(weight: int = 600, spacing: int = 0, opsz: int = 72) -> FontVariation:
	return _variation(DISPLAY_PATH, {WGHT: clampi(weight, 100, 900), OPSZ: clampi(opsz, 9, 144), SOFT: 50}, spacing)


## A fresh (uncached) Fraunces variation, for tweening its letter spacing ("spacing_glyph").
static func display_unique(weight: int = 600, spacing: int = 0, opsz: int = 144) -> FontVariation:
	return _variation(DISPLAY_PATH, {WGHT: weight, OPSZ: opsz, SOFT: 50}, spacing, true)


## Dela Gothic One: heavy poster type for arcade titles and big numbers.
static func poster(spacing: int = 0) -> FontVariation:
	return _variation(POSTER_PATH, {}, spacing)


## A Label with font, size, colour and an optional outline (outline reads over any background).
static func label(text: String, size: int = 24, color: Color = Color.WHITE, font: Font = null, outline: int = 0, outline_color: Color = Color(0, 0, 0, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font if font != null else sans(700))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	return l
