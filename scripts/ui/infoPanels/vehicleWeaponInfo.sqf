// scripts/ui/infoPanels/vehicleWeaponAmmoInfo.sqf
params ["_ctrl", "_vehicle"];

if (isNull _vehicle) exitWith {
    _ctrl ctrlShow false;
};

// Get current weapon
private _currentWeapon = currentWeapon _vehicle;
private _weaponName = if (_currentWeapon == "") then {
    "None"
} else {
    getText (configFile >> "CfgWeapons" >> _currentWeapon >> "displayName")
};

// Get ammo information
private _ammoText = "";
if (_currentWeapon != "") then {
    private _ammo = _vehicle ammo _currentWeapon;
    private _maxAmmo = 1;
    
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
    
    _ammoText = format [" (%1/%2)", _ammo, _maxAmmo];
    
    // Set color based on ammo percentage
    private _percentage = (_ammo / _maxAmmo) * 100;
    private _color = switch (true) do {
        case (_percentage >= 75): {[0.2, 0.8, 0.2, 1]};
        case (_percentage >= 25): {[0.8, 0.8, 0.2, 1]};
        default {[0.8, 0.2, 0.2, 1]};
    };
    
    _ctrl ctrlSetTextColor _color;
} else {
    _ctrl ctrlSetTextColor [0.7, 0.7, 0.7, 1];
};

// Set combined text
_ctrl ctrlSetText format ["Weapon: %1%2", _weaponName, _ammoText];
_ctrl ctrlShow true;