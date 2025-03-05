// scripts/actions/squadActions/setSquadCrouchStance.sqf
params ["_unit", "_selections"];

// Apply to all selected units
{
    _x setUnitPos "MIDDLE";
} forEach _selections;

systemChat format ["Set %1 units to crouching stance", count _selections];