# Kerbo-scripts

This repository contains my autopilot scripts for Kerbal Space Program, written
using the kOS mod.

The `main.ks` script creates a GUI window which allows selecting any of the other
scripts in flight. The window can be toggled on/off with action group 0. Each script
then customizes the window to show relevant readouts and their own settings.

Scripts cannot be run stand-alone, as they require two variables defined in `main.ks`:
`window`, the main GUI variable, and `interrupt`, a boolean that can be set at
any time to interrupt the script (and kill all of its triggers).
