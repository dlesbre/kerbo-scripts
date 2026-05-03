// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// libs/orbital.ks - Orbital calculations
// =============================================================================

run once "0:libs/math.ks".

// orbit_of_pe_ap(pe, ap, [body], [inc], [lan]) -> Orbit
// Create a new orbit with specified periapsis and apoapsis
// The orbit's trueAnomaly is meaningless
function orbit_of_pe_ap {
  parameter pe. // in m
  parameter ap. // in m
  parameter focal is ship:body.
  parameter inclination is 0. // in deg
  parameter lan is 0. // in deg
  local sma is (ap + pe)/2 + focal:radius.
  local ecc is (ap - pe) / (ap + pe).
  return createOrbit(inclination, ecc, sma, lan, 0, 0, 0, focal).
}

// orbital_speed(alt, [pe], [ap], [body]) return the orbital speed at the
// specified altitude
function orbital_speed {
  parameter alti. // in m
  parameter pe is alti. // in m
  parameter ap is pe. // in m
  parameter focal is ship:body.
  local sma is (ap + pe)/2 + focal:radius.
  // https://en.wikipedia.org/wiki/Orbital_speed#Instantaneous_orbital_speed
  return sqrt(focal:mu * (2 / (alti + focal:radius) - 1 / sma)).
}

// Normal vector of an orbit (the purple vector in KSP's maneuver nodes)
function orbit_normal {
  parameter o.
  return vcrs(o:velocity:orbit, o:position - o:body:position):normalized().
}

// =============================================================================
// § Launch azimuth
// =============================================================================

// Absolute launch azimuth in degrees, i.e. the heading of the orbit's ground
// projection at the current latitude. This is not the heading we should aim
// for, as it does not account for initial velocity.
// Note that there are two valid solutions: x or 180 - x
function absolute_launch_azimuth {
  parameter inc.
  if abs(latitude) > abs(inc) { return 90. }
  return mod(arcsin(cos(inc) / cos(latitude)), 360).
}

// True launch azimuth, the heading we should aim for to insert into orbit at the
// specified inclination
// Returns a lexicon with three fields:
// - hdg: the target heading
// - dv_gain: the delta-v gain, how much dv is saved from initial velocity by
//            launching in this inclination
// - azimuth: the absolute launch azimuth
function launch_azimuth {
  parameter inc. // in deg
  parameter south_bound is false. // When false, aim north, else aim south
  parameter pe is 200. // in km
  parameter ap is pe. // in km
  // Take some margin (i.e slightly higher orbit), to avoid the heading flipping
  // if we exceed the orbital speed
  set pe to max(pe*1000, orbit:periapsis + 20000).
  set ap to max(ap*1000, orbit:apoapsis + 100000).
  local azimuth is absolute_launch_azimuth(inc).
  if south_bound { set azimuth to 180 - azimuth. }
  local orbital_velocity is heading(azimuth, 0, 0):vector.
  set orbital_velocity:mag to orbital_speed(max(pe,altitude),pe,ap).
  local true_velocity is orbital_velocity - velocity:orbit.
  return lexicon("hdg", vector_heading(true_velocity), "dv_gain", orbital_velocity:mag - true_velocity:mag, "azimuth", azimuth).
}

// time_to_zenith(inc, lan, lat, long, [body]) returns the next time the
// surface point (lat, long) will be in the orbital plane specified by inc and lan.
// Returns a lexicon with two fields:
//  - time: the time to orbital plane, in seconds (between 0 and body:rotationperiod/2)
//  - northbound: boolean, true if we intersect the orbit at ascending node (orbit
//                heading between 90° and 0°) false at descending node
//
// Original algorithm by https://www.reddit.com/r/KerbalSpaceProgram/comments/jzk3kn/comment/gdc9gbu/
function time_to_zenith {
  parameter inc.
  parameter lan.
  parameter lat.
  parameter long.
  parameter bod is body.
  local tlan is mod(360 + lan - bod:rotationangle, 360).
  local tldn is mod(tlan + 180, 360).

  local incl is max(ceiling(abs(lat),4), round(inc,4)).
  local gamma is arcsin(cos(incl) / cos(lat)).
  local delta is arccos(cos(gamma) / sin(incl)).
  if lat < 0 set delta to -delta.

  // Calculate differences between target and ship
  local lon_diff_AN is mod(360 + tlan - long + delta, 360). // deg
  local lon_diff_DN is mod(360 + tldn - long - delta, 360). // deg

  local lon_diff is min(lon_diff_AN, lon_diff_DN). //DN first
  local rot_rate is 360 / bod:rotationperiod. // deg/s

  return lexicon(
    "time", lon_diff / rot_rate,
    "northbound", lon_diff_AN < lon_diff_DN
  ).
}

// =============================================================================
// § Anomalies and time to nodes
// =============================================================================
// The true anomaly is the angle (periapsis -- body center -- position),
//   It ranges in -179.9° -- 180° , with 0 at periapsis and 180 at apoapsis
// The mean anomaly is what the angle would be if the orbit were perfectly circular
//   It also ranges in -179.9° -- 180° , with 0 at periapsis and 180 at apoapsis
//   However, it only matches the true anomaly at these points. It is useful to
//   compute time information, as it changes at a constant rate (orbit:period/360).

// Mean anomaly from true anomaly
function mean_anomaly {
  parameter orb.
  parameter true_anomaly is orb:trueAnomaly.
  local e is orb:eccentricity.
  if e < 1 { // Elliptical orbit
    // https://en.wikipedia.org/wiki/Mean_anomaly#Formulae
    local tmp is sqrt(1-e^2) * sin(true_anomaly).
    return arcTan2(tmp, e + cos(true_anomaly)) - e * tmp / (1 + e * cos(true_anomaly)) * constant:radtodeg.
  }
  else { // Hyperbolic orbit
    // https://en.wikipedia.org/wiki/Hyperbolic_trajectory#Position
    local hyperbolic_anomaly is 2*arctanh(sqrt((e-1)/(e+1))*tan(true_anomaly/2)).
    return (e*sinh(hyperbolic_anomaly) - hyperbolic_anomaly) * constant:radtodeg.
  }

}

// Time to a point on the orbit, specified by its mean anomaly
// Returns a value between 0 and orb:period.
function time_to_mean_anomaly {
  parameter orb.
  parameter mean_anom.
  local mean_anomaly_diff is mean_anom - mean_anomaly(orb).
  if mean_anomaly_diff < 0 { set mean_anomaly_diff to 360 + mean_anomaly_diff. }
  local n is sqrt(orb:body:mu / abs(orb:semimajoraxis^3)).
  return mean_anomaly_diff * constant:degtorad / n.
}

// Time to a point on the orbit, specified by its true anomaly
// Returns a value between 0 and orb:period.
function time_to_true_anomaly {
  parameter orb.
  parameter true_anomaly.
  return time_to_mean_anomaly(orb, mean_anomaly(orb, true_anomaly)).
}

// Time to periapsis, between 0 and orb:period.
function time_to_periapsis { parameter o is orbit. return time_to_mean_anomaly(o, 0). }

// Time to apoapsis, between 0 and orb:period.
function time_to_apoapsis {	parameter o is orbit.	return time_to_mean_anomaly(o, 180). }

// =============================================================================
// § Orbital altitude
// =============================================================================

// Returns the orbit altitude at the given true anomaly
function altitude_of_true_anomaly {
  parameter orb.
  parameter true_anomaly.
  // https://en.wikipedia.org/wiki/True_anomaly#Radius_from_true_anomaly
  return orb:semimajoraxis * (1 - orb:eccentricity^2) / (1 + orb:eccentricity*cos(true_anomaly)) - body:radius.
}

// Returns the true anomaly (between 0° and 180°) where the orbit has the specified altitude.
// Returns -1 if the altitude is invalid (not between periapsis and apoapsis).
// Note that -x is also a valid true anomaly for the altitude (an orbit passes each altitude twice)
function true_anomaly_of_altitude {
  parameter orb.
  parameter alti.
  // Inverse of https://en.wikipedia.org/wiki/True_anomaly#Radius_from_true_anomaly
  // https://en.wikipedia.org/wiki/Hyperbolic_trajectory#Position
  local true_anomaly_at_alt is ((orb:semimajoraxis * (1 - orb:eccentricity^2)) / (alti + orb:body:radius) - 1) / orb:eccentricity.
  // Unreachable altitude at current orbit
  if true_anomaly_at_alt < -1 or true_anomaly_at_alt > 1 { return -1. }
  return arcCos(true_anomaly_at_alt).
}

// Returns the time to reaching the given altitude (either by descending or ascending)
// Returns -1 if the altitude is invalid (not between periapsis and apoapsis).
function time_to_altitude {
  parameter orb.
  parameter alti.
  set true_anomaly_at_alt to true_anomaly_of_altitude(orb, alti).
  if true_anomaly_at_alt = -1 { return -1. }
  if orb:trueAnomaly > true_anomaly_at_alt or orb:trueAnomaly < -true_anomaly_at_alt {
    set true_anomaly_at_alt to -true_anomaly_at_alt.
  }
  return time_to_true_anomaly(orb, true_anomaly_at_alt).
}

// =============================================================================
// § Relative inclination and AN between two orbits
// =============================================================================

// Unsigned relative inclination between the two orbits
//: (Orbit, Orbit) -> Scalar<deg>
function relative_inclination {
  parameter obt1, obt2.
  // Relative incl is simply the angle between the normal vectors
  return vang(orbit_normal(obt1), orbit_normal(obt2)).
}

// Angle between current position on obt1 and the relative AN of obt1 and obt2
// I.E. angle (obt1:position -- body center -- relative AN).
// Ranges between -179.99° to 180°. 0° means we are at AN, 180° that we are at DN.
function angle_to_relative_AN {
  parameter obt1, obt2.
  local obt1_normal is orbit_normal(obt1).
  return signed_vang(
    vcrs(obt1_normal, orbit_normal(obt2)),
    obt1:position - obt1:body:position,
    obt1_normal).
}

function phase_angle {
  parameter obt1, obt2.
  return signed_vang(
    obt1:position - obt1:body:position,
    obt2:position - obt2:body:position,
    orbit_normal(obt1)
  ).
}
