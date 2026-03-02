// #include "libs/math.ks"
run once "0:/libs/math".
run once "0:/libs/gui".

lock g to earth:mu / (altitude + earth:radius)^2.
lock TWR to max(.001, ship:maxthrust/(ship:mass*g)).

global message is " ".
global message2 is " ".

function flightreadout{
	print "======= Flight Computer =======" at (0,0).
	print "Vessel Status: " + status + "                             " at (2,1).
	print "Current TWR:   " + round(twr,2) + "     "         at (2,2).
	print "Current Mass:  " + round(ship:mass) + " t     "  at (2,3).
	print "Current Accel: " + round(twr*g,2) + " m/s^2     " at (2,4).
	print "Heading:       " + round(vector_heading(ship:velocity:surface),2) + "°     "  at (2,5).
  print "Pitch:         " + round(vector_pitch(ship:velocity:surface),2) + "°     "  at (2,6).
	print "Current Vel:   " + round(ship:airspeed,2) + " m/s     " at (2,7).
	print "Current DV:    " + round(stage:deltav:current,2) + " m/s     " at (2,8).
  print "Remaining burn:" + round(stage:deltav:duration,2) + " s     " at (2,9).
	print message + "                      " at (0,10).
	print message2 + "                     " at (0,11).
}.

set logger to "".

function unlock {
	if logger:typename = "lexicon" {
		logger:log("Unlocking controls").
	}
	unlock steering.
	unlock throttle.
	set ship:control:pilotmainthrottle to 1.
	sas on.
}

function main {
	set logger to create_gui(
		list(
			lexicon("type", "vbox", "name", "grav_turn", "label", "Gravity turn", "widgets", list(
				lexicon("type", "input", "name", "alt", "label", "Turn start alt:", "tooltip", "1000", "unit", "m"),
				lexicon("type", "input", "name", "angle", "label", "Turn start angle:", "tooltip", "5", "unit", "°"))),
			lexicon("type", "vbox", "name", "orbit", "label", "Orbit", "widgets", list(
				lexicon("type", "input", "name", "pe", "label", "Periapsis:", "tooltip", "200", "unit", "km"),
				lexicon("type", "input", "name", "ap", "label", "Apoapsis:", "tooltip", "800", "unit", "km"))),
			lexicon("type", "checkbox", "name", "drop_fairings", "label", "Auto-deploy fairings"),
			lexicon("name", "Unlock controls", "onclick", unlock@, "type", "button")
		),
		list("Orbit", "Pitch", "AoP", "TWR")
	).
	logger:gui:show().

	local speed_of_sound is 350.
	local tower_clear_alt is ship:bounds:bottomaltradar + ship:bounds:size:mag.

	// Logging triggers
	when ship:bounds:bottomaltradar > tower_clear_alt then
		logger:log("Tower cleared").
	when ship:airspeed > speed_of_sound then
		logger:log("Vessel supersonic").
	when ship:airspeed > 2*speed_of_sound then
		logger:log("Mach 2").
	when ship:airspeed > 3*speed_of_sound then
		logger:log("Mach 3").
	when ship:altitude > 1_000 then
		logger:log("Altitude 1 km").
	when ship:altitude > 10_000 then
		logger:log("Altitude 10 km").
	when ship:altitude > 20_000 then
		logger:log("Altitude 20 km").
	when ship:altitude > 40_000 then
		logger:log("Altitude 40 km").
	when ship:altitude > 70_000 then
		logger:log("Altitude 70 km").
	when ship:altitude > 100_000 then
		logger:log("Altitude 100 km - Karman line").
	when ship:altitude > 140_000 then
		logger:log("Altitude 140 km - Left the atmosphere").
	on stage {
		logger:log("Stage").
	}

	lock TWR to max(.001, ship:maxthrust/(ship:mass*g)).

	until false {

		logger:update_readouts(lexicon(
			"Orbit", format_unit(orbit:apoapsis) + "m x " + format_unit(orbit:periapsis) + "m",
			"Pitch", round(vector_pitch(ship:facing:forevector), 1) + "°",
			"AoP", round(vang(ship:facing:forevector, ship:velocity:surface),1) + "°",
			"TWR", round(TWR,2)
		)).
		wait 0.1.
	}
}

main().
