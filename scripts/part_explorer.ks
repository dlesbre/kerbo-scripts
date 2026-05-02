// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// part_explorer.ks - Handy GUI to inspect part/modules in a vessel
// =============================================================================

local window is GUI(500,700).
set window:draggable to true.

local ended is false.
local hbox is window:addhlayout().
local title is hbox:addlabel("<b>Vessel Parts</b>").
set title:style:align to "center".
set title:style:hstretch to true.
local close is hbox:addbutton("<color=red>X</color>").
set close:style:width to 25.
set close:onclick to {
  set ended to true.
}.

set subwindow to window:addvlayout().

local part_list_box is subwindow:addstack().
set part_list_box:style:vstretch to true.
local part_list_vbox is part_list_box:addvlayout().
local searchbar is part_list_vbox:addtextfield("").
set searchbar:style:hstretch to true.
set searchbar:tooltip to "Search".
local part_scrollbox is part_list_vbox:addscrollbox().
set part_scrollbox:style:vstretch to true.


local part_details is subwindow:addstack().
set part_details:style:vstretch to true.
local part_details_layout is part_details:addvlayout().

local module_details is subwindow:addstack().
set module_details:style:vstretch to true.
local module_details_layout is module_details:addvlayout().



subwindow:showonly(part_list_box).

function back_to_part_list {
  set title:text to "<b>Vessel Parts</b>".
  subwindow:showonly(part_list_box).
}

function module_info {
  parameter part_module.

  set title:text to "<b>Module Details</b>".
  module_details_layout:clear().

  module_details_layout:addlabel("Name: " + part_module:name).

  local bck_btn is module_details_layout:addbutton("Back to part list").
  set bck_btn:style:align to "center".
  set bck_btn:style:hstretch to true.
  set bck_btn:onclick to back_to_part_list@.
  local bck_btn2 is module_details_layout:addbutton("Back to part '" + part_module:part:title + "'").
  set bck_btn2:style:align to "center".
  set bck_btn2:style:hstretch to true.
  set bck_btn2:onclick to { subwindow:showonly(part_details). }.

  local vbox is module_details_layout:addscrollbox().

  local fnames is part_module:allfieldnames.
  local i is 0.
  for field in part_module:allfields {
    if i < fnames:length {
      vbox:addlabel("Field: '" +fnames[i] + "' (" + field + ") = " + part_module:getfield(fnames[i])).
    }
    else vbox:addlabel("Field: " + field).
    set i to i + 1.
  }
  for action in part_module:allactions {
    vbox:addlabel("Action: " + action).
  }
  for event in part_module:allevents {
    vbox:addlabel("Event: " + event).
  }

  subwindow:showonly(module_details).
}

function part_info {
  parameter part.

  set title:text to "<b>Parts Details</b>".
  part_details_layout:clear().
  part_details_layout:addlabel("Name: " + part:name).
  part_details_layout:addlabel("Title: " + part:title).
  part_details_layout:addlabel("Type: " + part:typename).
  part_details_layout:addlabel("Mass: " + part:mass + "t  Stage: " + part:stage + "  Decouplein: " + part:decoupledin).
  // part_details_layout:addlabel("P: " + part:position + "   R: " + part:rotation).
  if part:hasparent {
    local hbox is part_details_layout:addhlayout().
    local lbl is hbox:addlabel("Parent: ").
    set lbl:style:hstretch to true.
    local btn is hbox:addbutton(part:parent:title).
    set btn:style:hstretch to true.
    set btn:style:align to "center".
    set btn:onclick to part_info@:bind(part:parent).
  }
  else
    part_details_layout:addlabel("Root part").

  local bck_btn is part_details_layout:addbutton("Back to part list").
  set bck_btn:style:align to "center".
  set bck_btn:style:hstretch to true.
  set bck_btn:onclick to back_to_part_list@.

  local vbox is part_details_layout:addscrollbox().
  local vbox_title is vbox:addlabel("<b>Modules</b>").
  set vbox_title:style:align to "center".

  for module in part:allmodules {
    local btn is vbox:addbutton(module).
    set btn:style:align to "center".
    set btn:style:hstretch to true.
    set btn:onclick to module_info@:bind(part:getmodule(module)).
  }

 //

  subwindow:showonly(part_details).
}


local vbox is part_scrollbox:addvlayout().

for part in ship:parts {
  local btn is vbox:addbutton(part:title).
  set btn:style:align to "center".
  set btn:style:hstretch to true.
  set btn:onclick to part_info@:bind(part).
}

set searchbar:onchange to {
  parameter text.
  if text = "" {
    for widget in vbox:widgets
      set widget:visible to true.
  }
  else {
    for widget in vbox:widgets
      set widget:visible to widget:text:matchespattern(text).
  }
}.


window:show().

until interrupt or ended {
  wait 0.5.
}

window:hide().
// until false {
//   wait 0.1.
// }
