// scripts/actions/unit/selectSidearm.sqf
params ["_unit"];
_unit selectWeapon (handgunWeapon _unit);
private _weapon = getText (configFile >> "CfgWeapons" >> handgunWeapon _unit >> "displayName");
systemChat format ["%1 switched to %2", name _unit, _weapon];