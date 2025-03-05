// scripts/actions/vehicleActions/toggleHold.sqf
params ["_vehicle", "_selections"];

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    systemChat "Not a vehicle!";
};

// Get current hold state
private _isOnHold = _vehicle getVariable ["RTS_onHold", false];
private _vehicleName = getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName");

if (_isOnHold) then {
    // Currently on hold - release it
    private _driver = driver _vehicle;
    if (!isNull _driver) then {
        _driver enableAI "MOVE";
        _driver enableAI "PATH";
    }; 
    
    systemChat format ["%1 released from hold position", _vehicleName];
    _vehicle setVariable ["RTS_onHold", false, true];
} else {
    // Not on hold - stop it
    _vehicle setVelocity [0, 0, 0];
    
    // Disable the drivers AI if there's a driver
    private _driver = driver _vehicle;
    if (!isNull _driver) then {
        _driver disableAI "MOVE";
        _driver disableAI "PATH";
        
        // No longer deleting waypoints - this allows continuing the waypoint path when released
    }; 
    
    systemChat format ["%1 holding position", _vehicleName];
    _vehicle setVariable ["RTS_onHold", true, true];
};