@tool
extends VBoxContainer

## Color Swatch dock. Root is a VBoxContainer (a real container) so the editor
## sizes it and it lays itself out — it can't collapse like an anchored plain
## Control. Add colors as Liked/Disliked, share the library, generate 60/30/10
## sets, and keep named palettes that persist across sessions.

const Store := preload("res://addons/color_swatch/color_store.gd")
const Extractor := preload("res://addons/color_swatch/image_swatch.gd")
const SWATCH := Vector2(26, 26)
const CAT_LABELS := {"liked": "Liked", "disliked": "Disliked", "neutral": "Neutral"}

var _store

var _picker: ColorPickerButton
var _hex_edit: LineEdit
var _name_edit: LineEdit
var _status: Label
var _palette_box: VBoxContainer
var _palette_name_edit: LineEdit
var _saved_box: VBoxContainer
var _swatch_box: VBoxContainer
var _lists := {}  # category -> VBoxContainer
var _last_generated: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_store = Store.new()
	_store.load_library()
	_build_ui()
	_refresh()
	_refresh_saved()


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_heading("Color Swatch", 17)

	# Add a color: pick or type a hex, optional name, then Like or Dislike.
	var add_row := HBoxContainer.new()
	_picker = ColorPickerButton.new()
	_picker.custom_minimum_size = Vector2(44, 0)
	_picker.color = Color("c1442e")
	_picker.color_changed.connect(_on_picker_changed)
	add_row.add_child(_picker)
	_hex_edit = LineEdit.new()
	_hex_edit.placeholder_text = "#RRGGBB"
	_hex_edit.text = "#C1442E"
	_hex_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hex_edit.text_submitted.connect(_on_hex_submitted)
	add_row.add_child(_hex_edit)
	add_child(add_row)

	var name_row := HBoxContainer.new()
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name (optional)"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	var like_btn := Button.new()
	like_btn.text = "Like"
	like_btn.tooltip_text = "Add this color to your Liked list."
	like_btn.pressed.connect(_on_add.bind("liked"))
	name_row.add_child(like_btn)
	var dislike_btn := Button.new()
	dislike_btn.text = "Dislike"
	dislike_btn.tooltip_text = "Add this color to your Disliked list."
	dislike_btn.pressed.connect(_on_add.bind("disliked"))
	name_row.add_child(dislike_btn)
	add_child(name_row)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(1, 1, 1, 0.7)
	add_child(_status)

	# Share.
	var share_row := HBoxContainer.new()
	var copy_btn := Button.new()
	copy_btn.text = "Copy Library"
	copy_btn.tooltip_text = "Copy your whole library as text to share with someone."
	copy_btn.pressed.connect(_on_copy_library)
	share_row.add_child(copy_btn)
	var paste_btn := Button.new()
	paste_btn.text = "Paste & Merge"
	paste_btn.tooltip_text = "Paste a library someone shared; new colors are added to yours."
	paste_btn.pressed.connect(_on_paste_merge)
	share_row.add_child(paste_btn)
	add_child(share_row)

	add_child(HSeparator.new())

	# Examine a screenshot: pull a relative swatch out of an image and drop the
	# colors into your library. Only one image is held at a time and it's never
	# stored — it's examined and discarded immediately.
	var examine_row := HBoxContainer.new()
	var examine_btn := Button.new()
	examine_btn.text = "Examine Screenshot…"
	examine_btn.tooltip_text = "Pick an image; pull its main colors into a swatch. The image isn't kept."
	examine_btn.pressed.connect(_on_examine)
	examine_row.add_child(examine_btn)
	var examine_hint := Label.new()
	examine_hint.text = "one at a time · not stored"
	examine_hint.modulate = Color(1, 1, 1, 0.45)
	examine_row.add_child(examine_hint)
	add_child(examine_row)
	_swatch_box = VBoxContainer.new()
	_swatch_box.add_theme_constant_override("separation", 4)
	add_child(_swatch_box)

	add_child(HSeparator.new())

	# Generate 60/30/10.
	var gen_btn := Button.new()
	gen_btn.text = "Generate 60 / 30 / 10"
	gen_btn.tooltip_text = "Build a palette from your Liked colors."
	gen_btn.pressed.connect(_on_generate)
	add_child(gen_btn)
	_palette_box = VBoxContainer.new()
	_palette_box.add_theme_constant_override("separation", 4)
	add_child(_palette_box)

	add_child(HSeparator.new())

	# Scrolling area: saved palettes, then the color library.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	content.add_child(_heading_label("Saved Palettes", 14))
	_saved_box = VBoxContainer.new()
	_saved_box.add_theme_constant_override("separation", 8)
	content.add_child(_saved_box)
	content.add_child(HSeparator.new())

	for cat in Store.CATEGORIES:
		content.add_child(_heading_label(CAT_LABELS[cat] + " Colors", 14))
		var box := VBoxContainer.new()
		content.add_child(box)
		_lists[cat] = box


func _heading(text: String, size: int) -> void:
	add_child(_heading_label(text, size))


func _heading_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


# ---------------------------------------------------------------------------
# Library list
# ---------------------------------------------------------------------------

func _refresh() -> void:
	for cat in Store.CATEGORIES:
		var box: VBoxContainer = _lists[cat]
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		var rows: Array = _store.by_category(cat)
		if rows.is_empty():
			var empty := Label.new()
			empty.text = "    (none)"
			empty.modulate = Color(1, 1, 1, 0.4)
			box.add_child(empty)
			continue
		for e in rows:
			box.add_child(_make_row(e))


func _make_row(e: Dictionary) -> HBoxContainer:
	var hex := str(e.get("hex", ""))
	var cat := str(e.get("category", "neutral"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var sw := ColorRect.new()
	sw.color = Store.hex_to_color(hex)
	sw.custom_minimum_size = SWATCH
	row.add_child(sw)

	var hex_label := Label.new()
	hex_label.text = "#" + hex
	hex_label.custom_minimum_size = Vector2(76, 0)
	row.add_child(hex_label)

	var name_edit := LineEdit.new()
	name_edit.text = str(e.get("name", ""))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.flat = true
	name_edit.text_submitted.connect(_on_name_submitted.bind(hex))
	name_edit.focus_exited.connect(_on_name_blur.bind(name_edit, hex))
	row.add_child(name_edit)

	for other in Store.CATEGORIES:
		if other != cat:
			row.add_child(_mini_button(CAT_LABELS[other], _move.bind(hex, other)))
	row.add_child(_mini_button("Copy", _copy_hex.bind(hex)))
	row.add_child(_mini_button("Delete", _delete.bind(hex)))
	return row


func _mini_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b


# ---------------------------------------------------------------------------
# Add / edit handlers
# ---------------------------------------------------------------------------

func _on_picker_changed(c: Color) -> void:
	_hex_edit.text = "#" + Store.color_to_hex(c)


func _on_hex_submitted(_t: String) -> void:
	var hex: String = _store.normalize_hex(_hex_edit.text)
	if hex != "":
		_picker.color = Store.hex_to_color(hex)


func _on_add(category: String) -> void:
	var res: Dictionary = _store.add_color(_hex_edit.text, _name_edit.text, category)
	if res.ok:
		_status.text = "Added to %s." % CAT_LABELS.get(category, category)
		_name_edit.text = ""
		_refresh()
	else:
		_status.text = res.error


func _on_name_submitted(new_text: String, hex: String) -> void:
	_store.rename(hex, new_text)


func _on_name_blur(edit: LineEdit, hex: String) -> void:
	_store.rename(hex, edit.text)


func _move(hex: String, category: String) -> void:
	_store.set_category(hex, category)
	_refresh()


func _copy_hex(hex: String) -> void:
	DisplayServer.clipboard_set("#" + hex)
	_status.text = "Copied #" + hex + "."


func _delete(hex: String) -> void:
	_store.remove(hex)
	_refresh()


func _on_copy_library() -> void:
	DisplayServer.clipboard_set(_store.to_share_text())
	_status.text = "Library copied to clipboard — paste it to share."


func _on_paste_merge() -> void:
	var added: int = _store.merge_from_text(DisplayServer.clipboard_get())
	_status.text = "Merged %d new color(s) from clipboard." % added
	_refresh()


# ---------------------------------------------------------------------------
# Examine a screenshot -> relative swatch (image held one at a time, never saved)
# ---------------------------------------------------------------------------

func _on_examine() -> void:
	var dlg := EditorFileDialog.new()
	dlg.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dlg.access = EditorFileDialog.ACCESS_FILESYSTEM
	dlg.title = "Pick a screenshot to examine"
	dlg.add_filter("*.png,*.jpg,*.jpeg,*.webp,*.bmp", "Images")
	dlg.file_selected.connect(_on_examine_chosen.bind(dlg))
	dlg.canceled.connect(dlg.queue_free)
	EditorInterface.get_base_control().add_child(dlg)
	dlg.popup_centered_ratio(0.6)


func _on_examine_chosen(path: String, dlg: EditorFileDialog) -> void:
	dlg.queue_free()  # done with the dialog
	var img := Image.load_from_file(path)
	if img == null:
		_status.text = "Couldn't read that image."
		return
	var swatch: Array = Extractor.extract(img, 6)
	img = null  # discard immediately — the screenshot is never kept
	_show_swatch(swatch)


func _show_swatch(swatch: Array) -> void:
	for child in _swatch_box.get_children():   # only ever one swatch on screen
		_swatch_box.remove_child(child)
		child.queue_free()
	if swatch.is_empty():
		var empty := Label.new()
		empty.text = "    (no colors found)"
		empty.modulate = Color(1, 1, 1, 0.4)
		_swatch_box.add_child(empty)
		return

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 4)
	for entry in swatch:
		var col: Color = entry["color"]
		var pct := int(round(float(entry["weight"]) * 100.0))
		var sw := ColorRect.new()
		sw.color = col
		sw.custom_minimum_size = Vector2(30, 26)
		sw.tooltip_text = "#%s  ~%d%%" % [Store.color_to_hex(col), pct]
		strip.add_child(sw)
	_swatch_box.add_child(strip)

	var actions := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "Add all → Neutral"
	add_btn.tooltip_text = "Add these colors to Neutral; sort them into Liked/Disliked from there."
	add_btn.pressed.connect(_on_add_examined.bind(swatch))
	actions.add_child(add_btn)
	var copy_btn := Button.new()
	copy_btn.text = "Copy Hexes"
	copy_btn.tooltip_text = "Copy the swatch as #HEX ~% lines."
	copy_btn.pressed.connect(_on_copy_swatch.bind(swatch))
	actions.add_child(copy_btn)
	_swatch_box.add_child(actions)


func _on_add_examined(swatch: Array) -> void:
	var added := 0
	for entry in swatch:
		var col: Color = entry["color"]
		var res: Dictionary = _store.add_color(Store.color_to_hex(col), "", "neutral")
		if res.ok:
			added += 1
	_status.text = "Added %d color(s) to Neutral." % added
	_refresh()


func _on_copy_swatch(swatch: Array) -> void:
	DisplayServer.clipboard_set(Extractor.to_text(swatch))
	_status.text = "Swatch copied to clipboard."


# ---------------------------------------------------------------------------
# 60 / 30 / 10
# ---------------------------------------------------------------------------

func _on_generate() -> void:
	for child in _palette_box.get_children():
		_palette_box.remove_child(child)
		child.queue_free()
	_last_generated = {}

	var res: Dictionary = _store.generate_palette()
	if not res.ok:
		var msg := Label.new()
		msg.text = str(res.message)
		msg.modulate = Color(1, 1, 1, 0.7)
		_palette_box.add_child(msg)
		return
	_last_generated = res

	for role in [["Dominant 60%", res.dominant], ["Secondary 30%", res.secondary], ["Accent 10%", res.accent]]:
		_palette_box.add_child(_role_row(str(role[0]), role[1]))

	var save_row := HBoxContainer.new()
	_palette_name_edit = LineEdit.new()
	_palette_name_edit.placeholder_text = "Name this palette"
	_palette_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_palette_name_edit)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.tooltip_text = "Keep this palette in Saved Palettes below."
	save_btn.pressed.connect(_on_save_palette)
	save_row.add_child(save_btn)
	var copy_btn := Button.new()
	copy_btn.text = "Copy as Text"
	copy_btn.tooltip_text = "Copy a labeled version that still makes sense pasted into chat."
	copy_btn.pressed.connect(_on_copy_generated)
	save_row.add_child(copy_btn)
	_palette_box.add_child(save_row)


func _role_row(label: String, family: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(96, 0)
	row.add_child(l)
	for key in ["shadow", "base", "light"]:
		var c: Color = family[key]
		var hx := Store.color_to_hex(c)
		var sw := ColorRect.new()
		sw.color = c
		sw.custom_minimum_size = Vector2(30, 26)
		sw.tooltip_text = key + "  #" + hx
		row.add_child(sw)
	return row


func _on_save_palette() -> void:
	if _last_generated.is_empty():
		_status.text = "Generate a palette first."
		return
	_store.save_palette(_palette_name_edit.text, _last_generated)
	_status.text = "Palette saved."
	_refresh_saved()


func _on_copy_generated() -> void:
	if _last_generated.is_empty():
		_status.text = "Generate a palette first."
		return
	DisplayServer.clipboard_set(_store.generated_to_text(_last_generated))
	_status.text = "Palette copied as labeled text."


# ---------------------------------------------------------------------------
# Saved palettes
# ---------------------------------------------------------------------------

func _refresh_saved() -> void:
	for child in _saved_box.get_children():
		_saved_box.remove_child(child)
		child.queue_free()
	var pals: Array = _store.list_palettes()
	if pals.is_empty():
		var empty := Label.new()
		empty.text = "    (none yet — generate one, then Save)"
		empty.modulate = Color(1, 1, 1, 0.4)
		_saved_box.add_child(empty)
		return
	for i in pals.size():
		_saved_box.add_child(_saved_row(i, pals[i]))


func _saved_row(index: int, p: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = str(p.get("name", "Palette"))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	top.add_child(_mini_button("Copy", _on_copy_saved.bind(index)))
	top.add_child(_mini_button("Delete", _on_delete_saved.bind(index)))
	box.add_child(top)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	for role_key in ["dominant", "secondary", "accent"]:
		var role: Dictionary = p.get(role_key, {})
		for shade in ["shadow", "base", "light"]:
			var hx := str(role.get(shade, "FFFFFF"))
			var sw := ColorRect.new()
			sw.color = Store.hex_to_color(hx)
			sw.custom_minimum_size = Vector2(22, 18)
			sw.tooltip_text = role_key + " " + shade + "  #" + hx
			strip.add_child(sw)
	box.add_child(strip)
	return box


func _on_copy_saved(index: int) -> void:
	var pals: Array = _store.list_palettes()
	if index >= 0 and index < pals.size():
		DisplayServer.clipboard_set(_store.palette_to_text(pals[index]))
		_status.text = "Palette copied as labeled text."


func _on_delete_saved(index: int) -> void:
	_store.delete_palette(index)
	_refresh_saved()
