// Virtual Hangar System - Core Functionality
// Handles aircraft storage, retrieval, and management

// == VIEW MODEL MANAGEMENT ==
// Array to track currently viewed aircraft for visualization
if (isNil "HANGAR_viewedAircraftArray") then { HANGAR_viewedAircraftArray = []; };

// == DEPLOYMENT MANAGEMENT ==
// Tracking array for deployed aircraft
if (isNil "HANGAR_deployedAircraft") then { HANGAR_deployedAircraft = []; };

// == POSITION CALCULATION ==
// Function to calculate offset position for viewing multiple aircraft
HANGAR_fnc_calculateViewPosition = {
    params ["_index"];
    
    // Ensure clean index
    if (isNil "_index") then { _index = 0; };
    if (typeName _index != "SCALAR") then { _index = 0; };
    
    // Base position from marker
    private _basePos = HANGAR_viewPosition;
    
    // Add randomness to prevent exact overlap even with calculation errors
    private _randomOffset = random(3);
    
    // Use larger spacing to ensure planes don't overlap
    private _spacingX = 15 + _randomOffset; // Increased from 10
    private _spacingY = 15 + _randomOffset; // Increased from 10
    
    // Calculate offset based on index
    // Each additional aircraft gets placed with spacing
    private _offsetX = _spacingX * (_index % 3);  // Only 3 per row to ensure bigger gaps
    private _offsetY = _spacingY * floor(_index / 3); // New row every 3 aircraft
    
    // Apply offset according to direction
    private _dirRad = HANGAR_viewDirection * (pi / 180);
    private _offsetPos = [
        (_basePos select 0) + (_offsetX * cos _dirRad) - (_offsetY * sin _dirRad),
        (_basePos select 1) + (_offsetX * sin _dirRad) + (_offsetY * cos _dirRad),
        _basePos select 2
    ];
    
    diag_log format ["POSITION: Calculated view position for index %1: %2 (offset: %3,%4)", 
        _index, _offsetPos, _offsetX, _offsetY];
    
    _offsetPos
};

// Function to store an aircraft in the hangar
HANGAR_fnc_storeAircraft = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {
        diag_log "HANGAR: Cannot store null aircraft";
        false
    };
    
    // Check if aircraft is within range of hangar
    if (_aircraft distance HANGAR_viewPosition > 500) exitWith {
        systemChat "Aircraft must be within 500m of hangar to store";
        diag_log format ["HANGAR: Aircraft too far to store: %1m", _aircraft distance HANGAR_viewPosition];
        false
    };
    
    // Store aircraft state
    private _type = typeOf _aircraft;
    private _displayName = getText (configFile >> "CfgVehicles" >> _type >> "displayName");
    private _fuel = fuel _aircraft;
    private _damage = damage _aircraft;
    
    // Store weapons and ammo state
    private _weaponsData = [];
    private _weapons = weapons _aircraft;
    {
        private _weapon = _x;
        private _ammo = _aircraft ammo _weapon;
        private _weaponName = getText (configFile >> "CfgWeapons" >> _weapon >> "displayName");
        _weaponsData pushBack [_weapon, _ammo, _weaponName];
    } forEach _weapons;
    
    // Store crew information
    private _crew = [];
    {
        _x params ["_unit", "_role", "_cargoIndex", "_turretPath"];
        
        // Only process if it's a pilot (from our system)
        if (!isNull _unit && {_unit getVariable ["HANGAR_isPilot", false]}) then {
            private _pilotIndex = [_unit] call HANGAR_fnc_getPilotIndex;
            if (_pilotIndex != -1) then {
                _crew pushBack [_pilotIndex, _role, _turretPath];
                
                // Update aircraft assignment in roster
                (HANGAR_pilotRoster select _pilotIndex) set [5, objNull];
            };
        };
    } forEach fullCrew _aircraft;
    
    // Create storage record with deployment status
    private _record = [
        _type,              // Aircraft type
        _displayName,       // Display name
        _fuel,              // Fuel level
        _damage,            // Damage level
        _weaponsData,       // Weapons data
        _crew,              // Crew assignments
        [],                 // Custom state data (for future use)
        false,              // Deployment status (initially not deployed)
        objNull             // Reference to deployed instance (if any)
    ];
    
    // Add to stored aircraft array
    HANGAR_storedAircraft pushBack _record;
    
    // Remove from deployed tracking if it was deployed
    {
        if (!isNull _x && {_x == _aircraft}) exitWith {
            HANGAR_deployedAircraft = HANGAR_deployedAircraft - [_x];
            diag_log format ["HANGAR: Removed aircraft from deployed tracking: %1", _aircraft];
        };
    } forEach HANGAR_deployedAircraft;
    
    // Delete the aircraft
    {deleteVehicle _x} forEach crew _aircraft;
    deleteVehicle _aircraft;
    
    systemChat format ["%1 stored in hangar", _displayName];
    diag_log format ["HANGAR: Aircraft stored: %1", _displayName];
    true
};

// Function to clear all viewed aircraft
HANGAR_fnc_clearAllViewedAircraft = {
    // Log what we're doing
    diag_log format ["HANGAR: Clearing all viewed aircraft: %1 in array", count HANGAR_viewedAircraftArray];
    
    // Make a copy of the array to work with
    private _toRemove = +HANGAR_viewedAircraftArray;
    
    // Process each aircraft in the array
    {
        if (!isNull _x) then {
            // Get crew and delete
            {
                if (!isNull _x) then {
                    deleteVehicle _x;
                };
            } forEach crew _x;
            
            // Delete aircraft
            deleteVehicle _x;
            diag_log format ["HANGAR: Deleted view model aircraft: %1", _x];
        };
    } forEach _toRemove;
    
    // Clear the tracking array
    HANGAR_viewedAircraftArray = [];
    
    // Make sure the currently viewed aircraft reference is also cleared
    HANGAR_viewedAircraft = objNull;
    
    diag_log "HANGAR: All viewed aircraft cleared";
};

// Function to clear viewed aircraft
HANGAR_fnc_clearViewedAircraft = {
    // If no aircraft is being viewed, nothing to do
    if (isNull HANGAR_viewedAircraft) exitWith {
        diag_log "HANGAR: No aircraft being viewed, nothing to clear";
    };
    
    // Check if the aircraft is deployed or a view model
    private _isDeployed = HANGAR_viewedAircraft getVariable ["HANGAR_deployed", false];
    private _isViewModel = HANGAR_viewedAircraft getVariable ["HANGAR_isViewModel", false];
    private _aircraftID = HANGAR_viewedAircraft getVariable ["HANGAR_uniqueID", "unknown"];
    
    diag_log format ["HANGAR: Clearing viewed aircraft: %1, Deployed: %2, ViewModel: %3", 
        _aircraftID, _isDeployed, _isViewModel];
    
    // Only delete if it's a view model (not deployed)
    if (_isViewModel && !_isDeployed) then {
        // Get crew and delete
        {
            if (!isNull _x) then {
                deleteVehicle _x;
            };
        } forEach crew HANGAR_viewedAircraft;
        
        // Delete aircraft
        deleteVehicle HANGAR_viewedAircraft;
        diag_log format ["HANGAR: Deleted view model aircraft: %1", _aircraftID];
        
        // Also remove from the tracking array
        HANGAR_viewedAircraftArray = HANGAR_viewedAircraftArray - [HANGAR_viewedAircraft];
    };
    
    // Log but don't delete deployed aircraft
    if (_isDeployed) then {
        diag_log format ["HANGAR: Keeping deployed aircraft in field: %1", _aircraftID];
    };
    
    // Always reset the reference
    HANGAR_viewedAircraft = objNull;
};

// Function to clean up any stray view models
HANGAR_fnc_cleanupViewModels = {
    private _count = 0;
    
    // Find all aircraft within 100m of the viewing position
    private _nearbyVehicles = nearestObjects [HANGAR_viewPosition, ["Air"], 100];
    
    {
        // Check if it's one of our view models
        if (_x getVariable ["HANGAR_isViewModel", false] && 
            !(_x getVariable ["HANGAR_deployed", false])) then {
            
            // Delete crew
            {
                if (!isNull _x) then {
                    deleteVehicle _x;
                };
            } forEach crew _x;
            
            // Delete the aircraft
            deleteVehicle _x;
            _count = _count + 1;
        };
    } forEach _nearbyVehicles;
    
    if (_count > 0) then {
        diag_log format ["HANGAR: Cleaned up %1 stray view model aircraft", _count];
    };
    
    // Also clean our tracking array of any null objects
    HANGAR_viewedAircraftArray = HANGAR_viewedAircraftArray - [objNull];
    
    _count
};

// Function to view an aircraft
HANGAR_fnc_viewAircraft = {
    params ["_index"];
    
    // Always clear currently viewed aircraft first and wait for deletion to complete
    call HANGAR_fnc_clearViewedAircraft;
    
    // Small delay to ensure cleanup is complete before creating new aircraft
    [_index] spawn {
        params ["_index"];
        
        // Wait to ensure cleanup has completed
        sleep 0.3;
        
        // Validate index
        if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {
            diag_log format ["HANGAR: Invalid aircraft index for viewing: %1", _index];
            HANGAR_viewedAircraft = objNull;
        };
        
        // Get aircraft data
        private _record = HANGAR_storedAircraft select _index;
        _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
        
        // Generate a unique ID for this aircraft view
        private _uniqueID = format ["%1_%2_%3", _type, _index, diag_tickTime];
        
        // Check if already deployed
        if (_isDeployed && !isNull _deployedInstance) then {
            diag_log format ["HANGAR: Viewing already deployed aircraft: %1", _displayName];
            HANGAR_viewedAircraft = _deployedInstance;
            systemChat format ["%1 is currently deployed in the field", _displayName];
        } else {
            // Calculate spawn position with offset based on array size
            private _viewPos = [count HANGAR_viewedAircraftArray] call HANGAR_fnc_calculateViewPosition;
            
            diag_log format ["HANGAR: Creating view model for aircraft: %1 at position %2", _displayName, _viewPos];
            
            // Create the aircraft
            private _aircraft = createVehicle [_type, [0,0,500], [], 0, "NONE"]; // Spawn high initially
            
            // Set initial state
            _aircraft setFuel _fuel;
            _aircraft setDamage _damage;
            
            // Wait a moment then move to position - helps prevent collision issues
            sleep 0.2;
            _aircraft setPos _viewPos;
            _aircraft setDir HANGAR_viewDirection;
            
            // Set weapons ammo
            {
                _x params ["_weapon", "_ammo"];
                _aircraft setAmmo [_weapon, _ammo];
            } forEach _weaponsData;
            
            // Mark as view model
            _aircraft setVariable ["HANGAR_uniqueID", _uniqueID, true];
            _aircraft setVariable ["HANGAR_storageIndex", _index, true];
            _aircraft setVariable ["HANGAR_isViewModel", true, true];
            
            // Add to tracking arrays
            HANGAR_viewedAircraft = _aircraft;
            HANGAR_viewedAircraftArray pushBack _aircraft;
            
            // Add aircraft to Zeus
            private _curator = getAssignedCuratorLogic player;
            if (!isNull _curator) then {
                _curator addCuratorEditableObjects [[_aircraft], true];
            };
            
            // Make sure it's not editable by Zeus
            _aircraft setVariable ["HANGAR_managedAircraft", true, true];
            
            // Create crew if necessary
            if (count _crew > 0) then {
                // Spawn crew members with slight delay to ensure aircraft is ready
                [_crew, _aircraft, _index] spawn {
                    params ["_crew", "_aircraft", "_index"];
                    sleep 0.5;
                    
                    // Check if aircraft still exists after delay
                    if (!isNull _aircraft) then {
                        {
                            _x params ["_pilotIndex", "_role", "_turretPath"];
                            if (_pilotIndex >= 0) then {
                                [_pilotIndex, _aircraft, _role, _turretPath, false] spawn HANGAR_fnc_assignPilotToAircraft;
                                sleep 0.3; // Small delay between crew members
                            };
                        } forEach _crew;
                    } else {
                        diag_log format ["HANGAR: Aircraft disappeared before crew could be assigned: %1", _index];
                    };
                };
            };
        };
    };
    
    HANGAR_viewedAircraft
};

// Function to deploy an aircraft with full AI capabilities
HANGAR_fnc_deployAircraft = {
    params ["_aircraftIndex", "_deployPosIndex"];
    
    // Validate index
    if (_aircraftIndex < 0 || _aircraftIndex >= count HANGAR_storedAircraft) exitWith {
        systemChat "Invalid aircraft index";
        diag_log format ["HANGAR: Invalid aircraft index for deployment: %1", _aircraftIndex];
        objNull
    };
    
    // Validate deploy position
    if (_deployPosIndex < 0 || _deployPosIndex >= count HANGAR_deployPositions) exitWith {
        systemChat "Invalid deploy position";
        diag_log "HANGAR: Invalid deploy position index";
        objNull
    };
    
    // Get marker name and aircraft data
    private _deployMarker = HANGAR_deployPositions select _deployPosIndex;
    private _record = HANGAR_storedAircraft select _aircraftIndex;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
    
    // Variable to hold the deployed aircraft
    private _aircraft = objNull;
    
    // Check if this aircraft is already deployed
    if (_isDeployed && !isNull _deployedInstance) then {
        // Just move existing aircraft to new position
        _aircraft = _deployedInstance;
        
        if (markerType _deployMarker != "") then {
            private _newPos = getMarkerPos _deployMarker;
            private _newDir = markerDir _deployMarker;
            
            // Move aircraft to new position
            _aircraft setPos _newPos;
            _aircraft setDir _newDir;
            
            systemChat format ["%1 moved to new position", _displayName];
            diag_log format ["HANGAR: Moved already deployed aircraft to new position: %1", _displayName];
        };
    } else {
        // This is a new deployment
        // Check if we're currently viewing this aircraft
        if (!isNull HANGAR_viewedAircraft && 
            (HANGAR_viewedAircraft getVariable ["HANGAR_storageIndex", -1]) == _aircraftIndex) then {
            
            // Use the currently viewed aircraft
            _aircraft = HANGAR_viewedAircraft;
            
            // Update its position
            if (markerType _deployMarker != "") then {
                private _newPos = getMarkerPos _deployMarker;
                private _newDir = markerDir _deployMarker;
                
                _aircraft setPos _newPos;
                _aircraft setDir _newDir;
            };
            
            // No longer a view model
            _aircraft setVariable ["HANGAR_isViewModel", false, true];
            
            // Remove from view tracking
            HANGAR_viewedAircraftArray = HANGAR_viewedAircraftArray - [_aircraft];
            HANGAR_viewedAircraft = objNull;
            
            systemChat format ["%1 deployed from viewing area", _displayName];
            diag_log format ["HANGAR: Deployed viewed aircraft: %1", _displayName];
        } else {
            // Create new aircraft at deploy position
            private _spawnPos = if (markerType _deployMarker != "") then {
                getMarkerPos _deployMarker
            } else {
                HANGAR_viewPosition
            };
            
            private _spawnDir = if (markerType _deployMarker != "") then {
                markerDir _deployMarker
            } else {
                HANGAR_viewDirection
            };
            
            // Create aircraft
            _aircraft = createVehicle [_type, _spawnPos, [], 0, "NONE"];
            _aircraft setDir _spawnDir;
            _aircraft setPos _spawnPos;
            
            // Set aircraft state
            _aircraft setFuel _fuel;
            _aircraft setDamage _damage;
            
            // Set weapons ammo
            {
                _x params ["_weapon", "_ammo"];
                _aircraft setAmmo [_weapon, _ammo];
            } forEach _weaponsData;
            
            // Add to Zeus
            private _curator = getAssignedCuratorLogic player;
            if (!isNull _curator) then {
                _curator addCuratorEditableObjects [[_aircraft], true];
            };
            
            systemChat format ["%1 deployed to position", _displayName];
            diag_log format ["HANGAR: Created new deployed aircraft: %1", _displayName];
        };
        
        // Mark as deployed
        _aircraft setVariable ["HANGAR_deployed", true, true];
        _aircraft setVariable ["HANGAR_storageIndex", _aircraftIndex, true];
        
        // CRITICAL CHANGE: Always allow editing by Zeus
        _aircraft setVariable ["HANGAR_managedAircraft", false, true];
        
        // Add destruction event handler
        _aircraft addEventHandler ["Killed", {
            params ["_unit", "_killer"];
            [_unit] call HANGAR_fnc_onAircraftDestroyed;
        }];
        
        // Also add damage handler for high damage
        _aircraft addEventHandler ["Dammaged", {
            params ["_unit", "_selection", "_damage", "_hitIndex", "_hitPoint", "_shooter", "_projectile"];
            
            // If overall damage is high but not quite destroyed
            if (damage _unit > 0.85 && alive _unit) then {
                [_unit] call HANGAR_fnc_onAircraftDestroyed;
            };
        }];
    };
    
    // IMPORTANT: Update storage record with deployment status
    _record set [7, true]; // isDeployed = true
    _record set [8, _aircraft]; // deployedInstance = the aircraft object
    
    // Add to deployed tracking array if not already there
    if (!(_aircraft in HANGAR_deployedAircraft)) then {
        HANGAR_deployedAircraft pushBack _aircraft;
    };
    
    // Create crew for deployment or reposition
    if (count _crew > 0) then {
        // Use a proper spawn to handle crew creation with delays
        [_crew, _aircraft] spawn {
            params ["_crew", "_aircraft"];
            
            // Make sure aircraft still exists
            if (isNull _aircraft) exitWith {
                diag_log "HANGAR: Aircraft no longer exists for crew assignment";
            };
            
            // Assign each crew member with delay
            {
                _x params ["_pilotIndex", "_role", "_turretPath"];
                if (_pilotIndex >= 0) then {
                    // CRITICAL CHANGE: Always deploy with full AI by setting _isDeployed to true
                    [_pilotIndex, _aircraft, _role, _turretPath, true] call HANGAR_fnc_assignPilotToAircraft;
                    sleep 0.3;
                };
            } forEach _crew;
            
            diag_log format ["HANGAR: Completed crew assignment for %1", _aircraft];
            
            // ===== CRITICAL SECTION: WAYPOINT SETUP WITH FULL AI =====
            // Get driver and group
            private _driver = driver _aircraft;
            if (isNull _driver) then {
                private _allCrew = crew _aircraft;
                if (count _allCrew > 0) then {
                    _driver = _allCrew select 0;
                };
            };
            
            if (!isNull _driver) then {
                private _group = group _driver;
                
                // Ensure ALL crew has AI enabled
                {
                    if (_x getVariable ["HANGAR_isPilot", false]) then {
                        // Enable ALL AI
                        _x enableAI "ALL";
                        _x enableAI "TARGET";
                        _x enableAI "AUTOTARGET";
                        _x enableAI "MOVE";
                        _x enableAI "FSM";
                        _x enableAI "PATH";
                        
                        // Set aggressive behavior
                        _x setBehaviour "COMBAT";
                        _x setCombatMode "RED";
                        _x allowFleeing 0;
                        _x setCaptive false;
                        
                        systemChat format ["AI fully enabled for pilot: %1", name _x];
                        diag_log format ["HANGAR: Enabled ALL AI for pilot: %1", name _x];
                    };
                } forEach crew _aircraft;
                
                // Clear existing waypoints
                while {count waypoints _group > 0} do {
                    deleteWaypoint [_group, 0];
                };
                
                // Look for a loiter marker
                private _loiterMarker = "air_loiter";
                private _loiterPos = [0,0,0];
                
                if (markerType _loiterMarker == "") then {
                    // If no specific loiter marker, use center of map
                    _loiterPos = [worldSize/2, worldSize/2, 300];
                    systemChat "No air_loiter marker found, using map center";
                } else {
                    _loiterPos = getMarkerPos _loiterMarker;
                    _loiterPos set [2, 300]; // Set altitude to 300m
                }; 
                
                // First add a MOVE waypoint to ensure initial movement
                private _moveWP = _group addWaypoint [_loiterPos, 0];
                _moveWP setWaypointType "MOVE";
                _moveWP setWaypointSpeed "NORMAL";
                // CRITICAL CHANGE: Set to COMBAT behavior
                _moveWP setWaypointBehaviour "COMBAT";
                _moveWP setWaypointCombatMode "RED";
                
                // Then add the loiter waypoint
                private _wp = _group addWaypoint [_loiterPos, 0];
                _wp setWaypointType "LOITER";
                _wp setWaypointLoiterType "CIRCLE";
                _wp setWaypointLoiterRadius 800; // 800m radius circle
                _wp setWaypointSpeed "LIMITED";
                // CRITICAL CHANGE: Set to COMBAT behavior
                _wp setWaypointBehaviour "COMBAT";
                _wp setWaypointCombatMode "RED";
                
                // Set group behavior
                _group setBehaviour "COMBAT";
                _group setCombatMode "RED";
                _group allowFleeing 0;
                
                // Start the engine
                _aircraft engineOn true;
                _driver action ["engineOn", _aircraft];
                
                // Force flying height
                _aircraft flyInHeight 300;
                
                diag_log format ["HANGAR: Created waypoints with COMBAT behavior for %1", _aircraft];
            } else {
                diag_log "HANGAR: No driver found for deployed aircraft";
            };
        };
    };
    
    _aircraft
};

// Function to get required crew count for an aircraft type
HANGAR_fnc_getRequiredCrew = {
    params ["_type"];
    
    private _requiredCrew = 1; // Default to 1
    
    // Look up in our aircraft types configuration
    {
        _x params ["_category", "_aircraftList"];
        
        {
            _x params ["_className", "_displayName", "_crewCount"];
            if (_className == _type) exitWith {
                _requiredCrew = _crewCount;
            };
        } forEach _aircraftList;
    } forEach HANGAR_aircraftTypes;
    
    _requiredCrew
};

// Function to check if an aircraft is fully crewed
HANGAR_fnc_isAircraftFullyCrewed = {
    params ["_index"];
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {false};
    
    private _record = HANGAR_storedAircraft select _index;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew"];
    
    private _requiredCrew = [_type] call HANGAR_fnc_getRequiredCrew;
    private _actualCrew = count _crew;
    
    _actualCrew >= _requiredCrew
};

// Function to refuel aircraft
HANGAR_fnc_refuelAircraft = {
    params ["_index"];
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {
        diag_log format ["HANGAR: Invalid aircraft index for refueling: %1", _index];
        false
    };
    
    // Get current fuel level
    private _record = HANGAR_storedAircraft select _index;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
    
    // Calculate fuel needed and cost
    private _fuelNeeded = 1.0 - _fuel;
    private _fuelCost = _fuelNeeded * 10; // 10 fuel resource per 0.1 tank
    
    // Check if we have enough fuel in economy
    private _hasFuel = true;
    if (!isNil "RTS_fnc_getResource") then {
        private _availableFuel = ["fuel"] call RTS_fnc_getResource;
        _hasFuel = _availableFuel >= _fuelCost;
    };
    
    if (!_hasFuel) exitWith {
        systemChat "Not enough fuel in storage to refuel aircraft";
        diag_log "HANGAR: Not enough fuel resources for refueling";
        false
    };
    
    // Deduct fuel from economy if available
    if (!isNil "RTS_fnc_modifyResource") then {
        ["fuel", -_fuelCost] call RTS_fnc_modifyResource;
    };
    
    // Update aircraft fuel to full
    _record set [2, 1.0]; // Set fuel to 100%
    
    // Update viewed aircraft if this is the one being viewed
    if (!isNull HANGAR_viewedAircraft) then {
        private _viewedIndex = HANGAR_viewedAircraft getVariable ["HANGAR_storageIndex", -1];
        if (_viewedIndex == _index) then {
            HANGAR_viewedAircraft setFuel 1.0;
        };
    };
    
    // Update deployed instance if deployed
    if (_isDeployed && !isNull _deployedInstance) then {
        _deployedInstance setFuel 1.0;
        diag_log format ["HANGAR: Updated fuel on deployed aircraft: %1", _deployedInstance];
    };
    
    systemChat format ["%1 refueled", _displayName];
    diag_log format ["HANGAR: Aircraft refueled: %1", _displayName];
    true
};

// Function to repair aircraft
HANGAR_fnc_repairAircraft = {
    params ["_index"];
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {
        diag_log format ["HANGAR: Invalid aircraft index for repair: %1", _index];
        false
    };
    
    // Get current damage level
    private _record = HANGAR_storedAircraft select _index;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
    
    // Calculate materials needed and cost
    private _repairCost = _damage * 20; // Cost scales with damage
    
    // Check if we have enough resources in economy
    private _hasResources = true;
    if (!isNil "RTS_fnc_getResource") then {
        private _availableAluminum = ["aluminum"] call RTS_fnc_getResource;
        _hasResources = _availableAluminum >= _repairCost;
    };
    
    if (!_hasResources) exitWith {
        systemChat "Not enough aluminum in storage to repair aircraft";
        diag_log "HANGAR: Not enough aluminum resources for repair";
        false
    };
    
    // Deduct resources from economy if available
    if (!isNil "RTS_fnc_modifyResource") then {
        ["aluminum", -_repairCost] call RTS_fnc_modifyResource;
    };
    
    // Update aircraft damage to 0
    _record set [3, 0]; // Set damage to 0%
    
    // Update viewed aircraft if this is the one being viewed
    if (!isNull HANGAR_viewedAircraft) then {
        private _viewedIndex = HANGAR_viewedAircraft getVariable ["HANGAR_storageIndex", -1];
        if (_viewedIndex == _index) then {
            HANGAR_viewedAircraft setDamage 0;
        };
    };
    
    // Update deployed instance if deployed
    if (_isDeployed && !isNull _deployedInstance) then {
        _deployedInstance setDamage 0;
        diag_log format ["HANGAR: Repaired deployed aircraft: %1", _deployedInstance];
    };
    
    systemChat format ["%1 repaired", _displayName];
    diag_log format ["HANGAR: Aircraft repaired: %1", _displayName];
    true
};

// Function to rearm aircraft
HANGAR_fnc_rearmAircraft = {
    params ["_index"];
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {
        diag_log format ["HANGAR: Invalid aircraft index for rearming: %1", _index];
        false
    };
    
    // Get weapon data
    private _record = HANGAR_storedAircraft select _index;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
    
    // Calculate ammunition needed and costs
    private _ammoCost = 0;
    private _ironCost = 0;
    
    {
        _x params ["_weapon", "_currentAmmo", "_weaponName"];
        
        // Get maximum ammo for this weapon
        private _maxAmmo = 1000; // Default
        private _weaponConfig = configFile >> "CfgWeapons" >> _weapon;
        if (isClass _weaponConfig) then {
            private _muzzles = getArray (_weaponConfig >> "muzzles");
            if (count _muzzles > 0) then {
                private _muzzleConfig = if (_muzzles select 0 == "this") then {
                    _weaponConfig
                } else {
                    _weaponConfig >> (_muzzles select 0)
                };
                
                if (isClass _muzzleConfig) then {
                    private _magazines = getArray (_muzzleConfig >> "magazines");
                    if (count _magazines > 0) then {
                        private _magConfig = configFile >> "CfgMagazines" >> (_magazines select 0);
                        if (isClass _magConfig) then {
                            _maxAmmo = getNumber (_magConfig >> "count");
                        };
                    };
                };
            };
        };
        
        // Calculate ammo needed
        private _ammoNeeded = _maxAmmo - _currentAmmo;
        
        if (_ammoNeeded > 0) then {
            // Different costs based on weapon type
            if (_weapon find "cannon" >= 0 || _weapon find "Cannon" >= 0) then {
                _ammoCost = _ammoCost + (_ammoNeeded * 0.2); // Cannons cost more
                _ironCost = _ironCost + (_ammoNeeded * 0.1);
            } else {
                _ammoCost = _ammoCost + (_ammoNeeded * 0.1); // Regular guns
                _ironCost = _ironCost + (_ammoNeeded * 0.05);
            };
            
            // Update weapon ammo to max
            _x set [1, _maxAmmo];
        };
    } forEach _weaponsData;
    
    // Round costs up
    _ammoCost = ceil _ammoCost;
    _ironCost = ceil _ironCost;
    
    // Check if we have enough resources in economy
    private _hasResources = true;
    if (!isNil "RTS_fnc_getResource") then {
        private _availableIron = ["iron"] call RTS_fnc_getResource;
        
        // We're adding ammo as a resource for this system
        private _availableAmmo = 1000; // Default high value if economy doesn't have ammo resource
        if ([["ammo", 0]] call BIS_fnc_arrayFindDeep select 0 >= 0) then {
            _availableAmmo = ["ammo"] call RTS_fnc_getResource;
        };
        
        _hasResources = (_availableIron >= _ironCost) && (_availableAmmo >= _ammoCost);
    };
    
    if (!_hasResources) exitWith {
        systemChat "Not enough resources to rearm aircraft";
        diag_log "HANGAR: Not enough resources for rearming";
        false
    };
    
    // No changes needed if no ammo costs
    if (_ammoCost == 0 && _ironCost == 0) exitWith {
        systemChat "Aircraft is already fully armed";
        diag_log "HANGAR: Aircraft already fully armed";
        true
    };
    
    // Deduct resources from economy if available
    if (!isNil "RTS_fnc_modifyResource") then {
        ["iron", -_ironCost] call RTS_fnc_modifyResource;
        
        // Try to deduct ammo if it exists in economy system
        if ([["ammo", 0]] call BIS_fnc_arrayFindDeep select 0 >= 0) then {
            ["ammo", -_ammoCost] call RTS_fnc_modifyResource;
        };
    };
    
    // Update the weapons data in storage
    _record set [4, _weaponsData];
    
    // Update viewed aircraft if this is the one being viewed
    if (!isNull HANGAR_viewedAircraft) then {
        private _viewedIndex = HANGAR_viewedAircraft getVariable ["HANGAR_storageIndex", -1];
        if (_viewedIndex == _index) then {
            {
                _x params ["_weapon", "_ammo"];
                HANGAR_viewedAircraft setAmmo [_weapon, _ammo];
            } forEach _weaponsData;
        };
    };
    
    // Update deployed instance if deployed
    if (_isDeployed && !isNull _deployedInstance) then {
        {
            _x params ["_weapon", "_ammo"];
            _deployedInstance setAmmo [_weapon, _ammo];
        } forEach _weaponsData;
        diag_log format ["HANGAR: Rearmed deployed aircraft: %1", _deployedInstance];
    };
    
    systemChat format ["%1 rearmed", _displayName];
    diag_log format ["HANGAR: Aircraft rearmed: %1", _displayName];
    true
};

// Function to add sample aircraft for testing
HANGAR_fnc_addSampleAircraft = {
    // Exit if we already have aircraft
    if (count HANGAR_storedAircraft > 0) exitWith {
        systemChat "Sample aircraft not added - hangar already contains aircraft";
        diag_log "HANGAR: Sample aircraft not added - hangar already has aircraft";
    };
    
    // Add some sample aircraft from each category
    {
        _x params ["_category", "_aircraftList"];
        
        {
            _x params ["_className", "_displayName", "_crewCount"];
            
            // Generate some sample weapons data based on class
            private _weaponsData = [];
            
            // Different weapons based on aircraft type
            switch (true) do {
                case (_className == "sab_fl_spitfire_mk1" || _className == "sab_fl_spitfire_mk9"): {
                    _weaponsData = [
                        ["LIB_BROWNING", 350, "Browning .303"],
                        ["LIB_BROWNING", 350, "Browning .303"]
                    ];
                };
                case (_className == "sab_fl_dh98"): {
                    _weaponsData = [
                        ["LIB_BROWNING", 500, "Browning .303"],
                        ["LIB_BESA", 750, "BESA 7.7mm"]
                    ];
                };
                case (_className == "sab_sw_halifax"): {
                    _weaponsData = [
                        ["LIB_BESA", 1000, "BESA 7.7mm"],
                        ["LIB_M2", 750, "M2 .50 Cal"]
                    ];
                };
                case (_className == "LIB_C47_RAF"): {
                    _weaponsData = [];
                };
            };
            
            // Create sample aircraft entry with deployment flags
            private _aircraft = [
                _className,           // Type
                _displayName,         // Display name
                0.8,                  // 80% fuel
                0.1,                  // 10% damage
                _weaponsData,         // Weapons data
                [],                   // No crew
                [],                   // No custom data
                false,                // Not deployed
                objNull               // No deployed instance
            ];
            
            // Add to stored aircraft
            HANGAR_storedAircraft pushBack _aircraft;
            
            systemChat format ["Added sample aircraft: %1", _displayName];
            diag_log format ["HANGAR: Added sample aircraft: %1", _displayName];
        } forEach _aircraftList;
    } forEach HANGAR_aircraftTypes;
};

// Monitor deployed aircraft status
HANGAR_fnc_monitorDeployedAircraft = {
    // Clean up invalid entries from deployment array
    HANGAR_deployedAircraft = HANGAR_deployedAircraft - [objNull];
    
    // Check status of deployed aircraft in storage records
    for "_i" from 0 to ((count HANGAR_storedAircraft) - 1) do {
        private _record = HANGAR_storedAircraft select _i;
        _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
        
        if (_isDeployed) then {
            // Check if the deployed instance is still valid
            if (isNull _deployedInstance) then {
                // Aircraft is marked as deployed but instance is gone
                _record set [7, false]; // Mark as not deployed
                diag_log format ["HANGAR: Fixed orphaned deployment record for: %1", _displayName];
            } else {
                // Update fuel and damage in the record from the actual aircraft
                _record set [2, fuel _deployedInstance]; // Update fuel
                _record set [3, damage _deployedInstance]; // Update damage
                
                // Check if seriously damaged
                if (damage _deployedInstance > 0.9 || !alive _deployedInstance) then {
                    // Process as destroyed
                    [_deployedInstance] call HANGAR_fnc_onAircraftDestroyed;
                };
            };
        };
    };
    
    // Also run the health monitor to check for destroyed aircraft
    call HANGAR_fnc_monitorAircraftHealth;
    
    // Check deployed aircraft against storage records
    {
        private _aircraft = _x;
        private _storageIndex = _aircraft getVariable ["HANGAR_storageIndex", -1];
        
        // Check if still in storage records
        if (_storageIndex >= 0 && _storageIndex < count HANGAR_storedAircraft) then {
            private _record = HANGAR_storedAircraft select _storageIndex;
            
            // Update deployment reference
            _record set [7, true]; // isDeployed = true
            _record set [8, _aircraft]; // deployedInstance = aircraft
        } else {
            // Aircraft deployment record was lost
            diag_log format ["HANGAR: Orphaned deployed aircraft with invalid storage index: %1", _aircraft];
        };
    } forEach HANGAR_deployedAircraft;
    
    // Periodically clean up invalid crew entries
    call HANGAR_fnc_cleanupInvalidCrewEntries;
    
    // Log status
    diag_log format ["HANGAR: Monitor - Deployed aircraft count: %1", count HANGAR_deployedAircraft];
};

// Function to check/add ammo resource to economy system
[] spawn {
    // Wait for economy system to initialize
    waitUntil {!isNil "RTS_resources"};
    sleep 1;
    
    // Check if ammo resource exists
    private _ammoExists = false;
    {
        if (_x select 0 == "ammo") then {
            _ammoExists = true;
        };
    } forEach RTS_resources;
    
    // Add ammo resource if it doesn't exist
    if (!_ammoExists) then {
        RTS_resources pushBack ["ammo", 1000]; // Start with 1000 ammo
        
        // Add income rate if income system exists
        if (!isNil "RTS_resourceIncome") then {
            private _incomeExists = false;
            {
                if (_x select 0 == "ammo") then {
                    _incomeExists = true;
                };
            } forEach RTS_resourceIncome;
            
            if (!_incomeExists) then {
                RTS_resourceIncome pushBack ["ammo", 5]; // 5 ammo per minute
            };
        };
        
        // Add icon if icon system exists
        if (!isNil "RTS_resourceIcons") then {
            private _iconExists = false;
            {
                if (_x select 0 == "ammo") then {
                    _iconExists = true;
                };
            } forEach RTS_resourceIcons;
            
            if (!_iconExists) then {
                RTS_resourceIcons pushBack ["ammo", "\a3\ui_f\data\igui\cfg\weaponicons\mg_ca.paa", "Ammunition: Used for aircraft weapons"];
            };
        };
        
        systemChat "Added ammunition resource to economy system";
        diag_log "HANGAR: Added ammo resource to economy system";
    };
};

// Function to force aircraft to move and fly properly
HANGAR_fnc_forceAircraftMovement = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {
        diag_log "MOVEMENT: Cannot force movement on null aircraft";
        false
    };
    
    diag_log format ["MOVEMENT: Forcing movement for aircraft %1", _aircraft];
    
    // Get driver and group
    private _driver = driver _aircraft;
    if (isNull _driver) exitWith {
        diag_log "MOVEMENT: No driver found";
        false
    };
    
    private _group = group _driver;
    if (isNull _group) exitWith {
        diag_log "MOVEMENT: No group found";
        false
    };
    
    // Make sure crew isn't captive
    {
        if (_x getVariable ["HANGAR_isPilot", false]) then {
            _x setCaptive false;
            diag_log format ["MOVEMENT: Setting pilot %1 to not captive", _x];
            
            // Explicitly enable ALL necessary AI
            _x enableAI "ALL";
            _x enableAI "PATH";
            _x enableAI "MOVE";
            _x enableAI "TARGET";
            _x enableAI "AUTOTARGET";
            _x enableAI "FSM";
            _x enableAI "WEAPONAIM";
            _x enableAI "TEAMSWITCH";
            
            // Ensure behavior settings allow movement
            _x setBehaviour "AWARE";
            _x setCombatMode "YELLOW";
        };
    } forEach crew _aircraft;
    
    // Clear existing waypoints completely
    while {count waypoints _group > 0} do {
        deleteWaypoint [_group, 0];
    };
    
    // Make sure the aircraft engine is running
    _aircraft engineOn true;
    
    // Set group behavior
    _group setBehaviour "AWARE";
    _group setCombatMode "YELLOW";
    _group allowFleeing 0;
    
    // Create a MOVE waypoint first to get it going, then a LOITER
    // Using flight altitude of 500m for better visibility
    private _loiterPos = [worldSize/2, worldSize/2, 500];
    
    // Look for a loiter marker
    if (markerType "air_loiter" != "") then {
        _loiterPos = getMarkerPos "air_loiter";
        _loiterPos set [2, 500]; // Force altitude
    };
    
    // First create a MOVE waypoint to ensure initial movement
    private _moveWP = _group addWaypoint [_loiterPos, 0];
    _moveWP setWaypointType "MOVE";
    _moveWP setWaypointSpeed "NORMAL";
    _moveWP setWaypointBehaviour "AWARE";
    _moveWP setWaypointCombatMode "YELLOW";
    _moveWP setWaypointStatements ["true", "vehicle this engineOn true; (vehicle this) flyInHeight 500;"];
    
    // Then add a LOITER waypoint
    private _loiterWP = _group addWaypoint [_loiterPos, 0];
    _loiterWP setWaypointType "LOITER";
    _loiterWP setWaypointLoiterType "CIRCLE";
    _loiterWP setWaypointLoiterRadius 1000;
    _loiterWP setWaypointSpeed "LIMITED";
    
    // Force flight height
    _aircraft flyInHeight 500;
    _aircraft doFollow _aircraft; // Sometimes helps "unstick" AI
    
    // Set active waypoint to the move waypoint
    _group setCurrentWaypoint _moveWP;
    
    // Monitor movement for diagnostic purposes
    [_aircraft, _group] spawn {
        params ["_aircraft", "_group"];
        
        // Store initial position
        private _startPos = getPosASL _aircraft;
        
        // Check after 10 seconds
        sleep 10;
        
        if (!isNull _aircraft) then {
            private _newPos = getPosASL _aircraft;
            private _distance = _startPos distance _newPos;
            
            diag_log format ["MOVEMENT: After 10 seconds, aircraft moved %1 meters", _distance];
            
            if (_distance < 10) then {
                diag_log "MOVEMENT: WARNING - Aircraft barely moved, applying emergency fixes";
                
                // Emergency fixes
                {
                    _x enableAI "ALL";
                    _x allowFleeing 0;
                    _x setCaptive false;
                } forEach crew _aircraft;
                
                _aircraft engineOn true;
                _group setSpeedMode "NORMAL";
                
                // Create an emergency waypoint far away
                private _emergencyPos = _newPos vectorAdd [5000, 5000, 500];
                
                // Clear waypoints again
                while {count waypoints _group > 0} do {
                    deleteWaypoint [_group, 0];
                };
                
                private _emergencyWP = _group addWaypoint [_emergencyPos, 0];
                _emergencyWP setWaypointType "MOVE";
                _emergencyWP setWaypointSpeed "FULL";
                _group setCurrentWaypoint _emergencyWP;
                
                // Force move command
                _aircraft doMove _emergencyPos;
                
                diag_log "MOVEMENT: Applied emergency movement fixes";
            };
        };
    };
    
    // Return success
    true
};

// Function to fix all deployed aircraft
HANGAR_fnc_fixAllDeployedAircraft = {
    // Clean up array first
    HANGAR_deployedAircraft = HANGAR_deployedAircraft - [objNull];
    
    if (count HANGAR_deployedAircraft == 0) exitWith {
        systemChat "No deployed aircraft to fix";
        diag_log "MOVEMENT: No deployed aircraft to fix";
        false
    };
    
    private _fixCount = 0;
    
    // Apply movement fix to each aircraft - NO SLEEP
    {
        if (!isNull _x) then {
            [_x] call HANGAR_fnc_forceAircraftMovement;
            _fixCount = _fixCount + 1;
            // Removed sleep that was causing the error
        };
    } forEach HANGAR_deployedAircraft;
    
    systemChat format ["Applied movement fix to %1 aircraft", _fixCount];
    diag_log format ["MOVEMENT: Fixed %1 deployed aircraft", _fixCount];
    
    true
};

// New function that uses spawn for when we need delays
HANGAR_fnc_fixAllDeployedAircraftWithDelay = {
    [] spawn {
        // Clean up array first
        HANGAR_deployedAircraft = HANGAR_deployedAircraft - [objNull];
        
        if (count HANGAR_deployedAircraft == 0) exitWith {
            systemChat "No deployed aircraft to fix";
            diag_log "MOVEMENT: No deployed aircraft to fix";
        };
        
        private _fixCount = 0;
        
        // Apply movement fix to each aircraft WITH DELAYS
        {
            if (!isNull _x) then {
                [_x] call HANGAR_fnc_forceAircraftMovement;
                _fixCount = _fixCount + 1;
                sleep 1; // Sleep is allowed here because we're in a spawn context
            };
        } forEach HANGAR_deployedAircraft;
        
        systemChat format ["Applied movement fix to %1 aircraft", _fixCount];
        diag_log format ["MOVEMENT: Fixed %1 deployed aircraft", _fixCount];
    };
    
    true
};

// Function to handle aircraft destruction
HANGAR_fnc_onAircraftDestroyed = {
    params ["_aircraft"];
    
    // Check if this is a managed aircraft
    private _storageIndex = _aircraft getVariable ["HANGAR_storageIndex", -1];
    if (_storageIndex < 0) exitWith {
        diag_log format ["HANGAR: Destroyed aircraft %1 is not managed", _aircraft];
    };
    
    // Get aircraft data
    private _record = HANGAR_storedAircraft select _storageIndex;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
    
    // Already processed?
    if (!_isDeployed || isNull _deployedInstance) exitWith {
        diag_log format ["HANGAR: Aircraft %1 already marked as not deployed", _displayName];
    };
    
    // Store crew info before we remove the aircraft
    private _crewData = +_crew; // Make a copy
    
    // CRITICAL: REMOVE AIRCRAFT FROM STORAGE
    HANGAR_storedAircraft deleteAt _storageIndex;
    
    // Remove from deployed tracking array
    HANGAR_deployedAircraft = HANGAR_deployedAircraft - [_aircraft];
    
    // Notification to player
    private _msg = format ["Aircraft Lost: %1 has been destroyed and removed from inventory!", _displayName];
    systemChat _msg;
    
    // More visible hint with details
    hint parseText format [
        "<t size='1.2' color='#ff5555' align='center'>Aircraft Lost</t><br/><br/>" +
        "<t align='center'>%1</t><br/><br/>" +
        "<t size='0.8' align='center'>The aircraft has been destroyed in action and removed from inventory</t>",
        _displayName
    ];
    
    // Update any UI if open
    if (!isNull findDisplay 312 && !isNull (findDisplay 312 displayCtrl 9802)) then {
        call HANGAR_fnc_refreshUI;
    };
    
    diag_log format ["HANGAR: Removed destroyed aircraft %1 from inventory", _displayName];
    
    // Handle crew casualties - assume all KIA unless evidence of ejection
    {
        _x params ["_pilotIndex"];
        
        if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
            // Check if pilot managed to eject
            private _pilotUnit = objNull;
            {
                if ((_x getVariable ["HANGAR_pilotIndex", -1]) == _pilotIndex) then {
                    _pilotUnit = _x;
                };
            } forEach allUnits;
            
            // Assume KIA unless unit is alive and outside aircraft
            private _survived = false;
            
            if (!isNull _pilotUnit && alive _pilotUnit && (vehicle _pilotUnit == _pilotUnit)) then {
                // Pilot ejected and is alive on the ground
                // Set as available in roster but don't delete
                (HANGAR_pilotRoster select _pilotIndex) set [5, objNull];
                systemChat format ["Pilot %1 ejected successfully and will return to duty", (HANGAR_pilotRoster select _pilotIndex) select 0];
                _survived = true;
            } else {
                // Pilot is KIA - remove from roster
                private _pilotName = (HANGAR_pilotRoster select _pilotIndex) select 0;
                private _pilotRank = [(HANGAR_pilotRoster select _pilotIndex) select 1] call HANGAR_fnc_getPilotRankName;
                systemChat format ["%1 %2 was killed in action", _pilotRank, _pilotName];
                
                // Remove from roster with confirmation
                diag_log format ["HANGAR: Removing KIA pilot %1 %2 (index %3) from roster", _pilotRank, _pilotName, _pilotIndex];
                HANGAR_pilotRoster deleteAt _pilotIndex;
                
                // Re-index remaining crew in this and other aircraft
                // This is CRITICAL - we need to adjust indices for all remaining crew
                // Pilots with higher indices need to be decremented
                {
                    if (_x getVariable ["HANGAR_isPilot", false]) then {
                        private _storedIndex = _x getVariable ["HANGAR_pilotIndex", -1];
                        if (_storedIndex > _pilotIndex) then {
                            // This pilot needs to be reindexed
                            _x setVariable ["HANGAR_pilotIndex", _storedIndex - 1, true];
                            diag_log format ["HANGAR: Adjusted pilot unit index from %1 to %2", _storedIndex, _storedIndex - 1];
                        };
                    };
                } forEach allUnits;
                
                // Process all aircraft records to update crew indices
                for "_i" from 0 to ((count HANGAR_storedAircraft) - 1) do {
                    private _record = HANGAR_storedAircraft select _i;
                    if (count _record >= 6) then {
                        private _aircraftCrew = _record select 5;
                        
                        // Process each crew assignment
                        for "_j" from 0 to ((count _aircraftCrew) - 1) do {
                            private _crewEntry = _aircraftCrew select _j;
                            if (count _crewEntry > 0) then {
                                private _crewPilotIndex = _crewEntry select 0;
                                
                                if (_crewPilotIndex == _pilotIndex) then {
                                    // This crew entry refers to the dead pilot - remove it
                                    _aircraftCrew deleteAt _j;
                                    diag_log format ["HANGAR: Removed dead pilot reference from aircraft %1", _i];
                                    break; // Exit loop as we modified the array
                                } else {
                                    if (_crewPilotIndex > _pilotIndex) then {
                                        // Decrement the index
                                        _crewEntry set [0, _crewPilotIndex - 1];
                                        diag_log format ["HANGAR: Adjusted crew reference from %1 to %2 in aircraft %3", 
                                            _crewPilotIndex, _crewPilotIndex - 1, _i];
                                    };
                                };
                            };
                        };
                    };
                };
            };
            
            // Log pilot status
            diag_log format ["HANGAR: Pilot index %1 %2", _pilotIndex, if (_survived) then {"survived"} else {"KIA"}];
        };
    } forEach _crewData;
    
    // Update storage indices for all aircraft after this one
    {
        private _aircraft = _x;
        private _currentIndex = _aircraft getVariable ["HANGAR_storageIndex", -1];
        
        if (_currentIndex > _storageIndex) then {
            // This aircraft's index needs to be decremented
            _aircraft setVariable ["HANGAR_storageIndex", _currentIndex - 1, true];
            diag_log format ["HANGAR: Updated storage index for %1 from %2 to %3", _aircraft, _currentIndex, _currentIndex - 1];
        };
    } forEach HANGAR_deployedAircraft;
    
    // Refresh UI if open
    if (!isNull findDisplay 312 && !isNull (findDisplay 312 displayCtrl 9802)) then {
        call HANGAR_fnc_refreshUI;
    };
};

// Function to monitor aircraft health
HANGAR_fnc_monitorAircraftHealth = {
    // Clean up invalid entries first
    HANGAR_deployedAircraft = HANGAR_deployedAircraft - [objNull];
    
    // Check each deployed aircraft
    {
        private _aircraft = _x;
        
        // If destroyed (very damaged or actually null)
        if (isNull _aircraft || !alive _aircraft || damage _aircraft > 0.9) then {
            // Process destruction if not already processed
            [_aircraft] call HANGAR_fnc_onAircraftDestroyed;
        };
    } forEach HANGAR_deployedAircraft;
};

// Function to get available crew positions for an aircraft
HANGAR_fnc_getAvailableCrewPositions = {
    params ["_aircraftIndex"];
    
    if (_aircraftIndex < 0 || _aircraftIndex >= count HANGAR_storedAircraft) exitWith {[]};
    
    // Get aircraft record
    private _record = HANGAR_storedAircraft select _aircraftIndex;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed"];
    
    // Get required crew count
    private _requiredCrew = [_type] call HANGAR_fnc_getRequiredCrew;
    
    // Get already filled positions
    private _filledPositions = [];
    {
        _x params ["_pilotIndex", "_role", "_turretPath"];
        _filledPositions pushBack [_role, _turretPath];
    } forEach _crew;
    
    // Define standard positions - this will vary based on aircraft
    private _allPositions = [
        ["driver", []],          // Pilot
        ["gunner", []],          // Main gunner
        ["commander", []],       // Commander position
        ["turret", [0]],         // Turret 1
        ["turret", [1]],         // Turret 2
        ["turret", [2]],         // Turret 3
        ["cargo", 0]             // Cargo (generic crew)
    ];
    
    // Filter to remove filled positions
    private _availablePositions = [];
    {
        if !(_x in _filledPositions) then {
            _availablePositions pushBack _x;
        };
    } forEach _allPositions;
    
    // Only return enough positions to meet requirements
    private _neededPositions = _requiredCrew - count _crew;
    if (_neededPositions <= 0) exitWith {[]};
    
    _availablePositions resize (_neededPositions min count _availablePositions);
    _availablePositions
};

// Add this to hangarSystem.sqf
// Updated monitoring function to check for destroyed aircraft
HANGAR_fnc_monitorDeployedAircraft = {
    // Clean up invalid entries from deployment array
    HANGAR_deployedAircraft = HANGAR_deployedAircraft - [objNull];
    
    // Check status of deployed aircraft in storage records
    for "_i" from 0 to ((count HANGAR_storedAircraft) - 1) do {
        private _record = HANGAR_storedAircraft select _i;
        _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
        
        if (_isDeployed) then {
            // Check if the deployed instance is still valid
            if (isNull _deployedInstance) then {
                // Aircraft is marked as deployed but instance is gone
                _record set [7, false]; // Mark as not deployed
                diag_log format ["HANGAR: Fixed orphaned deployment record for: %1", _displayName];
            } else {
                // Update fuel and damage in the record from the actual aircraft
                _record set [2, fuel _deployedInstance]; // Update fuel
                _record set [3, damage _deployedInstance]; // Update damage
                
                // Check if seriously damaged
                if (damage _deployedInstance > 0.9 || !alive _deployedInstance) then {
                    // Process as destroyed
                    [_deployedInstance] call HANGAR_fnc_onAircraftDestroyed;
                };
            };
        };
    };
    
    // Also run the health monitor to check for destroyed aircraft
    call HANGAR_fnc_monitorAircraftHealth;
    
    // Log status
    diag_log format ["HANGAR: Monitor - Deployed aircraft count: %1", count HANGAR_deployedAircraft];
};

// Function to clean up invalid crew entries
HANGAR_fnc_cleanupInvalidCrewEntries = {
    // Process all stored aircraft
    for "_i" from 0 to ((count HANGAR_storedAircraft) - 1) do {
        [_i] call HANGAR_fnc_validateAircraftCrew;
    };
    
    // This should be called periodically, e.g., from monitoring functions
};

// Function to validate aircraft crew
HANGAR_fnc_validateAircraftCrew = {
    params ["_aircraftIndex"];
    
    if (_aircraftIndex < 0 || _aircraftIndex >= count HANGAR_storedAircraft) exitWith {
        diag_log format ["HANGAR: Invalid aircraft index for crew validation: %1", _aircraftIndex];
        false
    };
    
    // Get aircraft record
    private _record = HANGAR_storedAircraft select _aircraftIndex;
    private _aircraftName = _record select 1;
    private _crew = _record select 5;
    private _validatedCrew = [];
    private _hasChanges = false;
    
    // Verify each crew member still exists in the roster
    {
        _x params ["_pilotIndex", "_role", "_turretPath"];
        
        if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
            // Additional check: make sure pilot isn't already assigned to another deployed aircraft
            private _pilotData = HANGAR_pilotRoster select _pilotIndex;
            private _currentAircraft = _pilotData select 5;
            
            if (isNull _currentAircraft || 
                {_currentAircraft getVariable ["HANGAR_storageIndex", -1] == _aircraftIndex}) then {
                // Pilot is available or already assigned to this aircraft
                _validatedCrew pushBack _x;
            } else {
                // Pilot is assigned to a different aircraft
                diag_log format ["HANGAR: Pilot %1 already assigned to another aircraft", _pilotData select 0];
                _hasChanges = true;
                // Don't add to validated crew
            };
        } else {
            // Pilot no longer exists (was removed from roster)
            diag_log format ["HANGAR: Invalid pilot index %1 for %2", _pilotIndex, _aircraftName];
            _hasChanges = true;
            // Don't add to validated crew
        };
    } forEach _crew;
    
    // Update crew with validated list if there were changes
    if (_hasChanges) then {
        diag_log format ["HANGAR: Fixed crew list for %1: %2 entries removed", 
            _aircraftName, (count _crew) - (count _validatedCrew)];
        _record set [5, _validatedCrew];
    };
    
    // Return if any changes were made
    _hasChanges
};

// Call initialization a few seconds after startup
[] spawn {
    sleep 3;
    [] call HANGAR_fnc_addSampleAircraft;
    
    // Start monitoring loop
    while {true} do {
        call HANGAR_fnc_monitorDeployedAircraft;
        sleep 30;
    };
};