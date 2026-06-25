class_name Game
extends Control

# Contrôleur principal (port de app.jsx App) : topbar (ère + 4 jauges), panneau
# (question, murmure, carte, nom), bottombar (année + couverture), poignée codex.
# Boucle : swipe → fly-out → applique fx → mort ou carte suivante. Pas de réaction
# (le prototype n'affiche pas le texte de réaction).

const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const FONT_MONO_BOLD = preload("res://assets/fonts/SpaceMono-Bold.ttf")
const FONT_CAVEAT = preload("res://assets/fonts/Caveat.ttf")
const FONT_SPECTRAL = preload("res://assets/fonts/Spectral-Regular.ttf")
const PANEL_SHADER = preload("res://assets/shaders/panel_bg.gdshader")
const DEATHFX_SHADER = preload("res://assets/shaders/death_fx.gdshader")
const QUESTION_MAX_H := 150.0

# état (port de App)
var cover := {}
var res := {"military": 50, "religion": 50, "commerce": 50, "politics": 50}
var legit := 100
var year := 1
var age := 36
var turns := 0
var y_start := 1
var recent: Array = []
var card := {}
var busy := false

# noeuds
var _era: RichTextLabel
var _gauges := {}
var _question: Label
var _q_scroll: ScrollContainer
var _whisper: Label
var _stage: Control
var _deck_card: Panel
var _cardview: CardView
var _bearer_name: Label
var _bearer_role: Label
var _year_lbl: Label
var _reign_lbl: Label
var _codex: Codex
var _death: Death
var _deathfx: ColorRect

func _ready() -> void:
	_build()
	_new_cover()
	_init_reign(100)
	card = Data.pick_card([])
	# attendre que les conteneurs se dimensionnent avant de placer/animer la carte
	await get_tree().process_frame
	await get_tree().process_frame
	_layout_stage()
	_cardview.show_card(card)
	_refresh_all()
	_cardview.play_entry()

# ── construction de l'UI ──
var _caveat_bold: FontVariation

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_caveat_bold = FontVariation.new()
	_caveat_bold.base_font = FONT_CAVEAT
	_caveat_bold.variation_opentype = {"wght": 700}
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	# TOPBAR
	var topbar := _bar(Color("#0b0e15"))
	vb.add_child(topbar)
	var tm := _margin(18, 12, 18, 11)
	topbar.add_child(tm)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 9)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tm.add_child(tv)
	_era = RichTextLabel.new()
	_era.bbcode_enabled = true
	_era.fit_content = true
	_era.scroll_active = false
	_era.add_theme_font_override("normal_font", FONT_MONO)
	_era.add_theme_font_size_override("normal_font_size", 9)
	_era.add_theme_color_override("default_color", Color("#9aa7bd"))
	_era.text = "[center]SECONDE FONDATION · [color=#4fd6e8]ÈRE HARDIN[/color] · ANS 1–80[/center]"
	tv.add_child(_era)
	var resrow := HBoxContainer.new()
	resrow.add_theme_constant_override("separation", 10)
	resrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(resrow)
	for r in Data.RESOURCES:
		var g := Gauge.new()
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resrow.add_child(g)
		g.setup(r["key"], r["label"])
		_gauges[r["key"]] = g

	# PANEL
	var panel := Control.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(panel)
	var pbg := ColorRect.new()
	pbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pmat := ShaderMaterial.new()
	pmat.shader = PANEL_SHADER
	pbg.material = pmat
	panel.add_child(pbg)
	var pm := _margin(22, 20, 22, 14)
	pm.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(pm)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pm.add_child(pv)

	_q_scroll = ScrollContainer.new()
	_q_scroll.custom_minimum_size = Vector2(300, 66)
	_q_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_q_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_q_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	pv.add_child(_q_scroll)
	_question = Label.new()
	_question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_question.add_theme_font_override("font", FONT_MONO)
	_question.add_theme_font_size_override("font_size", 17)
	_question.add_theme_constant_override("line_spacing", 5)
	_question.add_theme_color_override("font_color", Color("#dde6f2"))
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_q_scroll.add_child(_question)

	_whisper = Label.new()
	_whisper.add_theme_font_override("font", FONT_CAVEAT)
	_whisper.add_theme_font_size_override("font_size", 17)
	_whisper.add_theme_color_override("font_color", Pal.AMBER)
	_whisper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_whisper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_whisper.visible = false
	pv.add_child(_whisper)

	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = false
	pv.add_child(_stage)
	_deck_card = Panel.new()
	_deck_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color("#1a1f29")
	dsb.set_corner_radius_all(16)
	dsb.shadow_color = Color(0, 0, 0, 0.5)
	dsb.shadow_size = 18
	dsb.shadow_offset = Vector2(0, 10)
	_deck_card.add_theme_stylebox_override("panel", dsb)
	_stage.add_child(_deck_card)
	_cardview = CardView.new()
	_stage.add_child(_cardview)
	_cardview.committed.connect(_on_committed)
	_cardview.preview.connect(_on_preview)
	_stage.resized.connect(_layout_stage)

	var speaker := VBoxContainer.new()
	speaker.add_theme_constant_override("separation", 3)
	speaker.alignment = BoxContainer.ALIGNMENT_CENTER
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(speaker)
	_bearer_name = Label.new()
	_bearer_name.add_theme_font_override("font", FONT_MONO)
	_bearer_name.add_theme_font_size_override("font_size", 17)
	_bearer_name.add_theme_color_override("font_color", Pal.INK)
	_bearer_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker.add_child(_bearer_name)
	_bearer_role = Label.new()
	_bearer_role.add_theme_font_override("font", FONT_MONO)
	_bearer_role.add_theme_font_size_override("font_size", 8)
	_bearer_role.add_theme_color_override("font_color", Pal.ACCENT)
	_bearer_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker.add_child(_bearer_role)

	# BOTTOMBAR
	var bottombar := _bar(Color("#0b0e15"))
	vb.add_child(bottombar)
	var bm := _margin(18, 13, 18, 16)
	bottombar.add_child(bm)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	bm.add_child(bv)
	_year_lbl = Label.new()
	_year_lbl.add_theme_font_override("font", _caveat_bold)
	_year_lbl.add_theme_font_size_override("font_size", 30)
	_year_lbl.add_theme_color_override("font_color", Color("#eef1f6"))
	_year_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_year_lbl)
	_reign_lbl = Label.new()
	_reign_lbl.add_theme_font_override("font", FONT_MONO)
	_reign_lbl.add_theme_font_size_override("font_size", 10)
	_reign_lbl.add_theme_color_override("font_color", Pal.INK_DIM)
	_reign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_reign_lbl)

	# HANDLE
	var handle := Button.new()
	handle.text = "▲  TABLEAU DE BORD"
	handle.focus_mode = Control.FOCUS_NONE
	handle.custom_minimum_size = Vector2(0, 30)
	handle.add_theme_font_override("font", FONT_MONO)
	handle.add_theme_font_size_override("font_size", 9)
	handle.add_theme_color_override("font_color", Color("#7d8aa0"))
	handle.add_theme_color_override("font_hover_color", Pal.ACCENT)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color("#0b0e15")
	hsb.border_width_top = 1
	hsb.border_color = Color(0.471, 0.588, 0.745, 0.1)
	handle.add_theme_stylebox_override("normal", hsb)
	var hsbh := hsb.duplicate()
	hsbh.bg_color = Color(0.31, 0.839, 0.91, 0.05)
	handle.add_theme_stylebox_override("hover", hsbh)
	handle.add_theme_stylebox_override("pressed", hsbh)
	handle.pressed.connect(func(): _codex.open("chars"))
	vb.add_child(handle)

	# overlays
	_codex = Codex.new()
	_codex.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_codex)
	_death = Death.new()
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.respawn_pressed.connect(_respawn)
	add_child(_death)
	_deathfx = ColorRect.new()
	_deathfx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deathfx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dfm := ShaderMaterial.new()
	dfm.shader = DEATHFX_SHADER
	_deathfx.material = dfm
	_deathfx.visible = false
	add_child(_deathfx)

func _bar(c: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	p.add_theme_stylebox_override("panel", sb)
	return p

func _margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	return m

func _layout_stage() -> void:
	var a := _stage.size
	if a.x <= 0.0 or a.y <= 0.0: return
	var side: float = min(min(300.0, a.x * 0.76), a.y)
	var base := Vector2((a.x - side) / 2.0, (a.y - side) / 2.0)
	_deck_card.size = Vector2(side, side)
	_deck_card.pivot_offset = Vector2(side, side) * 0.5
	_deck_card.position = base + Vector2(9, 9)
	_deck_card.rotation = deg_to_rad(2.5)
	_cardview.layout(base, side)

# ── boucle ──
func _unhandled_input(e: InputEvent) -> void:
	if busy or _death.visible or _codex.visible: return
	if e.is_action_pressed("ui_left"): _cardview.swipe(true)
	elif e.is_action_pressed("ui_right"): _cardview.swipe(false)

func _on_preview(side: String) -> void:
	if side == "":
		for k in _gauges: _gauges[k].set_affected(false)
		return
	var fx: Dictionary = card[side]["fx"]
	for k in _gauges:
		_gauges[k].set_affected(fx.has(k) and int(fx[k]) != 0)

func _on_committed(is_left: bool) -> void:
	if busy: return
	busy = true
	for k in _gauges: _gauges[k].set_affected(false)
	var ans: Dictionary = card["left" if is_left else "right"]
	var fx: Dictionary = ans["fx"]
	for k in res:
		if fx.has(k): res[k] = clampi(res[k] + int(fx[k]), 0, 100)
	if fx.has("legit"): legit = clampi(legit + int(fx["legit"]), 0, 100)
	year += 1
	if randf() < 0.4: age += 1
	turns += 1
	_refresh_all()

	# mort ?
	var cause := ""
	var key := ""
	var hi := false
	for r in Data.RESOURCES:
		if res[r["key"]] <= 0: cause = r["label"]; key = r["key"]; break
		if res[r["key"]] >= 100: cause = r["label"]; key = r["key"]; hi = true; break
	if cause == "" and legit <= 0: cause = "legitimacy"; key = "legitimacy"
	if cause != "":
		await _play_death(key, hi)
		busy = false
		return

	# carte suivante
	recent = ([card["id"]] + recent).slice(0, 4)
	card = Data.pick_card(recent)
	_cardview.show_card(card)
	_refresh_card()
	await get_tree().process_frame
	_layout_stage()
	_cardview.play_entry()
	# déblocage de deck (jalon)
	for u in Data.DECK_UNLOCKS:
		if u["at"] == turns:
			_play_deck_unlock(u)
	busy = false

func _refresh_all() -> void:
	for r in Data.RESOURCES:
		_gauges[r["key"]].set_value(res[r["key"]])
	_year_lbl.text = "An %d" % year
	_reign_lbl.text = "%d ans · %s" % [age, str(cover.get("name", "Inconnu"))]
	_whisper.visible = legit < 35
	if _whisper.visible:
		_whisper.text = "vous semblez toujours avoir la bonne réponse…"
	_refresh_card()

func _refresh_card() -> void:
	_question.text = card.get("question", "")
	_bearer_name.text = card.get("bearer", "")
	_bearer_role.text = str(card.get("role", "")).to_upper()
	_fit_question()

func _fit_question() -> void:
	var h := _question.get_minimum_size().y
	_q_scroll.custom_minimum_size.y = clampf(h, 0.0, QUESTION_MAX_H)
	_q_scroll.scroll_vertical = 0

# ── mort / respawn ──
func _play_death(key: String, hi: bool) -> void:
	var mat := _deathfx.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", _deathfx.size)
	mat.set_shader_parameter("progress", 0.0)
	_deathfx.visible = true
	var t := create_tween()
	t.tween_method(func(v): mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.76)
	await t.finished
	_deathfx.visible = false

	var mk := "legitimacy" if key == "legitimacy" else key + ("_hi" if hi else "")
	var cause_label := "Orateur démasqué"
	if key != "legitimacy":
		cause_label = "%s — %s" % [cause_label_res(key), "excès fatal" if hi else "effondrement"]
	var info := {
		"causeLabel": cause_label,
		"bearerName": "Orateur — " + str(cover.get("name", "Inconnu")),
		"sub": "%d ans · Règne couvert : An %d → An %d" % [age, y_start, year],
		"message": Data.SELDON_MESSAGES.get(mk, Data.SELDON_MESSAGES.get(key, "« Le Plan se poursuit, malgré tout. »")),
		"turns": turns,
		"years": max(year - y_start, 0),
		"score": int(round(60 + turns * 8 + (0 if key == "legitimacy" else 40))),
		"deviation": "dévié de %.1f %%" % randf_range(2.0, 8.0),
		"res": res.duplicate(),
		"key": key,
	}
	_last_death_key = key
	_death.show_death(info)

var _last_death_key := ""

func cause_label_res(key: String) -> String:
	for r in Data.RESOURCES:
		if r["key"] == key: return r["label"]
	return key

func _respawn() -> void:
	legit = 50 if _last_death_key == "legitimacy" else 80
	_new_cover()
	_init_reign(legit)
	recent = []
	card = Data.pick_card([])
	_death.visible = false
	_cardview.show_card(card)
	_refresh_all()
	await get_tree().process_frame
	_layout_stage()
	_cardview.play_entry()
	busy = false

func _new_cover() -> void:
	cover = Data.COVERS[randi() % Data.COVERS.size()]

func _init_reign(legit_start: int) -> void:
	res = {"military": 50, "religion": 50, "commerce": 50, "politics": 50}
	res[cover["res"]] = 55
	legit = legit_start
	year = 1
	y_start = 1
	age = 36 + (randi() % 4)
	turns = 0

# ── bannière de déblocage de deck (port .deck-add + .deck-banner) ──
func _play_deck_unlock(u: Dictionary) -> void:
	var fx := Control.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(fx)
	var side: float = _cardview.size.x
	var target := _cardview.position + Vector2(10, 10)
	var n: int = clampi(u["cards"], 3, 6)
	for i in range(n):
		var ac := Panel.new()
		ac.size = Vector2(side, side)
		ac.pivot_offset = Vector2(side, side) * 0.5
		ac.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1b2433")
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.471, 0.784, 0.863, 0.16)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 16
		sb.shadow_offset = Vector2(0, 10)
		ac.add_theme_stylebox_override("panel", sb)
		ac.position = _cardview.position + Vector2(140, 150)
		ac.rotation = deg_to_rad(16)
		ac.scale = Vector2(0.9, 0.9)
		ac.modulate.a = 0.0
		fx.add_child(ac)
		var delay := i * 0.09
		var t := ac.create_tween().set_parallel()
		t.tween_property(ac, "modulate:a", 1.0, 0.2).set_delay(delay)
		t.tween_property(ac, "position", target, 0.5).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(ac, "rotation", deg_to_rad(2.5), 0.5).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(ac, "scale", Vector2.ONE, 0.5).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_unlock_banner(fx, u["name"], n)
	get_tree().create_timer(2.4).timeout.connect(func():
		if is_instance_valid(fx): fx.queue_free()
	, CONNECT_ONE_SHOT)

func _unlock_banner(parent: Control, deck_name: String, count: int) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var banner := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.094, 0.149, 0.94)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.31, 0.839, 0.91, 0.55)
	sb.shadow_color = Color(0.31, 0.839, 0.91, 0.35)
	sb.shadow_size = 22
	sb.content_margin_left = 30; sb.content_margin_right = 30
	sb.content_margin_top = 18; sb.content_margin_bottom = 18
	banner.add_theme_stylebox_override("panel", sb)
	center.add_child(banner)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 7)
	banner.add_child(vb)
	var tag := Label.new()
	tag.text = "N O U V E A U   D E C K"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", FONT_MONO)
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", Pal.ACCENT)
	vb.add_child(tag)
	var nm := Label.new()
	nm.text = deck_name
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_override("font", FONT_CAVEAT)
	nm.add_theme_font_size_override("font_size", 28)
	nm.add_theme_color_override("font_color", Color(0.933, 0.973, 0.984))
	vb.add_child(nm)
	var cnt := Label.new()
	cnt.text = "+%d cartes" % count
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.add_theme_font_override("font", FONT_MONO)
	cnt.add_theme_font_size_override("font_size", 9)
	cnt.add_theme_color_override("font_color", Color(0.624, 0.706, 0.769))
	vb.add_child(cnt)
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.9, 0.9)
	await get_tree().process_frame
	if not is_instance_valid(banner): return
	banner.pivot_offset = banner.size * 0.5
	var tw := banner.create_tween()
	tw.set_parallel()
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(banner, "modulate:a", 0.0, 0.2)
