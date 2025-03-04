// scripts/actions/vehicleActions/openFire.sqf
params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Set fire at will
_vehicle setCombatMode "RED";
{
    _x setCombatMode "RED";
} forEach (crew _vehicle);

// Get vehicle name for feedback
private _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
systemChat format ["%1 firing at will", _vehicleName];