// cargoSystem.sqf - With improved cargo detection

params ["_vehicle", "_selections"];

// Ensure we have a valid vehicle
if (isNil "_vehicle") exitWith {
    systemChat "No vehicle selected for cargo operation";
    false
};

// Debug: Show selected vehicle
systemChat format ["Selected vehicle for cargo: %1 (%2)", _vehicle, typeOf _vehicle];

// Check cargo lists
if (isNil "MISSION_cargoVehicles") then {
    systemChat "ERROR: MISSION_cargoVehicles is undefined!";
} else {
    systemChat format ["Cargo vehicles defined: %1", count MISSION_cargoVehicles];
};

if (isNil "MISSION_cargoObjects") then {
    systemChat "ERROR: MISSION_cargoObjects is undefined!";
} else {
    systemChat format ["Cargo objects defined: %1", count MISSION_cargoObjects];
    // Debug: List all defined cargo objects
    {
        systemChat format ["Valid cargo type: %1", _x];
    } forEach MISSION_cargoObjects;
}; 

// Check if vehicle can carry cargo
private _vehType = typeOf _vehicle;
if !(_vehType in MISSION_cargoVehicles) exitWith {
    systemChat format ["%1 cannot carry cargo (not in MISSION_cargoVehicles)", getText (configFile >> "CfgVehicles" >> _vehType >> "displayName")];
    false
};

// Get current cargo and capacity
private _currentCargo = _vehicle getVariable ["cargo_items", []];
private _maxCapacity = 0;

{
    _x params ["_type", "_capacity"];
    if (_type == _vehType) exitWith {
        _maxCapacity = _capacity;
    };
} forEach MISSION_cargoCapacity;

systemChat format ["Vehicle cargo: %1/%2", count _currentCargo, _maxCapacity];

// If we have cargo, unload the nearest item
if (count _currentCargo > 0) then {
    systemChat "Vehicle has cargo - unloading last item";
    
    // Unload the last item
    private _cargoInfo = _currentCargo select ((count _currentCargo) - 1);
    _cargoInfo params ["_cargoObj", "_cargoType", "_cargoPos", "_cargoVectors"];
    
    systemChat format ["Unloading: %1", _cargoType];
    
    // Find a suitable position to place the cargo
    private _pos = _vehicle modelToWorld [0, -6, 0];
    _pos set [2, 0]; // Place on ground
    
    // Make cargo visible again
    _cargoObj setPosASL [_pos select 0, _pos select 1, getTerrainHeightASL _pos + 0.1];
    _cargoObj setVectorDirAndUp _cargoVectors;
    _cargoObj hideObject false;
    _cargoObj enableSimulation true;
    _cargoObj setVariable ["loaded_in", objNull, true];
    
    // Remove from vehicle's cargo
    _currentCargo deleteAt ((count _currentCargo) - 1);
    _vehicle setVariable ["cargo_items", _currentCargo, true];
    
    systemChat format ["Unloaded %1 from vehicle (%2/%3)", 
        getText (configFile >> "CfgVehicles" >> _cargoType >> "displayName"),
        count _currentCargo,
        _maxCapacity
    ];
} else {
    // No cargo - try to load nearest cargo object
    systemChat "No cargo loaded - looking for nearby cargo objects...";
    
    // IMPROVED CARGO DETECTION - Use specific types instead of all objects
    private _searchRadius = 15; // Increased radius for better detection
    
    // Create array of cargo types as strings to search for
    private _cargoTypes = MISSION_cargoObjects;
    
    // This will only search for objects of the specific cargo types
    private _nearbyCargoObjects = nearestObjects [_vehicle, _cargoTypes, _searchRadius];
    
    systemChat format ["Found %1 valid cargo objects within %2m", count _nearbyCargoObjects, _searchRadius];
    
    // Filter out any objects that are already loaded
    private _availableCargo = [];
    {
        if (isNull (_x getVariable ["loaded_in", objNull])) then {
            _availableCargo pushBack _x;
        };
    } forEach _nearbyCargoObjects;
    
    systemChat format ["Available cargo objects: %1", count _availableCargo];
    
    // Debug all nearby cargo
    {
        systemChat format ["Valid cargo nearby: %1 at %2m", typeOf _x, _x distance _vehicle];
    } forEach _availableCargo;
    
    private _nearestCargo = objNull;
    
    if (count _availableCargo > 0) then {
        _nearestCargo = _availableCargo select 0; // Get the closest cargo
    };
    
    if (isNull _nearestCargo) exitWith {
        systemChat "No cargo found nearby to load.";
        false
    };
    
    if (count _currentCargo >= _maxCapacity) exitWith {
        systemChat "Vehicle cargo is full!";
        false
    };
    
    // Load cargo
    systemChat format ["Loading cargo: %1", typeOf _nearestCargo];
    
    private _cargoInfo = [
        _nearestCargo, 
        typeOf _nearestCargo, 
        getPosASL _nearestCargo, 
        [vectorDir _nearestCargo, vectorUp _nearestCargo]
    ];
    
    _nearestCargo hideObject true;
    _nearestCargo enableSimulation false;
    
    _currentCargo pushBack _cargoInfo;
    _vehicle setVariable ["cargo_items", _currentCargo, true];
    _nearestCargo setVariable ["loaded_in", _vehicle, true];
    
    systemChat format ["Loaded %1 into vehicle (%2/%3)", 
        getText (configFile >> "CfgVehicles" >> typeOf _nearestCargo >> "displayName"),
        count _currentCargo,
        _maxCapacity
    ];
};

// Return true for successful execution
true