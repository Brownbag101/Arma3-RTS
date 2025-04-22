// scripts/ui/infoPanels/ammoInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit || !(_unit isKindOf "CAManBase")) exitWith {
    _ctrl ctrlShow false;
};

private _currentWeapon = currentWeapon _unit;

if (_currentWeapon == "") exitWith {
    _ctrl ctrlSetText "Ammo: No weapon";
    _ctrl ctrlSetTextColor [0.7, 0.7, 0.7, 1];
    _ctrl ctrlShow true;
};

// Get ammunition count using the simpler approach
private _ammoCount = _unit ammo _currentWeapon;

// Determine magazine size
private _maxAmmo = 30; // Default magazine size
private _magazines = magazines _unit;

{
    private _magazineType = _x;
    private _weaponMags = getArray (configFile >> "CfgWeapons" >> _currentWeapon >> "magazines");
    
    if (_magazineType in _weaponMags) then {
        _maxAmmo = getNumber (configFile >> "CfgMagazines" >> _magazineType >> "count");
    };
} forEach _magazines;

// Color coding
private _percentage = (_ammoCount / _maxAmmo) * 100;
private _color = switch (true) do {
    case (_percentage >= 75): {[0.2, 0.8, 0.2, 1]};
    case (_percentage >= 25): {[0.8, 0.8, 0.2, 1]};
    default {[0.8, 0.2, 0.2, 1]};
};

_ctrl ctrlSetText format ["Ammo: %1/%2", _ammoCount, _maxAmmo];
_ctrl ctrlSetTextColor _color;
_ctrl ctrlShow true;