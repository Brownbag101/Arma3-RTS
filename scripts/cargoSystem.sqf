// scripts/cargoSystem.sqf - Enhanced with progress bar and improved object placement

// Beginning of cargoSystem.sqf
params [["_vehicle", objNull], ["_selections", []], ["_mode", "auto"]];

// Debug the input
systemChat format ["Cargo system called with vehicle: %1, Mode: %2", if (isNull _vehicle) then {"NULL"} else {typeOf _vehicle}, _mode];

// Ensure we have a valid vehicle
if (isNull _vehicle) exitWith {
    systemChat "No vehicle selected for cargo operation";
    false
};

// Continue with the rest of the script...

// Debug: Show what was passed
systemChat format ["Cargo system called with vehicle: %1, Mode: %2", typeOf _vehicle, _mode];

// Check if globals are initialized - if not, try to initialize them
if (isNil "MISSION_cargoVehicles" || isNil "MISSION_cargoObjects" || isNil "MISSION_cargoCapacity") then {
    systemChat "Cargo globals not found - attempting to initialize";
    [] execVM "scripts\towCargoGlobals.sqf";
    sleep 0.5; // Give it a moment to initialize
};

// Check cargo lists again after potential initialization
if (isNil "MISSION_cargoVehicles") exitWith {
    systemChat "ERROR: MISSION_cargoVehicles is still undefined!";
    false
};

if (isNil "MISSION_cargoObjects") exitWith {
    systemChat "ERROR: MISSION_cargoObjects is still undefined!";
    false
};

if (isNil "MISSION_cargoCapacity") exitWith {
    systemChat "ERROR: MISSION_cargoCapacity is still undefined!";
    false
};

// Check if vehicle can carry cargo
private _vehType = typeOf _vehicle;
if !(_vehType in MISSION_cargoVehicles) exitWith {
    systemChat format ["%1 cannot carry cargo (not in MISSION_cargoVehicles)", getText (configFile >> "CfgVehicles" >> _vehType >> "displayName")];
    false
};

// Get current cargo and capacity
private _currentCargo = _vehicle getVariable ["cargo_items", []];
if (isNil "_currentCargo") then {
    _currentCargo = [];
    _vehicle setVariable ["cargo_items", _currentCargo, true];
};

private _maxCapacity = 0;
{
    _x params ["_type", "_capacity"];
    if (_type == _vehType) exitWith {
        _maxCapacity = _capacity;
    };
} forEach MISSION_cargoCapacity;

systemChat format ["Vehicle cargo: %1/%2", count _currentCargo, _maxCapacity];

// Create progress bar
private _display = findDisplay 312;
private _ctrlGroup = _display ctrlCreate ["RscControlsGroup", -1];
_ctrlGroup ctrlSetPosition [
    safezoneX + 0.3 * safezoneW,
    safezoneY + 0.8 * safezoneH,
    0.4 * safezoneW,
    0.05 * safezoneH
];
_ctrlGroup ctrlCommit 0;

private _background = _display ctrlCreate ["RscText", -1, _ctrlGroup];
_background ctrlSetPosition [0, 0, 0.4 * safezoneW, 0.05 * safezoneH];
_background ctrlSetBackgroundColor [0, 0, 0, 0.7];
_background ctrlCommit 0;

private _text = _display ctrlCreate ["RscText", -1, _ctrlGroup];
_text ctrlSetPosition [0, 0, 0.4 * safezoneW, 0.025 * safezoneH];
_text ctrlCommit 0;

private _progress = _display ctrlCreate ["RscProgress", -1, _ctrlGroup];
_progress ctrlSetPosition [0.01, 0.03, 0.38 * safezoneW, 0.015 * safezoneH];
_progress ctrlCommit 0;

// Determine operation mode (unload or load)
private _shouldUnload = false;

// If mode is specified, use that
if (_mode == "unload") then {
    _shouldUnload = true;
} else {
    if (_mode == "load") then {
        _shouldUnload = false;
    } else {
        // Auto-detect: if we have cargo, unload, otherwise load
        _shouldUnload = (count _currentCargo > 0);
    };
};

// UNLOAD operation
if (_shouldUnload) then {
    if (count _currentCargo > 0) then {
        _text ctrlSetText format ["Unloading cargo from %1...", getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName")];
        _progress ctrlSetTextColor [0.2, 0.8, 0.2, 1];
        
        // Start unloading process with animation
        [_vehicle, _ctrlGroup, _progress, _display, _currentCargo] spawn {
            params ["_vehicle", "_ctrlGroup", "_progress", "_display", "_currentCargo"];
            
            private _duration = 3; // 3 seconds for unloading
            private _startTime = time;
            
            // Get last cargo item
            private _cargoInfo = _currentCargo select ((count _currentCargo) - 1);
            _cargoInfo params ["_cargoObj", "_cargoType", "_cargoPos", "_cargoVectors"];
            
            // Check if the cargo object is valid
            if (isNull _cargoObj) then {
                // Create a new object if the original was deleted
                _cargoObj = createVehicle [_cargoType, [0,0,0], [], 0, "NONE"];
            };
            
            while {time < _startTime + _duration && !isNull _display} do {
                private _elapsed = time - _startTime;
                private _progressValue = _elapsed / _duration;
                
                // Update progress bar
                _progress progressSetPosition _progressValue;
                
                sleep 0.1;
            };
            
            // Complete the unloading after animation is done
            if (!isNull _vehicle && !isNull _display) then {
                // Find a suitable position to place the cargo
                // Calculate multiple potential positions to avoid stacking
                private _placed = false;
                private _attempts = 0;
                private _maxAttempts = 8; // Try different positions in a circle
                private _distance = 6;
                private _pos = [];
                
                while {!_placed && _attempts < _maxAttempts} do {
                    private _dir = (_attempts * (360 / _maxAttempts));
                    private _offset = [sin(_dir) * _distance, cos(_dir) * _distance, 0];
                    private _testPos = _vehicle modelToWorld _offset;
                    _testPos set [2, 0]; // Place on ground
                    
                    // Check if position is clear
                    private _objects = nearestObjects [_testPos, [], 2];
                    private _isClear = true;
                    
                    {
                        if (_x != _vehicle && _x != _cargoObj) then {
                            _isClear = false;
                        };
                    } forEach _objects;
                    
                    if (_isClear) then {
                        _pos = _testPos;
                        _placed = true;
                    };
                    
                    _attempts = _attempts + 1;
                };
                
                // If no clear position found, use default position
                if (!_placed) then {
                    _pos = _vehicle modelToWorld [0, -6, 0];
                    _pos set [2, 0]; // Place on ground
                };
                
                // Make cargo visible again
                _cargoObj setPosASL [_pos select 0, _pos select 1, getTerrainHeightASL _pos + 0.1];
                _cargoObj setVectorDirAndUp _cargoVectors;
                _cargoObj hideObject false;
                _cargoObj enableSimulation true;
                _cargoObj setVariable ["loaded_in", objNull, true];
                
                // Remove from vehicle's cargo
                private _updatedCargo = _vehicle getVariable ["cargo_items", []];
                _updatedCargo deleteAt ((count _updatedCargo) - 1);
                _vehicle setVariable ["cargo_items", _updatedCargo, true];
                
                
            };
            
            // Cleanup
            if (!isNull _ctrlGroup) then {
                ctrlDelete _ctrlGroup;
            };
        };
        
        // Success
        true
    } else {
        systemChat "No cargo to unload";
        
        // Cleanup the progress bar if we didn't start the unload process
        if (!isNull _ctrlGroup) then {
            ctrlDelete _ctrlGroup;
        };
        
        false
    };
} else {
    // LOAD operation
    if (count _currentCargo >= _maxCapacity) exitWith {
        systemChat "Vehicle cargo is full!";
        
        // Cleanup the progress bar
        if (!isNull _ctrlGroup) then {
            ctrlDelete _ctrlGroup;
        };
        
        false
    };
    
    // Use specific types instead of all objects
    private _searchRadius = 15; // Radius for cargo detection
    
    // This will only search for objects of the specific cargo types
    private _nearbyCargoObjects = nearestObjects [_vehicle, MISSION_cargoObjects, _searchRadius];
    
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
        
        _text ctrlSetText format ["Loading cargo into %1...", getText(configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName")];
        _progress ctrlSetTextColor [0.9, 0.9, 0.1, 1];
        
        // Start loading process with animation
        [_vehicle, _ctrlGroup, _progress, _display, _nearestCargo, _maxCapacity] spawn {
            params ["_vehicle", "_ctrlGroup", "_progress", "_display", "_nearestCargo", "_maxCapacity"];
            
            private _duration = 4; // 4 seconds for loading
            private _startTime = time;
            
            while {time < _startTime + _duration && !isNull _display} do {
                private _elapsed = time - _startTime;
                private _progressValue = _elapsed / _duration;
                
                // Update progress bar
                _progress progressSetPosition _progressValue;
                
                sleep 0.1;
            };
            
            // Complete the loading after animation is done
            if (!isNull _vehicle && !isNull _display && !isNull _nearestCargo) then {
                // Load cargo
                private _cargoInfo = [
                    _nearestCargo, 
                    typeOf _nearestCargo, 
                    getPosASL _nearestCargo, 
                    [vectorDir _nearestCargo, vectorUp _nearestCargo]
                ];
                
                _nearestCargo hideObject true;
                _nearestCargo enableSimulation false;
                
                // Update vehicle's cargo (get the current value first in case it was changed)
                private _currentCargo = _vehicle getVariable ["cargo_items", []];
                _currentCargo pushBack _cargoInfo;
                _vehicle setVariable ["cargo_items", _currentCargo, true];
                _nearestCargo setVariable ["loaded_in", _vehicle, true];
                
                systemChat format ["Loaded %1 into vehicle (%2/%3)", 
                    getText (configFile >> "CfgVehicles" >> typeOf _nearestCargo >> "displayName"),
                    count _currentCargo,
                    _maxCapacity
                ];
            };
            
            // Cleanup
            if (!isNull _ctrlGroup) then {
                ctrlDelete _ctrlGroup;
            };
        };
        
        // Success
        true
    } else {
        systemChat "No cargo found nearby to load.";
        
        // Cleanup the progress bar
        if (!isNull _ctrlGroup) then {
            ctrlDelete _ctrlGroup;
        };
        
        false
    };
};