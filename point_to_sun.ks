// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// point_to_sun.ks - points current vessel at sun for solar panel exposure
// =============================================================================

// #include "main.ks"

local rot_vel is 1.

function aligned {
	parameter dir1, dir2 is facing.
	return abs(dir1:pitch - dir2:pitch) < 0.15 and abs(dir1:yaw - dir2:yaw) < 0.15 and rot_vel <= 0.5.
}

window:set_readouts(list("Sun angle", "Rotation speed")).

rcs on.
sas off.
local avionics_were_off is activate_avionics().
lock sun_pos to Body("Sun"):position.
lock np to lookdirup(sun_pos, facing:topvector).
lock steering to np.

local old_t is time:seconds.
local old_steer is facing:forevector.

until interrupt or aligned(np, facing) {

	wait 0.01.
	local t is time:seconds.
	local steer is facing:forevector.
	if t > old_t {
		set rot_vel to vang(steer, old_steer) / (t - old_t).
		set old_t to t.
		set old_steer to steer.
	}
	window:update_readouts(lexicon(
		"Sun angle", round(vang(sun_pos, facing:forevector),1):tostring + "°",
		"Rotation speed", round(rot_vel, 2) + "°/s"
	)).
}.

if avionics_were_off shutdown_avionics().
unlock steering.
sas on.
