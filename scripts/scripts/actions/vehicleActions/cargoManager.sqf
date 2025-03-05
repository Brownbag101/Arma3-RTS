// scripts/actions/vehicleActions/cargoManager.sqf
// Wrapper to call the original cargoSystem.sqf from the RTS UI

params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Execute the original cargo system script on the selected vehicle
[_vehicle] execVM "scripts\cargoSystem.sqf";