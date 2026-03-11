// #include "libs/math.ks"
run once "0:/libs/math".
run once "0:/libs/gui".

lock g to earth:mu / (altitude + earth:radius)^2.
lock TWR to max(.001, ship:maxthrust/(ship:mass*g)).

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

set stage_names to list(
	"Engine ignition",
	"Liftoff",
	"Booster separation",
	"First stage separation",
	"Second stage Ignition",
	"Payload release"
).

function log_stage {
	parameter n.
	if n < stage_names:length
		logger:log(stage_names[n]).
	else logger:log("Stage " + n).
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
		logger:log("Fairing jettison").
	}
	else if fairing_bases:length > 0
		logger:log("<color=orange>Only supports one fairing: found " + fairing_bases:length + "</color>").
}

function deploy_LES {
	local LES is ship:partstitledpattern("Launch Escape System").
	if LES:length = 1 {
		LES[0]:getmodule("ModuleEnginesRF"):doaction("activate engine", true).
		LES[0]:getmodule("ModuleDecouple"):doaction("decouple", true).
		logger:log("Launch Escape System Jettison").
	}
}

function set_min_incl {
	logger:set_settings(lexicon("orbit", lexicon("inc", ceiling(latitude,4)))).
}

function pp_attitude {
	parameter value.
	parameter command.
	local str is round(value,1):tostring.
	if abs(command - value) > 2 return "<color=red>" + str + "</color>/" + round(command,1).
	if abs(command - value) > 1 return "<color=orange>" + str + "</color>/" + round(command,1).
	local cmd_str is round(command,1).
	if str = cmd_str return str.
	return str + "/" + round(command,1).
}

function main {
	local cmd_pitch is 90.
	local cmd_hdg is 90.
	local cmd_roll is 90.
	lock cmd_dir to ship:facing.
	local active is true.

	local inc is ceiling(latitude,4).
	local pe is 200.
	local ap is 200.
	local turn_velocity is 50.
	local turn_angle is 10.
	local extra_pitch is 1.

	local state is "Prelaunch".

	set logger to create_gui(
		list(
			lexicon("type", "vbox", "name", "grav_turn", "label", "Gravity turn", "widgets", list(
				lexicon("type", "input", "name", "vel", "label", "Turn start speed:", "tooltip", turn_velocity, "unit", "m/s"),
				lexicon("type", "input", "name", "angle", "label", "Turn start angle:", "tooltip", turn_angle, "unit", "°"),
				lexicon("type", "input", "name", "pitch", "label", "Pitch from prograde:", "tooltip", extra_pitch, "unit", "°"))),
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
		list("Orbit", "P,H,R", "AoP", "TWR", "Status")
	).
	logger:set_settings(lexicon(
		"drop_fairings", true,
		"log_telemetry", false,
		"grav_turn", lexicon("vel", turn_velocity, "angle", turn_angle, "pitch", extra_pitch),
		"orbit", lexicon("pe", pe, "ap", ap, "inc", inc, "inc_info", "Launch azimuth: 90°")
	)).
	logger:gui:show().

	set on_switch to logger:panel:addbutton("Engage autopilot").
	set on_switch:style:align to "center".
	set on_switch:style:hstretch to true.
	set on_switch:toggle to true.
	set on_switch:onclick to {
		if on_switch:pressed {
			if active {
				sas off.
				lock steering to cmd_dir.
			}
		}
		else {
			sas on.
			unlock steering.
		}
	}.

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
			deploy_LES().
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
			set turn_angle to settings:grav_turn:angle:toscalar(turn_angle).
			set turn_velocity to settings:grav_turn:vel:toscalar(turn_velocity).
			set extra_pitch to settings:grav_turn:pitch:toscalar(extra_pitch).
			set cmd_hdg to launch_azimuth(inc).
			logger:set_settings(lexicon(
				"orbit", lexicon("inc_info", "Launch azimuth: " + round(cmd_hdg,1) + "°")
			)).
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

		local true_pitch is vector_pitch(ship:facing:forevector).
		// Roll is undefined if facing roof
		local roll_up is vector_orthogonal(ship:facing:forevector, up:vector).
		local roll is choose vang(ship:facing:topvector, roll_up) if roll_up:mag > 0 else cmd_roll.
		logger:update_readouts(lexicon(
			"Orbit", format_unit(orbit:apoapsis) + "m x " + format_unit(orbit:periapsis) + "m @ " + round(orbit:inclination,2) + "°",
			"P,H,R",
				"" + pp_attitude(true_pitch, cmd_pitch) +
				", " + pp_attitude(choose vector_heading(ship:facing:forevector) if abs(90 - true_pitch) > 0.01 else cmd_hdg, cmd_hdg) +
				", " + pp_attitude(roll, cmd_roll),
			"AoP", round(vang(ship:facing:forevector, ship:velocity:surface),1) + "°",
			"TWR", round(TWR,2),
			"Status", state
		)).


		if pe_shutdown > 0 and periapsis > pe_shutdown and check_cutoff {
			// set ship:control:mainthrottle to 0.
			set ship:control:pilotmainthrottle to 0.
			set check_cutoff to false.
			logger:log("Engine cut-off: " + format_unit(orbit:apoapsis) + "m x " + format_unit(orbit:periapsis) + "m").
		}

		if missionTime > 0 and state = "Prelaunch" {
			set state to "Vertical ascent".
			lock cmd_dir to ship:facing.
		}
		if tower_cleared and state = "Vertical ascent" {
			set state to "Roll program".
			lock cmd_dir to heading(cmd_hdg, cmd_pitch, 360-cmd_roll).
		}
		if state = "Roll program" and ship:velocity:surface:mag > turn_velocity {
			set state to "Pitch program".
			set cmd_pitch to 90 - turn_angle.
			logger:log("Begining pitch program").
		}
		if state = "Pitch program" {
			set cmd_pitch to clamp(vector_pitch(ship:velocity:surface)-extra_pitch, 45, 90-turn_angle).
			if altitude > 50_000 {
				logger:log("End guidance").
				set active to false.
				set on_switch:pressed to false.
				set on_switch:enabled to false.
				sas on.
				unlock steering.
				set state to "Manual flight".
			}
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
