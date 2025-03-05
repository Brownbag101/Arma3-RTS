// scripts/actions/vehicleActions/toggleTow.sqf
// Wrapper to call the original towSystem.sqf from the RTS UI

params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Simply execute the original tow system script on the selected vehicle
[_vehicle] execVM "scripts\towSystem.sqf";