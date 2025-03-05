// scripts/actions/unitActions/stance/setCrouchStance.sqf
params ["_unit", "_selections"];

systemChat format ["%1 crouching", name _unit];
_unit setUnitPos "MIDDLE";