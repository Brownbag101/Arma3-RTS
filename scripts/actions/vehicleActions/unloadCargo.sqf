// scripts/actions/vehicleActions/unloadCargo.sqf
params ["_vehicle", "_selections"];

// This check can cause errors if _vehicle is nil
// Make sure params is processed first, and check for null or nil
if (isNil "_vehicle" || isNull _vehicle) exitWith {
    systemChat "Error: No vehicle selected";
    false
};

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
    false
};

// Execute the cargo system script - ensure it's set to unload mode
systemChat format ["Attempting to unload cargo from %1", getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName")];
[_vehicle, _selections, "unload"] execVM "scripts\cargoSystem.sqf";