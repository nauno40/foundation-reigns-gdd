class_name EraUtils

static func get_era_info(year: int) -> Dictionary:
	var eras = [
		{"start": 1,   "end": 80,   "id": "hardin",     "label": "ÈRE HARDIN",     "sub": "ANS 1–80"},
		{"start": 80,  "end": 250,  "id": "merchants",  "label": "ÈRE DES MARCHANDS", "sub": "ANS 80–250"},
		{"start": 200, "end": 350,  "id": "mallow",     "label": "ÈRE MALLOW",     "sub": "ANS 200–350"},
		{"start": 290, "end": 380,  "id": "mulet",      "label": "ÈRE DU MULET",   "sub": "ANS 290–380"},
		{"start": 350, "end": 600,  "id": "restoration","label": "RESTAURATION",   "sub": "ANS 350–600"},
		{"start": 600, "end": 1000, "id": "late_empire","label": "EMPIRE TARDIF",  "sub": "ANS 600–1000"},
	]
	for era in eras:
		if year >= era["start"] and year < era["end"]:
			return era
	return eras[-1]

static func get_era_for_year(year: int) -> String:
	return get_era_info(year)["id"]
