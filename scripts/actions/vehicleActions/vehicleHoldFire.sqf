// scripts/actions/vehicleActions/holdFire.sqf
params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Set hold fire
_vehicle setCombatMode "BLUE";
{
    _x setCombatMode "BLUE";
} forEach (crew _vehicle);

// Get vehicle name for feedback
private _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
systemChat format ["%1 holding fire", _vehicleName];