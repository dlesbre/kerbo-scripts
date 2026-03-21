function should_cutoff {
  if ship:orbit:hasnextpatch {
    return ship:orbit:nextpatch:periapsis < 30_000.
  }
  return false.
}

local cutoff is false.

when should_cutoff then {
  set ship:control:pilotmainthrottle to 0.
  print "Cutoff".
  set cutoff to true.
}

until cutoff {
  wait 1.
}
