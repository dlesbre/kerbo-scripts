// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// libs/math.ks - Various math operation and calculations
// =============================================================================

// clamp(x, mini, maxi) return the element from [mini; maxi] closest to x
function clamp {
	parameter x, mini, maxi. //return 0 if x < 0, 1 if x > 1, x otherwise
	return max(min(x, maxi), mini).
}

// degree <-> radian converion
function degre2radian { parameter angle. return angle * constant:degtorad. }
function radian2degre { parameter angle. return angle * constant:radtodeg. }

// linear_interpolation(x,y, x',y', x'') returns y'' such that (x'', y'') lies on (x,y) -- (x', y')
function linear_interpolation {
	parameter x0, y0, x1, y1, x2.
	local a is (y1 - y0) / (x1 - x0).
	return a*x2 + (y1 - a*x1).
}

// The exponential function
function exp { parameter x. return constant:e^x. }

// Euclidian remainder, guaranteed to be in [0:d-1]
function remaider { parameter n,d.
	local re is mod(n,d).
	if re < 0 { return re + d. }
	return re.
}

// =============================================================================
// Vector operations
// =============================================================================

function vector_heading{
	parameter vector.
	local east is vcrs(up:vector, north:vector).
	local north_component is vdot(north:vector:normalized, vector).
	local east_component is vdot(east:normalized, vector).
	return mod(arcTan2(east_component, north_component)+360, 360).
}

function vector_pitch{
	parameter vector.
	return 90-vang(up:vector,vector).
}

// vector_orthogonal(v1,v2) returns a vector orthogonal to v1 in the plane of v1,v2
function vector_orthogonal{
	parameter v1, v2.
	return vcrs(vcrs(v1,v2), v1).
}

// vector_clamp(v1, v2, ang) is the vector closest to v2 whose max angle to v1 is ang.
function vector_clamp{
	parameter v1, v2, ang.
	set v1 to v1:normalized.
	set v2 to v2:normalized.
	local t_ang is vang(v1,v2).
	if t_ang <= ang return v2.
	return cos(ang)*v1 + sin(ang)*vector_orthogonal(v1,v2).
}

// signed_vang(va, vb, vn) is the angle (in degrees) between va and vb, oriented
// by vn in right-handed notation. Ranges between -179.99° and 180°.
function signed_vang {
  parameter va, vb, vn. return arctan2(vcrs(va,vb)*vn, va*vb).
}

// burn_time(deltav, thrust, massflow, [mass]) is the time it takes to change
// velocity by deltav at the specified thrust and massflow.
function burn_time {
	parameter deltav. // in m/s
	parameter thrust. // in kN
	parameter massflow. // in t/s (Mg/s)
	parameter init_mass is ship:mass. // in t (Mg)
	// Newton's law: F = ma, here F is constant and m = mass - massflow*t, so:
	//     a(t) = F / (mass - massflow * t) = F/mass * 1 / (1 - massflow/mass*t)
	// Integrating on t:
	//     dv = F/mass * (-mass/massflow) ln(1 - massflow/mass*t)
	// Which gives:
	//     exp(- dv * massflow / F) = 1 - massflow/mass * t
	//     t = (1 - exp(-dv*massflow / F)) * mass / massflow
	return (1 - constant:e^(-deltav*massflow / thrust)) * init_mass / massflow.
}

function time_to_orbit {
	parameter pe. // in m
	parameter ap. // in m
	parameter massflow. // in t/s (Mg/s)
	parameter thrust is ship:maxthrust. // in kN
	parameter init_mass is ship:mass.
	if thrust = 0 { return -1. }
	local deltav is orbital_speed(pe,pe,ap) - velocity:orbit:mag.
	if deltav < 0 { return 0. }
	return burn_time(deltav, thrust, massflow, init_mass).
}

// =============================================================================
// Hyperbolic trigonometry
// =============================================================================
// Hyperbolic trigonometric functions are essentially the same as the usual trig
// function, only replacing e^(ix) by e^x. Useful for calculation on hyperbolic
// orbits

// Hyperbolic sine, return value can be any real
function sinh { parameter x. return (exp(x) - exp(-x)) / 2. }

// Hyperbolic cosine, return value is >= 1.
function cosh { parameter x. return (exp(x) + exp(-x)) / 2. }

// Hyperbolic tangent, return value is in ]-1:1[
// tanh(x) = sinh(x) / cosh(x), inlined to limit calls to exp.
function tanh { parameter x.
	local ex is exp(x).
	local emx is exp(-x).
	return (ex - emx) / (ex + emx).
}

function arcsinh { parameter x. return ln(x + sqrt(x^2 + 1)). }

// Only defined if x >= 1.
function arccosh { parameter x. return ln(x + sqrt(x^2 - 1)). }

// Only defined if x in ]-1:1[
function arctanh { parameter x. return ln((1+x) / (1-x))/2. }
