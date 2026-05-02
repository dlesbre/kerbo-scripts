// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// libs/launch_vehicules.ks - Ascent settings for my various rockets
// =============================================================================

function stage_name {
	parameter name.
	parameter log_g is false.
	parameter log_twr is false.
	return lexicon("name", name, "log_g", log_g, "log_twr", log_twr).
}

local stage_names is list(
	stage_name("Engine ignition"),
	stage_name("Liftoff", false, true),
	stage_name("Booster separation", true),
	stage_name("First stage separation", true),
	stage_name("Second stage Ignition"),
	stage_name("Payload release")
).

local stage_names_with_SRB is stage_names:copy().
stage_names_with_SRB:insert(2, stage_name("SRB separation", true)).

// Settings per launch vehicule - To indicate which LV is used, tag a part of
// the launch vehicule with "LV: XXX" as a tag. I typically tag the first-stage
// avionics (ex: "LV: Mustang F")
local lv_settings is lexicon(
	"default", lexicon("turn_start", 50, "turn_angle", 10, "extra_pitch", 1, "roll", 90, "stage_names", stage_names),
	"Mustang F", lexicon("turn_angle", 5, "extra_pitch", 0.5),
	"Stallion", lexicon("turn_start", 60, "turn_angle", 3, "extra_pitch", 0.15, "roll", 0),
  "Stallion B", lexicon("turn_start", 60, "turn_angle", 3.5, "extra_pitch", 0.5, "roll", 0, "stage_names", stage_names_with_SRB)
).

function get_lv_settings {
  local res is lv_settings["default"].

  // Look for any "LV: XXX" tag in the launch vehicule
  local tags is ship:partstaggedpattern("^LV:").
  if tags:length > 0 {
    local lv_name is tags[0]:tag:substring(3, tags[0]:tag:length - 3):trim().
    if lv_settings:hasKey(lv_name) {
      for key in lv_settings[lv_name]:keys() {
        set res[key] to lv_settings[lv_name][key].
      }
    }
  }
  return res.
}
