clearScreen.
print "======== Auto-boot ========".
wait until ship:unpacked.

function is_min_cpu {
  for cpu in ship:modulesnamed("kosProcessor") {
    if cpu:bootfilename = core:bootfilename and cpu:mode = "ready" and cpu:part:cid < core:part:cid
      return false.
  }
  return true.
}

if not is_min_cpu() {
  print "Not main CPU. Waiting".
  until is_min_cpu() {
    wait 30.
  }
}

wait 1.
wait until homeConnection:isConnected.
run "0:main".
