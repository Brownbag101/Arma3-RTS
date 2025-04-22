// scripts/actions/unit/selectLauncher.sqf
params ["_unit"];
_unit selectWeapon (secondaryWeapon _unit);
private _weapon = getText (configFile >> "CfgWeapons" >> secondaryWeapon _unit >> "displayName");
systemChat format ["%1 switched to %2", name _unit, _weapon];