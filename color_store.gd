@tool
extends RefCounted

## Color Swatch storage + logic. Saves to a JSON file in the project so it's
## trivially shareable. No Resources, no enums, no external add-ons.
##
## File format: { "colors": [ {hex, name, category}, ... ],
##                "palettes": [ {name, dominant, secondary, accent}, ... ] }
## where each palette role is { "shadow": HEX, "base": HEX, "light": HEX }.
## An older file that's just an array of colors still loads (migrated on save).

const PATH := "res://color_swatch_library.json"
const CATEGORIES := ["liked", "disliked", "neutral"]
const CAT_TITLE := {"liked": "LIKED", "disliked": "DISLIKED", "neutral": "NEUTRAL"}
const CATEGORIES_UPPER := ["LIKED", "DISLIKED", "NEUTRAL"]

var entries: Array = []   # colors
var palettes: Array = []  # saved 60/30/10 sets


# ---------------------------------------------------------------------------
# Persistence (auto-saves on every change)
# ---------------------------------------------------------------------------

func load_library() -> void:
	entries = []
	palettes = []
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if data is Array:
		_load_colors(data, false)            # old format: just colors
	elif data is Dictionary:
		var d: Dictionary = data
		_load_colors(d.get("colors", []), false)
		_load_palettes(d.get("palettes", []))


func save_library() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"colors": entries, "palettes": palettes}, "\t"))
	f.close()


# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------

## Returns { ok: bool, error: String, duplicate: bool }.
func add_color(raw_hex: String, color_name: String = "", category: String = "liked") -> Dictionary:
	var hex := normalize_hex(raw_hex)
	if hex == "":
		return {"ok": false, "error": "Enter a hex color like #C1442E.", "duplicate": false}
	if _index_of(hex) != -1:
		return {"ok": false, "error": "That color is already in your library.", "duplicate": true}
	var nm := color_name.strip_edges()
	if nm == "":
		nm = "#" + hex
	var cat: String = category if (category in CATEGORIES) else "liked"
	entries.append({"hex": hex, "name": nm, "category": cat})
	save_library()
	return {"ok": true, "error": "", "duplicate": false}


func set_category(hex: String, category: String) -> void:
	var i := _index_of(hex)
	if i != -1:
		entries[i]["category"] = category
		save_library()


func rename(hex: String, color_name: String) -> void:
	var i := _index_of(hex)
	if i != -1 and str(entries[i].get("name", "")) != color_name:
		entries[i]["name"] = color_name
		save_library()


func remove(hex: String) -> void:
	var i := _index_of(hex)
	if i != -1:
		entries.remove_at(i)
		save_library()


func by_category(category: String) -> Array:
	var out: Array = []
	for e in entries:
		if str(e.get("category", "neutral")) == category:
			out.append(e)
	return out


# ---------------------------------------------------------------------------
# Sharing (colors)
# ---------------------------------------------------------------------------

func to_share_text() -> String:
	var out := "Color Swatch library (%d colors)\n" % entries.size()
	for cat in CATEGORIES:
		out += "\n" + str(CAT_TITLE[cat]) + "\n"
		var rows := by_category(cat)
		if rows.is_empty():
			out += "  (none)\n"
			continue
		for e in rows:
			var hex := str(e.get("hex", ""))
			var nm := str(e.get("name", ""))
			var line := "  #" + hex
			if nm != "" and nm != "#" + hex:
				line += "  " + nm
			out += line + "\n"
	return out


## Merge a pasted library (bare color array, or a full file dict) into this one.
## Skips colors already present. Returns the number of new colors added.
func merge_from_text(text: String) -> int:
	var before := entries.size()
	var data: Variant = JSON.parse_string(text)
	if data is Array:
		_load_colors(data, true)
	elif data is Dictionary:
		var d: Dictionary = data
		_load_colors(d.get("colors", []), true)
	else:
		_parse_sectioned(text)
	save_library()
	return entries.size() - before


# ---------------------------------------------------------------------------
# 60 / 30 / 10 generation
# ---------------------------------------------------------------------------

## Builds from LIKED colors (falls back to neutral, never disliked). Returns
## { ok, message, dominant/secondary/accent: {shadow, base, light} } as Colors.
func generate_palette() -> Dictionary:
	var cols: Array = _colors_in("liked")
	if cols.is_empty():
		cols = _colors_in("neutral")
	if cols.is_empty():
		return {"ok": false, "message": "Like a few colors first, then generate."}

	cols.sort_custom(_by_saturation)
	var dominant: Color = cols[0]
	var accent: Color = cols[cols.size() - 1]
	var secondary: Color = cols[cols.size() / 2]

	dominant = Color.from_hsv(dominant.h, clampf(dominant.s * 0.7, 0.0, 1.0), dominant.v)
	accent = Color.from_hsv(accent.h, clampf(accent.s * 1.15, 0.0, 1.0), accent.v)

	return {
		"ok": true,
		"message": "",
		"dominant": _family(dominant),
		"secondary": _family(secondary),
		"accent": _family(accent),
	}


# ---------------------------------------------------------------------------
# Saved palettes (persistent)
# ---------------------------------------------------------------------------

func save_palette(palette_name: String, generated: Dictionary) -> void:
	var nm := palette_name.strip_edges()
	if nm == "":
		nm = "Palette %d" % (palettes.size() + 1)
	palettes.append({
		"name": nm,
		"dominant": _role_to_hex(generated.get("dominant", {})),
		"secondary": _role_to_hex(generated.get("secondary", {})),
		"accent": _role_to_hex(generated.get("accent", {})),
	})
	save_library()


func list_palettes() -> Array:
	return palettes


func delete_palette(index: int) -> void:
	if index >= 0 and index < palettes.size():
		palettes.remove_at(index)
		save_library()


# ---------------------------------------------------------------------------
# Shareable, human-readable text (survives an unformatted Discord paste)
# ---------------------------------------------------------------------------

func palette_to_text(p: Dictionary) -> String:
	var out := "60 / 30 / 10 palette"
	var nm := str(p.get("name", ""))
	if nm != "":
		out += " - " + nm
	out += "\n(made with Color Swatch)\n"
	out += _role_text("Dominant  60%", p.get("dominant", {}))
	out += _role_text("Secondary 30%", p.get("secondary", {}))
	out += _role_text("Accent    10%", p.get("accent", {}))
	return out


func generated_to_text(generated: Dictionary) -> String:
	return palette_to_text({
		"name": "",
		"dominant": _role_to_hex(generated.get("dominant", {})),
		"secondary": _role_to_hex(generated.get("secondary", {})),
		"accent": _role_to_hex(generated.get("accent", {})),
	})


# ---------------------------------------------------------------------------
# Hex helpers
# ---------------------------------------------------------------------------

func normalize_hex(raw: String) -> String:
	var s := raw.strip_edges()
	if s.begins_with("#"):
		s = s.substr(1)
	if s.length() == 8:
		s = s.substr(0, 6)
	if s.length() != 6 or not s.is_valid_hex_number(false):
		return ""
	return s.to_upper()


static func hex_to_color(hex: String) -> Color:
	if hex.length() == 6 and hex.is_valid_hex_number(false):
		return Color.html(hex)
	return Color.WHITE


static func color_to_hex(c: Color) -> String:
	return c.to_html(false).to_upper()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _index_of(hex: String) -> int:
	for i in entries.size():
		if str(entries[i].get("hex", "")) == hex:
			return i
	return -1


func _colors_in(category: String) -> Array:
	var out: Array = []
	for e in by_category(category):
		out.append(hex_to_color(str(e.get("hex", ""))))
	return out


func _by_saturation(a: Color, b: Color) -> bool:
	return a.s < b.s


func _family(c: Color) -> Dictionary:
	return {
		"shadow": Color.from_hsv(c.h, clampf(c.s + 0.06, 0.0, 1.0), clampf(c.v - 0.18, 0.0, 1.0)),
		"base": c,
		"light": Color.from_hsv(c.h, clampf(c.s - 0.06, 0.0, 1.0), clampf(c.v + 0.16, 0.0, 1.0)),
	}


## Accepts a role dict whose fields are Colors (from generate) OR hex strings
## (from a loaded file) and returns one with uppercase hex strings.
func _role_to_hex(role: Variant) -> Dictionary:
	var r: Dictionary = role if role is Dictionary else {}
	return {
		"shadow": _field_hex(r.get("shadow", Color.WHITE)),
		"base": _field_hex(r.get("base", Color.WHITE)),
		"light": _field_hex(r.get("light", Color.WHITE)),
	}


func _field_hex(v: Variant) -> String:
	if v is Color:
		return color_to_hex(v)
	if v is String:
		var h := normalize_hex(v)
		return h if h != "" else "FFFFFF"
	return "FFFFFF"


func _role_text(label: String, role: Variant) -> String:
	var r: Dictionary = role if role is Dictionary else {}
	var s := "\n" + label + "\n"
	s += "  shadow  #" + str(r.get("shadow", "")) + "\n"
	s += "  base    #" + str(r.get("base", "")) + "\n"
	s += "  light   #" + str(r.get("light", "")) + "\n"
	return s


## Parse the human-readable, section-organized share format: LIKED / DISLIKED /
## NEUTRAL headers with "  #HEX  Name" rows. Adds new colors only.
func _parse_sectioned(text: String) -> void:
	var current := "neutral"
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line == "":
			continue
		var upper := line.to_upper()
		if upper in CATEGORIES_UPPER:
			current = upper.to_lower()
			continue
		if not line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		var hex := normalize_hex(parts[0])
		if hex == "" or _index_of(hex) != -1:
			continue
		var nm := ""
		if parts.size() >= 2:
			nm = " ".join(parts.slice(1))
		if nm == "":
			nm = "#" + hex
		entries.append({"hex": hex, "name": nm, "category": current})


func _load_colors(data: Variant, merging: bool) -> void:
	if not merging:
		entries = []
	if not (data is Array):
		return
	for e in data:
		if not (e is Dictionary) or not e.has("hex"):
			continue
		var hex := normalize_hex(str(e.get("hex", "")))
		if hex == "" or _index_of(hex) != -1:
			continue
		var cat: String = str(e.get("category", "neutral"))
		if not (cat in CATEGORIES):
			cat = "neutral"
		entries.append({
			"hex": hex,
			"name": str(e.get("name", "#" + hex)),
			"category": cat,
		})


func _load_palettes(data: Variant) -> void:
	if not (data is Array):
		return
	for p in data:
		if not (p is Dictionary):
			continue
		palettes.append({
			"name": str(p.get("name", "Palette")),
			"dominant": _role_to_hex(p.get("dominant", {})),
			"secondary": _role_to_hex(p.get("secondary", {})),
			"accent": _role_to_hex(p.get("accent", {})),
		})
