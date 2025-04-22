// scripts/actions/vehicleActions/secondaryWeapon.sqf
params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Make sure vehicle has secondary weapons
private _weapons = _vehicle weaponsTurret [0];
if (count _weapons < 2) exitWith {
    systemChat "No secondary weapon available";
};

// Switch to secondary weapon
_vehicle selectWeapon (_weapons select 1);
systemChat format ["%1 switched to secondary weapon", getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName")];