// towSystem.sqf - Using setTowParent with rope visual

params ["_vehicle", "_selections"];

// Ensure we have a valid vehicle
if (isNil "_vehicle") exitWith {
    systemChat "No vehicle selected for towing operation";
    false
};

// Check if vehicle can tow
private _vehType = typeOf _vehicle;
if !(_vehType in MISSION_towingVehicles) exitWith {
    systemChat format ["%1 cannot tow other vehicles", getText (configFile >> "CfgVehicles" >> _vehType >> "displayName")];
    false
};

// Check if already towing something
if (!isNull (_vehicle getVariable ["towing_vehicle", objNull])) then {
    // Already towing - handle detach
    private _towedVehicle = _vehicle getVariable ["towing_vehicle", objNull];
    
    systemChat format ["Detaching currently towed vehicle: %1", typeOf _towedVehicle];
    
    // Get the rope (if exists)
    private _rope = _vehicle getVariable ["towing_rope", objNull];
    if (!isNull _rope) then {
        ropeDestroy _rope;
    };
    
    // If using setTowParent, clear the tow parent
    if (!isNull _towedVehicle) then {
        _towedVehicle setTowParent objNull;
        
        // Clear variables
        _towedVehicle setVariable ["being_towed", false, true];
        _towedVehicle setVariable ["towed_by", objNull, true];
        
        systemChat format ["Detached %1 from tow", getText (configFile >> "CfgVehicles" >> typeOf _towedVehicle >> "displayName")];
    };
    
    // Clear variables on towing vehicle
    _vehicle setVariable ["towing_vehicle", objNull, true];
    _vehicle setVariable ["towing_rope", objNull, true];
    
} else {
    // Not currently towing - find nearby towable vehicle
    systemChat "Looking for towable vehicles nearby...";
    
    // Direct search for towable types
    private _searchRadius = 15;
    private _nearbyTowables = nearestObjects [_vehicle, MISSION_towableVehicles, _searchRadius];
    systemChat format ["Found %1 valid towable vehicles within %2m", count _nearbyTowables, _searchRadius];
    
    // Filter out the vehicle itself and any already being towed
    private _availableTowables = [];
    {
        if (_x != _vehicle && {isNull (_x getVariable ["towed_by", objNull])}) then {
            _availableTowables pushBack _x;
        };
    } forEach _nearbyTowables;
    
    if (count _availableTowables == 0) exitWith {
        systemChat "No towable vehicles found within 15 meters";
        false
    };
    
    private _towable = _availableTowables select 0;
    systemChat format ["Found towable vehicle: %1", typeOf _towable];
    
    // Create rope for visual effect
    private _towingPoint = [0, -2.5, 0.2]; // Rear attachment
    private _towedPoint = [0, 3, 0.2];     // Front attachment
    
    private _rope = ropeCreate [
        _vehicle, _towingPoint,
        _towable, _towedPoint,
        5  // Rope length
    ];
    
    // Set tow parent relationship
    _towable setTowParent _vehicle;
    
    // Store references
    _vehicle setVariable ["towing_vehicle", _towable, true];
    _vehicle setVariable ["towing_rope", _rope, true];
    _towable setVariable ["being_towed", true, true];
    _towable setVariable ["towed_by", _vehicle, true];
    
    systemChat format ["Now towing %1", getText (configFile >> "CfgVehicles" >> typeOf _towable >> "displayName")];
};

// Return true for successful execution
true