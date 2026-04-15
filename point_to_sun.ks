// #include "main.ks"
run once "0:libs/string".

function aligned {
	parameter dir1, dir2 is facing.
	return abs(dir1:pitch - dir2:pitch) < 0.15 and abs(dir1:yaw - dir2:yaw) < 0.15.
}

local rd_sun_angle is "Sun angle".
local rd_rotation is "Rotation speed".

window:set_readouts(list(rd_sun_angle, rd_rotation)).

rcs on.
sas off.
lock sun_pos to Body("Sun"):position.
lock np to lookdirup(sun_pos, facing:topvector).
lock steering to np.

local old_t is time:seconds.
local old_steer is facing:forevector.
local rot_vel is 0.

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
		rd_sun_angle, round(vang(sun_pos, facing:forevector),1):tostring + "°",
		rd_rotation, round(rot_vel, 2) + "°/s"
	)).
}.

unlock steering.
sas on.
