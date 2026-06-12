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
import webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")
CARDS_PATH = os.path.join(DATA_DIR, "foundation_cards.json")
ALIASES_PATH = os.path.join(DATA_DIR, "link_aliases.json")
CHARACTERS_PATH = os.path.join(DATA_DIR, "characters.json")
PORT = 8080

_cards = []
_link_aliases = {}
_characters = {}
_dirty = False


def load_data():
    global _cards, _link_aliases, _characters
    def _load(p):
        with open(p) as f:
            return json.load(f)
    _cards = _load(CARDS_PATH)
    _link_aliases = _load(ALIASES_PATH)
    _characters = _load(CHARACTERS_PATH)


_backup_done = False

def save_cards():
    global _backup_done
    if not _backup_done:
        bk = backup_cards()
        print(f"[explorer] Backup créé : {bk}")
        _backup_done = True
    with open(CARDS_PATH, "w") as f:
        json.dump(_cards, f, indent=2, ensure_ascii=False)
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
            for o in out_list:
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
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
input, textarea, select {
  background: var(--surface);
  border: 1px solid var(--border);
  color: var(--ink);
  padding: 4px 8px;
  border-radius: 4px;
  font-family: var(--mono);
  font-size: 12px;
}
textarea { font-family: var(--font); resize: vertical; min-height: 28px; }
input:focus, textarea:focus, select:focus {
  outline: none;
  border-color: var(--accent);
  box-shadow: 0 0 0 1px var(--accent);
}
button {
  background: var(--surface-2);
  color: var(--ink);
  border: 1px solid var(--border);
  padding: 5px 12px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  font-family: var(--mono);
  transition: all .15s;
}
button:hover { border-color: var(--accent); color: var(--accent); }
button.danger { border-color: var(--danger); color: var(--danger); }
button.danger:hover { background: var(--danger); color: #fff; }
button.primary {
  background: var(--accent);
  color: var(--bg);
  border-color: var(--accent);
  font-weight: 600;
}
button.primary:hover { background: #6de0f0; }
button.small { padding: 2px 8px; font-size: 11px; }

/* Layout */
#sidebar {
  width: 240px;
  min-width: 240px;
  background: var(--surface);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
#sidebar h1 {
  font-size: 13px;
  font-family: var(--mono);
  padding: 12px 14px;
  border-bottom: 1px solid var(--border);
  color: var(--accent);
  text-transform: uppercase;
  letter-spacing: 1px;
}
#sidebar h1 span { color: var(--ink-dim); font-size: 11px; }
#deck-search {
  margin: 8px 10px;
  padding: 5px 8px;
  font-family: var(--font);
}
#deck-list {
  flex: 1;
  overflow-y: auto;
  padding: 4px 0;
}
.deck-item {
  padding: 6px 14px;
  cursor: pointer;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-left: 3px solid transparent;
  transition: all .1s;
}
.deck-item:hover { background: var(--surface-2); }
.deck-item.active {
  border-left-color: var(--accent);
  background: rgba(79,214,232,.08);
}
.deck-item .name { font-size: 12px; }
.deck-item .badge {
  font-size: 10px;
  color: var(--ink-faint);
  font-family: var(--mono);
}
.deck-item .badge.hidden { color: var(--danger); }
.deck-item .badge.neg { color: var(--amber); }
.deck-type-label {
  padding: 8px 14px 4px;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--ink-faint);
  font-family: var(--mono);
}

/* Main content */
#main {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
#toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 14px;
  border-bottom: 1px solid var(--border);
  background: var(--surface);
}
#toolbar .title {
  font-family: var(--mono);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: .5px;
  flex: 1;
}
#toolbar .title .sub { color: var(--ink-faint); font-size: 11px; }
#toolbar .actions { display: flex; gap: 6px; }
#content {
  flex: 1;
  display: flex;
  overflow: hidden;
}

/* Card list */
#card-list {
  width: 340px;
  min-width: 340px;
  overflow-y: auto;
  border-right: 1px solid var(--border);
  padding: 4px;
}
.card-item {
  padding: 6px 10px;
  cursor: pointer;
  border-radius: 4px;
  margin: 1px 0;
  border-left: 3px solid transparent;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 6px;
}
.card-item:hover { background: var(--surface-2); }
.card-item.active { border-left-color: var(--accent); background: rgba(79,214,232,.08); }
.card-item .cid { color: var(--ink-faint); font-family: var(--mono); font-size: 11px; min-width: 40px; }
.card-item .clabel { flex: 1; font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.card-item .cflags { display: flex; gap: 3px; font-size: 10px; }
.card-item .flag {
  padding: 0 4px;
  border-radius: 2px;
  font-family: var(--mono);
}
.card-item .flag.h { color: var(--danger); border: 1px solid var(--danger); }
.card-item .flag.w { color: var(--amber); border: 1px solid var(--amber); }
.card-item .flag.l { color: var(--commerce); border: 1px solid var(--commerce); }

/* Card detail */
#card-detail {
  flex: 1;
  overflow-y: auto;
  padding: 16px 20px;
}
#card-detail .empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--ink-faint);
  font-family: var(--mono);
  font-size: 13px;
  text-align: center;
  padding: 40px;
}
.detail-section {
  margin-bottom: 16px;
  background: var(--panel);
  border-radius: var(--radius);
  padding: 12px 14px;
  border: 1px solid var(--border);
}
.detail-section h3 {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--ink-faint);
  font-family: var(--mono);
  margin-bottom: 8px;
  padding-bottom: 6px;
  border-bottom: 1px solid var(--border);
}
.field-row {
  display: flex;
  gap: 8px;
  margin-bottom: 6px;
  align-items: center;
  flex-wrap: wrap;
}
.field-row label {
  font-size: 11px;
  color: var(--ink-dim);
  min-width: 70px;
  font-family: var(--mono);
}
.field-row input, .field-row select { flex: 1; min-width: 60px; }
.field-row input.chk { flex: none; width: auto; }
.field-row .val {
  font-size: 12px;
  color: var(--ink-dim);
  font-family: var(--mono);
}
.array-item {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 6px 8px;
  margin-bottom: 4px;
  position: relative;
}
.array-item .del {
  position: absolute;
  right: 4px;
  top: 4px;
  background: none;
  border: none;
  color: var(--danger);
  cursor: pointer;
  font-size: 14px;
  line-height: 1;
  padding: 2px 4px;
}
.array-item .del:hover { color: #ff8a7a; }
.array-item .row { display: flex; gap: 4px; margin: 2px 0; align-items: center; flex-wrap: wrap; }
.array-item .row input, .array-item .row select { flex: 1; min-width: 50px; font-family: var(--font); font-size: 11px; }
.array-item .row input.small { flex: 0 0 60px; }
.array-item .row label { font-size: 10px; color: var(--ink-faint); min-width: 40px; font-family: var(--mono); }
.add-btn {
  font-size: 11px;
  padding: 2px 10px;
  margin-top: 4px;
}

/* Locale field (FR/EN) */
.locale-field { display: flex; gap: 4px; flex: 1; }
.locale-field input { flex: 1; }

/* Graph tab */
#graph-view {
  flex: 1;
  position: relative;
  overflow: hidden;
}
#graph-view svg {
  width: 100%;
  height: 100%;
}
.graph-node {
  cursor: pointer;
  transition: opacity .15s;
}
.graph-node:hover { opacity: .7; }
.graph-node text {
  font-size: 10px;
  fill: var(--ink-dim);
  font-family: var(--mono);
  pointer-events: none;
}
.graph-link { stroke-width: 2; fill: none; opacity: .5; }
.graph-link:hover { opacity: 1; }
.graph-link-label {
  font-size: 9px;
  fill: var(--ink-faint);
  font-family: var(--mono);
}

/* Tabs */
.tabs {
  display: flex;
  gap: 0;
  border-bottom: 1px solid var(--border);
  padding: 0 14px;
  background: var(--surface);
}
.tab {
  padding: 8px 16px;
  cursor: pointer;
  font-size: 11px;
  font-family: var(--mono);
  text-transform: uppercase;
  letter-spacing: .5px;
  color: var(--ink-dim);
  border-bottom: 2px solid transparent;
  transition: all .15s;
}
.tab:hover { color: var(--ink); }
.tab.active { color: var(--accent); border-bottom-color: var(--accent); }
.tab-content { display: none; flex: 1; overflow: hidden; }
.tab-content.active { display: flex; }

/* Toast */
.toast {
  position: fixed;
  bottom: 20px;
  right: 20px;
  padding: 10px 18px;
  border-radius: 6px;
  font-family: var(--mono);
  font-size: 12px;
  z-index: 999;
  animation: fadeInUp .3s ease;
  pointer-events: none;
}
.toast.success { background: var(--green); color: var(--bg); }
.toast.error { background: var(--danger); color: #fff; }
.toast.info { background: var(--surface-2); border: 1px solid var(--border); color: var(--ink); }
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

/* Scrollbar */
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: var(--ink-faint); }

/* JSON viewer */
.json-preview {
  font-family: var(--mono);
  font-size: 11px;
  color: var(--ink-dim);
  white-space: pre-wrap;
  background: var(--surface);
  padding: 8px;
  border-radius: 4px;
  max-height: 200px;
  overflow-y: auto;
  margin-top: 4px;
}

/* Outcome editor adapters */
.resource-tag {
  display: inline-block;
  font-size: 10px;
  padding: 0 5px;
  border-radius: 3px;
  font-family: var(--mono);
}
.resource-tag.military { color: var(--military); border: 1px solid var(--military); }
.resource-tag.religion { color: var(--religion); border: 1px solid var(--religion); }
.resource-tag.commerce { color: var(--commerce); border: 1px solid var(--commerce); }
.resource-tag.politics { color: var(--politics); border: 1px solid var(--politics); }
.resource-tag.link { color: var(--accent); border: 1px solid var(--accent); }
.resource-tag.legitimacy { color: var(--amber); border: 1px solid var(--amber); }

/* Mood colors */
.mood-dot {
  display: inline-block;
  width: 8px; height: 8px;
  border-radius: 50%;
  margin-right: 4px;
}
.mood-neutral .mood-dot { background: #7d8aa3; }
.mood-suspicious .mood-dot { background: #e0a64f; }
.mood-afraid .mood-dot { background: #7fb4d8; }
.mood-angry .mood-dot { background: #d96a5a; }
.mood-flattered .mood-dot { background: #b98ad6; }
.mood-curious .mood-dot { background: #4fd6e8; }
.mood-sad .mood-dot { background: #8693a8; }
.mood-desperate .mood-dot { background: #c8505a; }
</style>
</head>
<body>

<div id="sidebar">
  <h1>Narrative <span>Explorer</span></h1>
  <input id="deck-search" placeholder="Filtrer les decks…">
  <div id="deck-list"></div>
</div>

<div id="main">
  <div id="toolbar">
    <div class="title">
      <span id="toolbar-title">Sélectionnez un deck</span>
      <span class="sub" id="toolbar-sub"></span>
    </div>
    <div class="actions">
      <button class="small" onclick="saveAll()" id="btn-save" disabled>💾 Sauvegarder</button>
      <button class="small" onclick="exportJSON()">📋 Export JSON</button>
      <button class="small" onclick="addCard()">+ Carte</button>
    </div>
  </div>

  <div class="tabs">
    <div class="tab active" data-tab="edit" onclick="switchTab('edit')">✏️ Cartes</div>
    <div class="tab" data-tab="graph" onclick="switchTab('graph')">🕸️ Graphe</div>
  </div>

  <div id="content">
    <div id="tab-edit" class="tab-content active">
      <div id="card-list"></div>
      <div id="card-detail">
        <div class="empty-state">
          Sélectionnez un deck à gauche<br>
          puis une carte dans la liste
        </div>
      </div>
    </div>
    <div id="tab-graph" class="tab-content">
      <div id="graph-view"></div>
    </div>
  </div>
</div>

<div id="toast-container"></div>

<script>
// === State ===
let allCards = [];
let allDecks = {};
let linkAliases = {};
let characters = {};
let selectedDeck = null;
let selectedCard = null;
let autoSaveTimer = null;
let graphData = null;

// === Init ===
async function init() {
  const [cardsData, decksData, aliasesData, charsData] = await Promise.all([
    fetch("/api/cards").then(r => r.json()),
    fetch("/api/decks").then(r => r.json()),
    fetch("/api/aliases").then(r => r.json()),
    fetch("/api/characters").then(r => r.json()),
  ]);
  allCards = cardsData.cards;
  allDecks = decksData;
  linkAliases = aliasesData;
  characters = charsData;
  renderDecks();
}

// === Toast ===
function toast(msg, type = "info") {
  const el = document.createElement("div");
  el.className = `toast ${type}`;
  el.textContent = msg;
  document.getElementById("toast-container").appendChild(el);
  setTimeout(() => el.remove(), 2500);
}

let _dirty = false;
function markDirty() {
  _dirty = true;
  document.getElementById("btn-save").disabled = false;
  document.getElementById("btn-save").textContent = "💾 Sauvegarder*";
}
function markClean() {
  _dirty = false;
  document.getElementById("btn-save").disabled = true;
  document.getElementById("btn-save").textContent = "💾 Sauvegarder";
}

// === Deck List ===
function renderDecks(filter) {
  const container = document.getElementById("deck-list");
  const names = Object.keys(allDecks).sort((a, b) => {
    const aP = a.startsWith("crisis_") ? 1 : a.startsWith("planet_") ? 2 : 0;
    const bP = b.startsWith("crisis_") ? 1 : b.startsWith("planet_") ? 2 : 0;
    if (aP !== bP) return aP - bP;
    return a.localeCompare(b);
  });
  let html = "";
  let lastPrefix = "";
  for (const name of names) {
    if (filter && !name.includes(filter.toLowerCase())) continue;
    const d = allDecks[name];
    const prefix = name.startsWith("crisis_") ? "⚔️ Crise" :
                   name.startsWith("planet_") ? "🪐 Planète" :
                   "📦 Deck";
    if (prefix !== lastPrefix) {
      html += `<div class="deck-type-label">${prefix}</div>`;
      lastPrefix = prefix;
    }
    const warnings = [];
    if (d.hidden > 0) warnings.push(`<span class="badge hidden">${d.hidden}H</span>`);
    if (d.neg_weight > 0) warnings.push(`<span class="badge neg">${d.neg_weight}W</span>`);
    html += `<div class="deck-item${name === selectedDeck ? ' active' : ''}" onclick="selectDeck('${name}')">
      <span class="name">${name}</span>
      <span>${warnings.join(' ')} <span class="badge">${d.count}</span></span>
    </div>`;
  }
  container.innerHTML = html;
}

document.getElementById("deck-search").addEventListener("input", e => {
  renderDecks(e.target.value);
});

// === Deck Selection ===
async function selectDeck(name) {
  selectedDeck = name;
  selectedCard = null;
  renderDecks(document.getElementById("deck-search").value);
  document.getElementById("toolbar-title").textContent = name;
  document.getElementById("toolbar-sub").textContent =
    `${allDecks[name].count} cartes`;
  await loadCardList(name);
  document.getElementById("card-detail").innerHTML =
    `<div class="empty-state">Sélectionnez une carte dans la liste</div>`;
  switchTab("edit");
}

async function loadCardList(deck) {
  const res = await fetch(`/api/cards?deck=${encodeURIComponent(deck)}`);
  const data = await res.json();
  const cards = data.cards;
  const container = document.getElementById("card-list");
  let html = "";
  for (const c of cards) {
    const flags = [];
    if (c.hidden) flags.push('<span class="flag h">H</span>');
    if (c.weight < 0) flags.push('<span class="flag w">W-</span>');
    if (c.lockturn > 0) flags.push(`<span class="flag l">L${c.lockturn}</span>`);
    const label = c.label || `card_${c.id}`;
    html += `<div class="card-item" onclick="selectCard(${c.id})" id="card-item-${c.id}">
      <span class="cid">#${c.id}</span>
      <span class="clabel">${label}</span>
      <span class="cflags">${flags.join('')}</span>
    </div>`;
  }
  container.innerHTML = html;
}

// === Card Selection ===
async function selectCard(id) {
  selectedCard = id;
  document.querySelectorAll(".card-item").forEach(el => el.classList.remove("active"));
  const el = document.getElementById(`card-item-${id}`);
  if (el) el.classList.add("active");
  const res = await fetch(`/api/card/${id}`);
  const card = await res.json();
  renderCardDetail(card);
}

// === Card Detail Renderer ===
function renderCardDetail(card) {
  const container = document.getElementById("card-detail");
  container.innerHTML = `
    <div class="detail-section">
      <h3>🆔 Identité</h3>
      <div class="field-row">
        <label>ID</label>
        <input type="number" value="${card.id}" onchange="updateCardField(${card.id},'id',parseInt(this.value)||0)" style="flex:0 0 80px">
        <label style="min-width:40px">Label</label>
        <input value="${escHtml(card.label||'')}" onchange="updateCardField(${card.id},'label',this.value)">
      </div>
      <div class="field-row">
        <label>Deck</label>
        <input value="${escHtml(card.deck||'')}" onchange="updateCardField(${card.id},'deck',this.value)" list="deck-list-datalist">
        <datalist id="deck-list-datalist">${Object.keys(allDecks).map(d => `<option value="${d}">`).join('')}</datalist>
        <label style="min-width:40px">Weight</label>
        <input type="number" value="${card.weight||1}" onchange="updateCardField(${card.id},'weight',parseInt(this.value)||0)" style="flex:0 0 70px">
      </div>
      <div class="field-row">
        <label style="min-width:40px">Lockturn</label>
        <input type="number" value="${card.lockturn||0}" onchange="updateCardField(${card.id},'lockturn',parseInt(this.value)||0)" style="flex:0 0 70px">
        <label class="chk">
          <input type="checkbox" ${card.hidden?'checked':''} onchange="updateCardField(${card.id},'hidden',this.checked)">
          Cachée
        </label>
        <label class="chk">
          <input type="checkbox" ${card.key?'checked':''} onchange="updateCardField(${card.id},'key',this.checked)">
          Clé
        </label>
      </div>
      <div class="field-row">
        <label>Bearer</label>
        <input value="${escHtml(card.bearer||'')}" onchange="updateCardField(${card.id},'bearer',this.value||null)" placeholder="role:&lt;id&gt;">
      </div>
    </div>

    <div class="detail-section">
      <h3>💬 Question</h3>
      ${renderLocaleField(card, 'question')}
    </div>

    <div class="detail-section">
      <h3>⬅️ Réponse Gauche</h3>
      <div class="field-row"><label>Titre</label>${renderLocaleField(card, 'leftAnswer', 'title')}</div>
      <div class="field-row"><label>Réaction</label>${renderLocaleField(card, 'leftAnswer', 'reaction')}</div>
    </div>

    <div class="detail-section">
      <h3>➡️ Réponse Droite</h3>
      <div class="field-row"><label>Titre</label>${renderLocaleField(card, 'rightAnswer', 'title')}</div>
      <div class="field-row"><label>Réaction</label>${renderLocaleField(card, 'rightAnswer', 'reaction')}</div>
    </div>

    <div class="detail-section">
      <h3>📋 Conditions</h3>
      <div id="conditions-container"></div>
      <button class="add-btn small" onclick="addArrayItem(${card.id},'conditions',{})">+ Condition</button>
    </div>

    <div class="detail-section">
      <h3>📥 Load Outcomes</h3>
      <div id="loadOutcome-container"></div>
      <button class="add-btn small" onclick="addArrayItem(${card.id},'loadOutcome',{})">+ Outcome</button>
    </div>

    <div class="detail-section">
      <h3>✅ Yes Outcomes</h3>
      <div id="yesOutcome-container"></div>
      <button class="add-btn small" onclick="addArrayItem(${card.id},'yesOutcome',{})">+ Outcome</button>
    </div>

    <div class="detail-section">
      <h3>❌ No Outcomes</h3>
      <div id="noOutcome-container"></div>
      <button class="add-btn small" onclick="addArrayItem(${card.id},'noOutcome',{})">+ Outcome</button>
    </div>

    <div class="detail-section">
      <h3>😊 Moods</h3>
      <div class="field-row">
        <label>Défaut</label>
        <select onchange="updateMoodField(${card.id},'default',this.value)">
          ${moodOptions(card.moods?.default||'neutral')}
        </select>
        <label>Oui</label>
        <select onchange="updateMoodField(${card.id},'yes',this.value)">
          ${moodOptions(card.moods?.yes||'neutral')}
        </select>
        <label>Non</label>
        <select onchange="updateMoodField(${card.id},'no',this.value)">
          ${moodOptions(card.moods?.no||'neutral')}
        </select>
      </div>
    </div>

    <div class="detail-section">
      <h3>🔍 JSON brut</h3>
      <div class="json-preview">${escHtml(JSON.stringify(card, null, 2))}</div>
    </div>

    <div class="detail-section">
      <h3 style="color:var(--danger)">🗑️ Zone dangereuse</h3>
      <button class="danger" onclick="deleteCard(${card.id})">Supprimer cette carte</button>
    </div>
  `;
  // Render array items
  renderArrayItems(card, 'conditions');
  renderArrayItems(card, 'loadOutcome');
  renderArrayItems(card, 'yesOutcome');
  renderArrayItems(card, 'noOutcome');
}

function escHtml(s) {
  if (s == null) return '';
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function renderLocaleField(card, field, sub) {
  let obj = card;
  if (sub) {
    obj = card[field] || {};
    field = sub;
  }
  const val = obj[field] || {};
  const fr = val.FR || '';
  const en = val.EN || '';
  return `<div class="locale-field">
    <input placeholder="FR" value="${escHtml(fr)}" onchange="updateLocaleField(${card.id},'${field}'${sub ? `,'${sub}'` : ''},'FR',this.value)">
    <input placeholder="EN" value="${escHtml(en)}" onchange="updateLocaleField(${card.id},'${field}'${sub ? `,'${sub}'` : ''},'EN',this.value)">
  </div>`;
}

function moodOptions(current) {
  const moods = ['neutral','suspicious','afraid','angry','flattered','curious','sad','desperate'];
  return moods.map(m => `<option value="${m}" ${m===current?'selected':''}>${m}</option>`).join('');
}

// === Array Item Renderers ===
function renderArrayItems(card, key) {
  const container = document.getElementById(`${key}-container`);
  if (!container) return;
  const items = card[key] || [];
  let html = "";
  for (let i = 0; i < items.length; i++) {
    html += renderArrayItem(card.id, key, items[i], i);
  }
  container.innerHTML = html;
}

function renderArrayItem(cardId, key, item, idx) {
  if (key === 'conditions') {
    const ops = ['equal','above','below','not'];
    const v = item.value;
    const vStr = v !== undefined && v !== null ? String(v) : "";
    return `<div class="array-item" data-idx="${idx}">
      <button class="del" onclick="removeArrayItem(${cardId},'${key}',${idx})">✕</button>
      <div class="row">
        <label>Variable</label>
        <input value="${escHtml(item.variable||'')}" onchange="updateArrayItemField(${cardId},'${key}',${idx},'variable',this.value)">
        <label>Op</label>
        <select onchange="updateArrayItemField(${cardId},'${key}',${idx},'op',this.value)">
          ${ops.map(o => `<option value="${o}" ${item.op===o?'selected':''}>${o}</option>`).join('')}
        </select>
        <label>Value</label>
        <input class="small" value="${escHtml(vStr)}" onchange="updateArrayItemField(${cardId},'${key}',${idx},'value',this.value)">
      </div>
    </div>`;
  }
  if (key.endsWith('Outcome') || key === 'loadOutcome') {
    const sv = item.stringValue || "";
    return `<div class="array-item" data-idx="${idx}">
      <button class="del" onclick="removeArrayItem(${cardId},'${key}',${idx})">✕</button>
      <div class="row">
        <label>Variable</label>
        <input value="${escHtml(item.variable||'')}" onchange="updateArrayItemField(${cardId},'${key}',${idx},'variable',this.value)" list="var-list">
        <datalist id="var-list">
          ${['military','religion','commerce','politics','legitimacy','turns','year','mood','link','location','age'].map(v => `<option value="${v}">`).join('')}
        </datalist>
        <label class="chk">
          <input type="checkbox" ${item.addOperation!==false?'checked':''} onchange="updateArrayItemField(${cardId},'${key}',${idx},'addOperation',this.checked)">
          Add
        </label>
        <label>Value</label>
        <input class="small" type="number" value="${item.intValue!==undefined?item.intValue:0}" onchange="updateArrayItemField(${cardId},'${key}',${idx},'intValue',parseInt(this.value)||0)">
        <label class="chk">
          <input type="checkbox" ${item.toKeep?'checked':''} onchange="updateArrayItemField(${cardId},'${key}',${idx},'toKeep',this.checked)">
          Keep
        </label>
      </div>
      <div class="row">
        <label>stringValue</label>
        <input value="${escHtml(sv)}" onchange="updateArrayItemField(${cardId},'${key}',${idx},'stringValue',this.value||'')" placeholder="Alias ou lien">
      </div>
    </div>`;
  }
  return `<div class="array-item">
    <button class="del" onclick="removeArrayItem(${cardId},'${key}',${idx})">✕</button>
    <pre>${escHtml(JSON.stringify(item))}</pre>
  </div>`;
}

// === Card Updates ===
let _cardCache = {};

function getCard(id) {
  if (_cardCache[id]) return _cardCache[id];
  return allCards.find(c => c.id === id);
}

async function updateCardField(id, field, value) {
  const card = getCard(id);
  if (!card) return;
  card[field] = value;
  _cardCache[id] = card;
  scheduleAutoSave(id);
}

async function updateLocaleField(cardId, field, sub, locale, value) {
  const card = getCard(cardId);
  if (!card) return;
  let obj = card;
  if (sub) {
    if (!obj[field]) obj[field] = {};
    obj = obj[field];
    field = sub;
  }
  if (!obj[field]) obj[field] = {};
  obj[field][locale] = value;
  scheduleAutoSave(cardId);
}

async function updateMoodField(cardId, key, value) {
  const card = getCard(cardId);
  if (!card) return;
  if (!card.moods) card.moods = {};
  card.moods[key] = value;
  scheduleAutoSave(cardId);
}

async function updateArrayItemField(cardId, key, idx, field, value) {
  const card = getCard(cardId);
  if (!card) return;
  if (!card[key]) card[key] = [];
  if (!card[key][idx]) card[key][idx] = {};
  card[key][idx][field] = value;
  scheduleAutoSave(cardId);
}

async function addArrayItem(cardId, key, template) {
  const card = getCard(cardId);
  if (!card) return;
  if (!card[key]) card[key] = [];
  card[key].push({...template});
  scheduleAutoSave(cardId);
  renderCardDetail(card);
}

async function removeArrayItem(cardId, key, idx) {
  const card = getCard(cardId);
  if (!card) return;
  card[key].splice(idx, 1);
  scheduleAutoSave(cardId);
  renderCardDetail(card);
}

async function deleteCard(id) {
  if (!confirm(`Supprimer la carte #${id} ?`)) return;
  const res = await fetch(`/api/card/${id}`, { method: "DELETE" });
  if (res.ok) {
    allCards = allCards.filter(c => c.id !== id);
    toast("Carte supprimée", "success");
    markDirty();
    selectedCard = null;
    if (selectedDeck) await loadCardList(selectedDeck);
    document.getElementById("card-detail").innerHTML =
      `<div class="empty-state">Carte supprimée</div>`;
  }
}

async function addCard() {
  if (!selectedDeck) { toast("Sélectionnez d'abord un deck", "error"); return; }
  const template = {
    id: 0,
    label: "nouvelle_carte",
    deck: selectedDeck,
    weight: 1,
    lockturn: 0,
    hidden: false,
    question: { FR: "?" },
    conditions: [],
    loadOutcome: [],
    leftAnswer: { title: { FR: "Gauche" }, reaction: { FR: "" } },
    rightAnswer: { title: { FR: "Droite" }, reaction: { FR: "" } },
    yesOutcome: [],
    noOutcome: [],
    moods: { default: "neutral", yes: "neutral", no: "neutral" },
  };
  const res = await fetch("/api/card", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(template),
  });
  const data = await res.json();
  allCards.push({...template, id: data.id});
  markDirty();
  toast(`Carte #${data.id} créée`, "success");
  if (selectedDeck) await loadCardList(selectedDeck);
  selectCard(data.id);
}

function scheduleAutoSave(cardId) {
  markDirty();
  if (autoSaveTimer) clearTimeout(autoSaveTimer);
  autoSaveTimer = setTimeout(() => {
    const card = getCard(cardId);
    if (!card) return;
    fetch(`/api/card/${cardId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(card),
    }).then(r => {
      if (r.ok) toast("Carte sauvegardée", "success");
    });
    autoSaveTimer = null;
  }, 500);
}

async function saveAll() {
  // Send all dirty cards
  for (const card of allCards) {
    await fetch(`/api/card/${card.id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(card),
    });
  }
  await fetch("/api/save", { method: "POST" });
  markClean();
  toast("Toutes les modifications sauvegardées ✅", "success");
}

function exportJSON() {
  const blob = new Blob([JSON.stringify(allCards, null, 2)], {type: "application/json"});
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "foundation_cards_export.json";
  a.click();
  URL.revokeObjectURL(url);
}

// === Tabs ===
function switchTab(tab) {
  document.querySelectorAll(".tab").forEach(t => t.classList.toggle("active", t.dataset.tab === tab));
  document.querySelectorAll(".tab-content").forEach(t => t.classList.toggle("active", t.id === `tab-${tab}`));
  if (tab === "graph") renderGraph();
}

// === Graph ===
async function renderGraph() {
  const container = document.getElementById("graph-view");
  const deck = selectedDeck || "";
  const res = await fetch(`/api/graph?deck=${encodeURIComponent(deck)}`);
  const data = await res.json();
  graphData = data;

  if (!data.nodes.length) {
    container.innerHTML = `<div class="empty-state">Aucune carte à afficher<br><span style="font-size:11px">Sélectionnez un deck contenant des liens</span></div>`;
    return;
  }

  // Simple force-directed layout
  const w = container.clientWidth || 900;
  const h = container.clientHeight || 600;
  const nodeMap = {};
  for (const n of data.nodes) {
    n.x = 100 + Math.random() * (w - 200);
    n.y = 100 + Math.random() * (h - 200);
    n.vx = 0; n.vy = 0;
    nodeMap[n.id] = n;
  }

  // Run simple force simulation
  for (let iter = 0; iter < 100; iter++) {
    // Repulsion between all nodes
    for (let i = 0; i < data.nodes.length; i++) {
      for (let j = i + 1; j < data.nodes.length; j++) {
        const a = data.nodes[i], b = data.nodes[j];
        let dx = a.x - b.x, dy = a.y - b.y;
        let dist = Math.sqrt(dx*dx + dy*dy) || 1;
        const force = 5000 / (dist * dist);
        a.vx += (dx / dist) * force;
        a.vy += (dy / dist) * force;
        b.vx -= (dx / dist) * force;
        b.vy -= (dy / dist) * force;
      }
    }
    // Attraction along edges
    for (const e of data.edges) {
      const a = nodeMap[e.from], b = nodeMap[e.to];
      if (!a || !b) continue;
      const dx = b.x - a.x, dy = b.y - a.y;
      const dist = Math.sqrt(dx*dx + dy*dy) || 1;
      const force = dist / 100;
      a.vx += (dx / dist) * force;
      a.vy += (dy / dist) * force;
      b.vx -= (dx / dist) * force;
      b.vy -= (dy / dist) * force;
    }
    // Center gravity
    for (const n of data.nodes) {
      n.vx += (w/2 - n.x) * 0.001;
      n.vy += (h/2 - n.y) * 0.001;
      n.x += n.vx;
      n.y += n.vy;
      n.x = Math.max(20, Math.min(w-20, n.x));
      n.y = Math.max(20, Math.min(h-20, n.y));
      n.vx *= 0.5;
      n.vy *= 0.5;
    }
  }

  // Build SVG
  const deckColors = {};
  let colorIdx = 0;
  const palette = ['#4fd6e8','#e8b65a','#b98ad6','#5ad96a','#d97a4a','#7fb4d8','#d96a5a','#7ac87a','#c8505a','#8693a8'];
  for (const n of data.nodes) {
    if (!deckColors[n.deck]) deckColors[n.deck] = palette[colorIdx++ % palette.length];
  }

  let svg = `<svg viewBox="0 0 ${w} ${h}">
    <defs>
      <filter id="glow"><feGaussianBlur stdDeviation="2" result="blur"/><feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    </defs>
    <rect width="${w}" height="${h}" fill="#05070d"/>`;

  // Edges
  for (const e of data.edges) {
    const a = nodeMap[e.from], b = nodeMap[e.to];
    if (!a || !b) continue;
    svg += `<line class="graph-link" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}"
      stroke="${deckColors[e.fromDeck] || '#55667a'}" stroke-dasharray="${e.label==='load'?'':e.label==='yes'?'6,3':'2,4'}"/>
      <text class="graph-link-label" x="${(a.x+b.x)/2}" y="${(a.y+b.y)/2 - 4}" text-anchor="middle">${e.label}</text>`;
  }

  // Nodes
  for (const n of data.nodes) {
    const color = deckColors[n.deck] || '#55667a';
    const r = n.hidden ? 5 : n.weight < 0 ? 6 : 7;
    svg += `<g class="graph-node" onclick="selectCardById(${n.id})">
      <circle cx="${n.x}" cy="${n.y}" r="${r}"
        fill="${color}" stroke="${n.hidden ? '#d96a5a' : 'none'}" stroke-width="2"
        filter="${n.weight > 100 ? 'url(#glow)' : ''}"/>
      <text x="${n.x}" y="${n.y + r + 12}" text-anchor="middle">${escHtml(n.label)}</text>
    </g>`;
  }

  svg += `</svg>`;
  container.innerHTML = svg;
}

async function selectCardById(id) {
  selectedCard = id;
  switchTab("edit");
  await selectCard(id);
  // Scroll to it
  const el = document.getElementById(`card-item-${id}`);
  if (el) el.scrollIntoView({ block: 'center', behavior: 'smooth' });
}

// === Keyboard Shortcuts ===
document.addEventListener("keydown", e => {
  if ((e.ctrlKey || e.metaKey) && e.key === "s") {
    e.preventDefault();
    saveAll();
  }
});

// === Start ===
init();
</script>
</body>
</html>"""


def main():
    global PORT
    import argparse
    parser = argparse.ArgumentParser(description="Narrative Explorer")
    parser.add_argument("--port", type=int, default=8080, help="Port (defaut: 8080)")
    args = parser.parse_args()
    PORT = args.port

    load_data()
    print(f"\n  🧭 Narrative Explorer — Foundation Reigns")
    print(f"  ─────────────────────────────────────")
    print(f"  📂 {len(_cards)} cartes chargées")
    print(f"  📦 {len(get_decks())} decks")
    print(f"  🔗 {len(_link_aliases)} alias de link")
    print(f"  🎭 {len(_characters)} personnages")
    print(f"\n  🌐 http://localhost:{PORT}")
    print(f"  ⏎  Ctrl+C pour quitter\n")

    server = HTTPServer(("0.0.0.0", PORT), NarrativeAPI)
    try:
        webbrowser.open(f"http://localhost:{PORT}")
        server.serve_forever()
    except KeyboardInterrupt:
        if _dirty:
            print("\n  ⚠️  Modifications non sauvegardées ! Utilisez le bouton 💾 dans l'interface.")
        print("\n  👋 Au revoir\n")
        server.server_close()


if __name__ == "__main__":
    main()
