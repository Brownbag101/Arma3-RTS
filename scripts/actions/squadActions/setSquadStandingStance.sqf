// scripts/actions/squadActions/setSquadStandingStance.sqf
params ["_unit", "_selections"];

// Apply to all selected units
{
    _x setUnitPos "UP";
} forEach _selections;

systemChat format ["Set %1 units to standing stance", count _selections];