// libs/parts.ks - various utility function for manipulating vessel parts
// =============================================================================

// =============================================================================
// Avionics
// =============================================================================

// True if avionics are currently active, false if at least one is deactivated
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

// Deactivate avionics. Returns true if the avionics were previously activated
function shutdown_avionics {
  local avionics is ship:modulesnamed("ModuleProceduralAvionics").
  local deactivated is false.
  for avionic in avionics {
    if avionic:hasevent("shutdown avionics") {
      avionic:doevent("shutdown avionics").
      set deactivated to true.
    }
  }
  return deactivated.
}

// =============================================================================
// Engines
// =============================================================================

// List of all currently active engines
function active_engines {
  list engines in engs.
  local active is list().
  for engine in engs {
    if engine:ignition active:add(engine).
  }
  return active.
}

// Returns all engines that activate on the specified stage
//: (stage? nat) -> List<Engine>
function engines_by_stage {
  parameter stage_nb is stage:number.
  list engines in engs.
  local res is list().
  for engine in engs {
    if engine:stage = stage_nb res:add(engine).
  }
  return res.
}

// Do any of the specified engines require ullage
//: (Engine | List<Engine>) -> Boolean
function engine_ullage {
  parameter engines is active_engines().
  if engines:typename <> "list" set engines to list(engines).
  for engine in engines { if engine:ullage return true. }
  return false.
}

// Max spool-up time of the specified engines
//: (Engine | List<Engine>) -> Boolean
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

local rcs_configs is list("MMH+NTO", "NitrousOxide", "Hydrazine").

// Human friendly name for this engine
function engine_name{
  parameter engine. //: Engine
  if engine:config = "SolidFuel" return engine:title.
  if rcs_configs:find(engine:config) >= 0 return engine:title.
  return engine:config.
}

// After an engine failure, shutdown symmetric engines if specified by engine tag.
// I.E: the engine must be tagged "ShutdownXXX", and all symmetric engines should
// share that tag.
// Returns the number of shutdown engines
function shutdown_symmetric_engines {
  parameter engine.
  if engine:tag:startswith("Shutdown") {
    engine:shutdown().
    // Shutdown symmetric engines to avoid unbalance thrust
    local symmetric_engines is ship:partstagged(engine:tag).
    for eng in symmetric_engines {
      eng:shutdown().
    }
    return symmetric_engines:length.
  }
  return 0.
}

local failed_engines is lexicon().

// Returns "" if the engine is running ok or has run out of fuel
// Returns a failure description if the engine has had a Testflight failure
//   Caches engines, so calling this again on the same failed engine will return "",
//   unless a new failure occurred
function engine_failed {
  parameter engine. //: Engine
  if not engine:hasmodule("ModuleEnginesRF") return "".
  local module is engine:getmodule("ModuleEnginesRF").
  if not module:hasfield("status") return "".
  local engine_status is module:getfield("status").
  if engine_status = "Nominal" return "".
  if engine_status = "Flame-Out!" return "".
  set engine_status to engine_status + " " + (choose module:getfield("cause") if module:hasfield("cause") else "unknown").
  if failed_engines:haskey(engine:uid) {
    local previous_fail is failed_engines[engine:uid].
    if engine_status = previous_fail return "".
  }
  set failed_engines[engine:uid] to engine_status.
  return engine_status.
}

// Unique identifier for engine (including configuration and tech level)
function engine_id {
  parameter engine.
  return engine:title + "##" + engine:config.
}
