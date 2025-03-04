// scripts/actions/squadActions/setSquadProneStance.sqf
params ["_unit", "_selections"];

// Apply to all selected units
{
    _x setUnitPos "DOWN";
} forEach _selections;

systemChat format ["Set %1 units to prone stance", count _selections];