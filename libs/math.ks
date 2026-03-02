
// clamp(x, mini, maxi) return the element from [mini; maxi] closest to x
function clamp {
	parameter x, mini, maxi. //return 0 if x < 0, 1 if x > 1, x otherwise
	if x >= maxi { return maxi. }
	if x <= mini { return mini. }
	return x.
}

// degree <-> radian converion
function degre2radian { parameter angle. return angle * constant:pi / 180. }
function radian2degre { parameter angle. return angle * 180 / constant:pi. }

// linear_interpolation(x,y, x',y', x'') returns y'' such that (x'', y'') lies on (x,y) -- (x', y')
function linear_interpolation {
	parameter x0, y0, x1, y1, x2.
	local a is (y1 - y0) / (x1 - x0).
	return a*x2 + (y1 - a*x1).
}

function vector_heading{
	parameter vector.
	set a1 to vdot(ship:up:vector,vector)*vector:normalized.
	set a2 to vector-a1.
	return vang(ship:north:vector,a2).
}

function vector_pitch{
	parameter vector.
	return 90-vang(ship:up:vector,vector).
}
