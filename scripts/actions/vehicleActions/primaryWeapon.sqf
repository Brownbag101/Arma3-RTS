// scripts/actions/vehicleActions/primaryWeapon.sqf
params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Switch to primary weapon
_vehicle selectWeapon ((_vehicle weaponsTurret [0]) select 0);
systemChat format ["%1 switched to primary weapon", getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName")];