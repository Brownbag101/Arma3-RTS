// scripts/actions/vehicleActions/exitVehicle.sqf
params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Get vehicle name for feedback
private _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");

// Get all crew members
private _crew = crew _vehicle;
if (count _crew == 0) exitWith {
    systemChat format ["%1 has no crew", _vehicleName];
};

// Make all crew members exit the vehicle
{
    unassignVehicle _x;
    [_x] orderGetIn false;
    _x action ["getOut", _vehicle];
} forEach _crew;

systemChat format ["All crew exiting %1", _vehicleName];