#!/usr/bin/env python3
"""
Narrative Explorer — outil de visualisation et d'édition des cartes/decks.

Usage:
    python3 tools/narrative_explorer.py
    python3 tools/narrative_explorer.py --port 8080
    python3 tools/narrative_explorer.py --data data/foundation_cards.json
"""

import json
import os
import sys
import threading
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
CARDS_PATH = os.path.join(DATA_DIR, "foundation_cards.json")
ALIASES_PATH = os.path.join(DATA_DIR, "link_aliases.json")
CHARACTERS_PATH = os.path.join(DATA_DIR, "characters.json")
REFERENCE_DIR = os.path.join(os.path.dirname(__file__), "..", "reference", "REIGNS_DATA_EXPORT", "json")
REFERENCE_CARDS_PATH = os.path.join(REFERENCE_DIR, "cards_fr.json")
PORT = 8080

_cards = []
_link_aliases = {}
_characters = {}
_dirty = False
_data_lock = threading.Lock()
_watcher_stop = threading.Event()
_file_mtimes = {}
_last_save_time = 0

_ref_raw = {}        # raw deck->{name,deckId,nodes[]} from cards_fr.json
_ref_flat = []       # flat list of mapped reference cards

# ── Skeleton data ──
_skeletons = {}      # deck_name -> skeleton dict
_skeleton_meta = {}  # deck_name -> {filled, total, source_deck, node_count, hidden_count}

# ── Validation ──
VALID_VARIABLES = {
    'custom','deck','military','religion','commerce','politics',
    'turns','year','month','day','quest','link','seen','objective','location',
    'region','party','relation','mood','faction','age','legitimacy',
    'mentalic','mentalic_strength','synaptic','strength',
    'planet_ruler','player:rank','player:score','player:threat',
    'difficulty','cover_name','age_next','age_last',
}
VALID_OPS = {'equal','above','below','not'}
REQUIRED_CARD_FIELDS = ['id','label','deck']
REQUIRED_NESTED = {'question': ['FR']}


def load_data():
    global _cards, _link_aliases, _characters, _file_mtimes
    def _load(p):
        with open(p) as f:
            return json.load(f)
    _cards = _load(CARDS_PATH)
    _link_aliases = _load(ALIASES_PATH)
    _characters = _load(CHARACTERS_PATH)
    _file_mtimes = {
        CARDS_PATH: _try_mtime(CARDS_PATH),
        ALIASES_PATH: _try_mtime(ALIASES_PATH),
        CHARACTERS_PATH: _try_mtime(CHARACTERS_PATH),
    }
    load_skeleton_data()


def _try_mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return 0


# ── Reference cards (Reigns: Three Kingdoms) ──
VAR_MAP = {
    0: "custom", 1: "deck", 2: "military", 3: "people", 4: "supply",
    5: "morality", 6: "turns", 7: "gold", 8: "month", 9: "year",
    10: "link", 11: "seen", 12: "objective", 13: "location",
    14: "party", 15: "relation", 16: "mood", 17: "faction", 18: "age",
}
OP_MAP = {0: "equal", 1: "not", 2: "above", 3: "below"}
MOOD_MAP = {0: "neutral", 1: "suspicious", 2: "afraid", 3: "angry",
            4: "flattered", 5: "curious", 6: "sad", 7: "desperate"}


def load_reference_data():
    global _ref_raw, _ref_flat
    try:
        with open(REFERENCE_CARDS_PATH) as f:
            raw = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"[explorer] ⚠️ Référence introuvable: {e}")
        _ref_raw = {}
        _ref_flat = []
        return
    _ref_raw = raw
    flat = []
    for deck_name, deck_data in raw.items():
        for node in deck_data.get("nodes", []):
            cid = node.get("id", 0)
            flat.append({
                "id": cid,
                "refId": cid,
                "label": node.get("label", str(cid)),
                "deck": deck_name,
                "weight": node.get("weight", 1),
                "lockturn": node.get("lockturn", 0),
                "hidden": node.get("hidden", False),
                "bearer": str(node.get("bearer", "")),
                "question": {
                    "FR": node.get("question_fr", ""),
                    "EN": node.get("question_all", [""])[0] if node.get("question_all") else "",
                },
                "leftAnswer": {
                    "title": {"FR": node.get("answerLeft_fr", "")},
                    "reaction": {"FR": node.get("reactionLeft_fr", "")},
                },
                "rightAnswer": {
                    "title": {"FR": node.get("answerRight_fr", "")},
                    "reaction": {"FR": node.get("reactionRight_fr", "")},
                },
                "conditions": [_map_ref_cond(c) for c in node.get("conditions", [])],
                "yesOutcome": [_map_ref_outcome(o) for o in node.get("yesOutcome", [])],
                "noOutcome": [_map_ref_outcome(o) for o in node.get("noOutcome", [])],
                "loadOutcome": [_map_ref_outcome(o) for o in node.get("loadOutcome", [])],
                "moods": {
                    "default": MOOD_MAP.get(node.get("moods", {}).get("mood_default", 0), "neutral"),
                    "yes": MOOD_MAP.get(node.get("moods", {}).get("mood_yes", 0), "neutral"),
                    "no": MOOD_MAP.get(node.get("moods", {}).get("mood_no", 0), "neutral"),
                },
                "key": node.get("nodeFilterLevel", 1) > 1,
                "_refNodeIndex": node.get("nodeIndex", 0),
                "_refRaw": node,
            })
    _ref_flat = flat
    print(f"[explorer] 📖 Référence chargée: {len(_ref_raw)} decks, {len(_ref_flat)} cartes")


def _map_ref_cond(c):
    op = OP_MAP.get(c.get("op", 0), "equal")
    v = c.get("value", 0)
    var_name = c.get("varName", VAR_MAP.get(c.get("variable", 0), f"v{c['variable']}"))
    return {"variable": var_name, "op": op, "value": str(v)}


def _map_ref_outcome(o):
    var_name = o.get("varName", VAR_MAP.get(o.get("variable", 0), f"v{o['variable']}"))
    raw_val = o.get("value", 0)
    sv = o.get("stringValue", "")
    is_add = o.get("operation", "add") == "add"
    # Link outcomes store target in stringValue, not value
    if var_name == "link" and sv:
        raw_val = int(sv) if sv.isdigit() else 0
    return {
        "variable": var_name,
        "intValue": raw_val,
        "addOperation": is_add,
        "toKeep": False,
        "stringValue": sv,
    }


def build_reference_graph(deck_filter=None):
    """Build graph from reference cards (same structure as build_graph)."""
    nodes = []
    edges = []
    card_map = {c["id"]: c for c in _ref_flat}
    for c in _ref_flat:
        if deck_filter and c.get("deck") != deck_filter:
            continue
        cid = c["id"]
        nodes.append({
            "id": cid,
            "label": c.get("label", str(cid)),
            "deck": c.get("deck", ""),
            "hidden": c.get("hidden", False),
            "weight": c.get("weight", 1),
        })
        for out_list, key in [
            (c.get("loadOutcome", []), "load"),
            (c.get("yesOutcome", []), "yes"),
            (c.get("noOutcome", []), "no"),
        ]:
            for i, o in enumerate(out_list):
                target = None
                if o.get("variable") == "link":
                    target = o.get("intValue")
                sv = str(o.get("stringValue", ""))
                if sv.startswith("_") and sv in _link_aliases:
                    alias = _link_aliases.get(sv, {})
                    if "node" in alias:
                        target = alias["node"]
                if target is not None:
                    tgt = int(target)
                    if tgt in card_map:
                        edges.append({
                            "from": cid,
                            "to": tgt,
                            "label": key,
                            "outcomeIdx": i,
                            "outcomeKey": key,
                            "fromDeck": c.get("deck", ""),
                            "toDeck": card_map[tgt].get("deck", ""),
                        })
    return {"nodes": nodes, "edges": edges}


def get_reference_decks():
    decks = {}
    for c in _ref_flat:
        d = c.get("deck", "")
        if d not in decks:
            decks[d] = {"count": 0, "hidden": 0, "neg_weight": 0, "cards": []}
        decks[d]["count"] += 1
        if c.get("hidden"):
            decks[d]["hidden"] += 1
        if c.get("weight", 1) < 0:
            decks[d]["neg_weight"] += 1
        decks[d]["cards"].append(c["id"])
    return decks


# ── Skeleton loading ──
def load_skeleton_data():
    global _skeletons, _skeleton_meta
    _skeletons = {}
    _skeleton_meta = {}
    sk_dir = os.path.join(DATA_DIR, "skeletons")
    if not os.path.isdir(sk_dir):
        print(f"[explorer] ⚠️ Dossier squelettes introuvable: {sk_dir}")
        return
    card_ids = {c["id"] for c in _cards}
    for fname in sorted(os.listdir(sk_dir)):
        if not fname.endswith(".json"):
            continue
        try:
            with open(os.path.join(sk_dir, fname)) as f:
                sk = json.load(f)
        except (json.JSONDecodeError, OSError) as e:
            print(f"[explorer] ⚠️ Erreur squelette {fname}: {e}")
            continue
        deck = sk.get("target_deck", "")
        nodes = sk.get("nodes", [])
        sk_ids = {n["id"] for n in nodes}
        filled = sum(1 for cid in sk_ids if cid in card_ids)
        _skeletons[deck] = sk
        _skeleton_meta[deck] = {
            "source_deck": sk.get("source_deck", ""),
            "node_count": sk.get("node_count", len(nodes)),
            "hidden_count": sk.get("hidden_count", 0),
            "filled": filled,
            "total": len(nodes),
        }
    print(f"[explorer] 📦 Squelettes chargés: {len(_skeleton_meta)} decks")


# ── Card validation ──
def validate_card(c):
    """Validate a single card, return list of issue dicts."""
    issues = []
    cid = c.get("id", "?")
    for f in REQUIRED_CARD_FIELDS:
        if not c.get(f) and c.get(f) != 0:
            issues.append({"card": cid, "field": f, "severity": "error",
                           "msg": f"Champ obligatoire '{f}' manquant"})
    # Nested required fields
    for parent, children in REQUIRED_NESTED.items():
        obj = c.get(parent, {})
        for child in children:
            if not obj.get(child):
                issues.append({"card": cid, "field": f"{parent}.{child}",
                               "severity": "warning",
                               "msg": f"Champ '{parent}.{child}' manquant"})
    # Weight
    w = c.get("weight", 1)
    if not isinstance(w, int) or w < -1 or w == 0:
        issues.append({"card": cid, "field": "weight", "severity": "error",
                       "msg": f"Weight invalide: {w} (doit être int ≠ 0)"})
    # Lockturn
    lt = c.get("lockturn", 0)
    if not isinstance(lt, int) or lt < 0:
        issues.append({"card": cid, "field": "lockturn", "severity": "warning",
                       "msg": f"Lockturn invalide: {lt}"})
    # Condition validation
    for i, cond in enumerate(c.get("conditions", [])):
        v = cond.get("variable", "")
        if v and v not in VALID_VARIABLES:
            issues.append({"card": cid, "field": f"conditions[{i}].variable",
                           "severity": "warning",
                           "msg": f"Variable inconnue '{v}'"})
        if cond.get("op") and cond["op"] not in VALID_OPS:
            issues.append({"card": cid, "field": f"conditions[{i}].op",
                           "severity": "error",
                           "msg": f"Opérateur inconnu '{cond['op']}'"})
    # Outcome validation
    for key in ("yesOutcome", "noOutcome", "loadOutcome"):
        for i, o in enumerate(c.get(key, [])):
            v = o.get("variable", "")
            if v and v not in VALID_VARIABLES:
                issues.append({"card": cid, "field": f"{key}[{i}].variable",
                               "severity": "warning",
                               "msg": f"Variable inconnue '{v}'"})
            if v == "link" and o.get("intValue"):
                tgt = o["intValue"]
                if not any(x["id"] == tgt for x in _cards):
                    issues.append({"card": cid, "field": f"{key}[{i}].intValue",
                                   "severity": "warning",
                                   "msg": f"Lien #{tgt} → cible inexistante"})
    # Moods
    moods = c.get("moods", {})
    for mk in ("default", "yes", "no"):
        if moods.get(mk) and moods[mk] not in MOOD_MAP.values() and moods[mk] not in MOOD_MAP.values():
            # Accept both names and numbers
            pass
    return issues


def validate_all_cards(deck_filter=None):
    """Validate all cards (or a deck), return {errors, warnings, by_card}."""
    errors = []
    warnings = []
    by_card = {}
    seen_ids = {}
    target = [c for c in _cards if not deck_filter or c.get("deck") == deck_filter]
    for c in target:
        cid = c.get("id")
        if cid is not None:
            if cid in seen_ids:
                errors.append({"card": cid, "field": "id", "severity": "error",
                               "msg": f"ID #{cid} dupliqué"})
            seen_ids[cid] = True
        issues = validate_card(c)
        if issues:
            by_card[cid] = issues
            for iss in issues:
                if iss["severity"] == "error":
                    errors.append(iss)
                else:
                    warnings.append(iss)
    return {"errors": errors, "warnings": warnings, "by_card": by_card,
            "total": len(target), "error_count": len(errors),
            "warning_count": len(warnings)}


# ── Deck management ──
def rename_deck(old_name, new_name):
    global _dirty
    if new_name in get_decks() and new_name != old_name:
        return False, f"Un deck '{new_name}' existe déjà"
    count = 0
    for c in _cards:
        if c.get("deck") == old_name:
            c["deck"] = new_name
            count += 1
    _dirty = True
    return True, f"{count} cartes renommées en '{new_name}'"


def bulk_edit_cards(card_ids, updates):
    global _dirty
    count = 0
    for c in _cards:
        if c["id"] in card_ids:
            for k, v in updates.items():
                c[k] = v
            count += 1
    _dirty = True
    return count


def get_skeleton_progress(deck_name=None):
    """Return skeleton fill status for all decks or one deck."""
    if deck_name:
        return _skeleton_meta.get(deck_name, {})
    return _skeleton_meta


# ── Simulation / context testing ──
DEFAULT_CONTEXT = {
    "military": 50, "religion": 50, "commerce": 50, "politics": 50,
    "legitimacy": 50, "turns": 1, "year": 1, "age": 35, "mood": 0,
}


def simulate_card(card_id, context_override=None):
    """Simulate a card: check conditions, show possible outcomes with delta."""
    ctx = dict(DEFAULT_CONTEXT)
    if context_override:
        ctx.update(context_override)
    card = None
    for c in _cards:
        if c["id"] == card_id:
            card = c
            break
    if not card:
        return {"error": "Carte introuvable"}
    # Check conditions
    conditions_met = []
    for cond in card.get("conditions", []):
        var = cond.get("variable", "")
        op = cond.get("op", "equal")
        raw_val = cond.get("value", "0")
        try:
            val = int(raw_val)
        except (ValueError, TypeError):
            val = 0
        cur = ctx.get(var, 0)
        met = False
        if op == "equal":
            met = cur == val
        elif op == "above":
            met = cur > val
        elif op == "below":
            met = cur < val
        elif op == "not":
            met = cur != val
        conditions_met.append({
            "variable": var, "op": op, "value": val, "current": cur, "met": met,
        })
    eligible = all(c["met"] for c in conditions_met)
    # Simulate outcomes
    def sim_outcomes(outcomes, ctx_in):
        delta = {}
        new_ctx = dict(ctx_in)
        for o in outcomes:
            v = o.get("variable", "")
            if v == "link":
                continue
            val = o.get("intValue", 0)
            if o.get("addOperation") is not False:
                new_ctx[v] = new_ctx.get(v, 0) + val
                delta[v] = (delta.get(v, 0) or 0) + val
            else:
                delta[v] = new_ctx.get(v, 0) - ctx_in.get(v, 0)
                new_ctx[v] = val
        return new_ctx, delta
    ctx_yes, delta_yes = sim_outcomes(card.get("yesOutcome", []), ctx)
    ctx_no, delta_no = sim_outcomes(card.get("noOutcome", []), ctx)
    ctx_load, delta_load = sim_outcomes(card.get("loadOutcome", []), ctx)
    return {
        "eligible": eligible,
        "conditions": conditions_met,
        "context_before": ctx,
        "load_delta": delta_load,
        "yes_delta": delta_yes,
        "no_delta": delta_no,
        "context_after_yes": ctx_yes,
        "context_after_no": ctx_no,
    }


_backup_done = False

def save_cards():
    global _backup_done, _last_save_time, _dirty
    if not _backup_done:
        bk = backup_cards()
        print(f"[explorer] Backup créé : {bk}")
        _backup_done = True
    with open(CARDS_PATH, "w") as f:
        json.dump(_cards, f, indent=2, ensure_ascii=False)
    _last_save_time = _try_mtime(CARDS_PATH)
    _dirty = False


def backup_cards():
    import shutil
    from datetime import datetime
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    bk = CARDS_PATH.replace(".json", f"_backup_{ts}.json")
    shutil.copy2(CARDS_PATH, bk)
    return os.path.basename(bk)


def get_decks():
    decks = {}
    for c in _cards:
        d = c.get("deck", "")
        if d not in decks:
            decks[d] = {"count": 0, "hidden": 0, "neg_weight": 0, "cards": []}
        decks[d]["count"] += 1
        if c.get("hidden"):
            decks[d]["hidden"] += 1
        if c.get("weight", 1) < 0:
            decks[d]["neg_weight"] += 1
        decks[d]["cards"].append(c["id"])
    # Attach skeleton progress
    for name, meta in _skeleton_meta.items():
        if name in decks:
            decks[name]["skeleton_filled"] = meta["filled"]
            decks[name]["skeleton_total"] = meta["total"]
            decks[name]["skeleton_pct"] = round(meta["filled"] / meta["total"] * 100) if meta["total"] else 0
            decks[name]["source_deck"] = meta["source_deck"]
        else:
            decks[name] = {"count": 0, "hidden": 0, "neg_weight": 0, "cards": [],
                           "skeleton_filled": meta["filled"],
                           "skeleton_total": meta["total"],
                           "skeleton_pct": 0,
                           "source_deck": meta["source_deck"]}
    return decks


def build_graph(deck_filter=None):
    nodes = []
    edges = []
    card_map = {c["id"]: c for c in _cards}
    for c in _cards:
        if deck_filter and c.get("deck") != deck_filter:
            continue
        cid = c["id"]
        label = c.get("label", str(cid))
        nodes.append({
            "id": cid,
            "label": label,
            "deck": c.get("deck", ""),
            "hidden": c.get("hidden", False),
            "weight": c.get("weight", 1),
        })
        for out_list, key in [
            (c.get("loadOutcome", []), "load"),
            (c.get("yesOutcome", []), "yes"),
            (c.get("noOutcome", []), "no"),
        ]:
            for i, o in enumerate(out_list):
                target = None
                if o.get("variable") == "link":
                    target = o.get("intValue")
                sv = str(o.get("stringValue", ""))
                if sv.startswith("_") and sv in _link_aliases:
                    alias = _link_aliases[sv]
                    if "node" in alias:
                        target = alias["node"]
                if target and (not deck_filter or True):
                    tgt = int(target)
                    if tgt in card_map:
                        edges.append({
                            "from": cid,
                            "to": tgt,
                            "label": key,
                            "outcomeIdx": i,
                            "outcomeKey": key,
                            "fromDeck": c.get("deck", ""),
                            "toDeck": card_map[tgt].get("deck", ""),
                        })
    return {"nodes": nodes, "edges": edges}


class NarrativeAPI(BaseHTTPRequestHandler):

    def _send(self, data, status=200):
        self.send_response(status)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

    def _send_html(self, html):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode())

    def _send_error(self, msg, status=400):
        self._send({"error": msg}, status)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length))

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PUT, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)
        path = parsed.path.rstrip("/")

        if path == "" or path == "/" or path == "/index.html":
            self._send_html(HTML)
            return
        elif path == "/api/cards":
            deck = qs.get("deck", [None])[0]
            if deck:
                result = [c for c in _cards if c.get("deck") == deck]
            else:
                result = _cards
            self._send({"total": len(result), "cards": result})
        elif path.startswith("/api/card/"):
            cid = int(path.split("/")[-1])
            for c in _cards:
                if c["id"] == cid:
                    self._send(c)
                    return
            self._send_error("Card not found", 404)
        elif path == "/api/decks":
            self._send(get_decks())
        elif path == "/api/aliases":
            self._send(_link_aliases)
        elif path == "/api/characters":
            self._send(_characters)
        elif path == "/api/graph":
            deck = qs.get("deck", [None])[0]
            self._send(build_graph(deck))
        elif path == "/api/backup":
            bk = backup_cards()
            self._send({"backup": bk})
        elif path == "/api/status":
            self._send({"dirty": _dirty, "total_cards": len(_cards)})
        elif path == "/api/reference/decks":
            self._send(get_reference_decks())
        elif path == "/api/reference/cards":
            deck = qs.get("deck", [None])[0]
            if deck:
                result = [c for c in _ref_flat if c.get("deck") == deck]
            else:
                result = _ref_flat
            self._send({"total": len(result), "cards": result})
        elif path.startswith("/api/reference/card/"):
            cid = int(path.split("/")[-1])
            for c in _ref_flat:
                if c["id"] == cid:
                    self._send(c)
                    return
            self._send_error("Card not found", 404)
        elif path == "/api/reference/graph":
            deck = qs.get("deck", [None])[0]
            self._send(build_reference_graph(deck))
        elif path == "/api/validate":
            deck = qs.get("deck", [None])[0]
            self._send(validate_all_cards(deck))
        elif path == "/api/validate/card":
            cid = qs.get("id", [None])[0]
            if cid:
                for c in _cards:
                    if str(c["id"]) == cid:
                        self._send({"issues": validate_card(c)})
                        return
                self._send_error("Card not found", 404)
            else:
                self._send_error("Missing id param", 400)
        elif path == "/api/skeletons":
            deck = qs.get("deck", [None])[0]
            self._send(get_skeleton_progress(deck))
        elif path.startswith("/api/skeleton/gap/"):
            deck_name = path.split("/")[-1]
            sk = _skeletons.get(deck_name)
            if not sk:
                self._send_error("Skeleton not found", 404)
                return
            nodes = sk.get("nodes", [])
            card_ids = {c["id"] for c in _cards if c.get("deck") == deck_name}
            missing = [n for n in nodes if n["id"] not in card_ids]
            present = [n for n in nodes if n["id"] in card_ids]
            extra = [c for c in _cards if c.get("deck") == deck_name and c["id"] not in {n["id"] for n in nodes}]
            self._send({"deck": deck_name, "total": len(nodes),
                        "present": len(present), "missing": len(missing),
                        "extra": len(extra), "missing_nodes": missing[:100],
                        "extra_ids": [c["id"] for c in extra]})
        elif path == "/api/simulate":
            cid = qs.get("card", [None])[0]
            ctx_json = qs.get("context", [None])[0]
            context_override = json.loads(ctx_json) if ctx_json else None
            if cid:
                self._send(simulate_card(int(cid), context_override))
            else:
                self._send_error("Missing card param", 400)
        else:
            self._send_error("Not found", 404)

    def do_PUT(self):
        global _dirty
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path.startswith("/api/card/"):
            cid = int(path.split("/")[-1])
            body = self._read_body()
            for i, c in enumerate(_cards):
                if c["id"] == cid:
                    # Support partial field update: {"field": "label", "value": "x"}
                    # or full card replacement
                    if "field" in body:
                        keys = body["field"].split(".")
                        val = body["value"]
                        obj = _cards[i]
                        for k in keys[:-1]:
                            if k not in obj or not isinstance(obj[k], dict):
                                obj[k] = {}
                            obj = obj[k]
                        obj[keys[-1]] = val
                    else:
                        _cards[i] = body
                    _dirty = True
                    self._send({"ok": True, "id": cid})
                    return
            self._send_error("Card not found", 404)
        elif path == "/api/deck/rename":
            body = self._read_body()
            ok, msg = rename_deck(body.get("old_name", ""), body.get("new_name", ""))
            if ok:
                self._send({"ok": True, "msg": msg})
            else:
                self._send_error(msg, 400)
        elif path == "/api/deck/bulk":
            body = self._read_body()
            card_ids = body.get("card_ids", [])
            updates = body.get("updates", {})
            count = bulk_edit_cards(card_ids, updates)
            self._send({"ok": True, "count": count})
        elif path == "/api/save":
            save_cards()
            self._send({"ok": True})
        else:
            self._send_error("Not found", 404)

    def do_POST(self):
        global _dirty
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path == "/api/card":
            body = self._read_body()
            if "id" not in body:
                existing = {c["id"] for c in _cards}
                new_id = 1000
                while new_id in existing:
                    new_id += 1
                body["id"] = new_id
            _cards.append(body)
            _dirty = True
            self._send({"ok": True, "id": body["id"]})
        elif path == "/api/deck":
            body = self._read_body()
            name = body.get("name", "")
            if not name:
                self._send_error("Nom de deck manquant", 400)
                return
            existing_ids = {c["id"] for c in _cards}
            new_id = 1
            while new_id in existing_ids:
                new_id += 1
            _cards.append({
                "id": new_id, "label": "_deck_placeholder", "deck": name,
                "weight": 1, "lockturn": 0, "hidden": True,
                "question": {"FR": "PLACEHOLDER"},
                "conditions": [], "loadOutcome": [],
                "leftAnswer": {"title": {"FR": ""}, "reaction": {"FR": ""}},
                "rightAnswer": {"title": {"FR": ""}, "reaction": {"FR": ""}},
                "yesOutcome": [], "noOutcome": [],
                "moods": {"default": "neutral", "yes": "neutral", "no": "neutral"},
            })
            _dirty = True
            self._send({"ok": True, "name": name, "placeholder_id": new_id})
        elif path == "/api/save":
            save_cards()
            self._send({"ok": True})
        else:
            self._send_error("Not found", 404)

    def do_DELETE(self):
        global _dirty
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path.startswith("/api/card/"):
            cid = int(path.split("/")[-1])
            for i, c in enumerate(_cards):
                if c["id"] == cid:
                    _cards.pop(i)
                    _dirty = True
                    self._send({"ok": True, "id": cid})
                    return
            self._send_error("Card not found", 404)
        elif path.startswith("/api/deck/"):
            deck_name = path.split("/")[-1]
            count = 0
            i = 0
            while i < len(_cards):
                if _cards[i].get("deck") == deck_name:
                    _cards.pop(i)
                    count += 1
                else:
                    i += 1
            if count:
                _dirty = True
                self._send({"ok": True, "deck": deck_name, "deleted": count})
            else:
                self._send_error("Deck not found or empty", 404)
        else:
            self._send_error("Not found", 404)

    def log_message(self, fmt, *args):
        msg = fmt % args
        if "GET /api/status" not in msg and "GET /api/graph" not in msg:
            print(f"[explorer] {msg}")


HTML = r"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Narrative Explorer — Foundation Reigns</title>
<style>
:root {
  --bg: #f0f2f5;
  --surface: #ffffff;
  --surface-2: #f8f9fa;
  --border: #e2e8f0;
  --primary: #3b82f6;
  --primary-hover: #2563eb;
  --primary-light: #eff6ff;
  --amber: #f59e0b;
  --amber-light: #fffbeb;
  --danger: #ef4444;
  --danger-light: #fef2f2;
  --green: #10b981;
  --green-light: #f0fdf4;
  --ink: #1e293b;
  --ink-dim: #64748b;
  --ink-faint: #94a3b8;
  --sidebar-bg: #1e293b;
  --sidebar-hover: #334155;
  --sidebar-active: #3b82f6;
  --sidebar-text: #cbd5e1;
  --sidebar-text-dim: #64748b;
  --radius: 6px;
  --radius-lg: 8px;
  --shadow: 0 1px 3px rgba(0,0,0,.08), 0 1px 2px rgba(0,0,0,.06);
  --shadow-md: 0 4px 6px -1px rgba(0,0,0,.1), 0 2px 4px -2px rgba(0,0,0,.1);
  --font: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  --mono: 'SF Mono', 'JetBrains Mono', 'Fira Code', monospace;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  background: var(--bg);
  color: var(--ink);
  font-family: var(--font);
  height: 100vh;
  display: flex;
  overflow: hidden;
  font-size: 13px;
  line-height: 1.5;
}
a { color: var(--primary); text-decoration: none; }
a:hover { text-decoration: underline; }
input, textarea, select {
  background: var(--surface);
  border: 1px solid var(--border);
  color: var(--ink);
  padding: 5px 8px;
  border-radius: var(--radius);
  font-family: var(--font);
  font-size: 12px;
  transition: border-color .15s, box-shadow .15s;
}
input:focus, textarea:focus, select:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(59,130,246,.12);
}
button {
  background: var(--surface);
  color: var(--ink);
  border: 1px solid var(--border);
  padding: 5px 12px;
  border-radius: var(--radius);
  cursor: pointer;
  font-size: 12px;
  font-family: var(--font);
  transition: all .15s;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
button:hover { border-color: var(--primary); color: var(--primary); background: var(--primary-light); }
button.danger { color: var(--danger); }
button.danger:hover { background: var(--danger-light); border-color: var(--danger); color: var(--danger); }
button.primary { background: var(--primary); color: #fff; border-color: var(--primary); font-weight: 500; }
button.primary:hover { background: var(--primary-hover); border-color: var(--primary-hover); color: #fff; }
button.small { padding: 2px 8px; font-size: 11px; }

/* Sidebar */
#sidebar {
  width: 230px; min-width: 230px;
  background: var(--sidebar-bg);
  display: flex; flex-direction: column; overflow: hidden;
}
#sidebar h1 {
  font-size: 14px; font-weight: 600; padding: 14px 14px 10px;
  color: #f1f5f9; letter-spacing: -.02em;
}
#sidebar h1 span { color: var(--sidebar-text-dim); font-weight: 400; font-size: 12px; }
#deck-search {
  margin: 4px 10px 6px; padding: 6px 10px; font-size: 12px;
  background: var(--sidebar-hover); border-color: transparent;
  color: var(--sidebar-text); border-radius: var(--radius);
}
#deck-search::placeholder { color: var(--sidebar-text-dim); }
#deck-search:focus { background: #1a2236; border-color: var(--sidebar-active); }
#deck-list { flex: 1; overflow-y: auto; padding: 2px 0; }
.deck-item {
  padding: 6px 10px 6px 14px; cursor: pointer; display: flex;
  align-items: center; gap: 4px;
  border-left: 3px solid transparent; font-size: 12px;
  color: var(--sidebar-text); transition: background .1s;
}
.deck-item:hover { background: var(--sidebar-hover); }
.deck-item.active { border-left-color: var(--sidebar-active); background: rgba(59,130,246,.1); color: #f1f5f9; }
.deck-item .badge {
  font-size: 10px; color: var(--sidebar-text-dim); font-family: var(--mono);
  margin-left: auto; white-space: nowrap;
}
.deck-item .badge.h { color: var(--danger); }
.deck-item .badge.w { color: var(--amber); }
.deck-type-label {
  padding: 10px 14px 3px; font-size: 10px; font-weight: 600;
  text-transform: uppercase; letter-spacing: .8px;
  color: var(--sidebar-text-dim);
}
.deck-sk-progress { height: 3px; background: rgba(255,255,255,.08); border-radius: 2px; margin: 2px 10px 0; overflow: hidden; }
.deck-sk-progress .fill { height: 100%; border-radius: 2px; transition: width .3s; }
.deck-sk-progress .fill.good { background: var(--green); }
.deck-sk-progress .fill.ok { background: var(--amber); }
.deck-sk-progress .fill.low { background: var(--danger); }
.deck-actions { display: none; position: absolute; right: 6px; top: 4px; gap: 2px; }
.deck-item { position: relative; }
.deck-item:hover .deck-actions { display: flex; }
.deck-actions button {
  font-size: 9px; padding: 0 4px; height: 16px; line-height: 1;
  background: transparent; border: 1px solid rgba(255,255,255,.1);
  cursor: pointer; color: var(--sidebar-text-dim); border-radius: 3px;
}
.deck-actions button:hover { border-color: var(--sidebar-active); color: #f1f5f9; }
.deck-item .deck-info { display: flex; flex-direction: column; flex: 1; min-width: 0; overflow: hidden; }
.deck-item .deck-meta { font-size: 10px; color: var(--sidebar-text-dim); font-family: var(--mono); }
.deck-rename-input { font-size: 11px; padding: 1px 4px; width: 100%; background: #1a2236; border: 1px solid var(--sidebar-active); color: #f1f5f9; border-radius: 3px; }
#deck-create-btn { margin: 4px 10px 6px; font-size: 11px; padding: 5px 10px; background: transparent; border: 1px dashed rgba(255,255,255,.15); color: var(--sidebar-text); }
#deck-create-btn:hover { border-color: var(--sidebar-active); color: #f1f5f9; background: rgba(59,130,246,.08); }
#deck-delete-btn { font-size: 9px; color: var(--danger); }
.modal-overlay {
  position: fixed; inset: 0; background: rgba(15,23,42,.5); backdrop-filter: blur(2px);
  z-index: 998; display: flex; align-items: center; justify-content: center;
}
.modal-box {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--radius-lg); padding: 24px;
  min-width: 360px; max-width: 480px;
  box-shadow: var(--shadow-md);
}
.modal-box h2 { font-size: 16px; font-weight: 600; margin-bottom: 8px; color: var(--ink); }
.modal-box p { font-size: 13px; color: var(--ink-dim); margin-bottom: 16px; line-height: 1.5; }
.modal-box input { width: 100%; margin-bottom: 12px; }
.modal-box select { width: 100%; margin-bottom: 12px; }
.modal-buttons { display: flex; gap: 8px; justify-content: flex-end; }
.bulk-bar {
  display: flex; align-items: center; gap: 6px; padding: 5px 10px;
  background: var(--surface); border-bottom: 1px solid var(--border);
  font-size: 11px; color: var(--ink-dim);
  min-height: 32px; display: none;
}
.bulk-bar.visible { display: flex; }
.bulk-bar button { font-size: 10px; padding: 2px 8px; }
.bulk-bar .count { color: var(--primary); font-weight: 600; margin-right: 8px; font-size: 11px; }

/* Main */
#main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
#toolbar {
  display: flex; align-items: center; gap: 8px;
  padding: 8px 14px; background: var(--surface);
  border-bottom: 1px solid var(--border);
  box-shadow: 0 1px 2px rgba(0,0,0,.04);
  z-index: 5;
}
#toolbar .title { font-size: 14px; font-weight: 600; flex: 1; color: var(--ink); }
#toolbar .title .sub { color: var(--ink-faint); font-size: 11px; margin-left: 8px; font-weight: 400; }
#toolbar .actions { display: flex; gap: 6px; align-items: center; }
#content { flex: 1; display: flex; overflow: hidden; }

/* Table */
#card-list { flex: 0 0 55%; overflow: hidden; border-right: 1px solid var(--border); display: flex; flex-direction: column; background: var(--surface); }
#card-search { margin: 8px 10px 4px; padding: 6px 10px; font-size: 12px; }
#card-table-wrap { flex: 1; overflow: auto; }
#card-table { width: 100%; border-collapse: collapse; font-size: 12px; }
#card-table th {
  position: sticky; top: 0; background: var(--surface-2); z-index: 2;
  padding: 6px 8px; text-align: left; font-weight: 600;
  font-size: 10px; text-transform: uppercase; letter-spacing: .4px;
  color: var(--ink-faint); border-bottom: 1px solid var(--border);
  cursor: pointer; white-space: nowrap;
}
#card-table th:hover { color: var(--primary); }
#card-table td { padding: 5px 8px; border-bottom: 1px solid var(--border); vertical-align: middle; }
#card-table tr { cursor: pointer; transition: background .1s; }
#card-table tr:hover td { background: var(--primary-light); }
#card-table tr.active td { background: var(--primary-light); }
#card-table .cid { color: var(--ink-faint); font-family: var(--mono); font-size: 11px; width: 50px; }
#card-table .clabel { font-size: 12px; max-width: 180px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
#card-table .cnum { font-family: var(--mono); font-size: 11px; color: var(--ink-dim); text-align: center; }
#card-table .cflags { white-space: nowrap; }
.flag {
  display: inline-block; padding: 1px 4px; border-radius: 3px;
  font-family: var(--mono); font-size: 9px; line-height: 1.3;
  margin-right: 3px; font-weight: 500;
}
.flag.h { color: var(--danger); background: var(--danger-light); }
.flag.w { color: var(--amber); background: var(--amber-light); }
.flag.l { color: #0891b2; background: #ecfeff; }
.flag.k { color: var(--amber); background: var(--amber-light); }
.flag.b { color: #7c3aed; background: #f5f3ff; }

/* Impact chips */
.impact {
  display: inline-block; font-family: var(--mono); font-size: 9px;
  padding: 1px 5px; border-radius: 3px; margin: 1px;
  white-space: nowrap; font-weight: 500;
}
.impact.pos { color: #059669; background: var(--green-light); }
.impact.neg { color: #dc2626; background: var(--danger-light); }
.impact.link { color: var(--primary); background: var(--primary-light); }
.impact.leg { color: var(--amber); background: var(--amber-light); }
.impact.set { color: var(--ink-dim); background: var(--surface-2); }
.link-target { color: var(--primary); font-family: var(--mono); font-size: 10px; }

/* Detail panel */
#card-detail { flex: 0 0 45%; overflow-y: auto; background: var(--surface); }
#card-detail .empty-state {
  display: flex; align-items: center; justify-content: center;
  height: 100%; color: var(--ink-faint); font-size: 13px;
  text-align: center; padding: 40px;
}
#detail-scroll { padding: 12px 14px; }
.detail-section {
  margin-bottom: 10px; background: var(--surface);
  border-radius: var(--radius); border: 1px solid var(--border);
  overflow: hidden;
}
.detail-section .section-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 8px 12px; cursor: pointer; user-select: none;
  background: var(--surface-2);
}
.detail-section .section-header:hover { background: #f1f5f9; }
.detail-section .section-header h3 {
  font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: .4px;
  color: var(--ink-dim);
}
.detail-section .section-header .arrow { color: var(--ink-faint); font-size: 11px; transition: transform .15s; }
.detail-section.collapsed .section-header .arrow { transform: rotate(-90deg); }
.detail-section .section-body { padding: 10px 12px 12px; border-top: 1px solid var(--border); }
.detail-section.collapsed .section-body { display: none; }

.field-row {
  display: flex; gap: 8px; margin-bottom: 6px; align-items: center; flex-wrap: wrap;
}
.field-row label {
  font-size: 11px; color: var(--ink-dim); min-width: 55px; font-weight: 500;
}
.field-row input, .field-row select { flex: 1; min-width: 60px; font-size: 12px; }
.field-row input.chk { flex: none; width: auto; }

.array-item {
  background: var(--surface-2); border: 1px solid var(--border);
  border-radius: var(--radius); padding: 6px 8px; margin-bottom: 4px; position: relative;
}
.array-item .del {
  position: absolute; right: 4px; top: 4px; background: none; border: none;
  color: var(--ink-faint); cursor: pointer; font-size: 14px; line-height: 1; padding: 2px 4px;
  border-radius: 3px;
}
.array-item .del:hover { color: var(--danger); background: var(--danger-light); }
.array-item .row { display: flex; gap: 4px; margin: 3px 0; align-items: center; flex-wrap: wrap; }
.array-item .row input, .array-item .row select { flex: 1; min-width: 45px; font-size: 11px; }
.array-item .row input.num { flex: 0 0 60px; }
.array-item .row label { font-size: 10px; color: var(--ink-faint); min-width: 30px; font-weight: 500; }
.add-btn { font-size: 11px; padding: 3px 10px; margin-top: 4px; }

.locale-field { display: flex; gap: 6px; flex: 1; }
.locale-field textarea { flex: 1; font-size: 12px; min-height: 55px; }
.locale-field input.locale-short { flex: 1; font-size: 12px; }

/* Graph */
#graph-view {
  flex: 1; overflow: hidden; background: var(--surface); position: relative;
}
#graph-canvas {
  width: 100%; height: 100%; cursor: grab; overflow: hidden;
}
#graph-canvas:active { cursor: grabbing; }
#graph-canvas svg { display: block; }
.graph-card { cursor: pointer; transition: opacity .15s; }
.graph-card:hover { opacity: .9; }
.graph-card rect { rx: 4; ry: 4; }
.graph-card .gid { font-family: var(--mono); font-size: 7px; fill: var(--ink-faint); }
.graph-card .glabel { font-family: var(--font); font-size: 8px; fill: var(--ink); font-weight: 600; }
.graph-card .graph-port:hover { r: 9; }
.graph-card.graph-link-target { cursor: crosshair; }
.graph-card.graph-link-source rect { stroke: var(--amber) !important; stroke-width: 2 !important; }
.graph-card .graph-port { cursor: pointer; transition: r .15s; }
.graph-card .graph-port:hover { stroke-width: 2; }
.graph-arrow { stroke-width: 1; fill: none; }
.graph-arrow.yes { stroke: #10b981; }
.graph-arrow.no { stroke: #ef4444; }
.graph-arrow.load { stroke: #3b82f6; }
.graph-alabel { font-family: var(--mono); font-size: 7px; fill: var(--ink-faint); }
.graph-toolbar {
  position: absolute; top: 8px; right: 8px; display: flex; gap: 4px; z-index: 10;
}
.graph-toolbar button {
  width: 30px; height: 30px; padding: 0; font-size: 14px; line-height: 1;
  display: flex; align-items: center; justify-content: center;
  background: var(--surface); border: 1px solid var(--border); color: var(--ink-dim);
  border-radius: var(--radius); cursor: pointer; box-shadow: var(--shadow);
}
.graph-toolbar button:hover { border-color: var(--primary); color: var(--primary); }
.graph-empty {
  display: flex; align-items: center; justify-content: center;
  height: 100%; color: var(--ink-faint); font-size: 13px;
  text-align: center; padding: 40px;
}

/* Context menu */
#graph-context-menu {
  position: fixed; z-index: 999; min-width: 170px;
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--radius); padding: 4px 0; display: none;
  box-shadow: var(--shadow-md);
}
#graph-context-menu .ctx-item {
  padding: 6px 14px; cursor: pointer; font-size: 12px;
  color: var(--ink); transition: background .1s;
}
#graph-context-menu .ctx-item:hover { background: var(--primary-light); color: var(--primary); }
#graph-context-menu .ctx-item.danger:hover { background: var(--danger-light); color: var(--danger); }
#graph-context-menu .ctx-sep {
  height: 1px; background: var(--border); margin: 4px 8px;
}

/* Link mode */
.graph-link-source { outline: 2px dashed var(--amber); outline-offset: 2px; }
.graph-link-target { cursor: crosshair !important; }
.graph-link-target:hover rect { stroke: var(--amber) !important; stroke-width: 2 !important; }
.link-mode-active .graph-toolbar button.link-toggle { background: var(--amber-light); color: var(--amber); border-color: var(--amber); }
.graph-edge { cursor: pointer; }
.graph-edge:hover path { stroke-width: 2.5 !important; }
.graph-edge .edge-hit { fill: transparent; stroke: transparent; stroke-width: 12; cursor: pointer; }

/* Highlight on outcome navigation */
.outcome-highlight { animation: outcomeFlash .8s ease 3; }
@keyframes outcomeFlash {
  0%, 100% { box-shadow: 0 0 0 transparent; }
  50% { box-shadow: 0 0 8px rgba(59,130,246,.5); }
}

/* Layout: graph primary */
#content { flex: 1; display: flex; overflow: hidden; position: relative; }
#graph-layout { flex: 1; display: flex; overflow: hidden; position: relative; }
#table-layout { flex: 1; display: flex; overflow: hidden; }
#graph-view { flex: 1; overflow: hidden; background: var(--surface); position: relative; min-width: 0; }

/* Card panel (slides in from right on graph) */
#graph-card-panel {
  width: 420px; min-width: 420px;
  background: var(--surface); border-left: 1px solid var(--border);
  display: flex; flex-direction: column; overflow: hidden;
  animation: panelSlideIn .2s ease;
}
@keyframes panelSlideIn {
  from { width: 0; min-width: 0; opacity: 0; }
  to { width: 420px; min-width: 420px; opacity: 1; }
}
#graph-panel-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 8px 12px; border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}
#graph-panel-header span { font-size: 13px; font-weight: 600; color: var(--ink); }
#graph-panel-header button { font-size: 11px; padding: 3px 10px; }

/* Source selector */
#source-select {
  background: var(--surface); border: 1px solid var(--border);
  color: var(--ink); padding: 4px 8px; border-radius: var(--radius);
  font-size: 11px; cursor: pointer;
}
#source-select:focus { outline: none; border-color: var(--primary); box-shadow: 0 0 0 3px rgba(59,130,246,.12); }

/* Reader layout */
#reader-layout { flex: 1; display: flex; overflow: hidden; }
#reader-col { flex: 1; display: flex; flex-direction: column; min-width: 0; }
#reader-toolbar {
  display: flex; align-items: center; gap: 8px;
  padding: 8px 14px; border-bottom: 1px solid var(--border);
  background: var(--surface);
}
#reader-progress { font-size: 13px; font-weight: 600; color: var(--ink); }
#reader-count { font-size: 11px; color: var(--ink-faint); font-family: var(--mono); }
.reader-actions { display: flex; gap: 4px; margin-left: auto; }
.reader-actions button { font-size: 11px; padding: 4px 12px; }
#reader-card-panel {
  display: none; width: 420px; min-width: 420px;
  background: var(--surface); border-left: 1px solid var(--border);
  flex-direction: column; overflow: hidden;
  animation: panelSlideIn .2s ease;
}
#reader-panel-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 8px 12px; border-bottom: 1px solid var(--border);
  background: var(--surface-2);
}
#reader-panel-title { font-size: 13px; font-weight: 600; color: var(--ink); }
#reader-panel-body { flex: 1; overflow-y: auto; padding: 12px 14px; }
#reader-card {
  flex: 1; overflow-y: auto; padding: 12px 32px 60px;
}
.reader-empty {
  display: flex; align-items: center; justify-content: center;
  height: 200px; color: var(--ink-faint); font-size: 14px;
}
.reader-card-actions {
  display: none; gap: 4px; margin-left: auto; flex-shrink: 0;
}
.reader-card-box:hover .reader-card-actions { display: flex; }
.reader-card-actions button {
  font-size: 10px; padding: 0 6px; height: 20px; line-height: 1;
  background: var(--surface); border: 1px solid var(--border);
  cursor: pointer; color: var(--ink-dim); border-radius: 4px;
}
.reader-card-actions button:hover { border-color: var(--primary); color: var(--primary); }
.reader-card-actions button.dng:hover { border-color: var(--danger); color: var(--danger); background: var(--danger-light); }
.reader-card-box { cursor: pointer; transition: border-color .15s; }
.reader-card-box:hover { border-color: var(--primary); }
.reader-card-box.active { border-color: var(--primary); box-shadow: 0 0 0 2px rgba(59,130,246,.2); }
.reader-insert-btn {
  display: flex; align-items: center; justify-content: center;
  height: 28px; margin: 4px 0; cursor: pointer; border: 1px dashed var(--border);
  border-radius: var(--radius); color: var(--ink-faint); font-size: 16px;
  transition: all .15s; background: transparent;
}
.reader-insert-btn:hover { border-color: var(--primary); color: var(--primary); background: var(--primary-light); }
.reader-card-box {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: var(--radius-lg); padding: 24px 28px;
  margin: 10px 0; box-shadow: var(--shadow);
  width: 100%;
}
.reader-card-box:hover { border-color: var(--primary); box-shadow: var(--shadow-md); }
.reader-card-box .rc-header {
  display: flex; gap: 10px; align-items: center; margin-bottom: 14px;
  font-size: 11px; color: var(--ink-faint);
}
.reader-card-box .rc-header .rc-id { color: var(--primary); font-size: 13px; font-weight: 600; font-family: var(--mono); }
.reader-card-box .rc-header .rc-label { color: var(--ink); font-size: 13px; font-weight: 600; }
.reader-question {
  font-size: 15px; line-height: 1.5;
  color: var(--ink); padding: 10px 0 14px; border-bottom: 1px solid var(--border);
  margin-bottom: 14px;
}
.reader-question .rc-en { font-size: 12px; color: var(--ink-faint); margin-top: 6px; }
.reader-choice {
  padding: 10px 14px; margin: 6px 0; border-radius: var(--radius);
  border-left: 3px solid var(--border); background: var(--surface-2);
}
.reader-choice.left { border-left-color: var(--primary); }
.reader-choice.right { border-left-color: var(--amber); }
.reader-choice .rc-ctitle { font-weight: 600; font-size: 13px; color: var(--ink); }
.reader-choice .rc-creaction { font-style: italic; font-size: 12px; color: var(--ink-dim); margin: 3px 0; }
.reader-choice .rc-coutcomes { font-size: 11px; margin-top: 4px; }
.reader-meta {
  display: flex; flex-wrap: wrap; gap: 6px 14px; margin-top: 14px;
  padding-top: 12px; border-top: 1px solid var(--border);
  font-size: 11px; color: var(--ink-faint);
}
.reader-meta span { background: var(--surface-2); padding: 2px 8px; border-radius: 4px; }
.reader-meta .cond { color: var(--primary); }
.reader-meta .link { color: var(--amber); }
.reader-meta .impact-pos { color: var(--green); }
.reader-meta .impact-neg { color: var(--danger); }

/* Inline editor styles */
.rc-label-input { font-size: 13px; font-weight: 600; color: var(--ink); border: 1px solid transparent; background: transparent; padding: 1px 4px; border-radius: 3px; min-width: 120px; flex: 1; }
.rc-label-input:hover { border-color: var(--border); }
.rc-label-input:focus { border-color: var(--primary); background: var(--surface); outline: none; }
.rc-meta-group { display: flex; align-items: center; gap: 3px; font-size: 10px; color: var(--ink-faint); font-family: var(--mono); }
.rc-meta-num { width: 35px; font-size: 10px; padding: 1px 3px; border: 1px solid var(--border); border-radius: 3px; background: var(--surface); text-align: center; }
.rc-editor-section { margin-bottom: 6px; }
.rc-editor-section label { display: block; font-size: 9px; font-weight: 600; text-transform: uppercase; letter-spacing: .5px; color: var(--ink-faint); margin-bottom: 2px; font-family: var(--mono); }
.rc-editor-section textarea { width: 100%; font-size: 12px; padding: 4px 6px; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface-2); resize: vertical; min-height: 32px; font-family: var(--font); }
.rc-editor-section textarea:focus { border-color: var(--primary); box-shadow: 0 0 0 2px rgba(59,130,246,.12); outline: none; background: var(--surface); }
.rc-editor-section input[type="text"], .rc-editor-section input:not([type="checkbox"]):not([type="number"]) { width: 100%; font-size: 12px; padding: 4px 6px; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface-2); }
.rc-editor-section input:focus { border-color: var(--primary); box-shadow: 0 0 0 2px rgba(59,130,246,.12); outline: none; background: var(--surface); }
.rc-editor-section select { font-size: 11px; padding: 3px 6px; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface-2); }
.rc-editor-row { display: flex; gap: 8px; margin-bottom: 6px; }
.rc-editor-col { flex: 1; }
.rc-editor-col.left { border-left: 3px solid var(--primary); padding-left: 8px; }
.rc-editor-col.right { border-left: 3px solid var(--amber); padding-left: 8px; }
.inline-array-wrap { display: flex; flex-direction: column; gap: 3px; }
.inline-array-item { display: flex; align-items: center; gap: 3px; padding: 3px 4px; background: var(--surface); border: 1px solid var(--border); border-radius: 3px; flex-wrap: wrap; }
.inline-array-item select { font-size: 10px; padding: 1px 3px; }
.inline-array-item input.inline-num { font-size: 10px; padding: 1px 3px; width: 50px; border: 1px solid var(--border); border-radius: 2px; }
.inline-array-item label { font-size: 10px; display: flex; align-items: center; gap: 2px; }
.inline-array-item label input[type="checkbox"] { width: auto; }
.inline-del { background: none; border: none; color: var(--ink-faint); cursor: pointer; font-size: 12px; padding: 0 2px; line-height: 1; }
.inline-del:hover { color: var(--danger); }
.inline-add { font-size: 10px; padding: 2px 8px; border: 1px dashed var(--border); border-radius: 3px; background: transparent; color: var(--ink-faint); cursor: pointer; }
.inline-add:hover { border-color: var(--primary); color: var(--primary); background: var(--primary-light); }

/* Toast */
.toast {
  position: fixed; bottom: 20px; right: 20px; padding: 10px 16px;
  border-radius: var(--radius); font-size: 12px; font-weight: 500;
  z-index: 999; animation: fadeInUp .25s ease; pointer-events: none;
  box-shadow: var(--shadow-md);
}
.toast.success { background: var(--green); color: #fff; }
.toast.error { background: var(--danger); color: #fff; }
.toast.info { background: var(--surface); border: 1px solid var(--border); color: var(--ink); }
@keyframes fadeInUp { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }

::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: #94a3b8; }
</style>
</head>
<body>

<div id="sidebar">
  <h1>Foundation <span>Explorer</span></h1>
  <div style="padding: 0 10px;">
    <button id="deck-create-btn" onclick="createDeckDialog()">+ New Deck</button>
  </div>
  <input id="deck-search" placeholder="Search decks…">
  <div id="deck-list"></div>
</div>

<div id="main">
  <div id="toolbar">
    <div class="title"><span id="toolbar-title">Select a deck</span><span class="sub" id="toolbar-sub"></span></div>
    <div class="actions">
      <select id="source-select" onchange="switchSource(this.value)" title="Data source">
        <option value="foundation">Foundation</option>
        <option value="reference">Reigns TK (ref)</option>
      </select>
      <button onclick="toggleReaderView()" id="btn-reader-view">Graph</button>
      <button onclick="toggleTableView()" id="btn-table-view">Table</button>
      <button onclick="validateDeck()" id="btn-validate" title="Validate current deck">Validate</button>
      <button class="primary" onclick="saveAll()" id="btn-save" disabled>Save</button>
      <button onclick="addCard()">+ Add Card</button>
    </div>
  </div>
  <div id="content">
    <div id="graph-layout">
      <div id="graph-view"></div>
      <div id="graph-card-panel" style="display:none">
        <div id="graph-panel-header">
          <span id="graph-panel-title">Card</span>
          <button onclick="closeCardPanel()">Close</button>
        </div>
        <div id="graph-panel-body"></div>
      </div>
    </div>
    <div id="table-layout" style="display:none">
      <div id="card-list">
        <input id="card-search" placeholder="Search by label, id, question, reactions, outcomes…">
        <div id="bulk-bar" class="bulk-bar">
          <span class="count" id="bulk-count">0</span>
          <button onclick="selectAllBulk()">All</button>
          <button onclick="bulkMove()">Move</button>
          <button onclick="bulkSetHidden(true)">Hide</button>
          <button onclick="bulkSetHidden(false)">Show</button>
          <button class="danger" onclick="bulkDelete()">Delete</button>
        </div>
        <div id="card-table-wrap">
          <table id="card-table">
            <thead><tr>
              <th style="width:24px"><input type="checkbox" onchange="selectAllBulk()" title="Select all"></th>
              <th onclick="sortBy('id')" data-sort="id">#</th>
              <th onclick="sortBy('label')" data-sort="label">Label</th>
              <th onclick="sortBy('weight')" data-sort="weight">W</th>
              <th onclick="sortBy('lockturn')" data-sort="lockturn">L</th>
              <th>Flags</th>
              <th>Impacts</th>
              <th>Links</th>
            </tr></thead>
            <tbody id="card-tbody"></tbody>
          </table>
        </div>
      </div>
      <div id="card-detail">
        <div class="empty-state">Select a deck on the left<br>then a card from the list</div>
      </div>
    </div>
    <div id="reader-layout" style="display:none">
      <div id="reader-col">
        <div id="reader-toolbar">
          <span id="reader-progress">—</span>
          <span id="reader-count"></span>
          <div class="reader-actions">
            <button onclick="addCardToReader()">+ Add Card</button>
          </div>
        </div>
        <div id="reader-card">
          <div class="reader-empty">Select a deck to read / edit cards</div>
        </div>
      </div>
      <div id="reader-card-panel" style="display:none">
        <div id="reader-panel-header">
          <span id="reader-panel-title">Card</span>
          <button onclick="closeReaderPanel()">Close</button>
        </div>
        <div id="reader-panel-body"></div>
      </div>
    </div>
  </div>
</div>
<div id="graph-context-menu" onclick="event.stopPropagation()">
  <div class="ctx-item" onclick="contextMenuEdit()">✏️ Éditer</div>
  <div class="ctx-item" onclick="contextMenuAddLink()">🔗 Ajouter un lien</div>
  <div class="ctx-sep"></div>
  <div class="ctx-item danger" onclick="contextMenuDelete()">🗑 Supprimer</div>
</div>
<div id="toast-container"></div>

<script>
// === State ===
let allCards = [];
let allDecks = {};
let linkAliases = {};
let selectedDeck = null;
let selectedCard = null;
let sortField = 'id';
let sortAsc = true;
let autoSaveTimer = null;
let _cardCache = {};
let _linkMode = null; // {sourceId, sourceLabel} when a source card is locked for link creation
let _pageSize = 100;
let _page = 0;

// === Modals ===
function showModal(html) {
  const existing = document.querySelector('.modal-overlay');
  if (existing) existing.remove();
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = '<div class="modal-box">' + html + '</div>';
  overlay.onclick = (e) => { if (e.target === overlay) overlay.remove(); };
  document.body.appendChild(overlay);
  return overlay.querySelector('.modal-box');
}

function createDeckDialog() {
  const box = showModal('<h2>+ Nouveau deck</h2>'
    + '<p>Cr\u00e9er un nouveau deck vide</p>'
    + '<input id="new-deck-name" placeholder="Nom du deck" autofocus>'
    + '<div class="modal-buttons">'
    + '<button onclick="this.closest(\'.modal-overlay\').remove()">Annuler</button>'
    + '<button class="primary" onclick="createDeck()">Cr\u00e9er</button></div>');
  box.querySelector('#new-deck-name').onkeydown = (e) => { if (e.key === 'Enter') createDeck(); };
}

async function createDeck() {
  const name = document.getElementById('new-deck-name')?.value?.trim();
  if (!name) { toast('Nom requis', 'error'); return; }
  const res = await fetch('/api/deck', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({name}) });
  if (!res.ok) { toast('Erreur cr\u00e9ation', 'error'); return; }
  document.querySelector('.modal-overlay')?.remove();
  toast('Deck "' + name + '" cr\u00e9\u00e9', 'success');
  // Refresh decks
  const decksRes = await fetch('/api/decks');
  allDecks = await decksRes.json();
  renderDecks(document.getElementById('deck-search').value);
}

function renameDeckDialog(oldName) {
  const box = showModal('<h2>Renommer le deck</h2>'
    + '<p>"' + oldName + '"</p>'
    + '<input id="rename-deck-name" value="' + oldName + '" autofocus>'
    + '<div class="modal-buttons">'
    + '<button onclick="this.closest(\'.modal-overlay\').remove()">Annuler</button>'
    + '<button class="primary" onclick="renameDeck(\'' + oldName + '\')">Renommer</button></div>');
  box.querySelector('#rename-deck-name').onkeydown = (e) => { if (e.key === 'Enter') renameDeck(oldName); };
}

async function renameDeck(oldName) {
  const newName = document.getElementById('rename-deck-name')?.value?.trim();
  if (!newName) { toast('Nom requis', 'error'); return; }
  const res = await fetch('/api/deck/rename', { method: 'PUT', headers: {'Content-Type':'application/json'}, body: JSON.stringify({old_name: oldName, new_name: newName}) });
  if (!res.ok) { const d = await res.json(); toast(d.error || 'Erreur', 'error'); return; }
  document.querySelector('.modal-overlay')?.remove();
  toast('Deck renomm\u00e9', 'success'); markDirty();
  if (selectedDeck === oldName) selectedDeck = newName;
  const decksRes = await fetch('/api/decks');
  allDecks = await decksRes.json();
  renderDecks(document.getElementById('deck-search').value);
  document.getElementById('toolbar-title').textContent = selectedDeck || 'S\u00e9lectionnez un deck';
}

function deleteDeckConfirm(name) {
  const box = showModal('<h2>Supprimer le deck</h2>'
    + '<p style="color:var(--danger)">⚠ Supprimer d\u00e9finitivement toutes les cartes du deck "' + name + '"</p>'
    + '<p>' + (allDecks[name]?.count || 0) + ' carte(s) seront effac\u00e9es.</p>'
    + '<div class="modal-buttons">'
    + '<button onclick="this.closest(\'.modal-overlay\').remove()">Annuler</button>'
    + '<button class="danger" onclick="deleteDeck(\'' + name + '\')">Tout supprimer</button></div>');
}

async function deleteDeck(name) {
  const res = await fetch('/api/deck/' + encodeURIComponent(name), { method: 'DELETE' });
  if (!res.ok) { toast('Erreur suppression', 'error'); return; }
  document.querySelector('.modal-overlay')?.remove();
  toast('Deck "' + name + '" supprim\u00e9', 'success'); markDirty();
  if (selectedDeck === name) { selectedDeck = null; document.getElementById('toolbar-title').textContent = 'S\u00e9lectionnez un deck'; }
  const decksRes = await fetch('/api/decks');
  allDecks = await decksRes.json();
  renderDecks(document.getElementById('deck-search').value);
  document.getElementById('graph-view').innerHTML = '<div class="graph-empty">S\u00e9lectionnez un deck</div>';
  document.getElementById('card-detail').innerHTML = '<div class="empty-state">S\u00e9lectionnez un deck</div>';
  document.getElementById('reader-card').innerHTML = '<div class="reader-empty">S\u00e9lectionnez un deck</div>';
  closeCardPanel();
}

// === Bulk operations ===
let _selectedBulk = new Set();

function toggleBulk(cardId, checked) {
  if (checked) _selectedBulk.add(cardId);
  else _selectedBulk.delete(cardId);
  updateBulkBar();
}

function selectAllBulk() {
  const cards = window._deckCards || [];
  if (_selectedBulk.size === cards.length) {
    _selectedBulk.clear();
  } else {
    cards.forEach(c => _selectedBulk.add(c.id));
  }
  updateBulkBar();
  renderTable();
}

function updateBulkBar() {
  const bar = document.getElementById('bulk-bar');
  const count = document.getElementById('bulk-count');
  if (!bar || !count) return;
  if (_selectedBulk.size > 0) {
    bar.classList.add('visible');
    count.textContent = _selectedBulk.size + ' s\u00e9lectionn\u00e9e' + (_selectedBulk.size > 1 ? 's' : '');
  } else {
    bar.classList.remove('visible');
  }
}

async function bulkDelete() {
  if (!_selectedBulk.size) return;
  if (!confirm('Supprimer ' + _selectedBulk.size + ' carte(s) ?')) return;
  for (const id of [..._selectedBulk]) {
    await fetch('/api/card/' + id, { method: 'DELETE' });
  }
  _selectedBulk.clear();
  toast('Cartes supprim\u00e9es', 'success'); markDirty();
  await refreshAfterBulk();
}

async function bulkMove() {
  if (!_selectedBulk.size) return;
  const decks = Object.keys(allDecks).filter(d => d !== '_orphaned');
  const box = showModal('<h2>D\u00e9placer vers…</h2>'
    + '<select id="bulk-target-deck" style="width:100%;margin-bottom:10px">'
    + decks.map(d => '<option value="' + d + '">' + d + ' (' + allDecks[d].count + ')</option>').join('')
    + '</select>'
    + '<div class="modal-buttons">'
    + '<button onclick="this.closest(\'.modal-overlay\').remove()">Annuler</button>'
    + '<button class="primary" onclick="executeBulkMove()">D\u00e9placer</button></div>');
}

async function executeBulkMove() {
  const targetDeck = document.getElementById('bulk-target-deck')?.value;
  if (!targetDeck) return;
  const cardIds = [..._selectedBulk];
  const res = await fetch('/api/deck/bulk', { method: 'PUT', headers: {'Content-Type':'application/json'},
    body: JSON.stringify({card_ids: cardIds, updates: {deck: targetDeck}}) });
  if (!res.ok) { toast('Erreur', 'error'); return; }
  document.querySelector('.modal-overlay')?.remove();
  _selectedBulk.clear();
  toast('Cartes d\u00e9plac\u00e9es vers "' + targetDeck + '"', 'success'); markDirty();
  await refreshAfterBulk();
}

async function bulkSetHidden(hidden) {
  const cardIds = [..._selectedBulk];
  await fetch('/api/deck/bulk', { method: 'PUT', headers: {'Content-Type':'application/json'},
    body: JSON.stringify({card_ids: cardIds, updates: {hidden}}) });
  _selectedBulk.clear();
  toast(hidden ? 'Cartes masqu\u00e9es' : 'Cartes d\u00e9masqu\u00e9es', 'success'); markDirty();
  await refreshAfterBulk();
}

async function refreshAfterBulk() {
  allCards = (await fetch('/api/cards').then(r => r.json())).cards;
  const decksRes = await fetch('/api/decks');
  allDecks = await decksRes.json();
  renderDecks(document.getElementById('deck-search').value);
  if (selectedDeck) {
    const cd = await fetch('/api/cards?deck=' + encodeURIComponent(selectedDeck));
    const d = await cd.json();
    window._deckCards = d.cards;
    renderTable();
  }
}

// === Validation ===
async function validateDeck() {
  if (!selectedDeck) { toast('S\u00e9lectionnez d\u00b4abord un deck', 'error'); return; }
  const res = await fetch('/api/validate?deck=' + encodeURIComponent(selectedDeck));
  const data = await res.json();
  let msg = data.error_count + ' erreur' + (data.error_count > 1 ? 's' : '');
  msg += ', ' + data.warning_count + ' avertissement' + (data.warning_count > 1 ? 's' : '');
  toast('Validation: ' + msg, data.error_count > 0 ? 'error' : data.warning_count > 0 ? 'info' : 'success');
  // Show detailed validation
  if (data.error_count > 0 || data.warning_count > 0) {
    _validationResults = data;
    showValidationPanel();
  }
}

let _validationResults = null;

function showValidationPanel() {
  if (!_validationResults) return;
  const data = _validationResults;
  let html = '<div class="detail-section" style="border-color:var(--danger)">' + sectionHeader('⚠ Validation')
    + '<p style="font-size:11px;margin-bottom:6px">' + data.error_count + ' erreur(s), ' + data.warning_count + ' avertissement(s)</p>';
  for (const err of (data.errors || [])) {
    html += '<div class="array-item" style="border-color:var(--danger)">'
      + '<div style="font-size:10px;color:var(--danger)">#' + err.card + ' — ' + err.field + '</div>'
      + '<div style="font-size:10px;color:var(--ink-dim)">' + escHtml(err.msg) + '</div></div>';
  }
  for (const warn of (data.warnings || [])) {
    html += '<div class="array-item" style="border-color:var(--amber)">'
      + '<div style="font-size:10px;color:var(--amber)">#' + warn.card + ' — ' + warn.field + '</div>'
      + '<div style="font-size:10px;color:var(--ink-dim)">' + escHtml(warn.msg) + '</div></div>';
  }
  html += '</div></div>';
  
  // Append to card detail
  const detail = document.getElementById('card-detail');
  if (detail && detail.querySelector('#detail-scroll')) {
    detail.querySelector('#detail-scroll').insertAdjacentHTML('afterbegin', html);
  }
}

// === Init ===
async function init() {
  const [cardsData, decksData, aliasesData, refDecksData] = await Promise.all([
    fetch('/api/cards').then(r => r.json()),
    fetch('/api/decks').then(r => r.json()),
    fetch('/api/aliases').then(r => r.json()),
    fetch('/api/reference/decks').then(r => r.json()),
  ]);
  allCards = cardsData.cards;
  allDecks = decksData;
  linkAliases = aliasesData;
  window._refDecks = refDecksData;
  renderDecks();
  // Reader is the default view
  _readerView = true;
  document.getElementById('reader-layout').style.display = 'flex';
  document.getElementById('graph-layout').style.display = 'none';
  document.getElementById('table-layout').style.display = 'none';
  document.getElementById('btn-reader-view').textContent = '🕸️ Graphe';
}

function toast(msg, type) {
  const el = document.createElement('div');
  el.className = 'toast ' + (type || 'info');
  el.textContent = msg;
  document.getElementById('toast-container').appendChild(el);
  setTimeout(() => el.remove(), 2200);
}

let _dirty = false;
function markDirty() { _dirty = true; document.getElementById('btn-save').disabled = false; document.getElementById('btn-save').textContent = '💾 Sauvegarder*'; }
function markClean() { _dirty = false; document.getElementById('btn-save').disabled = true; document.getElementById('btn-save').textContent = '💾 Sauvegarder'; }

// === Deck List ===
function renderDecks(filter) {
  const names = Object.keys(allDecks).sort((a,b) => {
    const ap = a.startsWith('crisis_') ? 1 : a.startsWith('planet_') ? 2 : 0;
    const bp = b.startsWith('crisis_') ? 1 : b.startsWith('planet_') ? 2 : 0;
    return ap !== bp ? ap - bp : a.localeCompare(b);
  });
  let html = '', last = '';
  for (const name of names) {
    if (filter && !name.includes(filter.toLowerCase())) continue;
    if (name === '_orphaned') continue;
    const d = allDecks[name];
    const p = name.startsWith('crisis_') ? '\u2694 Crise' : name.startsWith('planet_') ? '\uD83C\uDF10 Plan\u00e8te' : '\uD83D\uDCE6 Deck';
    if (p !== last) { html += '<div class="deck-type-label">' + p + '</div>'; last = p; }
    const w = [];
    if (d.hidden > 0) w.push('<span class="badge h">' + d.hidden + 'H</span>');
    if (d.neg_weight > 0) w.push('<span class="badge w">' + d.neg_weight + 'W-</span>');
    
    // Skeleton progress bar
    let skHtml = '';
    if (d.skeleton_total > 0) {
      const pct = d.skeleton_pct || 0;
      const cls = pct >= 100 ? 'good' : pct >= 50 ? 'ok' : 'low';
      const label = Math.round(d.skeleton_filled) + '/' + d.skeleton_total;
      skHtml = '<div class="deck-sk-progress" title="Squelette: ' + label + '"><div class="fill ' + cls + '" style="width:' + Math.min(pct,100) + '%"></div></div>'
        + '<div class="deck-meta">' + label + ' skel</div>';
    } else if (d.source_deck) {
      skHtml = '<div class="deck-meta">' + d.source_deck + '</div>';
    }
    
    html += '<div class="deck-item' + (name === selectedDeck ? ' active' : '') + '" onclick="selectDeck(\'' + name + '\')">'
      + '<div class="deck-info"><span>' + name + '</span>' + skHtml + '</div>'
      + '<span>' + w.join(' ') + ' <span class="badge">' + d.count + '</span></span>'
      + '<div class="deck-actions" onclick="event.stopPropagation()">'
      + '<button title="Renommer" onclick="renameDeckDialog(\'' + name + '\')">\u270F</button>'
      + '<button title="Supprimer" id="deck-delete-btn" onclick="deleteDeckConfirm(\'' + name + '\')">\u2715</button>'
      + '</div></div>';
  }
  document.getElementById('deck-list').innerHTML = html;
}
document.getElementById('deck-search').addEventListener('input', e => renderDecks(e.target.value));

// === Deck Selection ===
async function selectDeck(name) {
  selectedDeck = name; selectedCard = null; _selectedBulk.clear(); updateBulkBar();
  renderDecks(document.getElementById('deck-search').value);
  document.getElementById('toolbar-title').textContent = name;
  document.getElementById('toolbar-sub').textContent = allDecks[name].count + ' cartes';
  const cardsData = await fetchCardsForDeck(name);
  window._deckCards = cardsData;
  renderTable(cardsData);
  document.getElementById('card-detail').innerHTML = '<div class="empty-state">S\u00e9lectionnez une carte</div>';
  // Default to reader view (graph if table was active)
  if (_tableView) {
    document.getElementById('graph-layout').style.display = 'none';
    document.getElementById('table-layout').style.display = 'flex';
    document.getElementById('reader-layout').style.display = 'none';
  } else {
    document.getElementById('graph-layout').style.display = 'none';
    document.getElementById('table-layout').style.display = 'none';
    document.getElementById('reader-layout').style.display = 'flex';
    closeCardPanel();
    closeReaderPanel();
    _readerView = true;
    document.getElementById('btn-reader-view').textContent = '🕸️ Graphe';
    loadReaderCards();
  }
}

// === Table ===
function renderTable(cards) {
  cards = cards || window._deckCards || [];
  const q = (document.getElementById('card-search').value || '').toLowerCase();
  if (q) {
    cards = cards.filter(c => {
      const searchStr = ((c.label||'') + ' ' + c.id + ' ' 
        + (c.question?.FR||'') + ' ' + (c.question?.EN||'')
        + ' ' + (c.leftAnswer?.title?.FR||'') + ' ' + (c.rightAnswer?.title?.FR||'')
        + ' ' + (c.leftAnswer?.reaction?.FR||'') + ' ' + (c.rightAnswer?.reaction?.FR||'')
        + ' ' + (c.bearer||'')
        + ' ' + (c.yesOutcome||[]).map(o=>o.variable||'').join(' ')
        + ' ' + (c.noOutcome||[]).map(o=>o.variable||'').join(' ')
        + ' ' + (c.conditions||[]).map(o=>(o.variable||'')+(o.value||'')).join(' ')
      ).toLowerCase();
      return searchStr.includes(q);
    });
    _page = 0;
  }
  cards.sort((a,b) => {
    const va = a[sortField] || 0, vb = b[sortField] || 0;
    return sortAsc ? (va > vb ? 1 : -1) : (va < vb ? 1 : -1);
  });
  const total = cards.length;
  const pages = Math.ceil(total / _pageSize);
  if (_page >= pages) _page = Math.max(0, pages - 1);
  const start = _page * _pageSize;
  const pageCards = cards.slice(start, start + _pageSize);
  let html = '';
  for (const c of pageCards) {
    const flags = [];
    if (c.hidden) flags.push('<span class="flag h">H</span>');
    if ((c.weight||1) < 0) flags.push('<span class="flag w">W-</span>');
    if (c.lockturn) flags.push('<span class="flag l">L' + c.lockturn + '</span>');
    if (c.key) flags.push('<span class="flag k">Cl\u00e9</span>');
    if (c.bearer) flags.push('<span class="flag b">' + c.bearer + '</span>');
    const checked = _selectedBulk.has(c.id) ? 'checked' : '';
    html += '<tr class="' + (selectedCard === c.id ? 'active' : '') + '" onclick="selectCard(' + c.id + ')">'
      + '<td style="width:24px" onclick="event.stopPropagation()"><input type="checkbox" ' + checked + ' onchange="toggleBulk(' + c.id + ',this.checked)"></td>'
      + '<td class="cid">#' + c.id + '</td>'
      + '<td class="clabel">' + escHtml(c.label || '') + '</td>'
      + '<td class="cnum">' + (c.weight || 1) + '</td>'
      + '<td class="cnum">' + (c.lockturn || 0) + '</td>'
      + '<td class="cflags">' + flags.join('') + '</td>'
      + '<td>' + renderImpacts(c) + '</td>'
      + '<td>' + renderLinks(c) + '</td></tr>';
  }
  // Pagination controls
  let pagHtml = '';
  if (pages > 1) {
    pagHtml = '<div style="display:flex;align-items:center;justify-content:center;gap:6px;padding:6px 8px;font-size:10px;font-family:var(--mono);color:var(--ink-dim);border-top:1px solid var(--border)">'
      + '<button class="small" onclick="changePage(0)" ' + (_page === 0 ? 'disabled' : '') + '>«</button>'
      + '<button class="small" onclick="changePage(' + (_page-1) + ')" ' + (_page === 0 ? 'disabled' : '') + '>‹</button>'
      + '<span>' + (_page+1) + '/' + pages + ' (' + total + ' cartes)</span>'
      + '<button class="small" onclick="changePage(' + (_page+1) + ')" ' + (_page >= pages-1 ? 'disabled' : '') + '>›</button>'
      + '<button class="small" onclick="changePage(' + (pages-1) + ')" ' + (_page >= pages-1 ? 'disabled' : '') + '>»</button>'
      + '<select onchange="changePageSize(parseInt(this.value))" style="font-size:10px;margin-left:6px">'
      + [50, 100, 200, 500].map(s => '<option value="' + s + '"' + (_pageSize===s?' selected':'') + '>' + s + '/page</option>').join('')
      + '</select></div>';
  }
  document.getElementById('card-tbody').innerHTML = html;
  // Add pagination after table wrap
  let pagEl = document.getElementById('card-table-pagination');
  if (!pagEl) {
    pagEl = document.createElement('div');
    pagEl.id = 'card-table-pagination';
    document.getElementById('card-table-wrap').appendChild(pagEl);
  }
  pagEl.innerHTML = pagHtml;
}

function changePage(p) {
  _page = Math.max(0, p);
  renderTable();
}

function changePageSize(s) {
  _pageSize = s;
  _page = 0;
  renderTable();
}

function renderImpacts(c) {
  const parts = [];
  const seen = {};
  for (const key of ['yesOutcome','noOutcome','loadOutcome']) {
    for (const o of (c[key] || [])) {
      const v = o.variable || '';
      const sv = o.stringValue || '';
      if (v === 'link' || sv.startsWith('_')) continue;
      const val = o.intValue || 0;
      const isAdd = o.addOperation !== false;
      const tag = v === 'legitimacy' ? 'leg' : v === 'military' || v === 'religion' || v === 'commerce' || v === 'politics' ? v : '';
      const cls = tag || (isAdd ? '' : 'set');
      const sign = val > 0 ? '+' : '';
      const op = isAdd ? sign + val : '=' + val;
      if (tag && !seen[v]) { seen[v] = true; parts.push('<span class="impact ' + (val > 0 ? 'pos' : 'neg') + '">' + op + ' ' + v + '</span>'); }
    }
  }
  return parts.join('') || '<span style="color:var(--ink-faint);font-size:9px">—</span>';
}

function renderLinks(c) {
  const parts = [];
  for (const key of ['yesOutcome','noOutcome','loadOutcome']) {
    for (const o of (c[key] || [])) {
      let target = null;
      if (o.variable === 'link') target = o.intValue;
      const sv = o.stringValue || '';
      if (sv.startsWith('_') && linkAliases[sv] && linkAliases[sv].node) target = linkAliases[sv].node;
      if (target) {
        const deck = allCards.find(x => x.id === target);
        parts.push('<span class="link-target" onclick="event.stopPropagation();selectCard(' + target + ')">#' + target + (deck ? ' ' + (deck.label||'') : '') + '</span> ');
      }
    }
  }
  return parts.length ? parts.join('') : '<span style="color:var(--ink-faint);font-size:9px">—</span>';
}

document.getElementById('card-search').addEventListener('input', () => renderTable());

function sortBy(field) {
  if (sortField === field) sortAsc = !sortAsc;
  else { sortField = field; sortAsc = true; }
  renderTable();
}

function getCard(id) {
  if (_cardCache[id]) return _cardCache[id];
  const c = allCards.find(x => x.id === id);
  if (c) _cardCache[id] = c;
  return c;
}

// === Card Selection ===
async function selectCard(id) {
  selectedCard = id;
  document.querySelectorAll('#card-table tr').forEach(el => el.classList.remove('active'));
  const el = document.querySelector('#card-table tr[data-id="' + id + '"]');
  const res = await fetch('/api/card/' + id);
  const card = await res.json();
  renderCardDetail(card);
  renderTable();
}

// === Collapsible Sections ===
function toggleSection(el) {
  const section = el.closest('.detail-section');
  section.classList.toggle('collapsed');
}

function sectionHeader(title, collapsed) {
  return '<div class="section-header" onclick="toggleSection(this)">'
    + '<h3>' + title + '</h3><span class="arrow">\u25BC</span></div>'
    + '<div class="section-body">';
}

// === Card Detail ===
function renderCardDetail(card) {
  const c = document.getElementById('card-detail');
  c.innerHTML = '<div id="detail-scroll">'
    + '<div class="detail-section" style="border-color:var(--primary)">' + sectionHeader('\U0001F464 Identit\u00e9') 
    + '<div class="field-row"><label>ID</label><input type="number" value="' + card.id + '" onchange="updateCardField(' + card.id + ',\'id\',parseInt(this.value)||0)" style="flex:0 0 70px">'
    + '<label>Label</label><input value="' + escHtml(card.label||'') + '" onchange="updateCardField(' + card.id + ',\'label\',this.value)"></div>'
    + '<div class="field-row"><label>Deck</label><input value="' + escHtml(card.deck||'') + '" onchange="updateCardField(' + card.id + ',\'deck\',this.value)" list="dl" style="flex:1">'
    + '<datalist id="dl">' + Object.keys(allDecks).map(d => '<option value="' + d + '">').join('') + '</datalist>'
    + '<label>Weight</label><input type="number" value="' + (card.weight||1) + '" onchange="updateCardField(' + card.id + ',\'weight\',parseInt(this.value)||0)" style="flex:0 0 60px"></div>'
    + '<div class="field-row"><label>Lockturn</label><input type="number" value="' + (card.lockturn||0) + '" onchange="updateCardField(' + card.id + ',\'lockturn\',parseInt(this.value)||0)" style="flex:0 0 60px">'
    + '<label class="chk"><input type="checkbox" ' + (card.hidden?'checked':'') + ' onchange="updateCardField(' + card.id + ',\'hidden\',this.checked)"> Cach\u00e9e</label>'
    + '<label class="chk"><input type="checkbox" ' + (card.key?'checked':'') + ' onchange="updateCardField(' + card.id + ',\'key\',this.checked)"> Cl\u00e9</label></div>'
    + '<div class="field-row"><label>Bearer</label><input value="' + escHtml(card.bearer||'') + '" onchange="updateCardField(' + card.id + ',\'bearer\',this.value||null)" placeholder="role:&lt;id&gt;"></div>'
    + '</div></div>'

    + '<div class="detail-section">' + sectionHeader('\U0001F4AC Question')
    + renderLocaleField(card.id, 'question', card)
    + '</div></div>'

    + '<div class="detail-section">' + sectionHeader('\u2B05 R\u00e9ponse Gauche')
    + '<div class="field-row"><label>Titre</label>' + renderLocaleField(card.id, 'leftAnswer', card, 'title') + '</div>'
    + '<div class="field-row"><label>R\u00e9action</label>' + renderLocaleField(card.id, 'leftAnswer', card, 'reaction') + '</div>'
    + '</div></div>'

    + '<div class="detail-section">' + sectionHeader('\u27A1 R\u00e9ponse Droite')
    + '<div class="field-row"><label>Titre</label>' + renderLocaleField(card.id, 'rightAnswer', card, 'title') + '</div>'
    + '<div class="field-row"><label>R\u00e9action</label>' + renderLocaleField(card.id, 'rightAnswer', card, 'reaction') + '</div>'
    + '</div></div>'

    + '<div class="detail-section">' + sectionHeader('\U0001F4CB Conditions')
    + '<div id="conditions-container"></div><button class="add-btn" onclick="addArrayItem(' + card.id + ',\'conditions\',{})">+ Condition</button>'
    + '</div></div>'

    + '<div class="detail-section">' + sectionHeader('\U0001F4E5 Load Outcomes')
    + '<div id="loadOutcome-container"></div><button class="add-btn" onclick="addArrayItem(' + card.id + ',\'loadOutcome\',{})">+ Outcome</button>'
    + '</div></div>'

    + '<div class="detail-section">' + sectionHeader('\u2705 Yes Outcomes')
    + '<div id="yesOutcome-container"></div><button class="add-btn" onclick="addArrayItem(' + card.id + ',\'yesOutcome\',{})">+ Outcome</button>'
    + '</div></div>'

    + '<div class="detail-section">' + sectionHeader('\u274C No Outcomes')
    + '<div id="noOutcome-container"></div><button class="add-btn" onclick="addArrayItem(' + card.id + ',\'noOutcome\',{})">+ Outcome</button>'
    + '</div></div>'

    + '<div class="detail-section">' + sectionHeader('\U0001F60A Moods')
    + '<div class="field-row"><label>D\u00e9faut</label><select onchange="updateMoodField(' + card.id + ',\'default\',this.value)">' + moodOptions(card.moods?.default||'neutral') + '</select>'
    + '<label>Oui</label><select onchange="updateMoodField(' + card.id + ',\'yes\',this.value)">' + moodOptions(card.moods?.yes||'neutral') + '</select>'
    + '<label>Non</label><select onchange="updateMoodField(' + card.id + ',\'no\',this.value)">' + moodOptions(card.moods?.no||'neutral') + '</select></div>'
    + '</div></div>'

    + '<div class="detail-section" style="margin-top:8px">' + sectionHeader('\U0001F50D JSON brut')
    + '<pre style="font-family:var(--mono);font-size:10px;color:var(--ink-dim);white-space:pre-wrap;margin:0;max-height:150px;overflow:auto">' + escHtml(JSON.stringify(card, null, 2)) + '</pre>'
    + '</div></div>'

    + '<div class="detail-section" style="border-color:var(--primary)">' + sectionHeader('\U0001F9EA Simulation')
    + '<div style="font-size:10px;color:var(--ink-dim);margin-bottom:6px">Testez les conditions et outcomes de cette carte</div>'
    + '<div id="sim-ctx-' + card.id + '" class="sim-context" style="display:flex;flex-wrap:wrap;gap:3px;margin-bottom:4px"></div>'
    + '<button class="add-btn" onclick="runSimulation(' + card.id + ')">▶ Tester</button>'
    + '<div id="sim-results-' + card.id + '" style="margin-top:4px"></div>'
    + '</div></div>'

    + '<div class="detail-section" style="border-color:var(--danger)">' + sectionHeader('\U0001F5D1 Zone dangereuse')
    + '<button class="danger" onclick="deleteCard(' + card.id + ')">Supprimer cette carte</button>'
    + '</div></div>'

    + '</div>';
  renderArrayItems(card, 'conditions');
  renderArrayItems(card, 'loadOutcome');
  renderArrayItems(card, 'yesOutcome');
  renderArrayItems(card, 'noOutcome');
  renderSimContext(card.id);
}

function escHtml(s) { if (s == null) return ''; return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

// === Simulation ===
const SIM_DEFAULTS = { military:50, religion:50, commerce:50, politics:50, legitimacy:50, turns:1, year:1, age:35, mood:0 };

function renderSimContext(cardId) {
  const cont = document.getElementById('sim-ctx-' + cardId);
  if (!cont) return;
  // Collect all variables mentioned in card conditions + outcomes
  const card = getCard(cardId);
  if (!card) return;
  const vars = new Set(Object.keys(SIM_DEFAULTS));
  for (const c of (card.conditions||[])) { if (c.variable) vars.add(c.variable); }
  for (const key of ['yesOutcome','noOutcome','loadOutcome']) {
    for (const o of (card[key]||[])) { if (o.variable && o.variable !== 'link') vars.add(o.variable); }
  }
  let html = '';
  for (const v of [...vars].sort()) {
    const val = SIM_DEFAULTS[v] !== undefined ? SIM_DEFAULTS[v] : 0;
    html += '<div style="display:flex;align-items:center;gap:4px;font-size:9px;font-family:var(--mono)">'
      + '<label style="min-width:50px;color:var(--ink-faint)">' + v + '</label>'
      + '<input type="range" min="0" max="100" value="' + val + '" style="width:50px" id="sim-slider-' + cardId + '-' + v + '" oninput="document.getElementById(\'sim-val-' + cardId + '-' + v + '\').textContent=this.value">'
      + '<span id="sim-val-' + cardId + '-' + v + '" style="min-width:20px;color:var(--ink)">' + val + '</span></div>';
  }
  cont.innerHTML = html;
}

async function runSimulation(cardId) {
  const card = getCard(cardId);
  if (!card) return;
  const ctx = {};
  const vars = ['military','religion','commerce','politics','legitimacy','turns','year','age','mood'];
  for (const v of vars) {
    const slider = document.getElementById('sim-slider-' + cardId + '-' + v);
    if (slider) ctx[v] = parseInt(slider.value) || 0;
  }
  // Add extra vars from conditions
  for (const c of (card.conditions||[])) {
    if (c.variable && ctx[c.variable] === undefined) ctx[c.variable] = 0;
  }
  const res = await fetch('/api/simulate?card=' + cardId + '&context=' + encodeURIComponent(JSON.stringify(ctx)));
  const data = await res.json();
  if (data.error) { toast(data.error, 'error'); return; }
  
  // Build results HTML
  const cont = document.getElementById('sim-results-' + cardId);
  if (!cont) return;
  let html = '';
  
  // Conditions
  if (data.conditions?.length) {
    html += '<div style="font-size:9px;font-family:var(--mono);margin-top:4px"><b>Conditions:</b></div>';
    for (const c of data.conditions) {
      const cls = c.met ? 'color:var(--green)' : 'color:var(--danger)';
      html += '<div style="font-size:9px;font-family:var(--mono);' + cls + '">'
        + (c.met ? '✓ ' : '✗ ') + c.variable + ' ' + c.op + ' ' + c.value + ' (actuel: ' + c.current + ')</div>';
    }
  }
  
  function renderDelta(delta, label) {
    if (!Object.keys(delta).length) return '';
    let d = '<div style="font-size:9px;font-family:var(--mono);margin-top:4px"><b>' + label + ':</b></div>';
    for (const [v, val] of Object.entries(delta)) {
      if (val === 0) continue;
      const cls = val > 0 ? 'color:var(--green)' : 'color:var(--danger)';
      const sign = val > 0 ? '+' : '';
      d += '<span style="font-size:9px;font-family:var(--mono);' + cls + ';margin-right:4px">' + v + ' ' + sign + val + '</span>';
    }
    return d;
  }
  
  html += renderDelta(data.load_delta, 'Load');
  html += renderDelta(data.yes_delta, 'Oui (◀)');
  html += renderDelta(data.no_delta, 'Non (▶)');
  
  if (!html) html = '<div style="font-size:10px;color:var(--ink-faint)">Aucun changement</div>';
  cont.innerHTML = html;
}

function renderLocaleField(cardId, field, card, sub) {
  let obj = card;
  if (sub) { obj = card[field] || {}; field = sub; }
  const val = obj[field] || {};
  const fr = escHtml(val.FR||'');
  const en = escHtml(val.EN||'');
  if (field === 'question' || field === 'reaction') {
    return '<div class="locale-field">'
      + '<textarea placeholder="FR" rows="2" onchange="updateLocaleField(' + cardId + ',\'' + field + '\',\'' + (sub||'') + '\',\'FR\',this.value)">' + fr + '</textarea>'
      + '<textarea placeholder="EN" rows="2" onchange="updateLocaleField(' + cardId + ',\'' + field + '\',\'' + (sub||'') + '\',\'EN\',this.value)">' + en + '</textarea></div>';
  }
  return '<div class="locale-field">'
    + '<input class="locale-short" placeholder="FR" value="' + fr + '" onchange="updateLocaleField(' + cardId + ',\'' + field + '\',\'' + (sub||'') + '\',\'FR\',this.value)">'
    + '<input class="locale-short" placeholder="EN" value="' + en + '" onchange="updateLocaleField(' + cardId + ',\'' + field + '\',\'' + (sub||'') + '\',\'EN\',this.value)"></div>';
}

function moodOptions(c) {
  const moods = ['neutral','suspicious','afraid','angry','flattered','curious','sad','desperate'];
  return moods.map(m => '<option value="' + m + '"' + (m===c?'selected':'') + '>' + m + '</option>').join('');
}

// === Array Items ===
function renderArrayItems(card, key) {
  const cont = document.getElementById(key + '-container');
  if (!cont) return;
  const items = card[key] || [];
  cont.innerHTML = items.map((item,i) => renderArrayItem(card.id, key, item, i)).join('');
}

function renderArrayItem(cardId, key, item, idx) {
  if (key === 'conditions') {
    const v = item.value; const vStr = v != null ? String(v) : '';
    return '<div class="array-item"><button class="del" onclick="removeArrayItem(' + cardId + ',\'' + key + '\',' + idx + ')">\u2715</button>'
      + '<div class="row"><label>Var</label><input value="' + escHtml(item.variable||'') + '" onchange="updateArrayItemField(' + cardId + ',\'' + key + '\',' + idx + ',\'variable\',this.value)">'
      + '<label>Op</label><select onchange="updateArrayItemField(' + cardId + ',\'' + key + '\',' + idx + ',\'op\',this.value)">'
      + ['equal','above','below','not'].map(o => '<option value="' + o + '"' + (item.op===o?'selected':'') + '>' + o + '</option>').join('')
      + '</select><label>Val</label><input class="num" value="' + escHtml(vStr) + '" onchange="updateArrayItemField(' + cardId + ',\'' + key + '\',' + idx + ',\'value\',this.value)"></div></div>';
  }
  if (key.endsWith('Outcome') || key === 'loadOutcome') {
    return '<div class="array-item"><button class="del" onclick="removeArrayItem(' + cardId + ',\'' + key + '\',' + idx + ')">\u2715</button>'
      + '<div class="row"><label>Var</label><input value="' + escHtml(item.variable||'') + '" onchange="updateArrayItemField(' + cardId + ',\'' + key + '\',' + idx + ',\'variable\',this.value)" list="vl">'
      + '<datalist id="vl">' + ['military','religion','commerce','politics','legitimacy','link','turns','year','mood','location','age'].map(v => '<option value="' + v + '">').join('') + '</datalist>'
      + '<label class="chk"><input type="checkbox" ' + (item.addOperation!==false?'checked':'') + ' onchange="updateArrayItemField(' + cardId + ',\'' + key + '\',' + idx + ',\'addOperation\',this.checked)"> Add</label>'
      + '<input class="num" type="number" value="' + (item.intValue||0) + '" onchange="updateArrayItemField(' + cardId + ',\'' + key + '\',' + idx + ',\'intValue\',parseInt(this.value)||0)">'
      + '<label class="chk"><input type="checkbox" ' + (item.toKeep?'checked':'') + ' onchange="updateArrayItemField(' + cardId + ',\'' + key + '\',' + idx + ',\'toKeep\',this.checked)"> Keep</label></div>'
      + '<div class="row"><label>stringValue</label><input value="' + escHtml(item.stringValue||'') + '" onchange="updateArrayItemField(' + cardId + ',\'' + key + '\',' + idx + ',\'stringValue\',this.value||\'\')" placeholder="Alias ou lien"></div></div>';
  }
  return '';
}

// === Updates ===
async function updateCardField(id, field, value) {
  const card = getCard(id); if (!card) return;
  card[field] = value; _cardCache[id] = card; scheduleAutoSave(id);
}
async function updateLocaleField(cardId, field, sub, locale, value) {
  const card = getCard(cardId); if (!card) return;
  let obj = card;
  if (sub) { if (!obj[field]) obj[field] = {}; obj = obj[field]; field = sub; }
  if (!obj[field]) obj[field] = {};
  obj[field][locale] = value; scheduleAutoSave(cardId);
}
async function updateMoodField(cardId, key, value) {
  const card = getCard(cardId); if (!card) return;
  if (!card.moods) card.moods = {};
  card.moods[key] = value; scheduleAutoSave(cardId);
}
async function updateArrayItemField(cardId, key, idx, field, value) {
  const card = getCard(cardId); if (!card) return;
  if (!card[key]) card[key] = []; if (!card[key][idx]) card[key][idx] = {};
  card[key][idx][field] = value; scheduleAutoSave(cardId);
}
async function addArrayItem(cardId, key) {
  const card = getCard(cardId); if (!card) return;
  if (!card[key]) card[key] = [];
  card[key].push({}); scheduleAutoSave(cardId); renderCardDetail(card);
}
async function removeArrayItem(cardId, key, idx) {
  const card = getCard(cardId); if (!card) return;
  card[key].splice(idx, 1); scheduleAutoSave(cardId); renderCardDetail(card);
}
async function deleteCard(id) {
  if (!confirm('Supprimer la carte #' + id + ' ?')) return;
  const res = await fetch('/api/card/' + id, { method: 'DELETE' });
  if (res.ok) {
    allCards = allCards.filter(c => c.id !== id);
    delete _cardCache[id];
    toast('Carte supprim\u00e9e', 'success'); markDirty(); selectedCard = null;
    if (selectedDeck) { const r = await fetch('/api/cards?deck=' + encodeURIComponent(selectedDeck)); const d = await r.json(); window._deckCards = d.cards; renderTable(); }
    document.getElementById('card-detail').innerHTML = '<div class="empty-state">Carte supprim\u00e9e</div>';
  }
}
async function addCard() {
  if (!selectedDeck) { toast('S\u00e9lectionnez d\u00b4abord un deck', 'error'); return; }
  const tpl = { id: 0, label: 'nouvelle_carte', deck: selectedDeck, weight: 1, lockturn: 0, hidden: false,
    question: { FR: '?' }, conditions: [], loadOutcome: [],
    leftAnswer: { title: { FR: 'Gauche' }, reaction: { FR: '' } },
    rightAnswer: { title: { FR: 'Droite' }, reaction: { FR: '' } },
    yesOutcome: [], noOutcome: [], moods: { default: 'neutral', yes: 'neutral', no: 'neutral' } };
  const res = await fetch('/api/card', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(tpl) });
  const data = await res.json();
  allCards.push({...tpl, id: data.id}); markDirty();
  toast('Carte #' + data.id + ' cr\u00e9\u00e9e', 'success');
  if (selectedDeck) { const r = await fetch('/api/cards?deck=' + encodeURIComponent(selectedDeck)); const d = await r.json(); window._deckCards = d.cards; renderTable(); }
  selectCard(data.id);
}
function scheduleAutoSave(cardId) {
  markDirty();
  if (autoSaveTimer) clearTimeout(autoSaveTimer);
  autoSaveTimer = setTimeout(() => {
    const card = getCard(cardId); if (!card) return;
    fetch('/api/card/' + cardId, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(card) })
      .then(r => { if (!r.ok) throw new Error('HTTP ' + r.status); })
      .catch(e => { toast('⚠ Erreur auto-save #' + cardId + ': ' + e.message, 'error'); });
    autoSaveTimer = null;
  }, 500);
}
async function saveAll() {
  let ok = 0, fail = 0;
  for (const card of allCards) {
    try {
      const r = await fetch('/api/card/' + card.id, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(card) });
      if (r.ok) ok++; else fail++;
    } catch (e) { fail++; }
  }
  if (fail > 0) { toast(fail + ' carte(s) en échec', 'error'); return; }
  await fetch('/api/save', { method: 'POST' }); markClean(); toast('Sauvegard\u00e9e ✅ (' + ok + ' cartes)', 'success');
}

// === Reader/Editor view ===
let _readerCards = [];
let _readerView = false;

function toggleReaderView() {
  _readerView = !_readerView;
  hideAllContentViews();
  if (_readerView) {
    document.getElementById('reader-layout').style.display = 'flex';
    document.getElementById('btn-reader-view').textContent = '🕸️ Graphe';
    if (selectedDeck) loadReaderCards();
  } else {
    document.getElementById('graph-layout').style.display = 'flex';
    document.getElementById('btn-reader-view').textContent = '📖 Lecteur';
    if (selectedDeck) renderGraph();
  }
}

function hideAllContentViews() {
  document.getElementById('graph-layout').style.display = 'none';
  document.getElementById('table-layout').style.display = 'none';
  document.getElementById('reader-layout').style.display = 'none';
}

async function loadReaderCards() {
  const deck = selectedDeck;
  if (!deck) { document.getElementById('reader-card').innerHTML = '<div class="reader-empty">Sélectionnez un deck</div>'; return; }
  const cards = await fetchCardsForDeck(deck);
  if (currentSource === 'reference') {
    cards.sort((a, b) => (a._refNodeIndex||0) - (b._refNodeIndex||0));
  } else {
    cards.sort((a, b) => a.id - b.id);
  }
  _readerCards = cards;
  const total = cards.length;
  document.getElementById('reader-progress').textContent = deckLabel(selectedDeck);
  document.getElementById('reader-count').textContent = total + ' cartes';
  let html = '';
  for (const card of cards) {
    html += buildReaderCardHTML(card);
    html += '<div class="reader-insert-btn" onclick="addCardAfter(' + card.id + ')" title="Insérer après #' + card.id + '">+</div>';
  }
  document.getElementById('reader-card').innerHTML = html;
}

function deckLabel(name) {
  return name || '?';
}

// === Inline Card Editor ===
let _editTimers = {};

function inlineEditValue(cardId, path, value) {
  if (currentSource === 'reference') return;
  clearTimeout(_editTimers[cardId + '.' + path]);
  _editTimers[cardId + '.' + path] = setTimeout(() => {
    saveCardField(cardId, path, value);
  }, 400);
}

async function saveCardField(cardId, path, value) {
  try {
    const res = await fetch('/api/card/' + cardId, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ field: path, value: value })
    });
    if (!res.ok) throw new Error('Save failed');
    // Update local cache
    const card = _cardCache[cardId] || allCards.find(c => c.id === cardId);
    if (card) {
      const parts = path.split('.');
      let obj = card;
      for (let i = 0; i < parts.length - 1; i++) {
        if (!obj[parts[i]]) obj[parts[i]] = {};
        obj = obj[parts[i]];
      }
      obj[parts[parts.length - 1]] = value;
      _cardCache[cardId] = card;
    }
    markDirty();
  } catch (e) {
    toast('Erreur sauvegarde #' + cardId + ' ' + path, 'error');
  }
}

// Inline outcomes array editor
function inlineRenderOutcomes(cardId, outcomes, outKey) {
  const items = (outcomes || []).map((o, i) => {
    const isLink = o.variable === 'link';
    return '<div class="inline-array-item">'
      + '<select data-idx="' + i + '" data-parent="' + cardId + '-' + outKey + '" data-field="variable" onchange="inlineOutcomeChange(this)">'
      + '<option value="link"' + (isLink?' selected':'') + '>🔗 link</option>'
      + '<option value="military"' + (o.variable==='military'?' selected':'') + '>military</option>'
      + '<option value="religion"' + (o.variable==='religion'?' selected':'') + '>religion</option>'
      + '<option value="commerce"' + (o.variable==='commerce'?' selected':'') + '>commerce</option>'
      + '<option value="politics"' + (o.variable==='politics'?' selected':'') + '>politics</option>'
      + '<option value="legitimacy"' + (o.variable==='legitimacy'?' selected':'') + '>legitimacy</option>'
      + '<option value="turns"' + (o.variable==='turns'?' selected':'') + '>turns</option>'
      + '<option value="year"' + (o.variable==='year'?' selected':'') + '>year</option>'
      + '<option value="age"' + (o.variable==='age'?' selected':'') + '>age</option>'
      + '<option value="mood"' + (o.variable==='mood'?' selected':'') + '>mood</option>'
      + '<option value="location"' + (o.variable==='location'?' selected':'') + '>location</option>'
      + '<option value="link"' + (o.variable==='link'?' selected':'') + '>link</option>'
      + '</select>'
      + (isLink
        ? '<input class="inline-num" type="number" value="' + (o.intValue||0) + '" onchange="inlineOutcomeChange(this)" data-idx="' + i + '" data-parent="' + cardId + '-' + outKey + '" data-field="intValue" style="width:70px">'
        : '<input class="inline-num" type="number" value="' + (o.intValue||0) + '" onchange="inlineOutcomeChange(this)" data-idx="' + i + '" data-parent="' + cardId + '-' + outKey + '" data-field="intValue" style="width:60px">')
      + '<label style="font-size:10px;color:var(--ink-faint)"><input type="checkbox" ' + (o.addOperation !== false ? 'checked' : '') + ' onchange="inlineOutcomeChange(this)" data-idx="' + i + '" data-parent="' + cardId + '-' + outKey + '" data-field="addOperation"> +=</label>'
      + '<label style="font-size:10px;color:var(--ink-faint)"><input type="checkbox" ' + (o.toKeep ? 'checked' : '') + ' onchange="inlineOutcomeChange(this)" data-idx="' + i + '" data-parent="' + cardId + '-' + outKey + '" data-field="toKeep"> ♻</label>'
      + '<button class="inline-del" onclick="inlineOutcomeDel(' + cardId + ',\'' + outKey + '\',' + i + ')">✕</button>'
      + '</div>';
  }).join('');
  return '<div class="inline-array-wrap">' + items
    + '<button class="inline-add" onclick="inlineOutcomeAdd(' + cardId + ',\'' + outKey + '\')">+ outcome</button>'
    + '</div>';
}

function getOutcomesFromDOM(cardId, outKey) {
  const parent = cardId + '-' + outKey;
  const items = document.querySelectorAll('[data-parent="' + parent + '"]');
  const results = [];
  const indices = new Set();
  items.forEach(el => {
    const idx = parseInt(el.dataset.idx);
    const field = el.dataset.field;
    if (!indices.has(idx)) {
      indices.add(idx);
      results[idx] = { variable: 'link', intValue: 0, addOperation: true, toKeep: false };
    }
    if (field === 'variable') results[idx].variable = el.value;
    else if (field === 'intValue') results[idx].intValue = parseInt(el.value) || 0;
    else if (field === 'addOperation') results[idx].addOperation = el.checked;
    else if (field === 'toKeep') results[idx].toKeep = el.checked;
  });
  return results.filter(r => r !== undefined);
}

function inlineOutcomeChange(el) {
  const parts = el.dataset.parent.split('-');
  const cardId = parseInt(parts[0]);
  const outKey = parts.slice(1).join('-');
  const outcomes = getOutcomesFromDOM(cardId, outKey);
  inlineEditValue(cardId, outKey, outcomes);
}

function inlineOutcomeDel(cardId, outKey, idx) {
  const outcomes = getOutcomesFromDOM(cardId, outKey);
  outcomes.splice(idx, 1);
  saveCardField(cardId, outKey, outcomes);
  // Rebuild just this card
  refreshReaderCard(cardId);
}

function inlineOutcomeAdd(cardId, outKey) {
  const outcomes = getOutcomesFromDOM(cardId, outKey);
  outcomes.push({ variable: 'link', intValue: 0, addOperation: true, toKeep: false });
  inlineEditValue(cardId, outKey, outcomes);
  refreshReaderCard(cardId);
}

// Inline conditions editor
function inlineRenderConds(cardId, conds) {
  const items = (conds || []).map((c, i) => {
    return '<div class="inline-array-item">'
      + '<select onchange="inlineCondChange(' + cardId + ')" data-cond-idx="' + i + '">'
      + '<option value="military"' + (c.variable==='military'?' selected':'') + '>military</option>'
      + '<option value="religion"' + (c.variable==='religion'?' selected':'') + '>religion</option>'
      + '<option value="commerce"' + (c.variable==='commerce'?' selected':'') + '>commerce</option>'
      + '<option value="politics"' + (c.variable==='politics'?' selected':'') + '>politics</option>'
      + '<option value="legitimacy"' + (c.variable==='legitimacy'?' selected':'') + '>legitimacy</option>'
      + '<option value="turns"' + (c.variable==='turns'?' selected':'') + '>turns</option>'
      + '<option value="year"' + (c.variable==='year'?' selected':'') + '>year</option>'
      + '<option value="age"' + (c.variable==='age'?' selected':'') + '>age</option>'
      + '<option value="mood"' + (c.variable==='mood'?' selected':'') + '>mood</option>'
      + '<option value="season"' + (c.variable==='season'?' selected':'') + '>season</option>'
      + '<option value="location"' + (c.variable==='location'?' selected':'') + '>location</option>'
      + '</select>'
      + '<select onchange="inlineCondChange(' + cardId + ')" data-cond-idx="' + i + '">'
      + '<option value="equal"' + (c.op==='equal'?' selected':'') + '>=</option>'
      + '<option value="above"' + (c.op==='above'?' selected':'') + '>&gt;</option>'
      + '<option value="below"' + (c.op==='below'?' selected':'') + '>&lt;</option>'
      + '<option value="not"' + (c.op==='not'?' selected':'') + '>≠</option>'
      + '</select>'
      + '<input type="number" value="' + (c.value||0) + '" onchange="inlineCondChange(' + cardId + ')" data-cond-idx="' + i + '" style="width:55px">'
      + '<button class="inline-del" onclick="inlineCondDel(' + cardId + ',' + i + ')">✕</button>'
      + '</div>';
  }).join('');
  return '<div class="inline-array-wrap">' + items
    + '<button class="inline-add" onclick="inlineCondAdd(' + cardId + ')">+ condition</button>'
    + '</div>';
}

function getCondsFromDOM(cardId) {
  const items = document.querySelectorAll('#reader-card [data-card="' + cardId + '"] [data-cond-idx]');
  const results = [];
  const seen = new Set();
  items.forEach(el => {
    const idx = el.dataset.condIdx;
    if (!seen.has(idx)) {
      seen.add(idx);
      results[idx] = { variable: 'military', op: 'equal', value: 0 };
    }
    if (el.tagName === 'SELECT') {
      if (el.value === 'equal' || el.value === 'above' || el.value === 'below' || el.value === 'not') {
        results[idx].op = el.value;
      } else {
        results[idx].variable = el.value;
      }
    }
    if (el.tagName === 'INPUT') {
      results[idx].value = parseInt(el.value) || 0;
    }
  });
  return results.filter(r => r !== undefined);
}

function inlineCondChange(cardId) {
  const conds = getCondsFromDOM(cardId);
  inlineEditValue(cardId, 'conditions', conds);
}

function inlineCondDel(cardId, idx) {
  const conds = getCondsFromDOM(cardId);
  conds.splice(idx, 1);
  saveCardField(cardId, 'conditions', conds);
  refreshReaderCard(cardId);
}

function inlineCondAdd(cardId) {
  const conds = getCondsFromDOM(cardId);
  conds.push({ variable: 'military', op: 'equal', value: 0 });
  inlineEditValue(cardId, 'conditions', conds);
  refreshReaderCard(cardId);
}

async function refreshReaderCard(cardId) {
  const el = document.querySelector('.reader-card-box[data-id="' + cardId + '"]');
  if (!el) return;
  try {
    const res = await fetch('/api/card/' + cardId);
    const card = await res.json();
    _cardCache[cardId] = card;
    // Update the cached card in allCards
    const idx = allCards.findIndex(c => c.id === cardId);
    if (idx >= 0) allCards[idx] = card;
    el.outerHTML = buildReaderCardHTML(card);
  } catch(e) {}
}

function readerCardClick(cardId) {
  if (currentSource === 'reference') {
    showReaderCardPanel(cardId);
    return;
  }
  // Scroll to card and highlight briefly
  const el = document.querySelector('.reader-card-box[data-id="' + cardId + '"]');
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.add('active');
    setTimeout(() => el.classList.remove('active'), 1500);
  }
}

function closeReaderPanel() {
  document.getElementById('reader-card-panel').style.display = 'none';
  document.querySelectorAll('.reader-card-box').forEach(el => el.classList.remove('active'));
}

async function showReaderCardPanel(cardId) {
  const panel = document.getElementById('reader-card-panel');
  const body = document.getElementById('reader-panel-body');
  const title = document.getElementById('reader-panel-title');
  panel.style.display = 'flex';
  panel.style.flexDirection = 'column';
  
  // Highlight the card
  document.querySelectorAll('.reader-card-box').forEach(el => el.classList.remove('active'));
  const cardEl = document.querySelector('.reader-card-box[data-id="' + cardId + '"]');
  if (cardEl) cardEl.classList.add('active');
  
  if (currentSource === 'reference') {
    const res = await fetch('/api/reference/card/' + cardId);
    const card = await res.json();
    title.textContent = '#' + card.id + ' ' + (card.label||'') + ' [Référence]';
    body.innerHTML = '<div style="color:var(--ink-faint);font-family:var(--mono);font-size:11px;padding:20px;text-align:center">Mode référence — consultation uniquement</div>'
      + '<pre style="font-family:var(--mono);font-size:10px;color:var(--ink-dim);white-space:pre-wrap;margin:10px">' + escHtml(JSON.stringify(card, null, 2)) + '</pre>';
    return;
  }
}

async function addCardAfter(afterId) {
  if (!selectedDeck) return;
  const tpl = {
    id: 0, label: 'nouvelle_carte', deck: selectedDeck, weight: 1, lockturn: 0, hidden: false,
    key: false, bearer: null,
    question: { FR: '?', EN: '' },
    conditions: [], loadOutcome: [],
    leftAnswer: { title: { FR: 'Gauche' }, reaction: { FR: '' } },
    rightAnswer: { title: { FR: 'Droite' }, reaction: { FR: '' } },
    yesOutcome: [], noOutcome: [],
    moods: { default: 'neutral', yes: 'neutral', no: 'neutral' }
  };
  const res = await fetch('/api/card', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(tpl) });
  const data = await res.json();
  allCards.push({...tpl, id: data.id});
  markDirty();
  toast('Carte #' + data.id + ' créée', 'success');
  // Refresh the reader
  const decksRes = await fetch('/api/decks');
  allDecks = await decksRes.json();
  renderDecks(document.getElementById('deck-search').value);
  await loadReaderCards();
  // Open the new card
  showReaderCardPanel(data.id);
}

async function addCardToReader() {
  if (!selectedDeck) { toast('Sélectionnez d\'abord un deck', 'error'); return; }
  // Add at the end
  const lastCard = _readerCards[_readerCards.length - 1];
  await addCardAfter(lastCard ? lastCard.id : 0);
}

async function deleteCardFromReader(cardId) {
  if (!confirm('Supprimer la carte #' + cardId + ' ?')) return;
  const res = await fetch('/api/card/' + cardId, { method: 'DELETE' });
  if (res.ok) {
    allCards = allCards.filter(c => c.id !== cardId);
    delete _cardCache[cardId];
    markDirty();
    toast('Carte #' + cardId + ' supprimée', 'success');
    closeReaderPanel();
    // Refresh
    const decksRes = await fetch('/api/decks');
    allDecks = await decksRes.json();
    renderDecks(document.getElementById('deck-search').value);
    await loadReaderCards();
  }
}

function buildReaderCardHTML(card) {
  const FR = (s) => s?.FR || '';
  const EN = (s) => s?.EN || '';
  const qFR = FR(card.question);
  const qEN = EN(card.question);
  const leftTitle = FR(card.leftAnswer?.title);
  const leftReaction = FR(card.leftAnswer?.reaction);
  const rightTitle = FR(card.rightAnswer?.title);
  const rightReaction = FR(card.rightAnswer?.reaction);

  if (currentSource === 'reference') {
    // Read-only for reference
    return '<div class="reader-card-box" data-id="' + card.id + '">'
      + '<div class="rc-header">'
      + '<span class="rc-id">#' + card.id + '</span>'
      + '<span class="rc-label">' + escHtml(card.label||'') + '</span>'
      + '</div>'
      + '<div class="reader-question">' + escHtml(qFR) + (qEN ? '<div class="rc-en">' + escHtml(qEN) + '</div>' : '') + '</div>'
      + '</div>';
  }

  const moods = card.moods || {};
  const moodOpts = ['neutral','suspicious','afraid','angry','flattered','curious','sad','desperate'];
  const moodSel = (v) => moodOpts.map(m => '<option value="' + m + '"' + (v===m?' selected':'') + '>' + m + '</option>').join('');

  return '<div class="reader-card-box" data-id="' + card.id + '" data-card="' + card.id + '">'
    // === HEADER ===
    + '<div class="rc-header">'
    + '<span class="rc-id">#' + card.id + '</span>'
    + '<input class="rc-label-input" value="' + escHtml(card.label||'') + '"'
    + ' onchange="inlineEditValue(' + card.id + ',\'label\',this.value)" placeholder="label">'
    + '<span class="rc-meta-group">'
    + ' W <input type="number" class="rc-meta-num" value="' + (card.weight||1) + '" onchange="inlineEditValue(' + card.id + ',\'weight\',parseInt(this.value)||1)">'
    + ' L <input type="number" class="rc-meta-num" value="' + (card.lockturn||0) + '" onchange="inlineEditValue(' + card.id + ',\'lockturn\',parseInt(this.value)||0)">'
    + ' H <input type="checkbox" ' + (card.hidden?'checked':'') + ' onchange="inlineEditValue(' + card.id + ',\'hidden\',this.checked)">'
    + ' Clé <input type="checkbox" ' + (card.key?'checked':'') + ' onchange="inlineEditValue(' + card.id + ',\'key\',this.checked)">'
    + '</span>'
    + '<div class="reader-card-actions">'
    + '<button class="dng" onclick="event.stopPropagation();deleteCardFromReader(' + card.id + ')" title="Supprimer">🗑</button>'
    + '</div>'
    + '</div>'

    // === QUESTION ===
    + '<div class="rc-editor-section"><label>Question FR</label>'
    + '<textarea rows="2" onchange="inlineEditValue(' + card.id + ',\'question.FR\',this.value)">' + escHtml(qFR) + '</textarea></div>'
    + '<div class="rc-editor-section"><label>Question EN</label>'
    + '<textarea rows="1" onchange="inlineEditValue(' + card.id + ',\'question.EN\',this.value)">' + escHtml(qEN) + '</textarea></div>'

    // === LEFT ANSWER ===
    + '<div class="rc-editor-row">'
    + '<div class="rc-editor-col left">'
    + '<div class="rc-editor-section"><label>◀ Titre (gauche)</label>'
    + '<input value="' + escHtml(leftTitle) + '" onchange="inlineEditValue(' + card.id + ',\'leftAnswer.title.FR\',this.value)">'
    + '</div>'
    + '<div class="rc-editor-section"><label>Réaction</label>'
    + '<textarea rows="1" onchange="inlineEditValue(' + card.id + ',\'leftAnswer.reaction.FR\',this.value)">' + escHtml(leftReaction) + '</textarea>'
    + '</div>'
    + '<div class="rc-editor-section"><label>yesOutcome</label>'
    + inlineRenderOutcomes(card.id, card.yesOutcome, 'yesOutcome')
    + '</div>'
    + '</div>'

    // === RIGHT ANSWER ===
    + '<div class="rc-editor-col right">'
    + '<div class="rc-editor-section"><label>Titre (droite) ▶</label>'
    + '<input value="' + escHtml(rightTitle) + '" onchange="inlineEditValue(' + card.id + ',\'rightAnswer.title.FR\',this.value)">'
    + '</div>'
    + '<div class="rc-editor-section"><label>Réaction</label>'
    + '<textarea rows="1" onchange="inlineEditValue(' + card.id + ',\'rightAnswer.reaction.FR\',this.value)">' + escHtml(rightReaction) + '</textarea>'
    + '</div>'
    + '<div class="rc-editor-section"><label>noOutcome</label>'
    + inlineRenderOutcomes(card.id, card.noOutcome, 'noOutcome')
    + '</div>'
    + '</div>'
    + '</div>'

    // === LOAD OUTCOME + CONDITIONS + MOODS ===
    + '<div class="rc-editor-row">'
    + '<div class="rc-editor-col">'
    + '<div class="rc-editor-section"><label>loadOutcome</label>'
    + inlineRenderOutcomes(card.id, card.loadOutcome, 'loadOutcome')
    + '</div>'
    + '</div>'
    + '<div class="rc-editor-col">'
    + '<div class="rc-editor-section"><label>Conditions</label>'
    + inlineRenderConds(card.id, card.conditions)
    + '</div>'
    + '</div>'
    + '</div>'

    // === MOODS ===
    + '<div class="rc-editor-row" style="gap:4px">'
    + '<div class="rc-editor-section" style="flex:1"><label>Mood défaut</label>'
    + '<select onchange="inlineEditValue(' + card.id + ',\'moods.default\',this.value)">' + moodSel(moods.default||'neutral') + '</select></div>'
    + '<div class="rc-editor-section" style="flex:1"><label>Mood Oui</label>'
    + '<select onchange="inlineEditValue(' + card.id + ',\'moods.yes\',this.value)">' + moodSel(moods.yes||'neutral') + '</select></div>'
    + '<div class="rc-editor-section" style="flex:1"><label>Mood Non</label>'
    + '<select onchange="inlineEditValue(' + card.id + ',\'moods.no\',this.value)">' + moodSel(moods.no||'neutral') + '</select></div>'
    + '</div>'

    + '</div>';
}

// === Source switching ===
let currentSource = 'foundation';

async function switchSource(source) {
  currentSource = source;
  if (source === 'reference') {
    document.getElementById('btn-save').style.display = 'none';
    document.querySelector('button[onclick="addCard()"]').style.display = 'none';
    const res = await fetch('/api/reference/decks');
    allDecks = await res.json();
  } else {
    document.getElementById('btn-save').style.display = '';
    document.querySelector('button[onclick="addCard()"]').style.display = '';
    const res = await fetch('/api/decks');
    allDecks = await res.json();
    allCards = (await fetch('/api/cards').then(r => r.json())).cards;
  }
  closeCardPanel();
  selectedDeck = null; selectedCard = null; _selectedBulk.clear(); updateBulkBar();
  document.getElementById('toolbar-title').textContent = 'Sélectionnez un deck';
  document.getElementById('toolbar-sub').textContent = '';
  document.getElementById('card-detail').innerHTML = '<div class="empty-state">Sélectionnez un deck à gauche<br>puis une carte dans la liste</div>';
  renderDecks();
  document.getElementById('graph-view').innerHTML = '<div class="graph-empty">Sélectionnez un deck</div>';
  document.getElementById('reader-card').innerHTML = '<div class="reader-empty">Sélectionnez un deck</div>';
  document.getElementById('reader-progress').textContent = '—';
  _readerCards = [];
}

async function fetchCardsForDeck(deckName) {
  if (currentSource === 'reference') {
    const res = await fetch('/api/reference/cards?deck=' + encodeURIComponent(deckName));
    return (await res.json()).cards;
  }
  const res = await fetch('/api/cards?deck=' + encodeURIComponent(deckName));
  return (await res.json()).cards;
}

async function fetchGraphData(deckName) {
  if (currentSource === 'reference') {
    const res = await fetch('/api/reference/graph?deck=' + encodeURIComponent(deckName));
    return await res.json();
  }
  const res = await fetch('/api/graph?deck=' + encodeURIComponent(deckName));
  return await res.json();
}

// === View toggle (graph / table) ===
let _tableView = false;

function toggleTableView() {
  _tableView = !_tableView;
  if (_tableView) {
    hideAllContentViews();
    document.getElementById('table-layout').style.display = 'flex';
    document.getElementById('btn-table-view').textContent = '📖 Lecteur';
  } else {
    // Back to reader (default)
    _readerView = true;
    hideAllContentViews();
    document.getElementById('reader-layout').style.display = 'flex';
    document.getElementById('btn-reader-view').textContent = '🕸️ Graphe';
    document.getElementById('btn-table-view').textContent = '📋 Tableau';
    if (selectedDeck) loadReaderCards();
  }
}

function closeCardPanel() {
  document.getElementById('graph-card-panel').style.display = 'none';
  selectedCard = null;
}

// === Card panel in graph ===
async function showCardPanelInGraph(cardId) {
  const panel = document.getElementById('graph-card-panel');
  const body = document.getElementById('graph-panel-body');
  const title = document.getElementById('graph-panel-title');
  panel.style.display = 'flex';

  if (currentSource === 'reference') {
    const res = await fetch('/api/reference/card/' + cardId);
    const card = await res.json();
    title.textContent = '#' + card.id + ' ' + (card.label||'');
    body.innerHTML = renderRefCardDetail(card);
    return;
  }

  const res = await fetch('/api/card/' + cardId);
  const card = await res.json();
  title.textContent = '#' + card.id + ' ' + (card.label||'');

  renderCardDetail(card);
  body.innerHTML = document.getElementById('card-detail').innerHTML;
}

function renderRefCardDetail(card) {
  const diffHtml = buildRefDiff(card);
  return '<div id="detail-scroll">'
    + '<div class="detail-section" style="border-color:var(--primary)"><div class="section-header"><h3>\U0001F464 Identité</h3></div><div class="section-body">'
    + '<div class="field-row"><label>ID</label><span style="font-family:var(--mono);color:var(--ink-dim)">#' + card.id + '</span>'
    + '<label>Deck</label><span style="font-family:var(--mono);color:var(--ink-dim)">' + escHtml(card.deck||'') + '</span>'
    + '<label>Weight</label><span style="font-family:var(--mono);color:var(--ink-dim)">' + (card.weight||1) + '</span></div>'
    + '<div class="field-row"><label>Label</label><span>' + escHtml(card.label||'') + '</span></div>'
    + '<div class="field-row"><label>Moods</label><span style="color:var(--ink-dim)">D:' + card.moods?.default + ' Y:' + card.moods?.yes + ' N:' + card.moods?.no + '</span></div>'
    + '</div></div>'
    + '<div class="detail-section"><div class="section-header"><h3>\U0001F4AC Question</h3></div><div class="section-body">'
    + '<p style="font-style:italic;color:var(--ink);margin:4px 0">' + escHtml(card.question?.FR||'') + '</p>'
    + '<p style="font-size:10px;color:var(--ink-faint)">' + escHtml((card.question?.EN||'').substring(0,200)) + '</p>'
    + '</div></div>'
    + '<div class="detail-section"><div class="section-header"><h3>\U0001F4CB Conditions (' + (card.conditions||[]).length + ')</h3></div><div class="section-body">'
    + (card.conditions||[]).map(c => '<div class="array-item" style="font-size:10px;color:var(--ink-dim)">' + escHtml(c.variable||'') + ' ' + escHtml(c.op||'') + ' ' + escHtml(c.value||'') + '</div>').join('')
    + '</div></div>'
    + '<div class="detail-section"><div class="section-header"><h3>\u2B05 Left / \u27A1 Right</h3></div><div class="section-body">'
    + '<div class="field-row"><label>Gauche</label><span>' + escHtml(card.leftAnswer?.title?.FR||'') + '</span></div>'
    + '<div class="field-row"><label>Réaction</label><span style="color:var(--ink-dim);font-style:italic">' + escHtml(card.leftAnswer?.reaction?.FR||'') + '</span></div>'
    + '<div class="field-row" style="margin-top:4px"><label>Droite</label><span>' + escHtml(card.rightAnswer?.title?.FR||'') + '</span></div>'
    + '<div class="field-row"><label>Réaction</label><span style="color:var(--ink-dim);font-style:italic">' + escHtml(card.rightAnswer?.reaction?.FR||'') + '</span></div>'
    + '</div></div>'
    + '<div class="detail-section"><div class="section-header"><h3>\U0001F4E5 Outcomes</h3></div><div class="section-body">'
    + '<div style="font-size:10px;color:var(--ink-dim)">'
    + '<b>Load:</b> ' + renderRefOutcomes(card.loadOutcome||[]) + '<br>'
    + '<b style="color:var(--green)">Yes:</b> ' + renderRefOutcomes(card.yesOutcome||[]) + '<br>'
    + '<b style="color:var(--danger)">No:</b> ' + renderRefOutcomes(card.noOutcome||[]) + '</div>'
    + '</div></div>'
    + (diffHtml ? '<div class="detail-section" style="border-color:var(--amber)"><div class="section-header"><h3>\U0001F50D Différence Foundation</h3></div><div class="section-body">' + diffHtml + '</div></div>' : '')
    + '</div>';
}

function renderRefOutcomes(outcomes) {
  if (!outcomes.length) return '<span style="color:var(--ink-faint)">—</span>';
  return outcomes.map(o => {
    const v = o.variable || '?';
    const val = o.intValue || 0;
    const op = o.addOperation !== false ? (val >= 0 ? '+' : '') + val : '=' + val;
    const isLink = v === 'link';
    return '<span class="' + (isLink ? 'impact link' : val >= 0 ? 'impact pos' : 'impact neg') + '">' + escHtml(v) + ' ' + op + '</span>';
  }).join(' ');
}

function buildRefDiff(card) {
  // Find matching card in foundation data by label or id heuristic
  const label = card.label || '';
  const match = allCards.find(c => c.label === label || (c.id + '' === card.id + ''));
  if (!match) return '<span style="color:var(--ink-faint)">Aucune carte correspondante dans Foundation</span>';
  let html = '<div style="font-size:10px">';
  // Compare conditions count
  const refConds = (card.conditions||[]).length;
  const ourConds = (match.conditions||[]).length;
  if (refConds !== ourConds) html += '<div style="color:var(--amber)">⚠ Conditions: ' + refConds + ' (ref) vs ' + ourConds + ' (ici)</div>';
  // Compare outcome counts
  for (const key of ['yesOutcome','noOutcome','loadOutcome']) {
    const rl = (card[key]||[]).length;
    const ol = (match[key]||[]).length;
    if (rl !== ol) html += '<div style="color:var(--primary)">\U0001F4E5 ' + key + ': ' + rl + ' (ref) vs ' + ol + ' (ici)</div>';
  }
  // Compare weight
  if ((card.weight||1) !== (match.weight||1)) {
    html += '<div>Weight: ' + (card.weight||1) + ' → ' + (match.weight||1) + '</div>';
  }
  html += '</div>';
  return html;
}

// === Graph ===
let _graphTransform = { x: 40, y: 40, scale: 1 };
let _graphDragging = false, _graphDragStart = null;

async function renderGraph() {
  const container = document.getElementById('graph-view');
  const deck = selectedDeck || '';
  const data = await fetchGraphData(deck);
  if (!data.nodes.length) {
    container.innerHTML = '<div class="graph-empty">' + (deck ? 'Aucun lien dans ce deck' : 'S\u00e9lectionnez d\u00b4abord un deck') + '</div>';
    return;
  }

  // Card data lookup
  const fullCards = {};
  if (currentSource === 'reference') {
    const refRes = await fetch('/api/reference/cards?deck=' + encodeURIComponent(deck));
    const refData = await refRes.json();
    for (const c of refData.cards) fullCards[c.id] = c;
  } else {
    for (const c of allCards) fullCards[c.id] = c;
  }

  // Build adjacency
  const inDeg = {}; const edgesFrom = {};
  for (const n of data.nodes) { inDeg[n.id] = 0; edgesFrom[n.id] = []; }
  for (const e of data.edges) { inDeg[e.to] = (inDeg[e.to]||0) + 1; if (edgesFrom[e.from]) edgesFrom[e.from].push(e); }

  // Find roots + assign levels via BFS
  let roots = data.nodes.filter(n => !inDeg[n.id]).map(n => n.id);
  if (!roots.length) roots = [data.nodes[0].id];
  const level = {}; let maxLevel = 0;
  for (const n of data.nodes) level[n.id] = 0;
  const q = [...roots];
  const visited = new Set();
  while (q.length) {
    const id = q.shift();
    if (visited.has(id)) continue;
    visited.add(id);
    for (const e of edgesFrom[id] || []) {
      const nxt = level[id] + 1;
      if (nxt > (level[e.to]||0)) { level[e.to] = nxt; maxLevel = Math.max(maxLevel, nxt); }
      q.push(e.to);
    }
  }

  // Group by level
  const byLevel = {};
  for (const n of data.nodes) {
    const l = level[n.id] || 0;
    if (!byLevel[l]) byLevel[l] = [];
    byLevel[l].push(n.id);
  }

  // Layout params
  const CW = 300, CH = 120, GX = 80, GY = 40;
  const MARGIN = 20;

  // Position nodes: each level is a column, nodes spread vertically
  const positions = {};
  const colHeights = {};
  for (let l = 0; l <= maxLevel; l++) {
    const ids = byLevel[l] || [];
    const colH = ids.length * (CH + GY) - GY;
    colHeights[l] = colH;
    let yAcc = 0;
    ids.forEach((id, i) => {
      positions[id] = { x: MARGIN + l * (CW + GX), y: MARGIN + yAcc };
      yAcc += CH + GY;
    });
  }
  // Unlinked nodes at far right
  let extraY = MARGIN;
  for (const n of data.nodes) {
    if (positions[n.id]) continue;
    positions[n.id] = { x: MARGIN + (maxLevel+1) * (CW + GX), y: extraY };
    extraY += CH + GY;
  }

  // Compute SVG dimensions
  const maxX = Math.max(...Object.values(positions).map(p => p.x + CW)) + 80;
  const maxY = Math.max(...Object.values(positions).map(p => p.y + CH)) + 80;
  const svgW = Math.max(maxX, 400);
  const svgH = Math.max(maxY, 300);

  // Center columns vertically
  for (let l = 0; l <= maxLevel; l++) {
    const ids = byLevel[l] || [];
    if (ids.length < 2) continue;
    const totalH = ids.length * (CH + GY) - GY;
    const offset = (svgH - totalH) / 2 - MARGIN;
    ids.forEach((id, i) => { positions[id].y += offset; });
  }

  // Build SVG
  let svg = '<svg width="' + svgW + '" height="' + svgH + '">'
    + '<rect width="100%" height="100%" fill="#f8f9fa"/>';

  // Arrow markers
  svg += '<defs>';
  for (const [cls, color] of [['yes','#10b981'],['no','#ef4444'],['load','#3b82f6']]) {
    svg += '<marker id="gm-' + cls + '" viewBox="0 0 8 8" refX="8" refY="4" markerWidth="5" markerHeight="5" orient="auto">'
      + '<path d="M0,0 L8,4 L0,8" fill="' + color + '"/></marker>';
  }
  svg += '</defs>';

  // Edges with curved paths
  for (const e of data.edges) {
    const from = positions[e.from], to = positions[e.to];
    if (!from || !to) continue;
    const x1 = from.x + CW, y1 = from.y + CH/2;
    const x2 = to.x, y2 = to.y + CH/2;
    const cls = (e.outcomeKey === 'noOutcome' || e.label === 'no') ? 'no' : (e.outcomeKey === 'loadOutcome' || e.label === 'load') ? 'load' : 'yes';
    const d = 'M' + x1 + ',' + y1 + ' C' + ((x1+x2)/2) + ',' + y1 + ' ' + ((x1+x2)/2) + ',' + y2 + ' ' + x2 + ',' + y2;
    const mx = (x1 + x2) / 2, my = (y1 + y2) / 2 - 8;
    svg += '<g class="graph-edge" onclick="event.stopPropagation();navigateEdge(' + e.from + ',' + (e.outcomeIdx||0) + ',\'' + (e.outcomeKey||'load') + '\')">'
      + '<path class="graph-arrow ' + cls + '" d="' + d + '" marker-end="url(#gm-' + cls + ')"/>'
      + '<path class="edge-hit" d="' + d + '"/>'
      + '<rect x="' + (mx-10) + '" y="' + (my-6) + '" width="20" height="12" rx="2" fill="#e2e8f0" opacity=".9"/>'
      + '<text class="graph-alabel" x="' + mx + '" y="' + (my+3) + '" text-anchor="middle" fill="#475569" font-weight="600">' + e.label + '</text>'
      + '</g>';
  }

  // Card boxes with ports
  const PORT_SIZE = 7;
  for (const n of data.nodes) {
    const pos = positions[n.id];
    if (!pos) continue;
    const card = fullCards[n.id] || {};
    const isHidden = n.hidden;
    const highlight = n.id === selectedCard;
    const isLinkSource = _linkMode && _linkMode.sourceId === n.id;
    const fill = isHidden ? '#fef2f2' : highlight ? 'rgba(59,130,246,.08)' : isLinkSource ? 'rgba(245,158,11,.1)' : '#ffffff';
    const stroke = isHidden ? '#ef4444' : highlight ? '#3b82f6' : isLinkSource ? '#f59e0b' : '#e2e8f0';
    const label = card.label || n.label || 'card_' + n.id;
    const extraClass = _linkMode && _linkMode.sourceId !== n.id ? ' graph-link-target' : '';
    const question = (card.question?.FR || card.question?.EN || '');
    const hasYes = card.yesOutcome?.some(o => o.variable === 'link');
    const hasNo = card.noOutcome?.some(o => o.variable === 'link');
    const hasLoad = card.loadOutcome?.some(o => o.variable === 'link');
    // Word-wrap question into ~40-char lines
    function wrapQ(t, n) { if (!t) return []; const r=[]; let c=''; for (const w of t.split(' ')) { if ((c+' '+w).trim().length>n) { if(c)r.push(c); c=w; } else { c=c?c+' '+w:w; } } if(c)r.push(c); return r.slice(0,4); }
    const qLines = wrapQ(question, 44);
    
    const px = pos.x + CW;
    
    let inner = '<text class="gid" x="' + (pos.x+12) + '" y="' + (pos.y+18) + '" font-size="11">#' + n.id + '</text>'
      + '<text class="glabel" x="' + (pos.x+12) + '" y="' + (pos.y+38) + '" font-size="13">' + escHtml(label.substring(0, 28)) + '</text>';
    
    let ty = pos.y + 62;
    for (const line of qLines) {
      inner += '<text x="' + (pos.x+12) + '" y="' + ty + '" font-size="10" fill="#64748b" font-family="var(--font)">' + escHtml(line) + '</text>';
      ty += 14;
    }
    if (card.bearer) {
      inner += '<text x="' + (pos.x+12) + '" y="' + (pos.y+CH-10) + '" font-size="9" fill="#94a3b8" font-family="var(--mono)">' + escHtml(card.bearer.substring(0, 22)) + '</text>';
    }
    
    svg += '<g class="graph-card' + extraClass + '" data-id="' + n.id + '" onclick="event.stopPropagation();graphCardClick(' + n.id + ')" oncontextmenu="event.preventDefault();event.stopPropagation();showGraphContextMenu(event,' + n.id + ')">'
      + '<rect x="' + pos.x + '" y="' + pos.y + '" width="' + CW + '" height="' + CH + '" fill="' + fill + '" stroke="' + stroke + '" stroke-width="' + (highlight||isLinkSource?1.5:1) + '" rx="6"/>'
      + inner
      // Ports on right edge (top=yes, middle=load, bottom=no)
      + '<circle cx="' + (px+PORT_SIZE) + '" cy="' + (pos.y+22) + '" r="' + PORT_SIZE + '" fill="#10b981" stroke="#059669" stroke-width="1" class="graph-port yes-port" data-card="' + n.id + '" data-outcome="yesOutcome" onclick="event.stopPropagation();startLinkFromPort(' + n.id + ',\'yesOutcome\')" style="cursor:pointer" title="Lier depuis Oui"/>'
      + '<circle cx="' + (px+PORT_SIZE) + '" cy="' + (pos.y+CH/2) + '" r="' + PORT_SIZE + '" fill="#3b82f6" stroke="#2563eb" stroke-width="1" class="graph-port load-port" data-card="' + n.id + '" data-outcome="loadOutcome" onclick="event.stopPropagation();startLinkFromPort(' + n.id + ',\'loadOutcome\')" style="cursor:pointer" title="Lier depuis Load"/>'
      + '<circle cx="' + (px+PORT_SIZE) + '" cy="' + (pos.y+CH-22) + '" r="' + PORT_SIZE + '" fill="#ef4444" stroke="#dc2626" stroke-width="1" class="graph-port no-port" data-card="' + n.id + '" data-outcome="noOutcome" onclick="event.stopPropagation();startLinkFromPort(' + n.id + ',\'noOutcome\')" style="cursor:pointer" title="Lier depuis Non"/>'
      // Show existing links as lines from ports
      + (hasYes ? '<line x1="' + (px+PORT_SIZE*2) + '" y1="' + (pos.y+22) + '" x2="' + (px+PORT_SIZE*3) + '" y2="' + (pos.y+22) + '" stroke="#10b981" stroke-width="2" opacity=".5"/>' : '')
      + (hasLoad ? '<line x1="' + (px+PORT_SIZE*2) + '" y1="' + (pos.y+CH/2) + '" x2="' + (px+PORT_SIZE*3) + '" y2="' + (pos.y+CH/2) + '" stroke="#3b82f6" stroke-width="2" opacity=".5"/>' : '')
      + (hasNo ? '<line x1="' + (px+PORT_SIZE*2) + '" y1="' + (pos.y+CH-22) + '" x2="' + (px+PORT_SIZE*3) + '" y2="' + (pos.y+CH-22) + '" stroke="#ef4444" stroke-width="2" opacity=".5"/>' : '')
      + '</g>';
  }

  svg += '</svg>';

  // Build interactive canvas
  container.innerHTML = ''
    + '<div class="graph-toolbar">'
    + '<button onclick="graphZoom(1.3)" title="Zoom +">+</button>'
    + '<button onclick="graphZoom(0.7)" title="Zoom -">-</button>'
    + '<button onclick="graphFit()" title="Ajuster">\u229E</button>'
    + '<button class="link-toggle" onclick="toggleLinkMode()" title="Mode lien" style="' + (_linkMode ? 'background:var(--amber);color:#fff;border-color:var(--amber)' : '') + '">\uD83D\uDD17</button>'
    + '</div>'
    + '<div id="graph-canvas">'
    + '<div id="graph-svg-wrap" style="transform-origin:0 0">' + svg + '</div>'
    + '</div>';

  // Init zoom/pan
  _graphTransform = { x: 0, y: 0, scale: 1 };
  applyGraphTransform();
  graphFit();

  // Events
  const canvas = document.getElementById('graph-canvas');
  canvas.onmousedown = e => { if (e.target.closest('.graph-card,.graph-toolbar')) return; _graphDragging = true; _graphDragStart = { x: e.clientX - _graphTransform.x, y: e.clientY - _graphTransform.y }; };
  canvas.onmousemove = e => { if (!_graphDragging) return; _graphTransform.x = e.clientX - _graphDragStart.x; _graphTransform.y = e.clientY - _graphDragStart.y; applyGraphTransform(); };
  canvas.onmouseup = () => { _graphDragging = false; };
  canvas.onmouseleave = () => { _graphDragging = false; };
  canvas.onwheel = e => { e.preventDefault(); const d = e.deltaY > 0 ? 0.85 : 1.18; const r = canvas.getBoundingClientRect(); const mx = e.clientX - r.left, my = e.clientY - r.top; const ns = _graphTransform.scale * d; _graphTransform.x = mx - (mx - _graphTransform.x) * (ns / _graphTransform.scale); _graphTransform.y = my - (my - _graphTransform.y) * (ns / _graphTransform.scale); _graphTransform.scale = ns; applyGraphTransform(); };
}

function applyGraphTransform() {
  const wrap = document.getElementById('graph-svg-wrap');
  if (!wrap) return;
  wrap.style.transform = 'translate(' + _graphTransform.x + 'px,' + _graphTransform.y + 'px) scale(' + _graphTransform.scale + ')';
}

function graphZoom(factor) {
  const canvas = document.getElementById('graph-canvas');
  if (!canvas) return;
  const r = canvas.getBoundingClientRect();
  const mx = r.width / 2, my = r.height / 2;
  const ns = _graphTransform.scale * factor;
  _graphTransform.x = mx - (mx - _graphTransform.x) * (ns / _graphTransform.scale);
  _graphTransform.y = my - (my - _graphTransform.y) * (ns / _graphTransform.scale);
  _graphTransform.scale = ns;
  applyGraphTransform();
}

function graphFit() {
  const canvas = document.getElementById('graph-canvas');
  const wrap = document.getElementById('graph-svg-wrap');
  if (!canvas || !wrap) return;
  const svg = wrap.querySelector('svg');
  if (!svg) return;
  const cw = canvas.clientWidth, ch = canvas.clientHeight;
  const sw = parseFloat(svg.getAttribute('width')), sh = parseFloat(svg.getAttribute('height'));
  if (!sw || !sh) return;
  const pad = 30;
  const scale = Math.min((cw - pad*2) / sw, (ch - pad*2) / sh, 1.5);
  _graphTransform.scale = scale;
  _graphTransform.x = (cw - sw * scale) / 2;
  _graphTransform.y = (ch - sh * scale) / 2;
  applyGraphTransform();
}
async function selectCardById(id) {
  selectedCard = id;
  if (currentSource === 'reference') {
    await showCardPanelInGraph(id);
    return;
  }
  await showCardPanelInGraph(id);
  if (_tableView) {
    await selectCard(id);
    return;
  }
  // Just highlight in existing graph, don't re-render
  const svg = document.querySelector('#graph-svg-wrap svg');
  if (svg) {
    svg.querySelectorAll('.graph-card').forEach(g => {
      const gid = parseInt(g.getAttribute('data-id'));
      const r = g.querySelector('rect');
      if (r) {
        const isSel = gid === id;
        const isHidden = r.getAttribute('fill') === '#fef2f2';
        r.setAttribute('fill', isSel ? 'rgba(59,130,246,.08)' : (isHidden ? '#fef2f2' : '#ffffff'));
        r.setAttribute('stroke', isSel ? '#3b82f6' : (isHidden ? '#ef4444' : '#e2e8f0'));
        r.setAttribute('stroke-width', isSel ? '1.5' : '1');
      }
    });
  }
}

// === Edge click → navigate + highlight outcome ===
async function navigateEdge(fromId, outcomeIdx, outcomeKey) {
  await selectCardById(fromId);
  // If in table view, navigateEdge works there
  if (_tableView) {
    const sectionKey = outcomeKey === 'yes' ? 'yesOutcome' : outcomeKey === 'no' ? 'noOutcome' : 'loadOutcome';
    const container = document.getElementById(sectionKey + '-container');
    if (container) {
      const section = container.closest('.detail-section');
      if (section && section.classList.contains('collapsed')) {
        const header = section.querySelector('.section-header');
        if (header) header.click();
      }
      const items = container.querySelectorAll('.array-item');
      if (items[outcomeIdx]) {
        items[outcomeIdx].scrollIntoView({ behavior: 'smooth', block: 'center' });
        items[outcomeIdx].classList.add('outcome-highlight');
        setTimeout(() => items[outcomeIdx].classList.remove('outcome-highlight'), 2400);
      }
    }
    return;
  }
  // In graph view, find outcome container in the panel
  const sectionKey = outcomeKey === 'yes' ? 'yesOutcome' : outcomeKey === 'no' ? 'noOutcome' : 'loadOutcome';
  const container = document.getElementById('graph-panel-body')?.querySelector('#' + sectionKey + '-container');
  if (container) {
    const section = container.closest('.detail-section');
    if (section && section.classList.contains('collapsed')) {
      const header = section.querySelector('.section-header');
      if (header) header.click();
    }
    const items = container.querySelectorAll('.array-item');
    if (items[outcomeIdx]) {
      items[outcomeIdx].scrollIntoView({ behavior: 'smooth', block: 'center' });
      items[outcomeIdx].classList.add('outcome-highlight');
      setTimeout(() => items[outcomeIdx].classList.remove('outcome-highlight'), 2400);
    }
  }
}

// === Graph card click (link mode aware) ===
function graphCardClick(id) {
  if (_linkMode) {
    if (_linkMode.sourceId === id) {
      // Clicking same card to cancel
      toggleLinkMode();
      return;
    }
    addLink(_linkMode.sourceId, id);
    toggleLinkMode();
    return;
  }
  selectCardById(id);
}

// === Context menu ===
let _contextCardId = null;

function showGraphContextMenu(event, cardId) {
  _contextCardId = cardId;
  const menu = document.getElementById('graph-context-menu');
  if (!menu) return;
  menu.style.display = 'block';
  menu.style.left = event.clientX + 'px';
  menu.style.top = event.clientY + 'px';
}

function hideGraphContextMenu() {
  const menu = document.getElementById('graph-context-menu');
  if (menu) menu.style.display = 'none';
  _contextCardId = null;
}

document.addEventListener('click', hideGraphContextMenu);
document.addEventListener('contextmenu', hideGraphContextMenu);

function contextMenuEdit() {
  if (_contextCardId != null) selectCardById(_contextCardId);
  hideGraphContextMenu();
}

function contextMenuDelete() {
  if (_contextCardId != null) {
    deleteCard(_contextCardId);
    // Re-render graph to remove deleted node
    renderGraph();
  }
  hideGraphContextMenu();
}

function contextMenuAddLink() {
  if (_contextCardId != null) {
    _linkMode = { sourceId: _contextCardId, outcomeKey: 'yesOutcome' };
    renderGraph();
    toast('🔗 Mode lien: cliquez sur la cible depuis #' + _contextCardId, 'info');
  }
  hideGraphContextMenu();
}

function startLinkFromPort(cardId, outcomeKey) {
  if (currentSource === 'reference') { toast('Mode référence', 'info'); return; }
  _linkMode = { sourceId: cardId, outcomeKey: outcomeKey };
  toast('Cliquez sur la carte cible dans le graphe pour créer un lien ' + outcomeKey.replace('Outcome',''), 'info');
  renderGraph();
}

function toggleLinkMode() {
  if (_linkMode) {
    _linkMode = null;
    renderGraph();
    toast('Mode lien désactivé', 'info');
  } else {
    toast('Cliquez sur un port (●) dans le graphe', 'info');
  }
}

function addLink(sourceId, targetId) {
  const card = getCard(sourceId);
  if (!card) return;
  const outcomeKey = (_linkMode && _linkMode.outcomeKey) || 'yesOutcome';
  if (!card[outcomeKey]) card[outcomeKey] = [];
  // Check if this link already exists
  const exists = card[outcomeKey].some(o => o.variable === 'link' && o.intValue === targetId);
  if (exists) {
    toast('⚠️ Ce lien existe déjà', 'error');
    return;
  }
  card[outcomeKey].push({
    variable: 'link',
    intValue: targetId,
    addOperation: false,
    toKeep: false
  });
  scheduleAutoSave(sourceId);
  toast('🔗 Lien #' + sourceId + ' → #' + targetId + ' (' + outcomeKey.replace('Outcome','') + ') ajouté', 'success');
  renderGraph();
  // Also refresh the card detail if it's visible
  if (selectedCard === sourceId) {
    renderCardDetail(card);
  }
}

// === Keyboard ===
document.addEventListener('keydown', e => { if ((e.ctrlKey||e.metaKey) && e.key === 's') { e.preventDefault(); saveAll(); } });

init();
</script>
</body>
</html>"""


def start_file_watcher(interval=1.0):
    """Surveille les fichiers de données et recharge si modifiés."""
    global _file_mtimes
    _file_mtimes = {p: _try_mtime(p) for p in [CARDS_PATH, ALIASES_PATH, CHARACTERS_PATH]}

    def _watcher():
        while not _watcher_stop.is_set():
            if _watcher_stop.wait(interval):
                break
            mtime = _try_mtime(CARDS_PATH)
            if mtime == _file_mtimes.get(CARDS_PATH):
                continue
            # Skip if our own save just wrote the file
            if mtime == _last_save_time:
                _file_mtimes[CARDS_PATH] = mtime
                continue
            _file_mtimes[CARDS_PATH] = mtime
            try:
                with _data_lock:
                    with open(CARDS_PATH) as f:
                        reloaded = json.load(f)
                    # Only swap if parse succeeded
                    global _cards
                    _cards = reloaded
                print(f"\n  ♻️  {os.path.basename(CARDS_PATH)} rechargé ({len(_cards)} cartes)")
            except Exception as e:
                print(f"\n  ⚠️  Erreur rechargement {os.path.basename(CARDS_PATH)}: {e}")

    t = threading.Thread(target=_watcher, daemon=True)
    t.start()


def main():
    global PORT
    import argparse
    parser = argparse.ArgumentParser(description="Narrative Explorer")
    parser.add_argument("--port", type=int, default=8080, help="Port (defaut: 8080)")
    parser.add_argument("--no-watch", action="store_true", help="Désactiver le hot reload")
    parser.add_argument("--no-browser", action="store_true", help="Ne pas ouvrir le navigateur")
    args = parser.parse_args()
    PORT = args.port

    load_data()
    load_reference_data()
    print(f"\n  🧭 Narrative Explorer — Foundation Reigns")
    print(f"  ─────────────────────────────────────")
    print(f"  📂 {len(_cards)} cartes chargées")
    print(f"  📦 {len(get_decks())} decks")
    print(f"  🔗 {len(_link_aliases)} alias de link")
    print(f"  🎭 {len(_characters)} personnages")
    print(f"  📖 {len(_ref_flat)} cartes de référence (Reigns TK)")
    print(f"  🗂️  {len(_skeleton_meta)} squelettes chargés")
    print(f"\n  🌐 http://localhost:{PORT}")
    print(f"  ⏎  Ctrl+C pour quitter\n")

    if not args.no_watch:
        start_file_watcher()
        print(f"  👁️  Hot reload actif (fichier JSON surveillé)\n")

    server = HTTPServer(("0.0.0.0", PORT), NarrativeAPI)
    try:
        if not args.no_browser:
            try:
                webbrowser.open(f"http://localhost:{PORT}")
            except Exception:
                pass
        server.serve_forever()
    except KeyboardInterrupt:
        _watcher_stop.set()
        if _dirty:
            print("\n  ⚠️  Modifications non sauvegardées ! Utilisez le bouton 💾 dans l'interface.")
        print("\n  👋 Au revoir\n")
        server.server_close()


if __name__ == "__main__":
    main()
