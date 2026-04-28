// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// libs/parts.ks - various utility function for manipulating vessel parts
// =============================================================================

// get_field checks for field existence before getting it, else returns the default
function get_field {
  parameter module.
  parameter field.
  parameter default.
  if module:hasField(field) { return module:getField(field). }
  return default.
}

// list_filter(f, l) is the sublist of elements of l that verify f
function list_filter {
  parameter filter. // : 'a -> Boolean
  parameter lst. // : List<'a>
  local res is list().
  for elt in lst {
    if filter(elt) { res:add(elt). }
  }
  return res.
}

// =============================================================================
// Avionics
// =============================================================================

local MOD_AVIONICS is "ModuleProceduralAvionics".
local EVT_AVIONICS_ON is "activate avionics".
local EVT_AVIONICS_OFF is "shutdown avionics".

// True if avionics are currently active, false if at least one is deactivated
function avionics_status {
  local avionics is ship:modulesnamed(MOD_AVIONICS).
  for avionic in avionics {
    if avionic:hasevent(EVT_AVIONICS_ON)
      return false.
  }
  return true.
}

// Activate avionics. Returns true if the avionics were previously deactivated
function activate_avionics {
  local avionics is ship:modulesnamed(MOD_AVIONICS).
  local activated is false.
  for avionic in avionics {
    if avionic:hasevent(EVT_AVIONICS_ON) {
      avionic:doevent(EVT_AVIONICS_ON).
      set activated to true.
    }
  }
  return activated.
}

// Deactivate avionics. Returns true if the avionics were previously activated
function shutdown_avionics {
  local avionics is ship:modulesnamed(MOD_AVIONICS).
  local deactivated is false.
  for avionic in avionics {
    if avionic:hasevent(EVT_AVIONICS_OFF) {
      avionic:doevent(EVT_AVIONICS_OFF).
      set deactivated to true.
    }
  }
  return deactivated.
}

// =============================================================================
// Engines
// =============================================================================

local MOD_ENGINE_RF is "ModuleEnginesRF".

// engine spool-up time, in s
local FLD_ENGINE_SPOOL_UP is "effective spool-up time".

// residual fuel at flameout, as a fraction of total fuel amount
local FLD_ENGINE_RESIDUALS is "predicted residuals".

// List of all currently active engines
function active_engines {
  return list_filter({parameter engine. return engine:ignition.}, ship:engines).
}

// Returns all engines that activate on the specified stage
//: (stage? nat) -> List<Engine>
function engines_by_stage {
  parameter stage_nb is stage:number.
  return list_filter({parameter engine. return engine:stage = stage_nb.}, ship:engines).
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
    if engine:hasmodule(MOD_ENGINE_RF) {
      set max_time to max(max_time, get_field(engine:getmodule(MOD_ENGINE_RF), FLD_ENGINE_SPOOL_UP, 0)).
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
    // Shutdown symmetric engines to avoid unbalanced thrust
    local symmetric_engines is ship:partstagged(engine:tag).
    for eng in symmetric_engines { eng:shutdown(). }
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
  if not engine:hasmodule(MOD_ENGINE_RF) return "".
  local module is engine:getmodule(MOD_ENGINE_RF).
  if not module:hasfield("status") return "".
  local engine_status is module:getfield("status").
  if engine_status = "Nominal" return "".
  if engine_status = "Flame-Out!" return "".
  set engine_status to choose module:getfield("cause") if module:hasfield("cause") else engine_status.
  if failed_engines:haskey(engine) and failed_engines[engine] = engine_status { return "". }
  set failed_engines[engine] to engine_status.
  return engine_status.
}

// Unique identifier for engine (including configuration and tech level)
function engine_id {
  parameter engine.
  local id is engine:title + "##" + engine:config.
  if rcs_configs:find(engine:config) >= 0 {
    // RCS engines have different ISP based on tech level. Unfortunately, we can't
    // access the tech level directly as a part module, so we use ressource ratio instead
    local res is engine:consumedResources.
    for k in res:keys() {
      set id to id + "##" + res[k]:name + res[k]:maxfuelflow.
    }
  }
  return id.
}

// Predicted residual fuel at engine burn out
function engine_residuals {
  parameter engine.
  if not engine:hasmodule(MOD_ENGINE_RF) return 0.
  local module is engine:getmodule(MOD_ENGINE_RF).
  return get_field(module, FLD_ENGINE_RESIDUALS, 0).
}
