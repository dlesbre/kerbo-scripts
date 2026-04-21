clearScreen.
print "======== Auto-boot ========".
wait until ship:unpacked.
wait 1.
if not homeConnection:isConnected {print "Waiting for connection". wait until homeConnection:isConnected.}
run "0:main".
