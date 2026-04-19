
function active_engines {
  list engines in engs.
  local active is list().
  for engine in engs {
    if engine:ignition active:add(engine).
  }
  return active.
}

function engines_by_stage {
  parameter stage_nb is stage:number.
  list engines in engs.
  local res is list().
  for engine in engs {
    if engine:stage = stage_nb
      res:add(engine).
  }
  return res.
}

function engine_ullage {
  parameter engines is active_engines().
  if engines:typename <> "list" set engines to list(engines).
  for engine in engines {
    if engine:ullage return true.
  }
  return false.
}

function engine_spool_up_time {
  parameter engines is active_engines().
  if engines:typename <> "list" set engines to list(engines).
  local max_time is 0.
  for engine in engines {
    if engine:hasmodule("ModuleEnginesRF") {
      local module is engine:getmodule("ModuleEnginesRF").
      if module:hasfield("effective spool-up time")
        set max_time to max(max_time, module:getfield("effective spool-up time")).
    }
  }
  return max_time.
}

function avionics_status {
  local avionics is ship:modulesnamed("ModuleProceduralAvionics").
  for avionic in avionics {
    if avionic:hasevent("activate avionics")
      return false.
  }
  return true.
}

// Activate avionics. Returns true if the avionics were previously deactivated
function activate_avionics {
  local avionics is ship:modulesnamed("ModuleProceduralAvionics").
  local activated is false.
  for avionic in avionics {
    if avionic:hasevent("activate avionics") {
      avionic:doevent("activate avionics").
      set activated to true.
    }
  }
  return activated.
}

function shutdown_avionics {
  local avionics is ship:modulesnamed("ModuleProceduralAvionics").
  local activated is false.
  for avionic in avionics {
    if avionic:hasevent("shutdown avionics") {
      avionic:doevent("shutdown avionics").
      set activated to true.
    }
  }
  return activated.
}
