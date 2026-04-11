clearScreen.
print "======== Auto-boot ========".
wait 1.
wait until homeConnection:isConnected.
run "0:main".
