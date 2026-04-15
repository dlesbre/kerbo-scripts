// String manipulation functions, mostly for pretty printing

// left pad a number with zeros
function pad_with_0 {
  parameter n. parameter len is 2.
  return n:tostring():padleft(len):replace(" ", "0").
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

// format duration as '[Ny ][Nd+]HH:MM:SS'
function format_duration {
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
