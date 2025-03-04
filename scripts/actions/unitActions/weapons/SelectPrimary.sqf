// scripts/actions/unit/selectPrimary.sqf
params ["_unit"];
_unit selectWeapon (primaryWeapon _unit);
private _weapon = getText (configFile >> "CfgWeapons" >> primaryWeapon _unit >> "displayName");
systemChat format ["%1 switched to %2", name _unit, _weapon];