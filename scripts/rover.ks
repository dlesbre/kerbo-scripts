// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// rover.ks - simple rover autopilot and cruise control
// =============================================================================

// #include "0:main"
run once "0:libs/parts".
run once "0:libs/math".

local max_fail_time is 0.2.


window:set_readouts(list("Speed", "Wheel fail time")).
window:set_settings(list(lexicon("type", "input", "name", "max_fail_time", "label", "Max fail time"))).
window:update_settings(lexicon("max_fail_time", max_fail_time)).

local speed_tgt is 0.
local heading_tgt is round(vector_heading(ship:facing:forevector)).
create_controls(window:panel:addHLayout(), "Target speed:", {parameter val. set speed_tgt to val.}, speed_tgt).
create_controls(window:panel:addHLayout(), "Heading:", { parameter val. set heading_tgt to remaider(val,360). }, heading_tgt).

local on_switch is window:panel:addbutton("Engage autopilot").
local ctrl is ship:control.
lock cmd_dir to heading(heading_tgt, vector_pitch(ship:facing:forevector)).
set on_switch:style:align to "center".
set on_switch:style:hstretch to true.
set on_switch:toggle to true.
set on_switch:onclick to {
	if on_switch:pressed {
		sas off.
    activate_avionics().
	}
	else { sas on. unlock steering. set ctrl:neutralize to true. }
}.

local wheel_modules is get_wheel_dmg_modules().
local fail_cooldown is false.
local ctrl is ship:control.
local last_t is 0.

local steering_velocity_pid is pidLoop(0.5, 0, 0, -1, 1, 0.05).

local old_t is time:seconds.
local old_heading is vector_heading(ship:facing:forevector).
wait 0.1.

until interrupt {
  local hdg is vector_heading(ship:facing:forevector).
  local hdg_change_rate is (hdg-old_heading) / (time:seconds - old_t).
  set old_t to time:seconds.
  set old_heading to hdg.

  if time:seconds - last_t > 1 {
    local settings is window:get_settings().
    set max_fail_time to settings:max_fail_time:toScalar(max_fail_time).
    set last_t to time:seconds.
  }

  local speed is ship:velocity:surface:mag.
  local fail_time is wheel_failure_time(wheel_modules).

  if on_switch:pressed {
    if fail_cooldown {
      if fail_time < 0.01 { set fail_cooldown to false. }
    }
    else if fail_time > max_fail_time {
      set fail_cooldown to true.
      set ctrl:wheelthrottle to 0.
    }
    else {
      set ctrl:wheelthrottle to clamp(2*(speed_tgt - speed),0,1).

      local heading_diff is remaider(heading_tgt - hdg,360).
      if heading_diff > 180 { set heading_diff to heading_diff-360. }
      if abs(heading_diff) < 0.2 { set heading_diff to 0. }
      local vdiff is clamp(heading_diff/2, -10, 10) - hdg_change_rate.
      set ctrl:wheelsteer to -clamp(vdiff / (8 + max(2, 2*speed)), -1, 1).
    }
    if speed > speed_tgt + 1 { brakes on. }
    else if speed <= speed_tgt { brakes off. }
  }

  window:update_readouts(lexicon(
    "Speed", format_unit(speed) + "m/s",
    "Wheel fail time", format_precision(fail_time, 2)
    // "Inputs", round(ctrl:wheelthrottle,2) + " / " + round(ctrl:wheelsteer,2)
  )).
  wait 0.1.
}
unlock steering.
set ctrl:neutralize to true.
