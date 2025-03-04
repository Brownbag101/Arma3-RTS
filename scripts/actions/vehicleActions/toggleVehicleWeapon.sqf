// scripts/actions/vehicleActions/toggleVehicleWeapon.sqf
params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Get all available weapons
private _weapons = _vehicle weaponsTurret [0];
if (count _weapons == 0) exitWith {
    systemChat "Vehicle has no weapons";
};

// Get current weapon
private _currentWeapon = currentWeapon _vehicle;
private _currentIndex = _weapons find _currentWeapon;

// If no weapon is selected or current weapon is not found, select the first one
if (_currentWeapon == "" || _currentIndex == -1) then {
    _vehicle selectWeapon (_weapons select 0);
    private _weaponName = getText (configFile >> "CfgWeapons" >> (_weapons select 0) >> "displayName");
    systemChat format ["Switched to %1", _weaponName];
} else {
    // Select next weapon in the list (or loop back to first)
    private _nextIndex = (_currentIndex + 1) mod (count _weapons);
    private _nextWeapon = _weapons select _nextIndex;
    _vehicle selectWeapon _nextWeapon;
    private _weaponName = getText (configFile >> "CfgWeapons" >> _nextWeapon >> "displayName");
    systemChat format ["Switched to %1", _weaponName];
};

// Store the index of the currently selected weapon for UI updates
_vehicle setVariable ["RTS_selectedWeaponIndex", (_weapons find (currentWeapon _vehicle))];
_vehicle setVariable ["RTS_availableWeapons", _weapons];