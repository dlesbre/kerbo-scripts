
// clamp(x, mini, maxi) return the element from [mini; maxi] closest to x
function clamp {
	parameter x, mini, maxi. //return 0 if x < 0, 1 if x > 1, x otherwise
	if x >= maxi return maxi.
	if x <= mini return mini.
	return x.
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

function orbit_from_ap_pe {
	parameter pe.
	parameter ap.
	parameter focal is ship:body.
	parameter inclination is 0.
	parameter lan is 0.
	local sma is (ap + pe)/2 + focal:radius.
	local ecc is (ap - pe) / (ap + pe).
	return createOrbit(inclination, ecc, sma, lan, 0, 0, focal).
}

// orbit_speed_at(alt, [pe], [ap], [body]) return the orbital speed at the specified altitude
function orbit_speed_at {
	parameter alti.
	parameter pe is alti.
	parameter ap is pe.
	parameter focal is ship:body.
	local sma is (ap + pe)/2 + focal:radius.
	// https://en.wikipedia.org/wiki/Orbital_speed#Instantaneous_orbital_speed
	return sqrt(focal:mu * (2 / (alti + focal:radius) - 1 / sma)).
}

// Molar Gas constant, in J.K⁻¹.mol⁻¹ (or m³.Pa.K⁻¹.mol⁻¹)
set get_constant to 8.31446261815324.

// This is only an estimate because P/T do not only depend on altitude
// https://en.wikipedia.org/wiki/Dynamic_pressure
function dynamic_pressure {
	local alti is ship:altitude.
	local pressure is body:atm:altitudePressure(alti) * constant:atmtokpa.
	local temperature is body:atm:altitudeTemperature(alti).
	if temperature = 0 return 0.
	local density is 1000 * body:atm:molarmass * pressure / (get_constant * temperature).
	return density * ship:velocity:surface:mag^2 / 2.
}
