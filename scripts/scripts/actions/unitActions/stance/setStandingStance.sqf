// scripts/actions/unitActions/stance/setStandingStance.sqf
params ["_unit", "_selections"];

systemChat format ["%1 standing up", name _unit];
_unit setUnitPos "UP";