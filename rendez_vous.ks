// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// rendez_vous.ks
// =============================================================================

// #include "main.ks"
run once "0:libs/orbital".
run once "0:libs/math".

window:set_readouts(list("Orbit", "Target", "Relative incl", "A/D", "Phase angle")).

function format_node_angle{
  parameter angle.
  return round(angle) + "° (" + format_duration(time_to_true_anomaly(obt, obt:trueAnomaly + angle)) + ")".
}

until interrupt {
  if hasTarget {
    local tgt is target.
    if tgt:typename = "Part" { set tgt to tgt:ship. }
    local an_angle is angle_to_relative_AN(obt, tgt:orbit).
    local phase_diff is (orbit:period - tgt:orbit:period) * 360 / orbit:period.
    local dn_angle is choose an_angle + 180 if an_angle < 0 else an_angle - 180.
    window:update_readouts(lexicon(
      "Orbit", format_orbit(),
      "Target", format_orbit(tgt:obt),
      "Relative incl", format_precision(relative_inclination(obt, tgt:orbit),4) + "°",
      "A/D", format_node_angle(an_angle) + " / " + format_node_angle(dn_angle),
      "Phase angle", round(phase_angle(obt, tgt:orbit),1)+"° (" + (choose "+" if phase_diff > 0 else "") + round(phase_diff,1) + "°/obt)"
    )).
  }

  check_engines().
  wait 0.1.
}
