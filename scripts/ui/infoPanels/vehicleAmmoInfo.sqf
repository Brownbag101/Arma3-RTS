// scripts/ui/infoPanels/vehicleAmmoInfo.sqf
params ["_ctrl", "_vehicle"];

if (isNull _vehicle || !(_vehicle isKindOf "LandVehicle" || _vehicle isKindOf "Air" || _vehicle isKindOf "Ship")) exitWith {
    _ctrl ctrlShow false;
};

private _currentWeapon = currentWeapon _vehicle;
private _ammo = 0;
private _maxAmmo = 1;
private _percentage = 0;
private _weaponName = "No weapon";

if (_currentWeapon != "") then {
    _ammo = _vehicle ammo _currentWeapon;
    _weaponName = getText (configFile >> "CfgWeapons" >> _currentWeapon >> "displayName");
    
    // Try to get max ammo from magazines
    private _mags = magazinesAmmo _vehicle;
    {
        _x params ["_mag", "_rounds"];
        // Check if this magazine is used by the current weapon
        private _weaponMags = getArray (configFile >> "CfgWeapons" >> _currentWeapon >> "magazines");
        if (_mag in _weaponMags) then {
            private _magAmmo = getNumber (configFile >> "CfgMagazines" >> _mag >> "count");
            if (_magAmmo > 0) then {
                _maxAmmo = _magAmmo;
            };
        };
    } forEach _mags;
    
    // Fallback if max ammo couldn't be determined
    if (_maxAmmo < 1) then { _maxAmmo = 100; };
    
    _percentage = (_ammo / _maxAmmo) * 100;
} else {
    _percentage = 0;
};

private _color = switch (true) do {
    case (_percentage >= 75): {[0.2, 0.8, 0.2, 1]};
    case (_percentage >= 25): {[0.8, 0.8, 0.2, 1]};
    default {[0.8, 0.2, 0.2, 1]};
};

if (_currentWeapon != "") then {
    _ctrl ctrlSetText format ["Ammo: %1/%2 [%3]", _ammo, _maxAmmo, _weaponName];
} else {
    _ctrl ctrlSetText "Ammo: No weapon selected";
    _color = [0.7, 0.7, 0.7, 1]; // Gray when no weapon
};

_ctrl ctrlSetTextColor _color;
_ctrl ctrlShow true;