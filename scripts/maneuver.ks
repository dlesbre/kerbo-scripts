// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// maneuver.ks - Execute next maneuver node, with various stop burn conditions
// =============================================================================

// #include "main.ks"

local ullage_time is choose 4 if engine_ullage() else 0.
local spool_up is round(engine_spool_up_time(),2).

window:set_settings(list(
    lexicon("type", "input", "name", "ullage", "label", "RCS ullage", "unit", "s"),
    lexicon("type", "checkbox", "name", "follow_node", "label", "Follow maneuver marker"),
    lexicon("type", "popup", "name", "stop_cond", "label", "Stop on",
      "choices", list("Burn time", "Periapsis >=", "Periapsis <=", "Apoapsis >=", "Apoapsis <="),
      "tabs", list(
        list(lexicon("type", "input", "name", "burn_t", "label", "Burn time", "unit", "s")),
        list(lexicon("type", "input", "name", "pe_ge", "label", "Pe Alt >=", "unit", "km")),
        list(lexicon("type", "input", "name", "pe_le", "label", "Pe Alt <=", "unit", "km")),
        list(lexicon("type", "input", "name", "ap_ge", "label", "Ap Alt >=", "unit", "km")),
        list(lexicon("type", "input", "name", "ap_le", "label", "Ap Alt <=", "unit", "km"))
      )
    ),
    lexicon("type", "input", "name", "spool_up", "label", "Engine spoolup: ", "unit", "s")
  )).
window:set_readouts(list("Time to node", "Delta-v", "Status")).
window:gui:show().
window:update_settings(lexicon(
  "ullage", ullage_time,
  "follow_node", true,
  "stop_cond", "Burn Time",
  "pe_ge", 200, "pe_le", 200, "ap_le", 200, "ap_ge", 200,
  "spool_up", spool_up
)).

local warp_margin is 60. // s

local warp_panel is window:panel:addhlayout().
local warp_to is warp_panel:addbutton("Warp to Node").
warp_panel:addlabel("Margin: ").
local warp_to_input is warp_panel:addtextfield(warp_margin:tostring()).
set warp_to_input:onconfirm to {
  parameter text.
  set warp_margin to text:toscalar(warp_margin).
  set warp_to_input:text to warp_margin:tostring().
}.
warp_panel:addlabel("s").
local command_pane is window:panel:addhlayout().
local execute is command_pane:addbutton("Execute").
set execute:toggle to true.
local autostop is command_pane:addbutton("Auto-stop").
set autostop:toggle to true.

local abort is false.
local program_status is "Waiting".

local no_condition is { return true. }.
local check_condition is no_condition@.

set warp_to:onclick to {
  if not hasNode {
    error_hud_message("No node").
    return.
  }
  kuniverse:timewarp:warpto(time:seconds + nextNode:eta - spool_up - warp_margin - ullage_time).
}.

function set_autostop {
  parameter is_on is true.
  set abort to not is_on.
  when (abort or check_condition()) then {
    if not abort {
      set ship:control:pilotmainthrottle to 0.
      window:log("Engine cut-off").
      set program_status to "Burn finished".
      unlock steering.
      sas on.
    }
  }.
}

local autopilot_running is false.
local start_t is -1.
function start_burn {
  window:log("Engine ignition").
  set ship:control:fore to 0.
  set start_t to time:seconds + spool_up.
  set program_status to "Burning".
  rcs on.
  set ship:control:pilotmainthrottle to 1.
}

local orient is ship:facing:forevector.
local avionics_were_off is false.

set execute:ontoggle to {
  parameter is_on.
  set autopilot_running to is_on and not interrupt.
  if autopilot_running {
    set autostop:pressed to true.
    when (not autopilot_running or (hasNode and nextNode:eta - spool_up - ullage_time < 60)) then {
      if not autopilot_running return false.
      sas off.
      rcs on.
      set orient to nextNode:deltav.
      lock steering to lookDirUp(orient, ship:facing:topvector).
      set program_status to "Pointing to node".
      set avionics_were_off to activate_avionics().
      when (not autopilot_running or (hasNode and nextNode:eta - spool_up < ullage_time)) then {
        if not autopilot_running return false.
        if ullage_time > 0 {
          window:log("Settling tanks").
          set program_status to "Ullage burn".
          rcs on.
          set ship:control:fore to 1.
          when (not autopilot_running or (hasNode and nextNode:eta - spool_up < 0)) then start_burn().
        }
        else start_burn().
      }
    }
  }
  else {
    unlock steering.
    sas on.
  }
}.
set autostop:ontoggle to set_autostop@.


until interrupt {
  set abort to abort or interrupt.

  if hasNode {
    window:update_readouts(lexicon(
      "Time to node", format_HH_MM_SS(nextNode:eta, true),
      "Delta-v", format_unit(nextNode:deltav:mag, " ") + "m/s",
      "Status", program_status
    )).
  }
  else {
    window:update_readouts(lexicon(
      "Time to node", "<color=red>No node</color>",
      "Delta-v","<color=red>No node</color>",
      "Status", program_status
    )).
  }

  local settings is window:get_settings().
  set ullage_time to settings:ullage:toscalar(ullage_time).
  set spool_up to settings:spool_up:toscalar(spool_up).
  local burn_t is settings:burn_t:toscalar(-1).
  if settings:stop_cond = "Burn Time" set check_condition to { return start_t > 0 and time:seconds - start_t >= burn_t. }.
  if settings:stop_cond = "Apoapsis <=" set check_condition to { return apoapsis <= 1000*settings:ap_le:toscalar(). }.
  if settings:stop_cond = "Apoapsis >=" set check_condition to { return apoapsis >= 1000*settings:ap_ge:toscalar(). }.
  if settings:stop_cond = "Periapsis <=" set check_condition to { return periapsis <= 1000*settings:pe_le:toscalar(). }.
  if settings:stop_cond = "Periapsis >=" set check_condition to { return periapsis >= 1000*settings:pe_ge:toscalar(). }.
  check_engines().

  if autopilot_running and settings:follow_node and hasNode
    set orient to nextNode:deltav.

  wait 0.1.
}

if avionics_were_off shutdown_avionics().
set autopilot_running to false.
set abort to true.
unlock steering.
sas on.
