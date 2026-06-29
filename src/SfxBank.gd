extends RefCounted

# Banque de SFX (chargée via preload là où elle sert ; pas de class_name global).
# Génère des SFX simples par code (sinus + bruit + enveloppe exponentielle).
# Pas d'asset externe, libre de droits. Les sons sont mis en cache (générés une fois).

const RATE := 22050
static var _cache: Dictionary = {}

static func swipe() -> AudioStreamWAV:  return _cached("swipe", 420.0, 0.12, 18.0, 0.35)
static func commit() -> AudioStreamWAV: return _cached("commit", 300.0, 0.18, 12.0, 0.10)
static func death() -> AudioStreamWAV:  return _cached("death", 90.0, 0.90, 3.0, 0.05)
static func unlock() -> AudioStreamWAV: return _cached("unlock", 660.0, 0.25, 8.0, 0.0)
static func respawn() -> AudioStreamWAV: return _cached("respawn", 520.0, 0.30, 6.0, 0.0)

static func _cached(key: String, freq: float, dur: float, decay: float, noise: float) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = _tone(freq, dur, decay, noise)
	return _cache[key]

# Construit un AudioStreamWAV PCM 16 bits mono.
static func _tone(freq: float, dur: float, decay: float, noise: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / RATE
		var env := exp(-decay * t)
		var s := sin(TAU * freq * t) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		var v := int(clampf(s * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
