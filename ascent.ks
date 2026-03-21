// #include "libs/math.ks"
run once "0:/libs/math".
run once "0:/libs/gui".

lock g to earth:mu / (altitude + earth:radius)^2.
lock TWR to max(.001, ship:maxthrust/(ship:mass*g)).

set logger to "".

// TestFlight: ModuleEnginesRF
// status = Failed
// cause = Failed to ignite

function unlock {
	if logger:typename = "lexicon" {
		logger:log("Unlocking controls").
	}
	unlock steering.
	unlock throttle.
	set ship:control:pilotmainthrottle to 1.
	sas on.
}

// Inspired by https://www.reddit.com/r/KerbalSpaceProgram/comments/jzk3kn/comment/gdc9gbu/
local warp_margin is 300. // s
function warp_to_LAN {
	if status = "prelaunch" or status = "landed" {
		local tlan is mod(360 + target:orbit:lan - body:rotationangle, 360).
		local tldn is mod(tlan + 180, 360).
		print tlan + " " + tldn.

		local incl is max(ceiling(abs(latitude),4), round(target:orbit:inclination,4)).
		local gamma is arcsin(cos(incl) / cos(latitude)).
		local delta is arccos(cos(gamma) / sin(incl)).
		if latitude < 0 set delta to -delta.

		// Calculate differences between target and ship
		local lon_diff_AN is mod(360 + tlan - longitude + delta, 360). // deg
		local lon_diff_DN is mod(360 + tldn - longitude - delta, 360). // deg

		local lon_diff is min(lon_diff_AN, lon_diff_DN). //DN first
		local rot_rate is 360/BODY:ROTATIONPERIOD. // deg/s

		local wait_time is lon_diff/rot_rate. // seconds
		local margin is logger:get_settings():warp_margin:toscalar(warp_margin).
		logger:log("Warping to " + (choose "LAN" if lon_diff_AN < lon_diff_DN else "LDN") + " in " + format_duration(wait_time)).

		logger:set_settings(lexicon("orbit", lexicon("northbound", lon_diff_AN < lon_diff_DN, "inc", incl))).

		kuniverse:timewarp:warpto(time:seconds + wait_time - margin).
	}
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
	logger:set_settings(lexicon("orbit", lexicon("inc", ceiling(abs(latitude),4)))).
}

function set_tgt_incl {
	if hasTarget
		logger:set_settings(lexicon("orbit", lexicon("inc", max(ceiling(abs(latitude),4), round(target:orbit:inclination,4))))).
	else hudtext("No target selected", 3, 2, 30, red, true).
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

local altitude_triggers is list(
	1_000, "",
	10_000, "",
	20_000, "",
	40_000, "",
	70_000, "",
	100_000, "Karman Line",
	140_000, "Left the atmosphere",
	200_000, ""
).


local speed_of_sound is 350.

local speed_triggers is list(
	-100, "Passing 100 m/s",
	-speed_of_sound, "Vessel supersonic",
	-2*speed_of_sound, "Mach 2",
	-3*speed_of_sound, "Mach 3",
	2000, "Passing 2 km/s",
	4000, "Passing 4 km/s",
	6000, "Passing 6 km/s"
).

function above_speed {
	parameter speed.
	if speed < 0 return ship:airspeed >= - speed.
	return ship:velocity:orbit:mag >= speed.
}

function main {
	local cmd_pitch is 90.
	local cmd_hdg is 90.
	local cmd_roll is 90.
	lock cmd_dir to ship:facing.
	local active is true.

	local inc is ceiling(abs(latitude),4).
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
					lexicon("type", "button", "name", "min_incl", "label", "cur", "onclick", set_min_incl@),
					lexicon("type", "button", "name", "tgt_incl", "label", "tgt", "onclick", set_tgt_incl@)
				)),
				lexicon("type", "checkbox", "name", "Northbound"),
				lexicon("type", "label", "name", "inc_info", "label", "Launch azimuth: "))),
			lexicon("type", "checkbox", "name", "drop_fairings", "label", "Auto-deploy fairings"),
			lexicon("type", "checkbox", "name", "log_telemetry", "label", "Log telemetry"),
			lexicon("type", "input", "name", "shutdown_pe", "label", "Shutdown when Pe >", "tooltip", "150", "unit", "km"),
			lexicon("type", "hlayout", "name", "", "widgets", list(
				lexicon("type", "button", "name", "warp_btn", "label", "Warp to AN/DN", "onclick", warp_to_lan@),
				lexicon("type", "input", "name", "warp_margin", "label", "margin", "unit", "s", "tooltip", warp_margin)
			))
		),
		list("Orbit", "P,H,R", "AoP", "TWR", "Status")
	).
	logger:set_settings(lexicon(
		"drop_fairings", true,
		"log_telemetry", false,
		"grav_turn", lexicon("vel", turn_velocity, "angle", turn_angle, "pitch", extra_pitch),
		"orbit", lexicon("pe", pe, "ap", ap, "inc", inc, "inc_info", "Launch azimuth: 90°", "northbound", true),
		"warp_margin", warp_margin
	)).
	logger:gui:show().

	local pitch_input_val is 45.

	local pitch_ctrl is logger:panel:addhlayout().
	local pitch_lbl is pitch_ctrl:addlabel("Pitch:").
	local pitch_btn_m10 is pitch_ctrl:addbutton("-10").

	local pitch_btn_m1 is pitch_ctrl:addbutton("-1").
	local pitch_input is pitch_ctrl:addtextfield("0").
	set pitch_input:text to pitch_input_val:tostring().
	set pitch_input:onchange to {
		set pitch_input_val to pitch_input:text:toscalar(pitch_input_val).
		set pitch_input:text to pitch_input_val:tostring().
	}.
	local pitch_btn_p1 is pitch_ctrl:addbutton("+1").
	local pitch_btn_p10 is pitch_ctrl:addbutton("+10").

	function change_pitch{ parameter amount.
		set pitch_input_val to pitch_input_val + amount.
		set pitch_input:text to pitch_input_val:tostring(). }
	set pitch_btn_m10:onclick to change_pitch@:bind(-10).
	set pitch_btn_m1:onclick to change_pitch@:bind(-1).
	set pitch_btn_p1:onclick to change_pitch@:bind(1).
	set pitch_btn_p10:onclick to change_pitch@:bind(10).
	set pitch_ctrl:visible to false.


	local on_switch is logger:panel:addbutton("Engage autopilot").
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

	local tower_clear_alt is ship:bounds:bottomaltradar + ship:bounds:size:mag.

	// Vessel is locked upward until tower is cleared.
	local tower_cleared is false.

	// Logging triggers
	when ship:bounds:bottomaltradar > tower_clear_alt then {
		set tower_cleared to true.
		logger:log("Tower cleared").
	}

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

	when orbit:periapsis > pe_shutdown then {
		if pe_shutdown > 0 {
			set ship:control:pilotmainthrottle to 0.
			logger:log("Engine cut-off: " + format_unit(orbit:apoapsis) + "m x " + format_unit(orbit:periapsis) + "m").
		}
	}

	local alt_trigger_index is 0.
	until alt_trigger_index >= altitude_triggers:length or ship:altitude < altitude_triggers[alt_trigger_index] {
		set alt_trigger_index to alt_trigger_index + 2.
	}
	local speed_trigger_index is 0.
	until speed_trigger_index >= speed_triggers:length or not above_speed(speed_triggers[speed_trigger_index]) {
		set speed_trigger_index to speed_trigger_index + 2.
	}

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
			local azim is launch_azimuth(inc, not settings:orbit:northbound).
			set cmd_hdg to azim:hdg.
			logger:set_settings(lexicon(
				"orbit", lexicon("inc_info", "Azimuth: " + round(cmd_hdg,1) + "°, DV gain: " + format_unit(azim:dv_gain) + "m/s")
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

		// Print messages at specific altitudes during ascent
		if alt_trigger_index < altitude_triggers:length and altitude_triggers[alt_trigger_index] < ship:altitude {
			local msg is "Altitude " + round(altitude_triggers[alt_trigger_index] / 1000) + " km".
			if altitude_triggers[alt_trigger_index+1] <> "" {
				set msg to msg + " - " + altitude_triggers[alt_trigger_index+1].
			}
			logger:log(msg).
			set alt_trigger_index to alt_trigger_index + 2.
		}
		if speed_trigger_index < speed_triggers:length and above_speed(speed_triggers[speed_trigger_index]) {
			logger:log(speed_triggers[speed_trigger_index + 1]).
			set speed_trigger_index to speed_trigger_index + 2.
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
				set pitch_ctrl:visible to true.
				set state to "Manual flight".
			}
		}
		if state = "Manual flight" {
			set cmd_pitch to pitch_input_val.
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
