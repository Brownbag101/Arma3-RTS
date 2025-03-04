// scripts/ui/infoPanels/vehicleTypeInfo.sqf - Fixed version
params ["_ctrl", "_vehicle"];

// More robust type checking with debug info
private _isVehicle = _vehicle isKindOf "LandVehicle" || _vehicle isKindOf "Air" || _vehicle isKindOf "Ship";
systemChat format ["vehicleTypeInfo - Vehicle: %1, IsVehicle: %2", typeOf _vehicle, _isVehicle];

if (isNull _vehicle || !_isVehicle) exitWith {
    systemChat "vehicleTypeInfo - Exiting: Not a vehicle";
    _ctrl ctrlShow false;
};

private _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");
_ctrl ctrlSetText format ["Vehicle: %1", _vehicleName];
_ctrl ctrlSetTextColor [0.8, 0.8, 1, 1];
_ctrl ctrlShow true;
systemChat format ["vehicleTypeInfo - Set text: %1", format ["Vehicle: %1", _vehicleName]];

// Add this function to infoPanelManager.sqf
// Directly show vehicle info panels for testing
fnc_forceVehicleInfoPanels = {
    params ["_vehicle"];
    
    if (isNull _vehicle) exitWith {
        systemChat "forceVehicleInfoPanels - No vehicle";
    };
    
    systemChat format ["Forcing vehicle info panels for %1", typeOf _vehicle];
    
    {
        private _ctrl = _x;
        private _infoType = _ctrl getVariable ["infoType", ""];
        private _scriptPath = _ctrl getVariable ["scriptPath", ""];
        
        // Only process vehicle panels
        if (_infoType in RTSUI_vehicleInfoPanels && _scriptPath != "" && !isNull _ctrl) then {
            systemChat format ["Processing vehicle panel: %1", _infoType];
            // Execute the panel update script with the control and entity
            [_ctrl, _vehicle] call compile preprocessFileLineNumbers _scriptPath;
        } else {
            _ctrl ctrlShow false;
        };
    } forEach RTSUI_infoControls;
    
    systemChat "Vehicle panels processed";
};