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
  }
  wait 1.
}
