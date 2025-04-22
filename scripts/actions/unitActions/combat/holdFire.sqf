// scripts/actions/unitActions/combat/holdFire.sqf
params ["_unit", "_selections"];

// This is an individual unit action - only affect this unit, not its group
systemChat format ["%1 holding fire", name _unit];
_unit disableAI "TARGET";
_unit disableAI "AUTOTARGET";
_unit setCombatMode "BLUE";
_unit setBehaviour "CARELESS";
_unit setSpeedMode "NORMAL";