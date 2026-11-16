class_name ArenaCar
extends CarState
## A car in the points mode: free on a flat square instead of on the (s, d)
## road ribbon. Heading h has forward = (-sin h, cos h) in (x, z), the same
## convention as the race view.

const BODY_RADIUS := 1.02        # two circles along the body stand in for it
const BODY_OFFSET := 1.2

var x := 0.0
var z := 0.0
var h := 0.0
var vx := 0.0
var vz := 0.0
var spin_rate := 0.0             # rad/s left over from a knock
var lat := 0.0                   # sideways speed, for skid effects
var score := 0
var combo := 1                   # multiplier, 1..5
var combo_n := 0
var combo_t := -99.0
var hits_n := 0
var kills := 0
var ram_t := 0.0                 # armoured charge time left
var last_hit_id := -1             # car id, not a reference: no reference cycles
var last_hit_t := -99.0
var bot := {}                    # the AI's working memory


func forward() -> Vector2:
	return Vector2(-sin(h), cos(h))


func right() -> Vector2:
	return Vector2(cos(h), sin(h))


func at() -> Vector2:
	return Vector2(x, z)


## Centres of the two collision circles: front, rear.
func circles() -> Array[Vector2]:
	var f := forward() * BODY_OFFSET
	return [at() + f, at() - f]
