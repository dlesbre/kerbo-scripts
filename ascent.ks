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

function log_stage {
	parameter n.
	logger:log("Stage " + n).
	on stage:number log_stage(n+1).
}

function deploy_fairings {
	local fairing_bases is list().
	for fairing in Ship:ModulesNamed("ProceduralFairingBase") { // removes interstage fairings
		if fairing:part:title:matchespattern("^FB") {
			fairing_bases:add(fairing).
		}
	}
	if fairing_bases:length = 1 { // only one fairing base
		for child in fairing_bases[0]:part:children {
			if child:hasmodule("ProceduralFairingSide") {
				child:getmodule("ProceduralFairingDecoupler"):doaction("jettison fairing", true).
			}
		}
	}
	else
		logger:log("Only supports one fairing: found " + fairing_bases:length).
}

function set_min_incl {
	logger:set_settings(lexicon("orbit", lexicon("inc", ceiling(latitude,4)))).
}

function main {
	local inc is ceiling(latitude,4).
	local pe is 200.
	local ap is 200.
	set logger to create_gui(
		list(
			lexicon("type", "vbox", "name", "grav_turn", "label", "Gravity turn", "widgets", list(
				lexicon("type", "input", "name", "alt", "label", "Turn start alt:", "tooltip", "1000", "unit", "m"),
				lexicon("type", "input", "name", "angle", "label", "Turn start angle:", "tooltip", "5", "unit", "°"))),
			lexicon("type", "vbox", "name", "orbit", "label", "Orbit", "widgets", list(
				lexicon("type", "input", "name", "pe", "label", "Periapsis:", "tooltip", pe, "unit", "km"),
				lexicon("type", "input", "name", "ap", "label", "Apoapsis:", "tooltip", ap, "unit", "km"),
				lexicon("type", "hlayout", "name", "", "widgets", list(
					lexicon("type", "input", "name", "inc", "label", "Inclination:", "tooltip", inc, "unit", "°"),
					lexicon("type", "button", "name", "min_incl", "label", "cur", "onclick", set_min_incl@)
				)),
				lexicon("type", "label", "name", "inc_info", "label", "Launch azimuth: "))),
			lexicon("type", "checkbox", "name", "drop_fairings", "label", "Auto-deploy fairings"),
			lexicon("type", "checkbox", "name", "log_telemetry", "label", "Log telemetry"),
			lexicon("type", "input", "name", "shutdown_pe", "label", "Shutdown when Pe >", "tooltip", "150", "unit", "km"),
			lexicon("name", "Unlock controls", "onclick", unlock@, "type", "button")
		),
		list("Orbit", "Pitch", "AoP", "TWR", "Azimuth")
	).
	logger:set_settings(lexicon(
		"drop_fairings", true,
		"log_telemetry", false,
		"orbit", lexicon("pe", pe, "ap", ap, "inc", inc, "inc_info", "Launch azimuth: 90°")
	)).
	logger:gui:show().

	local speed_of_sound is 350.
	local tower_clear_alt is ship:bounds:bottomaltradar + ship:bounds:size:mag.

	// Vessel is locked upward until tower is cleared.
	local tower_cleared is false.

	// Logging triggers
	when ship:bounds:bottomaltradar > tower_clear_alt then {
		set tower_cleared to true.
		logger:log("Tower cleared").
	}
	when ship:airspeed > 100 then logger:log("Passing 100 m/s").
	when ship:airspeed > speed_of_sound then logger:log("Vessel supersonic").
	when ship:airspeed > 2*speed_of_sound then logger:log("Mach 2").
	when ship:airspeed > 3*speed_of_sound then logger:log("Mach 3").
	when ship:velocity:orbit:mag > 2500 then logger:log("Passing 2.5 km/s").
	when ship:velocity:orbit:mag > 5000 then logger:log("Passing 5 km/s").
	when ship:altitude > 1_000 then	logger:log("Altitude 1 km").
	when ship:altitude > 10_000 then logger:log("Altitude 10 km").
	when ship:altitude > 20_000 then logger:log("Altitude 20 km").
	when ship:altitude > 40_000 then logger:log("Altitude 40 km").
	when ship:altitude > 70_000 then logger:log("Altitude 70 km").
	when ship:altitude > 100_000 then logger:log("Altitude 100 km - Karman line").
	when ship:altitude > 140_000 then logger:log("Altitude 140 km - Left the atmosphere").
	on stage:number log_stage(0).
	when orbit:periapsis > 140_000 then	logger:log("Achieved orbit").
	when ship:altitude > 50_000 then {
		if logger:get_settings():drop_fairings {
			deploy_fairings().
			logger:log("Fairing jettison").
		}
	}

	lock TWR to max(.001, ship:maxthrust/(ship:mass*g)).
	local max_q is dynamic_pressure().
	local max_q_t is missionTime.
	local log_telemetry_t is -1.
	local settings_t is 0.

	// Settings
	local settings is logger:get_settings.
	local pe_shutdown is -1.
	local check_cutoff is true.


	until false {
		// refresh settings every second
		if (time:seconds - settings_t > 1) {
			set settings to logger:get_settings().
			set pe_shutdown to settings:shutdown_pe:toscalar(-1) * 1000.
			set pe to settings:orbit:pe:toscalar(pe).
			set ap to settings:orbit:ap:toscalar(ap).
			set inc to settings:orbit:inc:toscalar(inc).
		}

		local cur_q is dynamic_pressure().
		if (cur_q > max_q) {
			set max_q to cur_q.
			set max_q_t to missionTime.
		}
		else if (max_q_t > 0 and missionTime - max_q_t > 0.5) {
			logger:log("Passed max Q = " + format_unit(max_q, " ") + "Pa").
			set max_q_t to -1.
		}
		logger:update_readouts(lexicon(
			"Orbit", format_unit(orbit:apoapsis) + "m x " + format_unit(orbit:periapsis) + "m",
			"Pitch", round(vector_pitch(ship:facing:forevector), 1) + "°",
			"AoP", round(vang(ship:facing:forevector, ship:velocity:surface),1) + "°",
			"TWR", round(TWR,2),
			"Azimuth", "" + round(absolute_launch_azimuth(inc),1) + "° or " + round(launch_azimuth(inc),1)
		)).


		if pe_shutdown > 0 and periapsis > pe_shutdown and check_cutoff {
			// set ship:control:mainthrottle to 0.
			set ship:control:pilotmainthrottle to 0.
			set check_cutoff to false.
			logger:log("Engine cut-off: " + format_unit(orbit:apoapsis) + "m x " + format_unit(orbit:periapsis) + "m").
		}

		// Log telemetry on launch and then every 10 seconds.
		if (missionTime > 0 and log_telemetry_t < 0) or (missionTime - log_telemetry_t >= 10) {
			set log_telemetry_t to missionTime.
			set settings to logger:get_settings().
			if logger:get_settings():log_telemetry {
				logger:debug(
					"Alt: " + format_unit(altitude) +
					"m, SV: " + format_unit(ship:velocity:surface:mag) +
					"m/s, OV: " + format_unit(ship:velocity:orbit:mag) +
					"m/s, Pitch: " + round(vector_pitch(ship:facing:forevector), 1) +
					"°, Hdg: " + round(ship:heading, 1) + "°").
			}
		}

		wait 0.001.
	}
}

main().
