// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// libs/string.ks - String manipulation functions, mostly for pretty printing

// left pad a number with zeros
function pad_with_0 {
  parameter n. parameter len is 2.
  return n:tostring():padleft(len):replace(" ", "0").
}

// Print a number with this amount of significant digits
function format_precision {
  parameter n.
  parameter precision.
  set n to round(n, precision):tostring():split(".").
  if n:length = 0 { return n + "." + "":padright(precision):replace(" ", "0"). }
  return n[0] + "." + n[1]:padright(precision):replace(" ", "0").
}


// Print a number as 3 digits + a unit
function format_unit {
  parameter n.
  parameter space is "".

  if n = 0 return "0" + space.
  local units is list("", "k", "M", "G", "T", "Y").
  until abs(n) < 1000 { set n to n/1000. units:remove(0). }
  if abs(n) >= 100 return round(n):tostring() + space + units[0].
  if abs(n) >= 10 return round(n,1):tostring() + space + units[0].
  return round(n,2):tostring() + space + units[0].
}

// Pretty-print an orbit
function format_orbit {
  parameter orb is orbit.
  return format_unit(orb:apoapsis) + "m x " + format_unit(orb:periapsis) + "m @ " + round(orb:inclination,2) + "°".
}

// format duration as '[Ny ][Nd+]HH:MM:SS'
function format_HH_MM_SS {
  parameter t.
  parameter seconds_neg is false. // wether or not to format negative numbers
  local prefix is "".
  if t < 0 {
    if seconds_neg return round(t):tostring() + "s".
    set t to -t.
    set prefix to "-".
  }
  local days is floor(t/86400).
  set t to mod(t,86400).
  local res to pad_with_0(floor(t/3600))+":"+pad_with_0(floor(mod(t,3600)/60))+":"+pad_with_0(floor(mod(t, 60))).
  if days > 365 return prefix + floor(days/365)+"y "+mod(days,365)+"d+"+res.
  else if days > 0 return prefix + days:tostring()+"d+"+res.
  return prefix + res.
}

// format a duration as '4h 30m' or '20m 10s' or '5d 4h'
function format_duration {
  parameter t.
  local prefix is "".
  if t < 0 {
    set t to -t.
    set prefix to "-".
  }
  if t > 86400 return prefix + floor(t/86400):tostring() + "d " + pad_with_0(floor(mod(t,86400)/3600)) + "h".
  if t > 3600 return prefix + floor(t/3600):tostring() + "h " + pad_with_0(floor(mod(t,3600)/60)) + "m".
  if t > 60 return prefix + floor(t/60):tostring() + "m " + pad_with_0(floor(mod(t,60))) + "s".
  return prefix + floor(t):tostring() + "s".
}

// pretty print an angle as x° y' z''
// the second parameter sets the precision:
// 0 -> x°   1 -> x° y'   2 -> x° y' z''   3 -> x° y' z''
function format_angle {
  parameter angle. parameter precision is 2.
  local res is round(angle) + "°".
  if precision > 0 { set res to res + " " + pad_with_0(mod(round(angle*60), 60)) + "'".
  if precision > 1 { set res to res + " " + pad_with_0(mod(round(angle*3600), 60)) + "''".
  }} return res.
}

// Compact string representation of a list
function format_list {
  parameter lst. // : List<'a>
  parameter sep is "\n".
  parameter print_pos is true.
  parameter formatter is { parameter elt. return elt:tostring(). }. // : 'a -> String
  local str is "".
  local i is 0.
  for elt in lst {
    set str to str +
      (choose i:tostring() + ": " if print_pos else "") +
      formatter(elt) +
      (choose sep if i < lst:length - 1 else "").
    set i to i+1.
  }
  return str.
}
