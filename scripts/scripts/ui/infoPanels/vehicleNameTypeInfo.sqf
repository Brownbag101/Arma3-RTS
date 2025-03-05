// scripts/ui/infoPanels/vehicleNameTypeInfo.sqf
params ["_ctrl", "_vehicle"];

if (isNull _vehicle) exitWith {
    _ctrl ctrlSetText "Vehicle: No selection";
    _ctrl ctrlSetTextColor [0.7, 0.7, 0.7, 1];
    _ctrl ctrlShow true;
};

// Get vehicle display name
private _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
if (_vehicleName == "") then { _vehicleName = typeOf _vehicle; };

// Get vehicle class type
private _vehicleType = switch (true) do {
    case (_vehicle isKindOf "Tank"): { "Armored" };
    case (_vehicle isKindOf "Car"): { "Ground" };
    case (_vehicle isKindOf "Helicopter"): { "Helicopter" };
    case (_vehicle isKindOf "Plane"): { "Aircraft" };
    case (_vehicle isKindOf "Ship"): { "Naval" };
    default { "Vehicle" };
};

_ctrl ctrlSetText format ["%1 (%2)", _vehicleName, _vehicleType];
_ctrl ctrlSetTextColor [1, 1, 1, 1];
_ctrl ctrlShow true;