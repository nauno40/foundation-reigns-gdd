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


_backup_done = False

def save_cards():
    global _backup_done, _last_save_time
    if not _backup_done:
        bk = backup_cards()
        print(f"[explorer] Backup créé : {bk}")
        _backup_done = True
    with open(CARDS_PATH, "w") as f:
        json.dump(_cards, f, indent=2, ensure_ascii=False)
    _last_save_time = _try_mtime(CARDS_PATH)
    global _dirty
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
        else:
            self._send_error("Not found", 404)

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path.startswith("/api/card/"):
            cid = int(path.split("/")[-1])
            body = self._read_body()
            for i, c in enumerate(_cards):
                if c["id"] == cid:
                    _cards[i] = body
                    global _dirty
                    _dirty = True
                    self._send({"ok": True, "id": cid})
                    return
            self._send_error("Card not found", 404)
        elif path == "/api/save":
            save_cards()
            self._send({"ok": True})
        else:
            self._send_error("Not found", 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path == "/api/card":
            body = self._read_body()
            if "id" not in body:
                existing = {c["id"] for c in _cards}
                new_id = 1
                while new_id in existing:
                    new_id += 1
                body["id"] = new_id
            _cards.append(body)
            global _dirty
            _dirty = True
            self._send({"ok": True, "id": body["id"]})
        elif path == "/api/save":
            save_cards()
            self._send({"ok": True})
        else:
            self._send_error("Not found", 404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path.startswith("/api/card/"):
            cid = int(path.split("/")[-1])
            for i, c in enumerate(_cards):
                if c["id"] == cid:
                    _cards.pop(i)
                    global _dirty
                    _dirty = True
                    self._send({"ok": True, "id": cid})
                    return
            self._send_error("Card not found", 404)
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
  --bg: #05070d;
  --surface: #0a0e1a;
  --surface-2: #111827;
  --border: #1e2a3a;
  --accent: #4fd6e8;
  --amber: #e8b65a;
  --danger: #d96a5a;
  --green: #5ad96a;
  --ink: #eaf0f8;
  --ink-dim: #8899b0;
  --ink-faint: #55667a;
  --panel: #0d1220;
  --military: #d97a4a;
  --religion: #b98ad6;
  --commerce: #4fd6b8;
  --politics: #7ac87a;
  --radius: 8px;
  --font: system-ui, -apple-system, sans-serif;
  --mono: 'Space Mono', 'Fira Code', monospace;
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
}
a { color: var(--accent); }
input, textarea, select {
  background: var(--surface);
  border: 1px solid var(--border);
  color: var(--ink);
  padding: 5px 8px;
  border-radius: 4px;
  font-family: var(--mono);
  font-size: 12px;
}
textarea {
  font-family: var(--font);
  min-height: 60px;
  line-height: 1.4;
  resize: vertical;
}
input:focus, textarea:focus, select:focus {
  outline: none; border-color: var(--accent); box-shadow: 0 0 0 1px var(--accent);
}
button {
  background: var(--surface-2); color: var(--ink); border: 1px solid var(--border);
  padding: 5px 12px; border-radius: 4px; cursor: pointer; font-size: 12px;
  font-family: var(--mono); transition: all .15s;
}
button:hover { border-color: var(--accent); color: var(--accent); }
button.danger { border-color: var(--danger); color: var(--danger); }
button.danger:hover { background: var(--danger); color: #fff; }
button.primary { background: var(--accent); color: var(--bg); border-color: var(--accent); font-weight: 600; }
button.primary:hover { background: #6de0f0; }
button.small { padding: 2px 8px; font-size: 11px; }

/* Sidebar */
#sidebar {
  width: 220px; min-width: 220px;
  background: var(--surface); border-right: 1px solid var(--border);
  display: flex; flex-direction: column; overflow: hidden;
}
#sidebar h1 {
  font-size: 12px; font-family: var(--mono); padding: 10px 12px;
  border-bottom: 1px solid var(--border); color: var(--accent);
  text-transform: uppercase; letter-spacing: 1px;
}
#sidebar h1 span { color: var(--ink-dim); font-size: 10px; }
#deck-search { margin: 6px 8px; padding: 4px 6px; font-family: var(--font); font-size: 11px; }
#deck-list { flex: 1; overflow-y: auto; padding: 2px 0; }
.deck-item {
  padding: 4px 10px; cursor: pointer; display: flex;
  justify-content: space-between; align-items: center;
  border-left: 3px solid transparent; font-size: 12px;
}
.deck-item:hover { background: var(--surface-2); }
.deck-item.active { border-left-color: var(--accent); background: rgba(79,214,232,.08); }
.deck-item .badge { font-size: 10px; color: var(--ink-faint); font-family: var(--mono); }
.deck-item .badge.h { color: var(--danger); }
.deck-item .badge.w { color: var(--amber); }
.deck-type-label {
  padding: 6px 10px 2px; font-size: 9px; text-transform: uppercase;
  letter-spacing: 1px; color: var(--ink-faint); font-family: var(--mono);
}

/* Main */
#main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
#toolbar {
  display: flex; align-items: center; gap: 6px;
  padding: 6px 10px; border-bottom: 1px solid var(--border); background: var(--surface);
}
#toolbar .title { font-family: var(--mono); font-size: 12px; flex: 1; }
#toolbar .title .sub { color: var(--ink-faint); font-size: 10px; margin-left: 6px; }
#toolbar .actions { display: flex; gap: 4px; }
#content { flex: 1; display: flex; overflow: hidden; }

/* Table */
#card-list { flex: 0 0 55%; overflow: hidden; border-right: 1px solid var(--border); display: flex; flex-direction: column; }
#card-search { margin: 6px 8px 0; padding: 4px 6px; font-family: var(--font); font-size: 11px; }
#card-table-wrap { flex: 1; overflow: auto; }
#card-table { width: 100%; border-collapse: collapse; font-size: 11px; }
#card-table th {
  position: sticky; top: 0; background: var(--surface); z-index: 2;
  padding: 5px 6px; text-align: left; font-family: var(--mono);
  font-size: 9px; text-transform: uppercase; letter-spacing: .5px;
  color: var(--ink-faint); border-bottom: 1px solid var(--border);
  cursor: pointer; white-space: nowrap;
}
#card-table th:hover { color: var(--accent); }
#card-table td { padding: 4px 6px; border-bottom: 1px solid rgba(30,42,58,.3); vertical-align: middle; }
#card-table tr { cursor: pointer; }
#card-table tr:hover td { background: var(--surface-2); }
#card-table tr.active td { background: rgba(79,214,232,.08); }
#card-table .cid { color: var(--ink-faint); font-family: var(--mono); font-size: 10px; width: 50px; }
#card-table .clabel { font-size: 11px; max-width: 160px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
#card-table .cnum { font-family: var(--mono); font-size: 10px; color: var(--ink-dim); text-align: center; }
#card-table .cflags { white-space: nowrap; }
.flag {
  display: inline-block; padding: 0 3px; border-radius: 2px;
  font-family: var(--mono); font-size: 9px; line-height: 14px;
  margin-right: 2px;
}
.flag.h { color: var(--danger); border: 1px solid var(--danger); }
.flag.w { color: var(--amber); border: 1px solid var(--amber); }
.flag.l { color: var(--commerce); border: 1px solid var(--commerce); }
.flag.k { color: var(--amber); border: 1px solid var(--amber); }
.flag.b { color: var(--religion); border: 1px solid var(--religion); }

/* Impact chips */
.impact {
  display: inline-block; font-family: var(--mono); font-size: 9px;
  padding: 1px 4px; border-radius: 3px; margin: 1px;
  white-space: nowrap;
}
.impact.pos { color: var(--green); background: rgba(90,217,106,.1); }
.impact.neg { color: var(--danger); background: rgba(217,106,90,.1); }
.impact.link { color: var(--accent); background: rgba(79,214,232,.1); }
.impact.leg { color: var(--amber); background: rgba(232,182,90,.1); }
.impact.set { color: var(--ink-dim); background: rgba(136,153,176,.1); }

/* Link targets in table */
.link-target { color: var(--accent); font-family: var(--mono); font-size: 9px; }

/* Detail panel */
#card-detail { flex: 0 0 45%; overflow-y: auto; background: var(--bg); }
#card-detail .empty-state {
  display: flex; align-items: center; justify-content: center;
  height: 100%; color: var(--ink-faint); font-family: var(--mono);
  font-size: 12px; text-align: center; padding: 30px;
}
#detail-scroll { padding: 10px 12px; }
.detail-section {
  margin-bottom: 6px; background: var(--panel);
  border-radius: 6px; border: 1px solid var(--border);
}
.detail-section .section-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 7px 10px; cursor: pointer; user-select: none;
}
.detail-section .section-header:hover { background: var(--surface); }
.detail-section .section-header h3 {
  font-size: 10px; text-transform: uppercase; letter-spacing: .5px;
  color: var(--ink-dim); font-family: var(--mono);
}
.detail-section .section-header .arrow { color: var(--ink-faint); font-size: 10px; transition: transform .15s; }
.detail-section.collapsed .section-header .arrow { transform: rotate(-90deg); }
.detail-section .section-body { padding: 6px 10px 10px; border-top: 1px solid var(--border); }
.detail-section.collapsed .section-body { display: none; }

.field-row {
  display: flex; gap: 6px; margin-bottom: 4px; align-items: center; flex-wrap: wrap;
}
.field-row label {
  font-size: 10px; color: var(--ink-faint); min-width: 50px; font-family: var(--mono);
}
.field-row input, .field-row select { flex: 1; min-width: 50px; font-size: 11px; }
.field-row input.chk { flex: none; width: auto; }

.array-item {
  background: var(--surface); border: 1px solid var(--border);
  border-radius: 4px; padding: 5px 6px; margin-bottom: 3px; position: relative;
}
.array-item .del {
  position: absolute; right: 3px; top: 3px; background: none; border: none;
  color: var(--danger); cursor: pointer; font-size: 12px; line-height: 1; padding: 1px 3px;
}
.array-item .row { display: flex; gap: 3px; margin: 2px 0; align-items: center; flex-wrap: wrap; }
.array-item .row input, .array-item .row select { flex: 1; min-width: 40px; font-size: 10px; }
.array-item .row input.num { flex: 0 0 50px; }
.array-item .row label { font-size: 9px; color: var(--ink-faint); min-width: 30px; font-family: var(--mono); }
.add-btn { font-size: 10px; padding: 2px 8px; margin-top: 3px; }

.locale-field { display: flex; gap: 4px; flex: 1; }
.locale-field textarea { flex: 1; font-size: 11px; min-height: 50px; font-family: var(--font); }
.locale-field input.locale-short { flex: 1; font-size: 11px; }

/* Graph */
#graph-view {
  flex: 1; overflow: hidden; background: var(--bg); position: relative;
}
#graph-canvas {
  width: 100%; height: 100%; cursor: grab; overflow: hidden;
}
#graph-canvas:active { cursor: grabbing; }
#graph-canvas svg { display: block; }
.graph-card { cursor: pointer; transition: opacity .15s; }
.graph-card:hover { opacity: .7; }
.graph-card rect { rx: 4; ry: 4; }
.graph-card .gid { font-family: var(--mono); font-size: 7px; fill: var(--ink-faint); }
.graph-card .glabel { font-family: var(--font); font-size: 8px; fill: var(--ink); font-weight: 600; }
.graph-arrow { stroke-width: 1; fill: none; }
.graph-arrow.yes { stroke: #5ad96a; }
.graph-arrow.no { stroke: #d96a5a; }
.graph-arrow.load { stroke: #4fd6e8; }
.graph-alabel { font-family: var(--mono); font-size: 7px; fill: var(--ink-faint); }
.graph-toolbar {
  position: absolute; top: 8px; right: 8px; display: flex; gap: 4px; z-index: 10;
}
.graph-toolbar button {
  width: 28px; height: 28px; padding: 0; font-size: 14px; line-height: 1;
  display: flex; align-items: center; justify-content: center;
  background: var(--surface); border: 1px solid var(--border); color: var(--ink);
  border-radius: 4px; cursor: pointer;
}
.graph-toolbar button:hover { border-color: var(--accent); color: var(--accent); }
.graph-empty {
  display: flex; align-items: center; justify-content: center;
  height: 100%; color: var(--ink-faint); font-family: var(--mono);
  font-size: 12px; text-align: center; padding: 40px;
}

/* Context menu */
#graph-context-menu {
  position: fixed; z-index: 999; min-width: 160px;
  background: var(--surface-2); border: 1px solid var(--border);
  border-radius: 6px; padding: 3px 0; display: none;
  box-shadow: 0 4px 16px rgba(0,0,0,.5);
}
#graph-context-menu .ctx-item {
  padding: 5px 12px; cursor: pointer; font-size: 11px;
  font-family: var(--font); color: var(--ink); transition: background .1s;
}
#graph-context-menu .ctx-item:hover { background: var(--accent); color: var(--bg); }
#graph-context-menu .ctx-item.danger:hover { background: var(--danger); color: #fff; }
#graph-context-menu .ctx-sep {
  height: 1px; background: var(--border); margin: 3px 0;
}

/* Link mode */
.graph-link-source { outline: 2px dashed var(--amber); outline-offset: 2px; }
.graph-link-target { cursor: crosshair !important; }
.graph-link-target:hover rect { stroke: var(--amber) !important; stroke-width: 2 !important; }
.link-mode-active .graph-toolbar button.link-toggle { background: var(--amber); color: var(--bg); border-color: var(--amber); }
.graph-edge { cursor: pointer; }
.graph-edge:hover path { stroke-width: 2.5 !important; }
.graph-edge .edge-hit { fill: transparent; stroke: transparent; stroke-width: 12; cursor: pointer; }

/* Highlight on outcome navigation */
.outcome-highlight { animation: outcomeFlash .8s ease 3; }
@keyframes outcomeFlash {
  0%, 100% { box-shadow: 0 0 0 transparent; }
  50% { box-shadow: 0 0 8px rgba(79,214,232,.6); }
}

/* Layout: graph primary */
#content { flex: 1; display: flex; overflow: hidden; position: relative; }
#graph-layout { flex: 1; display: flex; overflow: hidden; position: relative; }
#table-layout { flex: 1; display: flex; overflow: hidden; }
#graph-view { flex: 1; overflow: hidden; background: var(--bg); position: relative; min-width: 0; }

/* Card panel (slides in from right on graph) */
#graph-card-panel {
  width: 420px; min-width: 420px;
  background: var(--bg); border-left: 1px solid var(--border);
  display: flex; flex-direction: column; overflow: hidden;
  animation: panelSlideIn .2s ease;
}
@keyframes panelSlideIn {
  from { width: 0; min-width: 0; opacity: 0; }
  to { width: 420px; min-width: 420px; opacity: 1; }
}
#graph-panel-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 6px 10px; border-bottom: 1px solid var(--border);
  background: var(--surface);
}
#graph-panel-header span { font-family: var(--mono); font-size: 11px; color: var(--accent); }
#graph-panel-header button { font-size: 11px; padding: 2px 8px; }
#graph-panel-body { flex: 1; overflow-y: auto; padding: 8px 10px; }

/* Source selector */
#source-select {
  background: var(--surface); border: 1px solid var(--border);
  color: var(--ink); padding: 3px 6px; border-radius: 4px;
  font-family: var(--mono); font-size: 10px; cursor: pointer;
}
#source-select:focus { outline: none; border-color: var(--accent); }

/* Reader layout */
#reader-layout { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
#reader-toolbar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 6px 12px; border-bottom: 1px solid var(--border);
  background: var(--surface);
}
#reader-progress { font-family: var(--mono); font-size: 11px; color: var(--ink-dim); }
.reader-actions { display: flex; gap: 4px; }
.reader-actions button { font-size: 10px; padding: 3px 10px; font-family: var(--mono); }
#reader-card {
  flex: 1; overflow-y: auto; padding: 8px 20px 40px; max-width: 720px; margin: 0 auto;
}
#reader-card .reader-card-box:first-child { margin-top: 4px; }
.reader-empty {
  display: flex; align-items: center; justify-content: center;
  height: 200px; color: var(--ink-faint); font-family: var(--mono); font-size: 13px;
}
.reader-card-box {
  background: var(--panel); border: 1px solid var(--border); border-radius: 10px;
  padding: 16px 20px; margin: 6px 0;
}
.reader-card-box:hover { border-color: var(--accent); }
.reader-card-box .rc-header {
  display: flex; gap: 8px; align-items: center; margin-bottom: 12px;
  font-family: var(--mono); font-size: 10px; color: var(--ink-faint);
}
.reader-card-box .rc-header .rc-id { color: var(--accent); font-size: 12px; }
.reader-card-box .rc-header .rc-label { color: var(--ink); font-size: 11px; font-weight: 600; }
.reader-question {
  font-family: 'Spectral', serif; font-size: 17px; line-height: 1.5;
  color: var(--ink); padding: 8px 0 12px; border-bottom: 1px solid var(--border);
  margin-bottom: 12px;
}
.reader-question .rc-en { font-size: 12px; color: var(--ink-faint); margin-top: 4px; }
.reader-choice {
  padding: 10px 12px; margin: 6px 0; border-radius: 6px;
  border-left: 3px solid var(--border);
}
.reader-choice.left { border-left-color: var(--accent); background: rgba(79,214,232,.04); }
.reader-choice.right { border-left-color: var(--amber); background: rgba(232,182,90,.04); }
.reader-choice .rc-ctitle { font-weight: 600; font-size: 13px; color: var(--ink); }
.reader-choice .rc-creaction { font-style: italic; font-size: 12px; color: var(--ink-dim); margin: 2px 0; }
.reader-choice .rc-coutcomes { font-size: 10px; margin-top: 3px; }
.reader-meta {
  display: flex; flex-wrap: wrap; gap: 4px 12px; margin-top: 12px;
  padding-top: 10px; border-top: 1px solid var(--border);
  font-size: 10px; color: var(--ink-faint); font-family: var(--mono);
}
.reader-meta span { background: var(--surface); padding: 1px 6px; border-radius: 3px; }
.reader-meta .cond { color: var(--accent); }
.reader-meta .link { color: var(--amber); }
.reader-meta .impact-pos { color: var(--green); }
.reader-meta .impact-neg { color: var(--danger); }

/* Toast */
.toast {
  position: fixed; bottom: 16px; right: 16px; padding: 8px 14px; border-radius: 6px;
  font-family: var(--mono); font-size: 11px; z-index: 999;
  animation: fadeInUp .25s ease; pointer-events: none;
}
.toast.success { background: var(--green); color: var(--bg); }
.toast.error { background: var(--danger); color: #fff; }
.toast.info { background: var(--surface-2); border: 1px solid var(--border); color: var(--ink); }
@keyframes fadeInUp { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }

::-webkit-scrollbar { width: 5px; height: 5px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
</style>
</head>
<body>

<div id="sidebar">
  <h1>Narrative <span>Explorer</span></h1>
  <input id="deck-search" placeholder="Filtrer decks…">
  <div id="deck-list"></div>
</div>

<div id="main">
  <div id="toolbar">
    <div class="title"><span id="toolbar-title">Sélectionnez un deck</span><span class="sub" id="toolbar-sub"></span></div>
    <div class="actions">
      <select id="source-select" onchange="switchSource(this.value)" title="Source de données">
        <option value="foundation">📜 Foundation</option>
        <option value="reference">📖 Reigns TK</option>
      </select>
      <button class="small" onclick="toggleReaderView()" id="btn-reader-view">📖 Lecteur</button>
      <button class="small" onclick="toggleTableView()" id="btn-table-view">📋 Tableau</button>
      <button class="small" onclick="saveAll()" id="btn-save" disabled>💾 Sauvegarder</button>
      <button class="small" onclick="addCard()">+ Carte</button>
    </div>
  </div>
  <div id="content">
    <div id="graph-layout">
      <div id="graph-view"></div>
      <div id="graph-card-panel" style="display:none">
        <div id="graph-panel-header">
          <span id="graph-panel-title">Carte</span>
          <button class="small" onclick="closeCardPanel()">✕</button>
        </div>
        <div id="graph-panel-body"></div>
      </div>
    </div>
    <div id="table-layout" style="display:none">
      <div id="card-list">
        <input id="card-search" placeholder="Filtrer les cartes…">
        <div id="card-table-wrap">
          <table id="card-table">
            <thead><tr>
              <th onclick="sortBy('id')" data-sort="id">#</th>
              <th onclick="sortBy('label')" data-sort="label">Label</th>
              <th onclick="sortBy('weight')" data-sort="weight">W</th>
              <th onclick="sortBy('lockturn')" data-sort="lockturn">L</th>
              <th>Flags</th>
              <th>Impacts</th>
              <th>Liens</th>
            </tr></thead>
            <tbody id="card-tbody"></tbody>
          </table>
        </div>
      </div>
      <div id="card-detail">
        <div class="empty-state">Sélectionnez un deck à gauche<br>puis une carte dans la liste</div>
      </div>
    </div>
    <div id="reader-layout" style="display:none">
      <div id="reader-toolbar">
        <span id="reader-progress">—</span>
        <span id="reader-count" style="font-family:var(--mono);font-size:10px;color:var(--ink-faint)"></span>
      </div>
      <div id="reader-card">
        <div class="reader-empty">Sélectionnez un deck pour lire les cartes</div>
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
  // Graph is the default view
  document.getElementById('graph-layout').style.display = 'flex';
  document.getElementById('table-layout').style.display = 'none';
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
    const d = allDecks[name];
    const p = name.startsWith('crisis_') ? '\u2694 Crise' : name.startsWith('planet_') ? '\uD83C\uDF10 Plan\u00e8te' : '\uD83D\uDCE6 Deck';
    if (p !== last) { html += '<div class="deck-type-label">' + p + '</div>'; last = p; }
    const w = [];
    if (d.hidden > 0) w.push('<span class="badge h">' + d.hidden + 'H</span>');
    if (d.neg_weight > 0) w.push('<span class="badge w">' + d.neg_weight + 'W-</span>');
    html += '<div class="deck-item' + (name === selectedDeck ? ' active' : '') + '" onclick="selectDeck(\'' + name + '\')">'
      + '<span>' + name + '</span><span>' + w.join(' ') + ' <span class="badge">' + d.count + '</span></span></div>';
  }
  document.getElementById('deck-list').innerHTML = html;
}
document.getElementById('deck-search').addEventListener('input', e => renderDecks(e.target.value));

// === Deck Selection ===
async function selectDeck(name) {
  selectedDeck = name; selectedCard = null;
  renderDecks(document.getElementById('deck-search').value);
  document.getElementById('toolbar-title').textContent = name;
  document.getElementById('toolbar-sub').textContent = allDecks[name].count + ' cartes';
  const cardsData = await fetchCardsForDeck(name);
  window._deckCards = cardsData;
  renderTable(cardsData);
  document.getElementById('card-detail').innerHTML = '<div class="empty-state">S\u00e9lectionnez une carte</div>';
  // Default to graph view (or reader if active)
  if (_readerView) {
    document.getElementById('graph-layout').style.display = 'none';
    document.getElementById('table-layout').style.display = 'none';
    document.getElementById('reader-layout').style.display = 'flex';
    loadReaderCards();
  } else {
    document.getElementById('graph-layout').style.display = 'flex';
    document.getElementById('table-layout').style.display = 'none';
    closeCardPanel();
    renderGraph();
  }
}

// === Table ===
function renderTable(cards) {
  cards = cards || window._deckCards || [];
  const q = (document.getElementById('card-search').value || '').toLowerCase();
  if (q) cards = cards.filter(c => (c.label||'').toLowerCase().includes(q) || String(c.id).includes(q));
  cards.sort((a,b) => {
    const va = a[sortField] || 0, vb = b[sortField] || 0;
    return sortAsc ? (va > vb ? 1 : -1) : (va < vb ? 1 : -1);
  });
  let html = '';
  for (const c of cards) {
    const flags = [];
    if (c.hidden) flags.push('<span class="flag h">H</span>');
    if ((c.weight||1) < 0) flags.push('<span class="flag w">W-</span>');
    if (c.lockturn) flags.push('<span class="flag l">L' + c.lockturn + '</span>');
    if (c.key) flags.push('<span class="flag k">Cl\u00e9</span>');
    if (c.bearer) flags.push('<span class="flag b">' + c.bearer + '</span>');
    html += '<tr class="' + (selectedCard === c.id ? 'active' : '') + '" onclick="selectCard(' + c.id + ')">'
      + '<td class="cid">#' + c.id + '</td>'
      + '<td class="clabel">' + escHtml(c.label || '') + '</td>'
      + '<td class="cnum">' + (c.weight || 1) + '</td>'
      + '<td class="cnum">' + (c.lockturn || 0) + '</td>'
      + '<td class="cflags">' + flags.join('') + '</td>'
      + '<td>' + renderImpacts(c) + '</td>'
      + '<td>' + renderLinks(c) + '</td></tr>';
  }
  document.getElementById('card-tbody').innerHTML = html;
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
    + '<div class="detail-section" style="border-color:var(--accent)">' + sectionHeader('\U0001F464 Identit\u00e9') 
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

    + '<div class="detail-section" style="border-color:var(--danger)">' + sectionHeader('\U0001F5D1 Zone dangereuse')
    + '<button class="danger" onclick="deleteCard(' + card.id + ')">Supprimer cette carte</button>'
    + '</div></div>'

    + '</div>';
  renderArrayItems(card, 'conditions');
  renderArrayItems(card, 'loadOutcome');
  renderArrayItems(card, 'yesOutcome');
  renderArrayItems(card, 'noOutcome');
}

function escHtml(s) { if (s == null) return ''; return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

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
    fetch('/api/card/' + cardId, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(card) });
    autoSaveTimer = null;
  }, 500);
}
async function saveAll() {
  for (const card of allCards)
    await fetch('/api/card/' + card.id, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(card) });
  await fetch('/api/save', { method: 'POST' }); markClean(); toast('Sauvegard\u00e9e \u2705', 'success');
}

// === Reader view ===
let _readerCards = [];
let _readerIndex = 0;
let _readerView = false;

function toggleReaderView() {
  _readerView = !_readerView;
  document.getElementById('graph-layout').style.display = _readerView ? 'none' : 'flex';
  document.getElementById('table-layout').style.display = 'none';
  document.getElementById('reader-layout').style.display = _readerView ? 'flex' : 'none';
  document.getElementById('btn-reader-view').textContent = _readerView ? '🕸️ Graphe' : '📖 Lecteur';
  if (_readerView && selectedDeck) loadReaderCards();
}

async function loadReaderCards() {
  const deck = selectedDeck;
  if (!deck) { document.getElementById('reader-card').innerHTML = '<div class="reader-empty">Sélectionnez un deck</div>'; return; }
  const cards = await fetchCardsForDeck(deck);
  // Sort by id for Foundation, by _refNodeIndex for reference
  if (currentSource === 'reference') {
    cards.sort((a, b) => (a._refNodeIndex||0) - (b._refNodeIndex||0));
  } else {
    cards.sort((a, b) => a.id - b.id);
  }
  _readerCards = cards;
  const total = cards.length;
  document.getElementById('reader-progress').textContent = deckLabel(selectedDeck);
  document.getElementById('reader-count').textContent = total + ' cartes';
  // Render all cards in one continuous scroll
  const html = cards.map((card, i) => buildReaderCardHTML(card, i, total)).join('<hr style="border:none;border-top:1px solid var(--border);margin:4px 0">');
  document.getElementById('reader-card').innerHTML = html;
}

function deckLabel(name) {
  return name || '?';
}

function buildReaderCardHTML(card, idx, total) {
  const FR = (s) => s?.FR || '';
  const EN = (s) => s?.EN || '';
  const qFR = FR(card.question);
  const qEN = EN(card.question);
  const leftTitle = FR(card.leftAnswer?.title);
  const leftReaction = FR(card.leftAnswer?.reaction);
  const rightTitle = FR(card.rightAnswer?.title);
  const rightReaction = FR(card.rightAnswer?.reaction);

  // Outcome chips
  function renderOutcomes(outcomes, cls) {
    if (!outcomes || !outcomes.length) return '';
    return outcomes.map(o => {
      const v = o.variable || '?';
      const val = o.intValue || 0;
      if (v === 'link') return '<span class="link">→ #' + val + '</span>';
      const sign = val >= 0 ? '+' : '';
      const op = o.addOperation !== false ? sign + val : '=' + val;
      const pcls = val > 0 ? 'impact-pos' : val < 0 ? 'impact-neg' : '';
      return '<span class="' + pcls + '">' + v + ' ' + op + '</span>';
    }).join(' ');
  }

  // Conditions
  const conds = (card.conditions||[]).map(c => '<span class="cond">' + (c.variable||'') + ' ' + (c.op||'') + ' ' + (c.value||'') + '</span>').join(' ');

  // Links from all outcomes
  const links = [];
  for (const key of ['yesOutcome','noOutcome','loadOutcome']) {
    for (const o of (card[key]||[])) {
      if (o.variable === 'link' && o.intValue) {
        const target = _readerCards.find(c => c.id === o.intValue);
        const tLabel = target ? '#' + target.id + ' ' + (target.label||'').substring(0, 20) : '#' + o.intValue;
        links.push('<span class="link">' + key.replace('Outcome','') + ' → ' + tLabel + '</span>');
      }
    }
  }

  const moods = card.moods || {};
  const moodStr = 'D:' + (moods.default||'neutral') + ' Y:' + (moods.yes||'neutral') + ' N:' + (moods.no||'neutral');

  return '<div class="reader-card-box">'
    + '<div class="rc-header">'
    + '<span class="rc-id">#' + card.id + '</span>'
    + '<span class="rc-label">' + escHtml(card.label||'') + '</span>'
    + '<span>W:' + (card.weight||1) + '</span>'
    + '<span>L:' + (card.lockturn||0) + '</span>'
    + (card.hidden ? '<span style="color:var(--danger)">CACHÉE</span>' : '')
    + (card.key ? '<span style="color:var(--amber)">CLÉ</span>' : '')
    + '</div>'

    + '<div class="reader-question">'
    + escHtml(qFR)
    + (qEN ? '<div class="rc-en">' + escHtml(qEN) + '</div>' : '')
    + '</div>'

    + '<div class="reader-choice left">'
    + '<div class="rc-ctitle">◀ ' + escHtml(leftTitle || 'Gauche') + '</div>'
    + (leftReaction ? '<div class="rc-creaction">' + escHtml(leftReaction) + '</div>' : '')
    + '<div class="rc-coutcomes">' + renderOutcomes(card.yesOutcome) + '</div>'
    + '</div>'

    + '<div class="reader-choice right">'
    + '<div class="rc-ctitle">' + escHtml(rightTitle || 'Droite') + ' ▶</div>'
    + (rightReaction ? '<div class="rc-creaction">' + escHtml(rightReaction) + '</div>' : '')
    + '<div class="rc-coutcomes">' + renderOutcomes(card.noOutcome) + '</div>'
    + '</div>'

    + (conds ? '<div class="reader-meta"><span>Conditions:</span> ' + conds + '</div>' : '')
    + '<div class="reader-meta">'
    + '<span>Moods:</span> ' + moodStr
    + (links.length ? ' <span>Liens:</span> ' + links.join(' ') : '')
    + (card.loadOutcome?.length ? ' <span>Load:</span> ' + renderOutcomes(card.loadOutcome) : '')
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
  selectedDeck = null;
  selectedCard = null;
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
  document.getElementById('graph-layout').style.display = _tableView ? 'none' : 'flex';
  document.getElementById('table-layout').style.display = _tableView ? 'flex' : 'none';
  document.getElementById('btn-table-view').textContent = _tableView ? '🕸️ Graphe' : '📋 Tableau';
  if (!_tableView && selectedDeck) renderGraph();
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
    + '<div class="detail-section" style="border-color:var(--accent)"><div class="section-header"><h3>\U0001F464 Identité</h3></div><div class="section-body">'
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
    if (rl !== ol) html += '<div style="color:var(--accent)">\U0001F4E5 ' + key + ': ' + rl + ' (ref) vs ' + ol + ' (ici)</div>';
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
  const CW = 130, CH = 40, GX = 40, GY = 16;
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
    + '<rect width="100%" height="100%" fill="#05070d"/>';

  // Arrow markers
  svg += '<defs>';
  for (const [cls, color] of [['yes','#5ad96a'],['no','#d96a5a'],['load','#4fd6e8']]) {
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
    const cls = e.label === 'yes' ? 'yes' : e.label === 'no' ? 'no' : 'load';
    const d = 'M' + x1 + ',' + y1 + ' C' + ((x1+x2)/2) + ',' + y1 + ' ' + ((x1+x2)/2) + ',' + y2 + ' ' + x2 + ',' + y2;
    const mx = (x1 + x2) / 2, my = (y1 + y2) / 2 - 8;
    svg += '<g class="graph-edge" onclick="event.stopPropagation();navigateEdge(' + e.from + ',' + (e.outcomeIdx||0) + ',\'' + (e.outcomeKey||'load') + '\')">'
      + '<path class="graph-arrow ' + cls + '" d="' + d + '" marker-end="url(#gm-' + cls + ')"/>'
      + '<path class="edge-hit" d="' + d + '"/>'
      + '<rect x="' + (mx-10) + '" y="' + (my-6) + '" width="20" height="12" rx="2" fill="#0a0e1a" opacity=".85"/>'
      + '<text class="graph-alabel" x="' + mx + '" y="' + (my+3) + '" text-anchor="middle">' + e.label + '</text>'
      + '</g>';
  }

  // Card boxes
  for (const n of data.nodes) {
    const pos = positions[n.id];
    if (!pos) continue;
    const card = fullCards[n.id] || {};
    const isHidden = n.hidden;
    const highlight = n.id === selectedCard;
    const isLinkSource = _linkMode && _linkMode.sourceId === n.id;
    const fill = isHidden ? '#1a0a0a' : highlight ? 'rgba(79,214,232,.12)' : isLinkSource ? 'rgba(232,182,90,.15)' : '#0d1220';
    const stroke = isHidden ? '#d96a5a' : highlight ? '#4fd6e8' : isLinkSource ? '#e8b65a' : '#1e2a3a';
    const label = card.label || n.label || 'card_' + n.id;
    const extraClass = _linkMode && _linkMode.sourceId !== n.id ? ' graph-link-target' : '';
    svg += '<g class="graph-card' + extraClass + '" onclick="event.stopPropagation();graphCardClick(' + n.id + ')" oncontextmenu="event.preventDefault();event.stopPropagation();showGraphContextMenu(event,' + n.id + ')">'
      + '<rect x="' + pos.x + '" y="' + pos.y + '" width="' + CW + '" height="' + CH + '" fill="' + fill + '" stroke="' + stroke + '" stroke-width="' + (highlight||isLinkSource?1.5:1) + '"/>'
      + '<text class="gid" x="' + (pos.x+6) + '" y="' + (pos.y+12) + '">#' + n.id + '</text>'
      + '<text class="glabel" x="' + (pos.x+6) + '" y="' + (pos.y+26) + '" dominant-baseline="middle">' + escHtml(label.substring(0, 22)) + '</text>'
      + '</g>';
  }

  svg += '</svg>';

  // Build interactive canvas
  container.innerHTML = ''
    + '<div class="graph-toolbar">'
    + '<button onclick="graphZoom(1.3)" title="Zoom +">+</button>'
    + '<button onclick="graphZoom(0.7)" title="Zoom -">-</button>'
    + '<button onclick="graphFit()" title="Ajuster">\u229E</button>'
    + '<button class="link-toggle" onclick="toggleLinkMode()" title="Mode lien" style="' + (_linkMode ? 'background:var(--amber);color:var(--bg);border-color:var(--amber)' : '') + '">\uD83D\uDD17</button>'
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
  if (currentSource === 'reference') {
    // In reference mode, show in graph panel
    selectedCard = id;
    await showCardPanelInGraph(id);
    return;
  }
  // In foundation mode: show in graph panel for quick view
  selectedCard = id;
  await showCardPanelInGraph(id);
  // Also select in table if visible
  if (_tableView) {
    await selectCard(id);
  }
  // Highlight in graph
  renderGraph();
  const el = document.getElementById('card-item-' + id);
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
    // Enter link mode with this card as source
    _linkMode = { sourceId: _contextCardId, sourceLabel: (getCard(_contextCardId)||{}).label || '' + _contextCardId };
    renderGraph();
    toast('🔗 Mode lien: cliquez sur la cible depuis #' + _contextCardId + ' ' + _linkMode.sourceLabel, 'info');
  }
  hideGraphContextMenu();
}

// === Link mode ===
function toggleLinkMode() {
  if (_linkMode) {
    _linkMode = null;
    renderGraph();
    toast('Mode lien désactivé', 'info');
  } else {
    toast('Cliquez sur une carte source dans le graphe', 'info');
    // Wait for a card click — use a prompt approach
    // Set a flag so next card click enters link mode
    // Actually: the user should right-click a card and choose "Ajouter un lien"
    // Button click alone: show instruction
  }
}

function addLink(sourceId, targetId) {
  const card = getCard(sourceId);
  if (!card) return;
  if (!card.yesOutcome) card.yesOutcome = [];
  // Check if this link already exists
  const exists = card.yesOutcome.some(o => o.variable === 'link' && o.intValue === targetId);
  if (exists) {
    toast('⚠️ Ce lien existe déjà', 'error');
    return;
  }
  card.yesOutcome.push({
    variable: 'link',
    intValue: targetId,
    addOperation: false,
    toKeep: false
  });
  scheduleAutoSave(sourceId);
  toast('🔗 Lien #' + sourceId + ' → #' + targetId + ' ajouté', 'success');
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
    print(f"\n  🌐 http://localhost:{PORT}")
    print(f"  ⏎  Ctrl+C pour quitter\n")

    if not args.no_watch:
        start_file_watcher()
        print(f"  👁️  Hot reload actif (fichier JSON surveillé)\n")

    server = HTTPServer(("0.0.0.0", PORT), NarrativeAPI)
    try:
        webbrowser.open(f"http://localhost:{PORT}")
        server.serve_forever()
    except KeyboardInterrupt:
        _watcher_stop.set()
        if _dirty:
            print("\n  ⚠️  Modifications non sauvegardées ! Utilisez le bouton 💾 dans l'interface.")
        print("\n  👋 Au revoir\n")
        server.server_close()


if __name__ == "__main__":
    main()
