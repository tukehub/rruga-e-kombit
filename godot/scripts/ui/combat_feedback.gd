extends RefCounted
## One explanation for simulation denials, touch feedback and HUD hints. The
## texts are in the string table: "deny.<reason>" is the full sentence for the
## feed, "hint.deny.<reason>" the short form under the inventory.


static func reason(code: String) -> String:
	return Data.t("deny.%s" % code) if Data.has_text("deny.%s" % code) else Data.t("deny.default")


static func target_hint(race, c: CarState, status: Dictionary) -> String:
	if not bool(status.ready):
		return Data.t("hint.deny.%s" % status.reason) if Data.has_text("hint.deny.%s" % status.reason) else reason(str(status.reason))
	var aim: CarState = status.target
	if aim != null:
		if aim.shield_t > 0.0:
			return Data.t("hint.target_shielded", aim.name)
		var metres := absf(race.track.wrap_s(aim.s - c.s))
		return "%s · %dm" % [aim.name, roundi(metres)]
	return Data.t("hint.kind.%s" % status.kind) if Data.has_text("hint.kind.%s" % status.kind) else ""
