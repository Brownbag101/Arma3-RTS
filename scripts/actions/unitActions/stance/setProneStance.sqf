// scripts/actions/unitActions/stance/setProneStance.sqf
params ["_unit", "_selections"];

systemChat format ["%1 going prone", name _unit];
_unit setUnitPos "DOWN";