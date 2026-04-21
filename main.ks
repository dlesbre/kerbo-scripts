// main.ks - Main program, opens a GUI with a flight log that allows selecting
// various autopilot scripts
// =============================================================================

function is_min_cpu {
  for cpu in ship:modulesnamed("kosProcessor") {
    if cpu:bootfilename = core:bootfilename and cpu:mode = "ready" and cpu:part:cid < core:part:cid
      return false.
  }
  return true.
}

// Only run main on one CPU per vessel - other CPUs wait for separation
if not is_min_cpu() {
  print "Not main CPU. Waiting".
  until is_min_cpu() {
    wait 30.
  }
}

wait until homeConnection:isConnected.
run once "0:/libs/gui".
run once "0:/libs/parts".

local program_list is list(
  "Ascent",
  "Maneuver",
  "Point to sun",
  "Part explorer"
).

function error_hud_message {
  parameter message.
  hudtext(message, 3, 2, 30, red, true).
}

global window is create_gui().
global interrupt is false.

local current_program is "".

local program_selector_layout is window:program_selector:addhlayout().
local program_selector is program_selector_layout:addpopupmenu().
set program_selector:options to program_list.
local run_pgrm_btn is program_selector_layout:addbutton("Run").
set run_pgrm_btn:style:width to 50.

local current_program_display is window:program_selector:addhlayout().
set current_program_display:visible to false.
local current_program_label is current_program_display:addlabel("").
local stop_pgrm_btn is current_program_display:addbutton("Stop").
set stop_pgrm_btn:style:width to 50.

function switch_display {
  set interrupt to false.
  set current_program_label:text to "Running: " + current_program.
  set program_selector_layout:visible to false.
  set current_program_display:visible to true.
  set stop_pgrm_btn:enabled to true.
}

set run_pgrm_btn:onclick to {
  set current_program to program_selector:value.
  switch_display().
}.

set stop_pgrm_btn:onclick to {
  set interrupt to true.
  set stop_pgrm_btn:enabled to false.
  set current_program_label:text to "Killed: " + current_program.
  set current_program to "".
}.

function check_engines {
  list engines in ship_engines.
  for engine in ship_engines {
    local fail is engine_failed(engine).
    if fail <> "" {
      local nb is shutdown_symmetric_engines(engine).
      if nb = 0 { window:log(engine_name(engine) + " " + fail). }
      else if nb = 1 { window:log(engine_name(engine) + " " + fail + ", shutdown"). }
      else if nb = 2 { window:log(engine_name(engine) + " " + fail + ", shutdown along with its symmetric engine"). }
      else { window:log(engine_name(engine) + " " + fail + ", shutdown along with " + nb + " symmetric engines"). }
    }
  }
}

if status = "prelaunch" {
  set current_program to "Ascent".
  switch_display().
}
if ship = kuniverse:activevessel
  window:gui:show().

local readouts is list("Electric Charge", "Net Power").
local ec_t is -1.
local ec_amount is -1.
local ec_percent is "none".
window:set_readouts(readouts).
until false {
  if current_program <> "" {
    runpath("0:" + current_program:tolower():replace(" ", "_")).

    set current_program to "".
    set current_program_display:visible to false.
    set program_selector_layout:visible to true.
    set current_program_label:text to "".
    window:panel:clear().
    window:set_readouts(readouts).
    window:set_settings(list()).
    set ec_amount to -1.
    set ec_t to -1.
  }
  local ec_power is 0.
  local ec_capacity is 0.
  local resources is ship:resources.
  for resource in resources {
    if resource:name = "ElectricCharge" {
      if ec_t >= 0 {
        set ec_power to (resource:amount - ec_amount) / (time:seconds - ec_t). // in mW
      }
      set ec_t to time:seconds.
      set ec_amount to resource:amount.
      set ec_capacity to resource:capacity.
      if resource:capacity > 0
        set ec_percent to round(resource:amount * 100 / resource:capacity):tostring() + "%".
      else set ec_percent to "none".
    }
  }
  local ec_power_str is format_unit(ec_power * 1000 , " ") + "W".
  if ec_power < 0 {
    set ec_power_str to "<color=orange>" + ec_power_str + "</color> (empty in " + format_duration(-ec_amount / ec_power) + ")".
  } else if ec_power > 0 {
    set ec_power_str to "<color=green>" + ec_power_str + "</color> (full in " + format_duration((ec_capacity - ec_amount) / ec_power) + ")".
  }
  window:update_readouts(lexicon("Electric Charge", ec_percent, "Net Power", ec_power_str)).
  check_engines().
  wait 1.
}
