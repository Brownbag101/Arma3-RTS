// scripts/ui/infoPanels/weaponInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlShow false;
};

private _currentWeapon = currentWeapon _unit;
private _weaponName = if (_currentWeapon == "") then {
    "None"
} else {
    getText (configFile >> "CfgWeapons" >> _currentWeapon >> "displayName")
};

_ctrl ctrlSetText format ["Active Weapon: %1", _weaponName];
_ctrl ctrlSetTextColor [0.8, 0.8, 1, 1];
_ctrl ctrlShow true;