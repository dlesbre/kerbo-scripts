run "0:libs/math".
run "0:libs/gui".

set runway_longitude to -(52 + 46 / 60 + 39 / 3600).
set runway_latitude to 5 + 14 / 60 + 37 / 3600.

set runway_altitude to 27.

set runway to latlng(runway_latitude, runway_longitude).

function sin_diff_sq { parameter a. parameter b. return sin((a-b)/2)^2. }.
function angle_from_lat_long {
  parameter lat1.
  parameter long1.
  parameter lat2.
  parameter long2.

  set lat1 to degre2radian(lat1).
  set long1 to degre2radian(long1).
  set lat2 to degre2radian(lat2).
  set long2 to degre2radian(long2).

  // haversine formula: https://fr.wikipedia.org/wiki/Formule_de_haversine
  return 2 * arcsin(sqrt(sin_diff_sq(lat1, lat2) + cos(lat1) * cos(lat2) * sin_diff_sq(long1, long2))).
}


set flap_module to "flp/splr".
set flap_submodule to "flap".
set flap_setting to "flap setting".
// set flap_deflection to flap_module + " dflct".

// Return a list of flaps on the vessel
function get_flaps {
  local flaps is list().
  for module in ship:modulesnamed("FARControllableSurface") {
    if not module:getfield(flap_module) {
      module:setfield(flap_module, true).
      wait 0.02. // Far flaps are hidden in a submodule, so we need to select it to find them
    }
    if module:getfield(flap_submodule) { flaps:add(module). }
    else { module:setfield(flap_module, false). }
  }
  return flaps.
}

function main {
  local logger is create_gui(
    list(lexicon("type", "radio", "name", "Runway", "label", "Runway", "choices", list("Kourou 90", "Kourou 270"))),
    list("Distance", "Off-axis distance", "Heading", "Glide angle", "Flaps")
  ).
  logger:log("Initiate landing guidance").
  logger:gui:show().
  local p_status is ship:status.
  local timer is 0.
  local flap_cur_setting is 0.
  local flaps is get_flaps().
  until false {
    local latitude_drift is ship:latitude - runway_latitude.
    local drift is round(earth:radius * angle_from_lat_long(runway_latitude, 0, ship:latitude, 0)).
    local drift_comment is choose "north" if latitude_drift < 0 else "south".
    if (drift < 10) { set drift_comment to "<color=blue>aligned</color>". }
    if flaps:length > 0 {
      local flp is flaps[0]:getfield(flap_setting).
      if flp = 0 set flap_cur_setting to "  0%".
      if flp = 1 set flap_cur_setting to " 33%".
      if flp = 2 set flap_cur_setting to " 66%".
      if flp = 3 set flap_cur_setting to "100%".
    }
    logger:update_readouts(lexicon(
      "Distance", format_unit(runway:distance) + "m",
      "Off-axis distance", format_unit(drift) + "m " + drift_comment,
      "Heading", + round(runway:heading,1) +"° (bear: " + round(runway:bearing,1) + "°)",
      "Glide angle", round(-vector_pitch(ship:velocity:surface)) + "° / " +round(arcTan((ship:altitude - runway_altitude) / runway:distance),1) + "°",
      "Flaps", flap_cur_setting
    )).
    if (alt:radar < 300) { gear on. }
    if (p_status <> ship:status) {
      if (ship:status = "Landed") {
        logger:log("Touchdown").
        set timer to time:seconds().
        for flap in flaps {
          flap:doaction("increase flap deflection", true).
          flap:doaction("increase flap deflection", true).
        }
      }
      if (ship:status = "Flying" and p_status = "Landed") {
        logger:log("Bounce").
        brakes off.
      }
      set p_status to ship:status.
    }
    if (p_status = "Landed" and time:seconds() - timer > 1) {
      logger:log("Engaging brakes").
      brakes on.
    }
    if (ship:airspeed = 0) {
      logger:log("<b>Landing complete</b>").
      break.
    }


    // print "latitude drift:    " + format_angle(latitude_drift) at (2,2).
    // print "latitude distance: " + drift + "m  " + ( + "    "at (2,3).
    // print "distance:          " + round(runway:distance) + "m" at (2,4).
    // print "bearing:           " + round(runway:bearing,1) at (2,5).
    // print "heading:           " + round(runway:heading,1) at (2,6).
    // print "Glide angle:       " + round(arcTan((ship:altitude - runway_altitude) / runway:distance),1) at (2,7).

    wait 0.01.
  }
}

main().
