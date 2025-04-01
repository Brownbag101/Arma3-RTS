// Virtual Hangar System - Core Functionality
// Handles aircraft storage, retrieval, and management

// Function to store an aircraft in the hangar
HANGAR_fnc_storeAircraft = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {false};
    
    // Check if aircraft is within range of hangar
    if (_aircraft distance HANGAR_viewPosition > 500) exitWith {
        systemChat "Aircraft must be within 500m of hangar to store";
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
    
    // Create storage record
    private _record = [
        _type,
        _displayName,
        _fuel,
        _damage,
        _weaponsData,
        _crew,
        [] // Custom state data (for future use)
    ];
    
    // Add to stored aircraft array
    HANGAR_storedAircraft pushBack _record;
    
    // NEW: Remove from deployed tracking
    [_aircraft] call HANGAR_fnc_removeDeployedAircraft;
    
    // Delete the aircraft
    {deleteVehicle _x} forEach crew _aircraft;
    deleteVehicle _aircraft;
    
    systemChat format ["%1 stored in hangar", _displayName];
    true
};

// Function to retrieve and spawn an aircraft from storage
HANGAR_fnc_retrieveAircraft = {
    params ["_index", ["_deploy", false], ["_deployPos", ""]];
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {
        systemChat "Invalid aircraft index";
        objNull
    };
    
    // Get aircraft data
    private _record = HANGAR_storedAircraft select _index;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData"];
    
    // Determine spawn position
    private _spawnPos = HANGAR_viewPosition;
    private _dir = HANGAR_viewDirection;
    
    if (_deploy && _deployPos != "") then {
        if (markerType _deployPos != "") then {
            _spawnPos = getMarkerPos _deployPos;
            _dir = markerDir _deployPos;
        };
    };
    
    // Create the aircraft
    private _aircraft = createVehicle [_type, _spawnPos, [], 0, "NONE"];
    _aircraft setDir _dir;
    _aircraft setPos _spawnPos;
    
    // Set aircraft state
    _aircraft setFuel _fuel;
    _aircraft setDamage _damage;
    
    // Set weapons ammo
    {
        _x params ["_weapon", "_ammo"];
        _aircraft setAmmo [_weapon, _ammo];
    } forEach _weaponsData;
    
    // Add aircraft to Zeus
    private _curator = getAssignedCuratorLogic player;
    if (!isNull _curator) then {
        _curator addCuratorEditableObjects [[_aircraft], true];
    };
    
    // Make sure it's not editable by Zeus
    _aircraft setVariable ["HANGAR_managedAircraft", true, true];
    
    // NEW: Store storage index for reference
    _aircraft setVariable ["HANGAR_storageIndex", _index, true];
    
    // If deploying, assign crew members
    if (_deploy) then {
        // NEW: Mark as deployed
        _aircraft setVariable ["HANGAR_deployed", true, true];
        
        // NEW: Add to deployed tracking
        HANGAR_deployedAircraft pushBack _aircraft;
        
        {
            _x params ["_pilotIndex", "_role", "_turretPath"];
            
            // Get pilot unit
            if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
                private _pilotData = HANGAR_pilotRoster select _pilotIndex;
                
                // Create pilot unit and move to aircraft
                [_pilotIndex, _aircraft, _role, _turretPath] spawn HANGAR_fnc_assignPilotToAircraft;
            };
        } forEach _crew;
        
        // Remove from storage if deploying
        HANGAR_storedAircraft deleteAt _index;
        systemChat format ["%1 deployed", _displayName];
    } else {
        systemChat format ["%1 retrieved for viewing", _displayName];
    };
    
    // Return the aircraft object
    _aircraft
};

// Function to update aircraft state in storage
HANGAR_fnc_updateStoredAircraft = {
    params ["_index", "_key", "_value"];
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {
        systemChat "Invalid aircraft index";
        false
    };
    
    private _record = HANGAR_storedAircraft select _index;
    
    switch (_key) do {
        case "fuel": {
            _record set [2, _value];
            systemChat format ["%1 fuel updated to %2%3", _record select 1, round(_value * 100), "%"];
        };
        case "damage": {
            _record set [3, _value];
            systemChat format ["%1 repaired", _record select 1];
        };
        case "addCrew": {
            private _crew = _record select 5;
            _crew pushBack _value;
            systemChat format ["Crew member assigned to %1", _record select 1];
        };
        case "removeCrew": {
            private _crew = _record select 5;
            private _index = _value;
            if (_index >= 0 && _index < count _crew) then {
                _crew deleteAt _index;
                systemChat "Crew member removed";
            };
        };
    };
    
    true
};

// Function to get index of an aircraft in storage by exact match
HANGAR_fnc_findStoredAircraftIndex = {
    params ["_aircraft"];
    
    private _index = -1;
    
    {
        if (_x isEqualTo _aircraft) exitWith {
            _index = _forEachIndex;
        };
    } forEach HANGAR_storedAircraft;
    
    _index
};

// Function to get aircraft already on field (that could be added to hangar)
HANGAR_fnc_getFieldAircraft = {
    private _fieldAircraft = [];
    
    {
        // Check if it's an aircraft and within range
        if (_x isKindOf "Air" && {_x distance HANGAR_viewPosition < 500}) then {
            _fieldAircraft pushBack _x;
        };
    } forEach vehicles;
    
    _fieldAircraft
};

// Fixed aircraft viewing function
HANGAR_fnc_viewAircraft = {
    params ["_index"];
    
    // Always clear any existing aircraft first
    call HANGAR_fnc_clearViewedAircraft;
    
    // Get aircraft data
    private _record = HANGAR_storedAircraft select _index;
    private _aircraftType = _record select 0;
    private _displayName = _record select 1;
    
    // Generate a unique ID for this aircraft view
    private _uniqueID = format ["%1_%2_%3", _aircraftType, _index, diag_tickTime];
    
    // Check if already deployed
    private _deployed = false;
    private _deployedAircraft = objNull;
    
    {
        if (!isNull _x) then {
            private _storedIndex = _x getVariable ["HANGAR_storageIndex", -1];
            if (_storedIndex == _index) exitWith {
                _deployed = true;
                _deployedAircraft = _x;
            };
        };
    } forEach HANGAR_deployedAircraft;
    
    if (_deployed && !isNull _deployedAircraft) then {
        HANGAR_viewedAircraft = _deployedAircraft;
        systemChat format ["%1 is currently deployed in the field", _displayName];
    } else {
        // Retrieve but don't deploy the aircraft
        HANGAR_viewedAircraft = [_index, false] call HANGAR_fnc_retrieveAircraft;
        
        HANGAR_viewedAircraft setVariable ["HANGAR_uniqueID", _uniqueID, true];
        HANGAR_viewedAircraft setVariable ["HANGAR_storageIndex", _index, true];
        HANGAR_viewedAircraft setVariable ["HANGAR_isViewModel", true, true];
    };
    
    HANGAR_viewedAircraft
};

// Add this function to hangarSystem.sqf for cleanup
HANGAR_fnc_cleanupViewModels = {
    private _count = 0;
    
    // Find all aircraft within 100m of the viewing position
    private _nearbyVehicles = nearestObjects [HANGAR_viewPosition, ["Air"], 100];
    
    {
        private _isViewModel = _x getVariable ["HANGAR_isViewModel", false];
        private _isDeployed = _x getVariable ["HANGAR_deployed", false];
        
        // Check if it's one of our view models and not deployed
        if (_isViewModel && !_isDeployed) then {
            // Delete crew
            {
                deleteVehicle _x;
            } forEach crew _x;
            
            // Delete the aircraft
            deleteVehicle _x;
            _count = _count + 1;
        };
    } forEach _nearbyVehicles;
    
    if (_count > 0) then {
        diag_log format ["Cleaned up %1 stray view model aircraft", _count];
    };
    
    _count
};

// Function to clear viewed aircraft
HANGAR_fnc_clearViewedAircraft = {
    // If no aircraft is being viewed, nothing to do
    if (isNull HANGAR_viewedAircraft) exitWith {
        diag_log "No aircraft being viewed, nothing to clear";
    };
    
    // Check if the aircraft is deployed or a view model
    private _isDeployed = HANGAR_viewedAircraft getVariable ["HANGAR_deployed", false];
    private _isViewModel = HANGAR_viewedAircraft getVariable ["HANGAR_isViewModel", false];
    private _aircraftID = HANGAR_viewedAircraft getVariable ["HANGAR_uniqueID", "unknown"];
    
    diag_log format ["Clearing viewed aircraft: %1, Deployed: %2, ViewModel: %3", 
        _aircraftID, _isDeployed, _isViewModel];
    
    // Only delete if it's a view model (not deployed)
    if (_isViewModel && !_isDeployed) then {
        // Get crew and delete
        {
            deleteVehicle _x;
        } forEach crew HANGAR_viewedAircraft;
        
        // Delete aircraft
        deleteVehicle HANGAR_viewedAircraft;
        diag_log format ["Deleted view model aircraft: %1", _aircraftID];
    };
    
    // Log but don't delete deployed aircraft
    if (_isDeployed) then {
        diag_log format ["Keeping deployed aircraft in field: %1", _aircraftID];
    };
    
    // Log warning for unidentified aircraft
    if (!_isViewModel && !_isDeployed) then {
        diag_log format ["WARNING: Aircraft %1 neither deployed nor view model, potential leak", _aircraftID];
    };
    
    // Always reset the reference
    HANGAR_viewedAircraft = objNull;
};

// Also add this function to hangarSystem.sqf to clean up any stray view models
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
                deleteVehicle _x;
            } forEach crew _x;
            
            // Delete the aircraft
            deleteVehicle _x;
            _count = _count + 1;
        };
    } forEach _nearbyVehicles;
    
    if (_count > 0) then {
        diag_log format ["Cleaned up %1 stray view model aircraft", _count];
    };
    
    _count
};

// Function to deploy aircraft - FIXED VERSION WITH LOITER WAYPOINT
HANGAR_fnc_deployAircraft = {
    params ["_index", "_deployPosIndex"];
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {
        systemChat "Invalid aircraft index";
        objNull
    };
    
    if (_deployPosIndex < 0 || _deployPosIndex >= count HANGAR_deployPositions) exitWith {
        systemChat "Invalid deploy position";
        objNull
    };
    
    private _deployPos = HANGAR_deployPositions select _deployPosIndex;
    private _record = HANGAR_storedAircraft select _index;
    private _displayName = _record select 1;
    private _deployedAircraft = objNull;
    
    // First check if viewed aircraft matches this index
    if (!isNull HANGAR_viewedAircraft && 
        (HANGAR_viewedAircraft getVariable ["HANGAR_storageIndex", -1]) == _index) then {
        
        diag_log format ["Using viewed aircraft for deployment: %1", _displayName];
        
        // Move to new position if marker exists
        if (markerType _deployPos != "") then {
            private _newPos = getMarkerPos _deployPos;
            private _newDir = markerDir _deployPos;
            
            // Move the aircraft to deploy position
            HANGAR_viewedAircraft setPos _newPos;
            HANGAR_viewedAircraft setDir _newDir;
            
            // Mark as deployed and remove view model status
            HANGAR_viewedAircraft setVariable ["HANGAR_isViewModel", false, true];
            HANGAR_viewedAircraft setVariable ["HANGAR_deployed", true, true];
            
            // Enable pilots that were in view-only mode
            {
                if (_x getVariable ["HANGAR_viewModelPilot", false]) then {
                    _x setVariable ["HANGAR_viewModelPilot", false, true];
                    _x enableAI "MOVE";
                    _x setBehaviour "AWARE";
                };
            } forEach crew HANGAR_viewedAircraft;
            
            // Add to deployed tracking
            HANGAR_deployedAircraft pushBack HANGAR_viewedAircraft;
            
            // Remove from storage
            HANGAR_storedAircraft deleteAt _index;
            
            // Update storage indices
            [_index] call HANGAR_fnc_updateStorageIndices;
            
            // Set the deployedAircraft for waypoint assignment
            _deployedAircraft = HANGAR_viewedAircraft;
            
            // Clear viewed aircraft reference
            HANGAR_viewedAircraft = objNull;
            
            systemChat format ["%1 deployed", _displayName];
        };
    } else {
        // Check if already deployed elsewhere
        private _alreadyDeployed = false;
        private _existingAircraft = objNull;
        
        {
            if (!isNull _x) then {
                private _storedIndex = _x getVariable ["HANGAR_storageIndex", -1];
                if (_storedIndex == _index) exitWith {
                    _alreadyDeployed = true;
                    _existingAircraft = _x;
                };
            };
        } forEach HANGAR_deployedAircraft;
        
        // If already deployed, just move it
        if (_alreadyDeployed && !isNull _existingAircraft) then {
            systemChat "Aircraft already deployed - moving to new position";
            
            if (markerType _deployPos != "") then {
                private _newPos = getMarkerPos _deployPos;
                private _newDir = markerDir _deployPos;
                
                _existingAircraft setPos _newPos;
                _existingAircraft setDir _newDir;
            };
            
            _deployedAircraft = _existingAircraft;
        } else {
            // Last resort - create new aircraft
            _deployedAircraft = [_index, true, _deployPos] call HANGAR_fnc_retrieveAircraft;
            
            if (isNull _deployedAircraft) exitWith {
                systemChat "Failed to deploy aircraft";
                objNull
            };
        };
    };
    
    // If we have a deployed aircraft, set up loiter waypoint
    if (!isNull _deployedAircraft) then {
        // Get the group of the aircraft
        private _group = group driver _deployedAircraft;
        
        if (!isNull _group) then {
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
            
            // Create loiter waypoint
            private _wp = _group addWaypoint [_loiterPos, 0];
            _wp setWaypointType "LOITER";
            _wp setWaypointLoiterType "CIRCLE";
            _wp setWaypointLoiterRadius 800; // 800m radius circle
            _wp setWaypointSpeed "LIMITED";
            _wp setWaypointBehaviour "SAFE";
            _wp setWaypointCombatMode "BLUE"; // Only fire in self-defense
            
            // Set group behavior
            _group setBehaviour "SAFE";
            _group setCombatMode "BLUE";
            
            
            
            systemChat format ["%1 assigned to loiter patrol", _displayName];
        };
    };
    
    _deployedAircraft
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
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {false};
    
    // Get current fuel level
    private _record = HANGAR_storedAircraft select _index;
    _record params ["_type", "_displayName", "_fuel"];
    
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
        false
    };
    
    // Deduct fuel from economy if available
    if (!isNil "RTS_fnc_modifyResource") then {
        ["fuel", -_fuelCost] call RTS_fnc_modifyResource;
    };
    
    // Update aircraft fuel to full
    [_index, "fuel", 1.0] call HANGAR_fnc_updateStoredAircraft;
    
    // Update viewed aircraft if this is the one being viewed
    if (!isNull HANGAR_viewedAircraft) then {
        private _viewedIndex = HANGAR_selectedAircraftIndex;
        if (_viewedIndex == _index) then {
            HANGAR_viewedAircraft setFuel 1.0;
        };
    };
    
    // NEW: Update deployed aircraft if deployed
    {
        if (!isNull _x) then {
            private _storedIndex = _x getVariable ["HANGAR_storageIndex", -1];
            if (_storedIndex == _index) then {
                _x setFuel 1.0;
                diag_log format ["Updated fuel on deployed aircraft %1", _x];
            };
        };
    } forEach HANGAR_deployedAircraft;
    
    true
};

// Function to repair aircraft
HANGAR_fnc_repairAircraft = {
    params ["_index"];
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {false};
    
    // Get current damage level
    private _record = HANGAR_storedAircraft select _index;
    _record params ["_type", "_displayName", "_fuel", "_damage"];
    
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
        false
    };
    
    // Deduct resources from economy if available
    if (!isNil "RTS_fnc_modifyResource") then {
        ["aluminum", -_repairCost] call RTS_fnc_modifyResource;
    };
    
    // Update aircraft damage to 0
    [_index, "damage", 0] call HANGAR_fnc_updateStoredAircraft;
    
    // Update viewed aircraft if this is the one being viewed
    if (!isNull HANGAR_viewedAircraft) then {
        private _viewedIndex = HANGAR_selectedAircraftIndex;
        if (_viewedIndex == _index) then {
            HANGAR_viewedAircraft setDamage 0;
        };
    };
    
    // NEW: Update deployed aircraft if deployed
    {
        if (!isNull _x) then {
            private _storedIndex = _x getVariable ["HANGAR_storageIndex", -1];
            if (_storedIndex == _index) then {
                _x setDamage 0;
                diag_log format ["Repaired deployed aircraft %1", _x];
            };
        };
    } forEach HANGAR_deployedAircraft;
    
    true
};

// Function to rearm aircraft
HANGAR_fnc_rearmAircraft = {
    params ["_index"];
    
    if (_index < 0 || _index >= count HANGAR_storedAircraft) exitWith {false};
    
    // Get weapon data
    private _record = HANGAR_storedAircraft select _index;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData"];
    
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
        false
    };
    
    // No changes needed if no ammo costs
    if (_ammoCost == 0 && _ironCost == 0) exitWith {
        systemChat "Aircraft is already fully armed";
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
        private _viewedIndex = HANGAR_selectedAircraftIndex;
        if (_viewedIndex == _index) then {
            {
                _x params ["_weapon", "_ammo"];
                HANGAR_viewedAircraft setAmmo [_weapon, _ammo];
            } forEach _weaponsData;
        };
    };
    
    // NEW: Update deployed aircraft if deployed
    {
        if (!isNull _x) then {
            private _storedIndex = _x getVariable ["HANGAR_storageIndex", -1];
            if (_storedIndex == _index) then {
                {
                    _x params ["_weapon", "_ammo"];
                    _x setAmmo [_weapon, _ammo];
                } forEach _weaponsData;
                diag_log format ["Rearmed deployed aircraft %1", _x];
            };
        };
    } forEach HANGAR_deployedAircraft;
    
    systemChat format ["%1 rearmed", _displayName];
    true
};

// Function to add some sample aircraft for testing
HANGAR_fnc_addSampleAircraft = {
    // Exit if we already have aircraft
    if (count HANGAR_storedAircraft > 0) exitWith {
        systemChat "Sample aircraft not added - hangar already contains aircraft";
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
                case (_className == "sab_fl_spitfire_mk1"): {
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
            };
            
            // Create sample aircraft entry
            private _aircraft = [
                _className,           // Type
                _displayName,         // Display name
                0.8,                  // 80% fuel
                0.1,                  // 10% damage
                _weaponsData,         // Weapons data
                [],                   // No crew
                []                    // No custom data
            ];
            
            // Add to stored aircraft
            HANGAR_storedAircraft pushBack _aircraft;
            
            systemChat format ["Added sample aircraft: %1", _displayName];
        } forEach _aircraftList;
    } forEach HANGAR_aircraftTypes;
    
    // Log aircraft status
    diag_log format ["Added %1 sample aircraft to hangar", count HANGAR_storedAircraft];
};

// NEW: Remove a deployed aircraft from tracking array
HANGAR_fnc_removeDeployedAircraft = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {false};
    
    // Find and remove from deployed array
    private _index = HANGAR_deployedAircraft find _aircraft;
    if (_index != -1) then {
        HANGAR_deployedAircraft deleteAt _index;
        diag_log format ["Removed aircraft from deployed tracking: %1", _aircraft];
        true
    } else {
        false
    };
};

// NEW: Monitor deployed aircraft status
HANGAR_fnc_monitorDeployedAircraft = {
    // Clean up invalid entries
    private _toRemove = [];
    {
        if (isNull _x) then {
            _toRemove pushBack _forEachIndex;
        };
    } forEach HANGAR_deployedAircraft;
    
    // Remove invalid entries
    {
        HANGAR_deployedAircraft deleteAt _x;
    } forEach _toRemove;
    
    // Log status
    diag_log format ["Current deployed aircraft count: %1", count HANGAR_deployedAircraft];
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
    };
};

// Update storage indices after a plane is deployed
HANGAR_fnc_updateStorageIndices = {
    params ["_deployedIndex"];
    
    // Update all deployed aircraft indices
    {
        if (!isNull _x) then {
            private _oldIndex = _x getVariable ["HANGAR_storageIndex", -1];
            if (_oldIndex > _deployedIndex) then {
                // Decrement index for all aircraft with higher indices
                _x setVariable ["HANGAR_storageIndex", _oldIndex - 1, true];
                diag_log format ["Updated aircraft index from %1 to %2", _oldIndex, _oldIndex - 1];
            };
        };
    } forEach HANGAR_deployedAircraft;
};

// Call this function a few seconds after initialization
[] spawn {
    sleep 3;
    [] call HANGAR_fnc_addSampleAircraft;
};