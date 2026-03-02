// #include "../libs/gui.ks"

run "../libs/gui.ks".

set logger to create_gui(
  list(
    lexicon("type", "vbox", "name", "turn_start", "label", "Gravity turn", "widgets", list(
      lexicon("type", "input", "name", "alt", "label", "Turn start alt:", "tooltip", "1000", "unit", "m"),
      lexicon("type", "input", "name", "angle", "label", "Turn start angle:", "tooltip", "5", "unit", "°"))),
    lexicon("type", "checkbox", "name", "drop_fairings", "label", "Auto-deploy fairings"),
    lexicon("type", "button", "name", "drop_fairings2", "label", "Auto-deploy fairings"),
    lexicon("type", "popup", "name", "ex", "label", "AA", "choices", list("AA", "BB", "CC")),
    lexicon("type", "popup", "name", "ex2", "choices", list("AA", "BB", "CC")),
    lexicon("type", "radio", "name", "runway", "label", "Runway", "choices", list("Runway 90", "Runway 270"))
  )
).
logger:gui:show().

logger:log("hello").
logger:debug("fidge").
logger:log("foo").
logger:log("<b>Everything is fine</b>").
logger:debug("<color=red>WAIT NO</color>").
logger:log("<b>RlqmkFJ SQFMDLKJ SQFDMLK FSQDLMJ FQSMLKJ SQDFMLJ QSDFMLJ QSFDLMKJ QFSLMKJ</b>").
logger:set_settings(lexicon("turn_start", lexicon("alt","10_000", "angle", "5"), "drop_fairings", true, "ex", "AA", "runway", "Runway 90")).
set x to logger:get_settings().
wait 5.
logger:log("Updated settings").
logger:set_settings(lexicon("turn_start", lexicon("alt","80_000", "angle", "25"), "drop_fairings2", true, "ex2", "BB", "ex", "", "runway", "Runway 270")).
wait 20.
logger:gui:hide().
