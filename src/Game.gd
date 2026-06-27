class_name Game
extends Control

# Contrôleur principal (port de app.jsx App) : topbar (ère + 4 jauges), panneau
# (question, murmure, carte, nom), bottombar (année + couverture), poignée codex.
# Boucle : swipe → fly-out → applique fx → mort ou carte suivante. Pas de réaction
# (le prototype n'affiche pas le texte de réaction).

const SfxBank = preload("res://src/SfxBank.gd")
const FONT_MONO = preload("res://assets/fonts/SpaceMono-Regular.ttf")
const FONT_CAVEAT = preload("res://assets/fonts/Caveat.ttf")
const QUESTION_MAX_H := 150.0

# Durée de vie de la bannière de déblocage de deck (réglable dans l'inspecteur).
# question_fade / death_fx ont leur durée dans les clips de l'AnimationPlayer.
@export var deck_unlock_lifetime: float = 2.4

# Apparence du déblocage de deck (éditable dans l'inspecteur).
@export var deck_card_style: StyleBox = preload("res://styles/deck_card_style.tres")
@export var banner_style: StyleBox = preload("res://styles/deck_banner_style.tres")
@export var unlock_tag_font: Font = FONT_MONO
@export var unlock_name_font: Font = FONT_CAVEAT
@export var unlock_count_font: Font = FONT_MONO
@export var unlock_tag_color: Color = Color("#4fd6e8")
@export var unlock_name_color: Color = Color(0.933, 0.973, 0.984)
@export var unlock_count_color: Color = Color(0.624, 0.706, 0.769)

# état (port de App)
var cover := {}
var res := {"military": 50, "religion": 50, "commerce": 50, "politics": 50}
var legit := 100
var year := 1
var age := 36
var turns := 0
var y_start := 1
var recent: Array = []
var card: CardData

# Machine à états de la boucle (remplace l'ancien flag booléen `busy`).
# DRAGGING/RELEASING/FLYING_OUT décrivent l'espace d'états complet de la carte ;
# ils sont gérés en interne par CardView. Game pilote IDLE/TRANSITIONING/DEATH/CODEX.
enum State { IDLE, DRAGGING, RELEASING, FLYING_OUT, TRANSITIONING, DEATH, CODEX }
var _state := State.IDLE

var _hdrag := false       # drag de la poignée du tableau de bord (geste local au handle)
var _hstart_y := 0.0
var _hmoved := false

# noeuds
@onready var _era: RichTextLabel = %EraLabel
@onready var _question: Label = %QuestionLabel
@onready var _q_scroll: ScrollContainer = %QuestionScroll
@onready var _whisper: Label = %Whisper
@onready var _stage: Control = %CardStage
@onready var _deck_card: Panel = %DeckCard
@onready var _cardview: CardView = %CardView
@onready var _bearer_name: Label = %BearerName
@onready var _bearer_role: Label = %BearerRole
@onready var _year_lbl: Label = %Year
@onready var _reign_lbl: RichTextLabel = %Reign
@onready var _handle: PanelContainer = %Handle
@onready var _handle_chev: RichTextLabel = %Chev
@onready var _codex: Codex = %Codex
@onready var _death: Death = %Death
@onready var _deathfx: ColorRect = %DeathFx
@onready var _gear: Button = %Gear
@onready var _tweaks: TweaksPanel = %Tweaks
@onready var _anims: AnimationPlayer = %Animations

func _ready() -> void:
	for r in Data.RESOURCES:
		_gauge(r["key"]).setup(r["key"], r["label"])
	_era.text = _era_text()
	_handle_chev.text = _handle_text()
	_question.add_theme_font_size_override("font_size", Cfg.prose)
	_connect_signals()
	_new_cover()
	_init_reign(100)
	card = Data.pick_card([])
	await get_tree().process_frame
	await get_tree().process_frame
	_layout_stage()
	_cardview.show_card(card)
	_refresh_all()
	_cardview.play_entry()

# Branche tous les signaux de la scène en un seul endroit (lisibilité).
func _connect_signals() -> void:
	_cardview.committed.connect(_on_committed)
	_cardview.preview.connect(_on_preview)
	_stage.resized.connect(_layout_stage)
	_handle.gui_input.connect(_on_handle_input)
	_death.respawn_pressed.connect(_respawn)
	_codex.visibility_changed.connect(_on_codex_visibility_changed)
	_gear.pressed.connect(_on_gear_pressed)
	Cfg.changed.connect(_on_cfg_changed)

# Les jauges vivent dans le groupe "gauges" ; on les indexe par resource_key.
func _get_gauges() -> Array:
	return get_tree().get_nodes_in_group("gauges")

func _gauge(key: String) -> Gauge:
	for g in _get_gauges():
		if (g as Gauge).resource_key == key:
			return g
	return null

# Transition d'état centralisée (un seul point de mutation).
func _set_state(new_state: State) -> void:
	_state = new_state

# Le codex pilote l'état : ouvert → CODEX, fermé → retour à IDLE.
func _on_codex_visibility_changed() -> void:
	if _codex.visible:
		_set_state(State.CODEX)
	elif _state == State.CODEX:
		_set_state(State.IDLE)

func _on_handle_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_hdrag = true
		_hstart_y = get_global_mouse_position().y
		_hmoved = false
		_codex.drag_start()

func _on_gear_pressed() -> void:
	_tweaks.open()

func _era_text() -> String:
	return "[center]SECONDE FONDATION · [color=#%s]ÈRE HARDIN[/color] · ANS 1–80[/center]" % Cfg.accent.to_html(false)

func _handle_text() -> String:
	return "[center][color=#7d8aa0]▲[/color]  [color=#%s]TABLEAU DE BORD[/color][/center]" % Cfg.accent.to_html(false)

func _on_cfg_changed() -> void:
	# accent + taille de texte appliqués en direct
	_era.text = _era_text()
	_handle_chev.text = _handle_text()
	_bearer_role.add_theme_color_override("font_color", Cfg.accent)
	_question.add_theme_font_size_override("font_size", Cfg.prose)
	for g in _get_gauges():
		(g as Gauge).refresh()
	_fit_question()

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
	if e.is_action_pressed("codex_toggle"):
		if _state == State.CODEX: _codex.close()
		elif _state == State.IDLE: _codex.open("chars")
		return
	if _state != State.IDLE: return
	if e.is_action_pressed("swipe_left"): _cardview.swipe(true)
	elif e.is_action_pressed("swipe_right"): _cardview.swipe(false)

# Suivi global du drag de la poignée du tableau de bord.
func _input(e: InputEvent) -> void:
	if not _hdrag: return
	if e is InputEventMouseMotion:
		var up := _hstart_y - get_global_mouse_position().y
		if up > 6.0: _hmoved = true
		_codex.drag_move(maxf(0.0, up))
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		_hdrag = false
		var up := _hstart_y - get_global_mouse_position().y
		if not _hmoved:
			_codex.open("chars")      # simple clic → ouvre
		else:
			_codex.drag_end(maxf(0.0, up))

func _on_preview(side: String) -> void:
	if side == "":
		for g in _get_gauges(): (g as Gauge).set_affected(false)
		return
	var fx: Dictionary = (card.left_answer if side == "left" else card.right_answer).fx
	for g in _get_gauges():
		var key: String = (g as Gauge).resource_key
		(g as Gauge).set_affected(fx.has(key) and int(fx[key]) != 0)

func _on_committed(is_left: bool) -> void:
	if _state != State.IDLE: return
	_set_state(State.TRANSITIONING)
	for g in _get_gauges(): (g as Gauge).set_affected(false)
	var ans: AnswerData = card.left_answer if is_left else card.right_answer
	var fx: Dictionary = ans.fx
	var mult: float = Data.DIFF.get(Cfg.difficulty, 1.0)
	for k in res:
		if fx.has(k): res[k] = clampi(res[k] + int(round(float(fx[k]) * mult)), 0, 100)
	if fx.has("legit"): legit = clampi(legit + int(round(float(fx["legit"]) * mult)), 0, 100)
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
		return   # reste en DEATH jusqu'au respawn

	# carte suivante
	recent = ([card.id] + recent).slice(0, 4)
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
	# Ne repasse à IDLE que si on est toujours en transition (le codex a pu prendre la main).
	if _state == State.TRANSITIONING:
		_set_state(State.IDLE)

func _refresh_all() -> void:
	for r in Data.RESOURCES:
		_gauge(r["key"]).set_value(res[r["key"]])
	_year_lbl.text = "An %d" % year
	_reign_lbl.text = "[center][b][color=#e7edf6]%d ans[/color][/b] · %s[/center]" % [age, str(cover.get("name", "Inconnu"))]
	_whisper.visible = legit < 35
	if _whisper.visible:
		_whisper.text = "vous semblez toujours avoir la bonne réponse…"
	_refresh_card()

func _refresh_card() -> void:
	_question.text = card.question
	_bearer_name.text = card.bearer
	_bearer_role.text = card.role.to_upper()
	_fit_question()
	# qrise : la question apparaît en fondu à chaque nouvelle carte (template .question.k)
	_question.modulate.a = 0.0
	_anims.play("question_fade")

func _fit_question() -> void:
	var h := _question.get_minimum_size().y
	_q_scroll.custom_minimum_size.y = clampf(h, 0.0, QUESTION_MAX_H)
	_q_scroll.scroll_vertical = 0

# ── mort / respawn ──
func _play_death(key: String, hi: bool) -> void:
	_set_state(State.DEATH)
	AudioManager.play_sfx(SfxBank.death())   # son dramatique de mort
	var mat := _deathfx.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", _deathfx.size)
	mat.set_shader_parameter("progress", 0.0)
	_deathfx.visible = true
	# death_fx (AnimationPlayer) anime le paramètre "progress" du shader de 0 à 1.
	_anims.play("death_fx")
	await _anims.animation_finished
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
	AudioManager.play_sfx(SfxBank.respawn())   # son de nouveau règne
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
	_set_state(State.IDLE)

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
# Reste en create_tween() : positions/cibles calculées au runtime (taille de carte,
# position courante) — un AnimationPlayer à valeurs figées ne conviendrait pas.
func _play_deck_unlock(u: Dictionary) -> void:
	AudioManager.play_sfx(SfxBank.unlock())   # son de déblocage de deck
	# Cartes qui glissent : SOUS la carte actuelle (template .deck-add z-index 1 < .card z-index 3).
	var fx := Control.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(fx)
	_stage.move_child(fx, _cardview.get_index())   # passe sous la carte courante
	var side: float = _cardview.size.x
	var target := _cardview.position + Vector2(10, 10)
	var n: int = clampi(u["cards"], 3, 6)
	for i in range(n):
		var ac := Panel.new()
		ac.size = Vector2(side, side)
		ac.pivot_offset = Vector2(side, side) * 0.5
		ac.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ac.add_theme_stylebox_override("panel", deck_card_style)
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
	# Bandeau : AU-DESSUS de la carte (template .deck-banner z-index 12).
	var banfx := Control.new()
	banfx.set_anchors_preset(Control.PRESET_FULL_RECT)
	banfx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(banfx)   # ajouté après la carte → rendu par-dessus
	_unlock_banner(banfx, u["name"], n)
	get_tree().create_timer(deck_unlock_lifetime).timeout.connect(
		_on_deck_unlock_cleanup.bind(fx, banfx), CONNECT_ONE_SHOT)

# Nettoie les nœuds temporaires de la bannière de déblocage de deck.
func _on_deck_unlock_cleanup(fx: Control, banfx: Control) -> void:
	if is_instance_valid(fx): fx.queue_free()
	if is_instance_valid(banfx): banfx.queue_free()

func _unlock_banner(parent: Control, deck_name: String, count: int) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", banner_style)
	center.add_child(banner)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 7)
	banner.add_child(vb)
	var tag := Label.new()
	tag.text = "N O U V E A U   D E C K"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", unlock_tag_font)
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", unlock_tag_color)
	vb.add_child(tag)
	var nm := Label.new()
	nm.text = deck_name
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_override("font", unlock_name_font)
	nm.add_theme_font_size_override("font_size", 28)
	nm.add_theme_color_override("font_color", unlock_name_color)
	vb.add_child(nm)
	var cnt := Label.new()
	cnt.text = "+%d cartes" % count
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.add_theme_font_override("font", unlock_count_font)
	cnt.add_theme_font_size_override("font_size", 9)
	cnt.add_theme_color_override("font_color", unlock_count_color)
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
