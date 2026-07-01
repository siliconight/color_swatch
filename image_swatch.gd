@tool
extends RefCounted

## Examine ONE image and output a RELATIVE color swatch: a few representative
## colors, each with its share of the frame. Pure GDScript, no dependencies,
## deliberately simple (no OkLab) to keep Color Swatch lean and stable.
##
## It holds nothing. You hand it an Image, you get colors back, and the caller
## drops the Image. One at a time; the screenshot is never stored or persisted.

## Returns Array of { "color": Color, "weight": float }, biggest share first.
## `weight` is the color's fraction of the sampled pixels. Only the top
## `max_colors` are returned, so the weights need not sum to 1.
static func extract(img: Image, max_colors: int = 6, long_edge: int = 96, merge_dist: float = 0.12) -> Array:
	if img == null or img.get_width() == 0 or img.get_height() == 0:
		return []
	var im := img.duplicate() as Image
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)

	# Downscale so extraction is fast and averages out noise / dithering.
	var w0 := im.get_width()
	var h0 := im.get_height()
	var scale := float(long_edge) / float(maxi(w0, h0))
	if scale < 1.0:
		im.resize(maxi(1, int(round(w0 * scale))), maxi(1, int(round(h0 * scale))), Image.INTERPOLATE_BILINEAR)
	var w := im.get_width()
	var h := im.get_height()

	# Coarse-quantize into buckets, accumulating summed color + count.
	var q := 5  # levels per channel -> up to 125 buckets
	var buckets := {}
	var total := 0
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			if c.a < 0.5:
				continue  # ignore transparent pixels
			var ri := int(clampf(c.r, 0.0, 0.999) * q)
			var gi := int(clampf(c.g, 0.0, 0.999) * q)
			var bi := int(clampf(c.b, 0.0, 0.999) * q)
			var key := (ri * q + gi) * q + bi
			if buckets.has(key):
				var e: Array = buckets[key]
				e[0] += c.r
				e[1] += c.g
				e[2] += c.b
				e[3] += 1
			else:
				buckets[key] = [c.r, c.g, c.b, 1]
			total += 1
	if total == 0:
		return []

	# Bucket -> {color, count}, biggest first.
	var list: Array = []
	for key in buckets:
		var e: Array = buckets[key]
		var cnt: int = e[3]
		list.append({"color": Color(e[0] / cnt, e[1] / cnt, e[2] / cnt), "count": cnt})
	list.sort_custom(func(a, b): return a["count"] > b["count"])

	# Greedily merge perceptually-near buckets into representative colors.
	var reps: Array = []
	for item in list:
		var item_col: Color = item["color"]
		var item_cnt: int = item["count"]
		var hit := false
		for rep in reps:
			if _close(rep["color"], item_col, merge_dist):
				var tc: int = rep["count"] + item_cnt
				rep["color"] = (rep["color"] as Color).lerp(item_col, float(item_cnt) / float(tc))
				rep["count"] = tc
				hit = true
				break
		if not hit:
			reps.append({"color": item_col, "count": item_cnt})
	reps.sort_custom(func(a, b): return a["count"] > b["count"])

	# Trim to max_colors, attach relative weight.
	var out: Array = []
	var n := mini(max_colors, reps.size())
	for i in n:
		var rep: Dictionary = reps[i]
		out.append({"color": rep["color"], "weight": float(rep["count"]) / float(total)})
	return out


## The swatch as "#RRGGBB  ~NN%" lines, for a Copy button.
static func to_text(swatch: Array) -> String:
	var lines := PackedStringArray()
	for entry in swatch:
		var col: Color = entry["color"]
		lines.append("#%s  ~%d%%" % [col.to_html(false).to_upper(), int(round(float(entry["weight"]) * 100.0))])
	return "\n".join(lines)


static func _close(a: Color, b: Color, t: float) -> bool:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db) < t
