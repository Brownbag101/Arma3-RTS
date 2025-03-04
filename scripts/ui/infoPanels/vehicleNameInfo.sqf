// scripts/ui/infoPanels/vehicleNameInfo.sqf
// Simplest possible version
params ["_ctrl", "_vehicle"];

if (isNull _vehicle) exitWith {
    _ctrl ctrlSetText "Vehicle: No selection";
    _ctrl ctrlSetTextColor [0.7, 0.7, 0.7, 1];
    _ctrl ctrlShow true;
};

// Get vehicle display name
private _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
if (_vehicleName == "") then { _vehicleName = typeOf _vehicle; };

_ctrl ctrlSetText format ["Vehicle: %1", _vehicleName];
_ctrl ctrlSetTextColor [1, 1, 1, 1];
_ctrl ctrlShow true;