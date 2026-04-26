// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// ascent.ks - Earth ascent script.
//   Autopilot with simple gravity turn in low atmosphere
//   Manual pitch control to circularize
//   Allows launching into a specific inclination, or even a specific plane.
// =============================================================================

// #include "main.ks"
run once "0:/libs/math".

// Settings per launch vehicule - To indicate which LV is used, tag a part of
// the launch vehicule with "LV: XXX" as a tag. I typically tag the first-stage
// avionics (ex: "LV: Mustang F")
local lv_settings is lexicon(
	"default", lexicon("turn_start", 50, "turn_angle", 10, "extra_pitch", 1, "roll", 90),
	"Mustang F", lexicon("turn_angle", 5, "extra_pitch", 0.5),
	"Stallion", lexicon("turn_start", 60, "turn_angle", 3, "extra_pitch", 0.15, "roll", 0)
).

local preset is lv_settings["default"].

// Look for any "LV: XXX" tag in the launch vehicule
local tags is ship:partstaggedpattern("^LV:").
if tags:length > 0 {
	local lv_name is tags[0]:tag:substring(3, tags[0]:tag:length - 3):trim().
	if lv_settings:hasKey(lv_name) {
		for key in lv_settings[lv_name]:keys() {
			set preset[key] to lv_settings[lv_name][key].
		}
	}
}

lock g to earth:mu / (altitude + earth:radius)^2.

local cmd_pitch is 90.
local cmd_hdg is 90.
local cmd_roll is preset:roll.
lock cmd_dir to ship:facing.

local inc is ceiling(abs(latitude),4).
local pe is 160.
local ap is 200.
local lan is 1000. // Default value for when no LAN is input
local turn_velocity is preset:turn_start.
local turn_angle is preset:turn_angle.
local extra_pitch is preset:extra_pitch.
local spool_stage is true.
local follow_prograde is false.

// Inspired by https://www.reddit.com/r/KerbalSpaceProgram/comments/jzk3kn/comment/gdc9gbu/
local warp_margin is 300. // s
local warp_LAN_diff is 0. // deg
function warp_to_LAN {
	if status = "prelaunch" or status = "landed" {
		if lan = 1000 {
			set lan to round(target:orbit:lan,4).
			set inc to target:orbit:inclination.
		}
		local tlan is mod(360 + lan - body:rotationangle + warp_LAN_diff, 360).
		local tldn is mod(tlan + 180, 360).

		local incl is max(ceiling(abs(latitude),4), round(inc,4)).
		local gamma is arcsin(cos(incl) / cos(latitude)).
		local delta is arccos(cos(gamma) / sin(incl)).
		if latitude < 0 set delta to -delta.

		// Calculate differences between target and ship
		local lon_diff_AN is mod(360 + tlan - longitude + delta, 360). // deg
		local lon_diff_DN is mod(360 + tldn - longitude - delta, 360). // deg

		local lon_diff is min(lon_diff_AN, lon_diff_DN). //DN first
		local rot_rate is 360/BODY:ROTATIONPERIOD. // deg/s

		local wait_time is lon_diff/rot_rate. // seconds
		window:log("Warping to " + (choose "LAN" if lon_diff_AN < lon_diff_DN else "LDN") + " in " + format_HH_MM_SS(wait_time)).
		window:update_settings(lexicon("orbit", lexicon("northbound", lon_diff_AN < lon_diff_DN, "inc", incl, "lan", lan))).
		kuniverse:timewarp:warpto(time:seconds + wait_time - warp_margin).
	}
}

function stage_name {
	parameter name.
	parameter log_g is false.
	parameter log_twr is false.
	return lexicon("name", name, "log_g", log_g, "log_twr", log_twr).
}

set stage_names to list(
	stage_name("Engine ignition"),
	stage_name("Liftoff", false, true),
	stage_name("Booster separation", true),
	stage_name("First stage separation", true),
	stage_name("Second stage Ignition"),
	stage_name("Payload release")
).

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
		window:log("Fairing jettison").
	}
	else if fairing_bases:length > 0
		window:log("<color=orange>Only supports one fairing: found " + fairing_bases:length + "</color>").
}

function deploy_LES {
	local LES is ship:partstitledpattern("Launch Escape System").
	if LES:length = 1 {
		LES[0]:getmodule("ModuleEnginesRF"):doaction("activate engine", true).
		LES[0]:getmodule("ModuleDecouple"):doaction("decouple", true).
		window:log("Launch Escape System Jettison").
	}
}

function set_min_incl {
	window:update_settings(lexicon("orbit", lexicon("inc", ceiling(abs(latitude),4)))).
}

function set_tgt_incl {
	if hasTarget
		window:update_settings(lexicon("orbit", lexicon("inc", max(ceiling(abs(latitude),4), round(target:orbit:inclination,4))))).
	else error_hud_message("No target selected").
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

// =============================================================================
// GUI updates
// =============================================================================
local state is "Prelaunch".

local spool_up_time is engine_spool_up_time(engines_by_stage(stage:number-1)).
window:set_settings(list(
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
			lexicon("type", "input", "name", "lan", "label", "LAN:", "tooltip", "", "unit", "°"),
			lexicon("type", "checkbox", "name", "Northbound"),
			lexicon("type", "label", "name", "inc_info", "label", "Launch azimuth: "))),
		lexicon("type", "checkbox", "name", "drop_fairings", "label", "Auto-deploy fairings"),
		lexicon("type", "checkbox", "name", "spool_stage", "label", "Stage after spool-up: " + round(spool_up_time,2) + "s"),
		lexicon("type", "checkbox", "name", "shutdown_pe", "label", "Shutdown when Pe reached"),
		lexicon("type", "checkbox", "name", "follow_prograde", "label", "Follow prograde heading")

	)).
window:set_readouts(list("Orbit", "P,H,R", "Angle on prograde", "TWR", "Status")).
window:update_settings(lexicon(
	"drop_fairings", true,
	"grav_turn", lexicon("vel", turn_velocity, "angle", turn_angle, "pitch", extra_pitch),
	"spool_stage", spool_stage,
	"orbit", lexicon("pe", pe, "ap", ap, "inc", inc, "inc_info", "Launch azimuth: 90°", "northbound", true),
	"follow_prograde", follow_prograde
)).

// Warp to target AN/DN
local warp_to_pane is window:panel:addvlayout().
local warp_to_btn is warp_to_pane:addbutton("Warp to TGT AN/DN").
set warp_to_btn:onclick to warp_to_LAN@.
local warp_to_subpane is warp_to_pane:addhlayout().
warp_to_subpane:addlabel("Margin: ").
local warp_to_input is warp_to_subpane:addtextfield(warp_margin:tostring()).
set warp_to_input:onconfirm to {
	parameter text.
	set warp_margin to text:toscalar(warp_margin).
	set warp_to_input:text to warp_margin:tostring().
}.
warp_to_subpane:addlabel("s").
warp_to_subpane:addlabel("Offset: ").
local warp_LAN_diff_input is warp_to_subpane:addtextfield(warp_LAN_diff:tostring()).
set warp_LAN_diff_input:onconfirm to {
	parameter text.
	set warp_LAN_diff to text:toscalar(warp_LAN_diff).
	set warp_LAN_diff_input:text to warp_LAN_diff:tostring().
}.
warp_to_subpane:addlabel("°").
set warp_to_pane:visible to false.

// Pitch input for circularization
local pitch_input_val is 45.
local pitch_ctrl is window:panel:addhlayout().
local pitch_lbl is pitch_ctrl:addlabel("Pitch:").
local pitch_btn_m10 is pitch_ctrl:addbutton("-10").
local pitch_btn_m1 is pitch_ctrl:addbutton("-1").
local pitch_input is pitch_ctrl:addtextfield("0").
set pitch_input:text to pitch_input_val:tostring().
set pitch_input:onconfirm to {
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

local on_switch is window:panel:addbutton("Engage autopilot").
set on_switch:style:align to "center".
set on_switch:style:hstretch to true.
set on_switch:toggle to true.
set on_switch:onclick to {
	if on_switch:pressed {
		sas off. lock steering to cmd_dir.
	}
	else { sas on. unlock steering. }
}.


// =============================================================================
// Program triggers
// =============================================================================
// Vessel is locked upward until tower is cleared.
local ship_bounds is ship:bounds.
local tower_clear_alt is ship_bounds:bottomaltradar + ship_bounds:size:mag.
local tower_cleared is false.
when interrupt or ship_bounds:bottomaltradar > tower_clear_alt then {
	if interrupt return false.
	set tower_cleared to true.
	window:log("Tower cleared").
}

lock TWR to max(.001, ship:maxthrust/(ship:mass*g)).
local max_g is 0.
local stage_number is stage:number.
local stage_count is 0.
local stage_time is -1.
when interrupt or stage_number <> stage:number then {
	if interrupt return false.
	if stage_count < stage_names:length {
		local stage_info is stage_names[stage_count].
		local message is stage_info:name.
		if stage_info:log_twr { set message to message + " - TWR: " + round(TWR, 2). }
		if stage_info:log_g { set message to message + " - " + round(max_g,2) + "g". set max_g to 0. }
		window:log(message).
	}
	else window:log("Stage " + stage_count).
	set stage_count to stage_count + 1.
	set stage_number to stage:number.
	if stage_time = -1
		set stage_time to time:seconds.
	return true.
}.
when interrupt or orbit:periapsis > 140_000 then {
	if interrupt return false.
	window:log("Achieved orbit").
}
when interrupt or ship:altitude > 50_000 then {
	if interrupt return false.
	if window:get_settings():drop_fairings {
		deploy_fairings().
		deploy_LES().
	}
}

when interrupt or orbit:periapsis > pe * 1000 then {
	if interrupt return false.
	if window:get_settings():shutdown_pe {
		set ship:control:pilotmainthrottle to 0.
		window:log("Engine cut-off: " + format_unit(orbit:apoapsis) + "m x " + format_unit(orbit:periapsis) + "m").
	}
}

local max_q is dynamic_pressure().
local max_q_t is missionTime.
local settings_t is 0.

// In case the script is restarted mid flight, skipped passed log calls
local alt_trigger_index is 0.
until alt_trigger_index >= altitude_triggers:length or ship:altitude < altitude_triggers[alt_trigger_index] {
	set alt_trigger_index to alt_trigger_index + 2.
}
local speed_trigger_index is 0.
until speed_trigger_index >= speed_triggers:length or not above_speed(speed_triggers[speed_trigger_index]) {
	set speed_trigger_index to speed_trigger_index + 2.
}

// =============================================================================
// Main program loop
// =============================================================================

until interrupt {
	// refresh settings every second
	if (time:seconds - settings_t > 1) {
		set settings to window:get_settings().
		set pe to settings:orbit:pe:toscalar(pe).
		set ap to settings:orbit:ap:toscalar(ap).
		set inc to settings:orbit:inc:toscalar(inc).
		set lan to settings:orbit:lan:toscalar(1000).
		set turn_angle to settings:grav_turn:angle:toscalar(turn_angle).
		set turn_velocity to settings:grav_turn:vel:toscalar(turn_velocity).
		set extra_pitch to settings:grav_turn:pitch:toscalar(extra_pitch).
		set spool_stage to settings:spool_stage.
		set follow_prograde to settings:follow_prograde.
		local azim is launch_azimuth(inc, not settings:orbit:northbound, pe, ap).
		set cmd_hdg to choose vector_heading(ship:velocity:orbit) if follow_prograde else azim:hdg.
		window:update_settings(lexicon(
			"orbit", lexicon("inc_info", "Azimuth: " + round(cmd_hdg,1) + "°, DV gain: " + format_unit(azim:dv_gain) + "m/s")
		)).
	}
	check_engines().
	local cur_q is dynamic_pressure().
	if (cur_q > max_q) {
		set max_q to cur_q.
		set max_q_t to missionTime.
	}
	else if (max_q_t > 0 and missionTime - max_q_t > 0.5) {
		window:log("Passed max Q = " + format_unit(max_q, " ") + "Pa").
		set max_q_t to -1.
	}
	set max_g to max(max_g, ship:maxthrust/(ship:mass*constant:g0)).

	local true_pitch is vector_pitch(ship:facing:forevector).
	// Roll is undefined if facing roof
	local roll_up is vector_orthogonal(ship:facing:forevector, up:vector).
	local roll is choose vang(ship:facing:topvector, roll_up) if roll_up:mag > 0 else cmd_roll.
	local readouts is lexicon(
		"Orbit", format_orbit(),
		"P,H,R",
			"" + pp_attitude(true_pitch, cmd_pitch) +
			", " + pp_attitude(choose vector_heading(ship:facing:forevector) if abs(90 - true_pitch) > 0.01 else cmd_hdg, cmd_hdg) +
			", " + pp_attitude(roll, cmd_roll),
		"Angle on prograde", choose round(vang(ship:facing:forevector, velocity:surface),1) + "°" if velocity:surface:mag > 2 else "--°",
		"TWR", round(TWR,2),
		"Status", state
	).


	// Print messages at specific altitudes during ascent
	if alt_trigger_index < altitude_triggers:length and altitude_triggers[alt_trigger_index] < ship:altitude {
		local msg is "Altitude " + round(altitude_triggers[alt_trigger_index] / 1000) + " km".
		if altitude_triggers[alt_trigger_index+1] <> "" {
			set msg to msg + " - " + altitude_triggers[alt_trigger_index+1].
		}
		window:log(msg).
		set alt_trigger_index to alt_trigger_index + 2.
	}
	if speed_trigger_index < speed_triggers:length and above_speed(speed_triggers[speed_trigger_index]) {
		window:log(speed_triggers[speed_trigger_index + 1]).
		set speed_trigger_index to speed_trigger_index + 2.
	}

	if state = "Prelaunch" {
		set warp_to_pane:visible to hasTarget or lan < 1000.
		if stage_time > 0 and time:seconds - stage_time >= spool_up_time and spool_stage {
			stage.
			set stage_time to -5.
		}
		if missionTime > 0 {
			set state to "Vertical ascent".
			lock cmd_dir to ship:facing.
			set warp_to_pane:visible to false.
		}
	}
	if tower_cleared and state = "Vertical ascent" {
		set state to "Roll program".
		lock cmd_dir to heading(cmd_hdg, cmd_pitch, 360-cmd_roll).
	}
	if state = "Roll program" and ship:velocity:surface:mag > turn_velocity {
		set state to "Pitch program".
		set cmd_pitch to 90 - turn_angle.
		window:log("Begining pitch program").
	}
	if state = "Pitch program" {
		set cmd_pitch to clamp(vector_pitch(ship:velocity:surface)-extra_pitch, 45, 90-turn_angle).
		if altitude > 50_000 {
			window:log("End guidance").
			set pitch_ctrl:visible to true.
			set state to "Manual flight".
			if lan < 1000
				window:set_readouts(list("Orbit", "P,H,R", "Time to orbit / AP", "Relative incl", "TWR", "Status")).
			else window:set_readouts(list("Orbit", "P,H,R", "Time to orbit / AP", "TWR", "Status")).
		}
	}
	if state = "Manual flight" {
		set cmd_pitch to pitch_input_val.
		readouts:remove("Angle on prograde").
		local time_to_ap is time_to_apoapsis().
		if time_to_ap > obt:period / 2 { set time_to_ap to time_to_ap - obt:period. }
		set readouts["Time to orbit / AP"] to round(time_to_orbit(pe,ap)):tostring() + "s / " + round(time_to_ap):tostring() + "s".
		if lan < 1000 {
			local tgt_obt is orbit_from_pe_ap(pe,ap,ship:body,inc,lan).
			set readouts["Relative incl"] to round(relative_inclination(orbit, tgt_obt), 3) + "°".
		}
	}
	window:update_readouts(readouts).

	wait 0.001.
}

// Post interrupt cleanup
sas on.
unlock steering.
