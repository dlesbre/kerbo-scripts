// #include "../libs/string.ks"

run "0:libs/string".

function mlog {
  parameter scrollbox.
  parameter vbox.
  parameter debug.
  parameter debug_labels.
  parameter show_debug.
  parameter message.
  local color is choose "purple" if debug else "white".
  local label is vbox:addlabel("[" + format_duration(missionTime) + "] <color=" + color + ">" + message + "</color>").
  set scrollbox:position to V(0,40000,0).
  set label:style:margin:v to 0.
  if debug {
    debug_labels:add(label).
    if not show_debug:pressed
      set label:visible to false.
  }
}

// Create a set of easily updatable flight readouts
// Takes a list of readouts (either string, or lexicon("name": String; "label": String, "align: String = "right" "unit": String?)
function create_readouts {
  parameter vbox.
  parameter readouts. // list<lexicon>

  local readout_widgets is lexicon().

  function set_style{ parameter label.
    set label:style:margin:v to 0.
    set label:style:margin:h to 10.
    set label:style:hstretch to true.
  }

  for readout in readouts {
    local hbox is vbox:addhlayout().
    set hbox:style:margin:v to 0.
    set hbox:style:padding:v to 0.

    if readout:typename = "lexicon" {
      set_style(hbox:addlabel(choose readout:label if readout:haskey("label") else readout:name)).
      local vlabel is hbox:addlabel("").
      set_style(vlabel).
      set vlabel:style:align to choose readout:align if readout:haskey("align") else "right".
      set vlabel:style:hstretch to true.
      set readout_widgets[readout:name] to vlabel.
    }
    else if readout:typename = "string" {
      set_style(hbox:addlabel(readout)).
      local vlabel is hbox:addlabel("").
      set_style(vlabel).
      set vlabel:style:align to "right".
      set readout_widgets[readout] to vlabel.
    }
  }
  return readout_widgets.
}

function update_readouts {
  parameter readout_widgets.
  parameter values.
  for k in values:keys() {
    set readout_widgets[k]:text to values[k]:tostring().
  }
}

function merge_lexicons {
  parameter parent.
  parameter child.
  for k in child:keys
    set parent[k] to child[k].
}

// Settings are specified via a list of lexicon with the following keys
// name: String, setting variable name
// label: String, pretty description, may be omitted for "popup"
// type: one of
// - "checkbox" -> simple checkbox with given label
// - "pbutton" -> checkbox but with button skin
// - "button" -> simple button with given label
// - "input" -> Text input
//               - optional 'align: String' specifies how a value should be aligned
//               - optional 'unit: String' specifies a unit displayed after the box
//               - optional 'tooltip: String' specifies greyed out text
// - "popup" -> list of choices, must be provided in "choices"
// - "radio" -> same as popup, but list of radio buttons
// - "vbox" -> box containing sub-widgets, specified in the "widgets" field
// Settings then need to be initialized via set_settings
function create_settings {
  parameter vbox.
  parameter settings.
  parameter title_text is "Settings".

  local setting_widgets is lexicon().

  if title_text <> "" {
    local title is vbox:addlabel("<b>" + title_text + "</b>").
    set title:style:align to "center".
    vbox:addspacing(10).
  }
  for setting in settings {
    local label is choose setting:label if setting:haskey("label") else setting:name.
    if setting:type = "checkbox"
      set setting_widgets[setting:name] to vbox:addcheckbox(label, false).
    else if setting:type = "pbutton" {
      local widget is vbox:addbutton(label).
      set widget:toggle to true.
      set setting_widgets[setting:name] to widget.
    }
    else if setting:type = "button" {
      local widget is vbox:addbutton(label).
      set setting_widgets[setting:name] to widget.
      if setting:haskey("onclick") set widget:onclick to setting:onclick.
    }
    else if setting:type = "label"
      set setting_widgets[setting:name] to vbox:addlabel(label).
    else if setting:type = "input" {
      local widget is vbox:addhlayout().
      local label_widget is widget:addlabel(label).
      set label_widget:style:hstretch to true.
      local text_widget is widget:addtextfield("").
      set text_widget:style:hstretch to true.
      set text_widget:style:align to choose setting:align if setting:haskey("align") else "right".
      if setting:haskey("tooltip") { set text_widget:tooltip to setting:tooltip:tostring(). }
      if setting:haskey("unit") { widget:addlabel(setting:unit). }
      set setting_widgets[setting:name] to text_widget.
    }
    else if setting:type = "popup" {
      local parent is vbox.
      if setting:haskey("label") {
        local widget is vbox:addhlayout().
        local label_widget is widget:addlabel(label).
        set label_widget:style:hstretch to true.
        set parent to widget.
      }
      local popup is parent:addpopupmenu().
      set popup:options to setting:choices.
      set popup:style:hstretch to true.
      set setting_widgets[setting:name] to popup.
    }
    else if setting:type = "radio" {
      local widget is vbox:addvlayout().
      if setting:haskey("label") {
        local title is widget:addlabel("<b>" + label + "</b>").
        set title:style:align to "center".
      }
      for choice in setting:choices { widget:addradiobutton(choice, false). }
      set setting_widgets[setting:name] to widget.
    }
    else if setting:type = "vbox" or setting:type = "hbox" or setting:type = "hlayout" or setting:type = "vlayout" {
      local box is
        choose vbox:addvbox() if setting:type = "vbox" else
        choose vbox:addhbox() if setting:type = "hbox" else
        choose vbox:addhlayout() if setting:type = "hlayout" else vbox:addvlayout().
      local sub_settings is
        choose create_settings(box, setting:widgets, label)
        if setting:haskey("label")
        else create_settings(box, setting:widgets, "").
      if setting:name <> ""
        set setting_widgets[setting:name] to sub_settings.
      else merge_lexicons(setting_widgets, sub_settings).
    }
    else print "Error: unknown setting:type '" + setting:type + "'".
  }
  return setting_widgets.
}

function set_settings {
  parameter setting_widgets.
  parameter values.
  for key in values:keys() {
    local widget is setting_widgets[key].
    if widget:typename = "checkbox" or widget:typename = "button"
      set widget:pressed to values[key].
    else if widget:typename = "textfield" or widget:typename = "label"
      set widget:text to values[key]:tostring().
    else if widget:typename = "popupmenu" {
      local index is widget:options:find(values[key]).
      set widget:index to index.
      if index < 0 print "Error: invalid popup choice '" + values[key] + "'".
    }
    else if widget:typename = "lexicon" {
      set_settings(widget, values[key]).
    }
    else if widget:typename = "box" {
      local correct is values[key] = "".
      for widget in widget:widgets {
        if widget:typename = "button" {
          local matches is widget:text = values[key].
          set widget:pressed to matches.
          set correct to correct or matches.
        }
      }
      if not correct print "Error: invalid checkbox choice '" + values[key] + "'".
    }
    else print "Error: unknown widget type '" + widget:typename + "'".
  }
}

function get_settings {
  parameter setting_widgets.
  local result is lexicon().
  for key in setting_widgets:keys() {
    local widget is setting_widgets[key].
    if widget:typename = "checkbox" or widget:typename = "button" set result[key] to widget:pressed.
    else if widget:typename = "textfield" or widget:typename = "label" set result[key] to widget:text.
    else if widget:typename = "popupmenu" set result[key] to widget:value.
    else if widget:typename = "lexicon" set result[key] to get_settings(widget).
    else if widget:typename = "box" set result[key] to widget:radiovalue.
    else print "Error: unknown widget type '" + widget:typename + "'".
  }
  return result.
}

function create_gui {
  parameter settings is list().
  parameter readouts is list().
  parameter width is 350.
  parameter height is 400.

  local readouts_height is 25 * readouts:length().

  local settings_width is 250.

  local main_gui is GUI(width, height + readouts_height).
  set main_gui:draggable to true.
  set main_gui:x to 120. // Window in top left
  set main_gui:y to 75.

  local contents is main_gui:addhlayout().

  local left_panel is contents:addvlayout().
  set left_panel:style:width to width - 20.
  local right_panel is contents:addvlayout().
  set right_panel:visible to false.

  local settings_widget is create_settings(right_panel, settings).

  local tbox is left_panel:addhlayout().
  local title is tbox:addlabel("<b>    Flight computer</b>").
  set title:style:hstretch to true.
  local close is tbox:addbutton("<color=red>X</color>").
  set close:style:width to 25.
  set close:onclick to { set main_gui:visible to false. }.


  set title:style:align to "center".
  left_panel:addspacing(10).

  local readouts_box is left_panel:addvbox().
  set readouts_box:style:height to readouts_height.
  set readouts_box:style:width to 270.
  set readouts_box:style:margin:h to 30.
  set readouts_box:style:padding:v to 5.
  local readout_widgets is create_readouts(readouts_box, readouts).

  local toggles is left_panel:addhlayout().
  set toggles:style:hstretch to true.

  local show_debug is toggles:addcheckbox("show debug", false).
  local debug_labels is list(). // type: list<label>
  set show_debug:onclick to { for label in debug_labels { set label:visible to show_debug:pressed. }}.
  set show_debug:style:hstretch to true.
  //set space:style:hstretch to true.
  local show_settings is toggles:addcheckbox("show settings", false).
  set show_settings:onclick to {
    set right_panel:visible to show_settings:pressed.
    if show_settings:pressed set main_gui:style:width to width + settings_width.
    else set main_gui:style:width to width.
  }.
  set show_settings:style:hstretch to true.

  local scrollbox is left_panel:AddScrollBox().
//set scrollbox:style:width to width - 40.
  //set scrollbox:style:height to 200.
  set scrollbox:style:vstretch to true.
  set scrollbox:valways to true.

  left_panel:addspacing(20).

  function toggle_gui_visibility {
    if main_gui:visible main_gui:hide().
    else main_gui:show().
    on ag10 toggle_gui_visibility().
  }
  on ag10 toggle_gui_visibility().



  local vbox is scrollbox:AddVLayout().
  return lexicon(
    "gui", main_gui,
    // "scrollbox", scrollbox,
    // "vbox", vbox,
    // "settings", settings_widget,
    "panel", left_panel:addvlayout(),
    "log", mlog@:bind(scrollbox, vbox, false, debug_labels, show_debug),
    "debug", mlog@:bind(scrollbox, vbox, true, debug_labels, show_debug),
    "set_settings", set_settings@:bind(settings_widget),
    "get_settings", get_settings@:bind(settings_widget),
    "update_readouts", update_readouts@:bind(readout_widgets)
  ).
}
