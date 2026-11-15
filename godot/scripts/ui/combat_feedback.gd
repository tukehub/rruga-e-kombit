extends RefCounted
## One Albanian explanation for simulation denials, touch feedback and HUD hints.

const REASONS := {
	"not_started": "Prit nisjen e garës.",
	"finished": "Gara përfundoi.",
	"wreck": "Prit rikthimin e makinës.",
	"spin": "Prit të rimarrësh timonin.",
	"empty": "Mblidh një fuqi në pistë.",
	"unknown": "Kjo fuqi nuk është e disponueshme.",
	"direction": "Kjo fuqi përdoret vetëm me butonin kryesor.",
	"no_target": "S’ka rival në rreze: 420 m para ose 160 m prapa.",
	"too_far": "Afrohu: Tërmeti godet rivalët brenda 15 metrave.",
	"first": "Je i pari. Stuhia ruhet për liderin rival.",
	"full": "Shëndeti është plot. Ruaje Ustën ose mbaj slotin për ta lëshuar.",
	"target_recovery": "Lideri po rimerr kontrollin. Prit pak.",
	"storm_active": "Ka ende kupola aktive. Prit të mbarojë Stuhia.",
	"nitro_active": "Turbo është aktiv. Prit të mbarojë.",
	"shield_active": "Mburoja është aktive. Ruaje tjetrën.",
	"charge": "Drifto pa prekur muret për të fituar një turbo.",
	"inventory_changed": "Inventari ndryshoi. Mbaje përsëri fuqinë që do të lëshosh.",
}


static func reason(code: String) -> String:
	return REASONS.get(code, "Fuqia nuk mund të përdoret tani.")


static func target_hint(race, c: CarState, status: Dictionary) -> String:
	if not bool(status.ready):
		return {"first": "JE I PARI", "full": "SHËNDET I PLOTË", "no_target": "PA SHËNJESTËR", "too_far": "AFROHU · 15 m", "storm_active": "STUHI AKTIVE", "target_recovery": "LIDERI NË RIMARRJE", "nitro_active": "TURBO AKTIV", "shield_active": "MBUROJË AKTIVE", "empty": "MBLIDH FUQI"}.get(status.reason, reason(status.reason))
	var aim: CarState = status.target
	if aim != null:
		if aim.shield_t > 0.0:
			return aim.name + " · MBUROJË"
		var metres := absf(race.track.wrap_s(aim.s - c.s))
		return "%s · %dm" % [aim.name, roundi(metres)]
	match status.kind:
		"bolt": return "GJUAN LIRSHËM · DREJTOHU"
		"mine": return "KURTH PARA OSE PRAPA"
		"nitro": return "SHPEJTËSI · PRAPA FRENON"
		"shield": return "MBROJTJE · 8 s"
		"repair": return "RREGULLO MAKINËN"
	return ""
