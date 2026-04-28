// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// landing.ks - Moon landing script
// =============================================================================

// #include "main.ks"
run once "0:libs/orbital".
run once "0:libs/math".

window:set_readouts(list("Altitude", "Speed H/V", "Time to impact", "Time to 0 m/s")).


// Pitch input for landing
local pitch_input_val is 0.
local pitch_ctrl is window:panel:addhlayout().
local pitch_input is create_controls(pitch_ctrl, "Pitch:", {parameter val. set pitch_input_val to val. }, pitch_input_val).
local vert_btn is pitch_ctrl:addbutton("Up").
set vert_btn:onclick to { set pitch_input:text to "90". }.

lock cmd_dir to
  choose heading(vector_heading(-velocity:surface), pitch_input_val, 0)
  if pitch_input_val <> 90
  else lookDirUp(up, facing:topvector).

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

local ship_bounds is ship:bounds().
local stage_nb is -1.
local ship_thrust is -1000.
until interrupt {

  if ship:stagenum <> stage_nb {
    set ship_bounds to ship:bounds().
    set stage_nb to ship:stagenum.
    local engines is active_engines().
    set ship_thrust to 0.
    for eng in engines { set ship_thrust to ship_thrust + eng:possiblethrust. }
  }

  local terrain_height is ship_bounds:bottomalt - ship_bounds:bottomaltradar.
  local time_to_impact is time_to_altitude(ship:orbit, terrain_height).

  window:update_readouts(lexicon(
    "Altitude", format_unit(ship_bounds:bottomaltradar) + "m",
    "Speed H/V", format_unit(ship:groundspeed) +"m/s / " + format_unit(ship:verticalspeed) + "m/s",
    "Time to impact", choose "--" if time_to_impact < 0 else round(time_to_impact,1) + "s",
    "Time to 0 m/s", round(ship:mass * velocity:surface:mag / ship_thrust,2) + "s"
  )).

  wait 0.1.
}
unlock steering.
sas on.
