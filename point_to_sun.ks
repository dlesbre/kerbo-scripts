function aligned {
	parameter dir1, dir2 is facing.
	return abs(dir1:pitch - dir2:pitch) < 0.15 and abs(dir1:yaw - dir2:yaw) < 0.15.
}

rcs on.
sas off.
lock np to lookdirup(Body("Sun"):position, facing:topvector).
lock steering to np.

until interrupt or aligned(np, facing) {
	wait 0.1.
}.

unlock steering.
sas on.
