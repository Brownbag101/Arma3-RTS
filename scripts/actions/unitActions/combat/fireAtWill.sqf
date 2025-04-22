// scripts/actions/unitActions/combat/fireAtWill.sqf
params ["_unit", "_selections"];

// This is an individual unit action - only affect this unit, not its group
systemChat format ["%1 firing at will", name _unit];
_unit enableAI "TARGET";
_unit enableAI "AUTOTARGET";
_unit setCombatMode "RED";
_unit setBehaviour "COMBAT";