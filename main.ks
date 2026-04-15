run once "0:/libs/gui".

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

local rcs_configs is list("MMH+NTO", "NitrousOxide", "Hydrazine").
function engine_name{
  parameter engine. //: Engine
  if engine:config = "SolidFuel" return engine:title.
  if rcs_configs:find(engine:config) >= 0 return engine:title.
  return engine:config.
}

local failed_engines is lexicon().
function engine_failed {
  parameter engine. //: Engine
  if not engine:hasmodule("ModuleEnginesRF") return false.
  local module is engine:getmodule("ModuleEnginesRF").
  if not module:hasfield("status") return false.
  local engine_status is module:getfield("status").
  if engine_status = "Nominal" return false.
  if engine_status = "Flame-Out!" return false.
  set engine_status to engine_status + " " + (choose module:getfield("cause") if module:hasfield("cause") else "unknown").
  if failed_engines:haskey(engine:uid) {
    local previous_fail is failed_engines[engine:uid].
    if engine_status = previous_fail return false.
  }
  window:log(engine_name(engine) + " " + engine_status).
  return true.
}

function check_engines {
  list engines in ship_engines.
  for engine in ship_engines {
    engine_failed(engine).
  }
}


if status = "prelaunch" {
  set current_program to "Ascent".
  switch_display().
}
window:gui:show().
until false {
  if current_program <> "" {
    runpath("0:" + current_program:tolower():replace(" ", "_")).

    set current_program to "".
    set current_program_display:visible to false.
    set program_selector_layout:visible to true.
    set current_program_label:text to "".
    window:panel:clear().
    set window:readout_box:visible to false.
    window:set_settings(list()).
  }
  wait 1.
}
