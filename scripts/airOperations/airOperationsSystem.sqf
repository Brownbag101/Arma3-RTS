// Air Operations System
// Core functionality for air mission planning and execution

// Function to get all deployed aircraft
AIR_OP_fnc_getDeployedAircraft = {
    // Make sure the HANGAR system is initialized
    if (isNil "HANGAR_deployedAircraft") exitWith {
        systemChat "Aircraft hangar system not initialized";
        diag_log "AIR_OPS: Hangar system not initialized";
        []
    };
    
    // Filter out null objects and return the valid aircraft
    private _deployedAircraft = HANGAR_deployedAircraft select {!isNull _x};
    
    // Log count for debugging
    diag_log format ["AIR_OPS: Found %1 deployed aircraft", count _deployedAircraft];
    
    _deployedAircraft
};

// Function to get aircraft details (type, fuel, ammo, etc.)
AIR_OP_fnc_getAircraftDetails = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS: Cannot get details for null aircraft";
        []
    };
    
    // Get basic info
    private _type = typeOf _aircraft;
    private _displayName = getText (configFile >> "CfgVehicles" >> _type >> "displayName");
    private _fuel = fuel _aircraft;
    private _damage = damage _aircraft;
    
    // Get storage index if this is a hangar aircraft
    private _storageIndex = _aircraft getVariable ["HANGAR_storageIndex", -1];
    
    // Get aircraft specialization/category
    private _specialization = "Unknown";
    
    if (!isNil "HANGAR_fnc_determineAircraftCategory") then {
        _specialization = [_type] call HANGAR_fnc_determineAircraftCategory;
    } else {
        // Fallback detection if hangar function not available
        switch (true) do {
            case (_aircraft isKindOf "Plane_Fighter_01_base_F" || 
                  _aircraft isKindOf "Plane_Fighter_02_base_F" || 
                  _aircraft isKindOf "Plane_Fighter_03_base_F" || 
                  _aircraft isKindOf "Plane_Fighter_04_base_F" ||
                  _type find "spitfire" >= 0 || 
                  _type find "hurricane" >= 0): { _specialization = "Fighters"; };
            
            case (_aircraft isKindOf "Plane_CAS_01_base_F" || 
                  _aircraft isKindOf "Plane_CAS_02_base_F" ||
                  _type find "mosquito" >= 0): { _specialization = "Recon"; };
            
            case (_aircraft isKindOf "Plane_Bomber_01_base_F" || 
                  _aircraft isKindOf "Plane_Bomber_02_base_F" ||
                  _type find "lancaster" >= 0 || 
                  _type find "halifax" >= 0 || 
                  _type find "B17" >= 0): { _specialization = "Bombers"; };
            
            case (_aircraft isKindOf "Plane_Transport_01_base_F" || 
                  _aircraft isKindOf "Plane_Civil_01_base_F" ||
                  _type find "C47" >= 0 || 
                  _type find "Dakota" >= 0): { _specialization = "Transport"; };
        };
    };
    
    // Get weapons info
    private _weapons = weapons _aircraft;
    private _weaponsData = [];
    
    {
        private _weapon = _x;
        private _ammo = _aircraft ammo _weapon;
        private _maxAmmo = 1000; // Default
        
        // Try to get magazine info for max ammo
        private _weaponConfig = configFile >> "CfgWeapons" >> _weapon;
        if (isClass _weaponConfig) then {
            private _magazines = getArray (_weaponConfig >> "magazines");
            if (count _magazines > 0) then {
                private _magConfig = configFile >> "CfgMagazines" >> (_magazines select 0);
                if (isClass _magConfig) then {
                    _maxAmmo = getNumber (_magConfig >> "count");
                };
            };
        };
        
        // Only include actual weapons (not sensors, etc.)
        if (_weapon find "Cannon" >= 0 || _weapon find "Launcher" >= 0 || _weapon find "Gun" >= 0 ||
            _weapon find "LIB_" >= 0 || _weapon find "MG" >= 0 || _weapon find "BROWNING" >= 0) then {
            _weaponsData pushBack [_weapon, _ammo, _maxAmmo];
        };
    } forEach _weapons;
    
    // Get crew info
    private _crew = [];
    {
        private _crewMember = _x;
        private _role = _crewMember getVariable ["HANGAR_role", "Crew"];
        if (_crewMember getVariable ["HANGAR_isPilot", false]) then {
            _crew pushBack [name _crewMember, _role];
        };
    } forEach crew _aircraft;
    
    // Get current mission if any
    private _currentMission = "";
    private _missionIndex = AIR_OP_activeMissions findIf {(_x select 1) == _aircraft};
    if (_missionIndex != -1) then {
        private _missionData = AIR_OP_activeMissions select _missionIndex;
        _currentMission = _missionData select 2;
    };
    
    // Return compiled data
    [
        _type,              // [0] Aircraft type
        _displayName,       // [1] Display name
        _specialization,    // [2] Aircraft category/specialization
        _fuel,              // [3] Current fuel
        _damage,            // [4] Current damage
        _weaponsData,       // [5] Weapons and ammo
        _crew,              // [6] Crew members
        _currentMission,    // [7] Current mission
        _storageIndex       // [8] Storage index (if from hangar)
    ]
};

// Function to get available mission types for aircraft
AIR_OP_fnc_getAvailableMissions = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS: Cannot get missions for null aircraft";
        []
    };
    
    // Get aircraft details
    private _details = [_aircraft] call AIR_OP_fnc_getAircraftDetails;
    private _specialization = _details select 2;
    
    // Get missions available for this specialization
    private _availableMissions = [];
    {
        _x params ["_category", "_missions"];
        if (_category == _specialization) exitWith {
            _availableMissions = _missions;
        };
    } forEach AIR_OP_CAPABILITIES;
    
    // If specialization not found, return a default set
    if (count _availableMissions == 0) then {
        _availableMissions = ["recon"]; // Fallback - at least recon is available
    };
    
    // Return only the mission types that match our definition list
    private _validMissions = [];
    {
        private _missionType = _x;
        
        private _index = AIR_OP_MISSION_TYPES findIf {(_x select 0) == _missionType};
        if (_index != -1) then {
            _validMissions pushBack (AIR_OP_MISSION_TYPES select _index);
        };
    } forEach _availableMissions;
    
    _validMissions
};

// FIXED: Function to create a new air mission - Modified to avoid initial waypoint at target
AIR_OP_fnc_createMission = {
    params ["_aircraft", "_missionType", "_targetIndex", "_targetType"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS: Cannot create mission for null aircraft";
        ""
    };
    
    // Get mission parameters
    private _missionParams = [];
    {
        if (_x select 0 == _missionType) exitWith {
            _missionParams = _x;
        };
    } forEach AIR_OP_WAYPOINT_PARAMS;
    
    if (count _missionParams == 0) exitWith {
        diag_log format ["AIR_OPS: Mission type %1 not found in parameters", _missionType];
        ""
    };
    
    // Get target position based on target type
    private _targetPos = [0,0,0];
    private _targetName = "Unknown";
    
    if (_targetType == "LOCATION") then {
        if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
            private _locationData = MISSION_LOCATIONS select _targetIndex;
            _targetPos = _locationData select 3;
            _targetName = _locationData select 1;
        };
    } else {
        // HVT target
        if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
            private _hvtData = HVT_TARGETS select _targetIndex;
            _targetPos = _hvtData select 3;
            _targetName = _hvtData select 1;
        };
    };
    
    if (_targetPos isEqualTo [0,0,0]) exitWith {
        diag_log "AIR_OPS: Invalid target position";
        ""
    };
    
    // Create a unique mission ID
    private _missionID = format ["air_mission_%1_%2_%3", _missionType, _targetIndex, round(serverTime)];
    
    // Get the pilot/vehicle group
    private _driver = driver _aircraft;
    if (isNull _driver) exitWith {
        diag_log "AIR_OPS: No driver found for aircraft";
        ""
    };
    
    private _group = group _driver;
    if (isNull _group) exitWith {
        diag_log "AIR_OPS: No group found for aircraft driver";
        ""
    };
    
    // Clear existing waypoints
    while {count waypoints _group > 0} do {
        deleteWaypoint [_group, 0];
    };
    
    // Make sure engine is on and AI is enabled
    _aircraft engineOn true;
    {
        if (_x getVariable ["HANGAR_isPilot", false]) then {
            private _unit = _x;
            {
                _unit enableAI _x;
            } forEach ["MOVE", "ANIM", "FSM"];
            
            _unit setBehaviour "CARELESS";
            _unit setCombatMode "BLUE";
        };
    } forEach crew _aircraft;
    
    // *** CRITICAL FIX: DO NOT create a waypoint at the target position! ***
    // Instead, create a staging waypoint for the aircraft to position itself
    
    // Calculate a holding position 5km NORTH of the target
    private _holdingPos = [
        _targetPos select 0,  // Same X coordinate
        (_targetPos select 1) + 5000, // 5km NORTH of target
        300 // Altitude
    ];
    
    // Create a SINGLE holding waypoint instead of going directly to target
    private _wp = _group addWaypoint [_holdingPos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointBehaviour "CARELESS";
    _wp setWaypointCombatMode "BLUE";
    
    // Add a statement to notify when aircraft reaches holding position
    _wp setWaypointStatements ["true", "systemChat 'Aircraft has reached mission holding position'"];
    
    // Force aircraft altitude
    _aircraft flyInHeight 300;
    
    // Create mission object including completion code
    private _completionCode = compile "
params ['_missionData'];
_missionData params ['_missionID', '_aircraft', '_missionType', '_targetIndex', '_targetType', '_waypoint', '_startTime'];

if (isNull _aircraft) exitWith { false };

private _targetPos = [0,0,0];
if (_targetType == 'LOCATION') then {
    if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
        _targetPos = (MISSION_LOCATIONS select _targetIndex) select 3;
    };
} else {
    if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
        _targetPos = (HVT_TARGETS select _targetIndex) select 3;
    };
};

private _missionTime = serverTime - _startTime;
private _timeComplete = false;

private _completionTime = switch (_missionType) do {
    case 'recon': { 180 };
    case 'patrol': { 300 };
    case 'cas': { 300 };
    case 'bombing': { 180 };
    case 'airsup': { 300 };
    default { 240 };
};

if (_missionTime >= _completionTime) then {
    _timeComplete = true;
};

private _driver = driver _aircraft;
private _group = group _driver;

private _missionComplete = false;

switch (_missionType) do {
    case 'recon': {
        private _inArea = _aircraft distance _targetPos < 300;
        private _areaTime = _aircraft getVariable ['AIR_OP_inAreaTime', 0];
        
        if (_inArea) then {
            if (_aircraft getVariable ['AIR_OP_inArea', false]) then {
                _aircraft setVariable ['AIR_OP_inAreaTime', _areaTime + 2];
            } else {
                _aircraft setVariable ['AIR_OP_inArea', true];
                _aircraft setVariable ['AIR_OP_inAreaTime', 0];
            };
        } else {
            _aircraft setVariable ['AIR_OP_inArea', false];
        };
        
        if ((_aircraft getVariable ['AIR_OP_inAreaTime', 0] >= 60) || _timeComplete) then {
            if (_targetType == 'LOCATION') then {
                if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
                    [_targetIndex, 25] call fnc_modifyLocationIntel;
                };
            } else if (_targetType == 'HVT') then {
                if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
                    [_targetIndex, 25] call fnc_modifyHVTIntel;
                };
            };
            
            _missionComplete = true;
        };
    };
    
    case 'patrol': {
        private _inArea = _aircraft distance _targetPos < 600;
        private _patrolCircuits = _aircraft getVariable ['AIR_OP_patrolCircuits', 0];
        private _lastWP = _aircraft getVariable ['AIR_OP_lastWP', -1];
        private _currentWP = currentWaypoint _group;
        
        private _enemiesInArea = false;
        private _nearbyAir = _targetPos nearEntities ['Air', 1000];
        private _enemyAir = _nearbyAir select {side _x != side player && side _x != civilian};
        if (count _enemyAir > 0) then {
            _enemiesInArea = true;
        };
        
        if (_inArea && _currentWP != _lastWP) then {
            _aircraft setVariable ['AIR_OP_lastWP', _currentWP];
            
            if (_currentWP == 1 && _lastWP > 1) then {
                _patrolCircuits = _patrolCircuits + 1;
                _aircraft setVariable ['AIR_OP_patrolCircuits', _patrolCircuits];
                systemChat format ['Patrol circuit completed (%1)', _patrolCircuits];
            };
        };
        
        if ((_patrolCircuits >= 3) || 
            (_patrolCircuits >= 1 && !_enemiesInArea) || 
            (_timeComplete && _patrolCircuits >= 1)) then {
            _missionComplete = true;
        };
    };
    
    case 'cas': {
        // For CAS, consider it complete when aircraft has reached the holding position
        // and has been there for a minute, or when timeout is reached
        
        private _holdingPosReached = _aircraft getVariable ['AIR_OP_holdingPosReached', false];
        private _holdingTime = _aircraft getVariable ['AIR_OP_holdingTime', 0];
        
        if (_holdingPosReached) then {
            _holdingTime = _holdingTime + 2;
            _aircraft setVariable ['AIR_OP_holdingTime', _holdingTime];
        } else {
            // Check if we're at the holding position
            private _holdingPos = [_targetPos select 0, (_targetPos select 1) + 5000, 0];
            if (_aircraft distance _holdingPos < 300) then {
                _aircraft setVariable ['AIR_OP_holdingPosReached', true];
                _aircraft setVariable ['AIR_OP_holdingTime', 0];
                systemChat 'Aircraft has reached CAS holding position';
            };
        };
        
        if (_holdingTime > 60 || _timeComplete) then {
            _missionComplete = true;
        };
    };
    
    case 'bombing': {
        // For bombing, similar to CAS - consider complete when aircraft has reached holding position
        private _holdingPosReached = _aircraft getVariable ['AIR_OP_holdingPosReached', false];
        private _holdingTime = _aircraft getVariable ['AIR_OP_holdingTime', 0];
        
        if (_holdingPosReached) then {
            _holdingTime = _holdingTime + 2;
            _aircraft setVariable ['AIR_OP_holdingTime', _holdingTime];
        } else {
            // Check if we're at the holding position
            private _holdingPos = [_targetPos select 0, (_targetPos select 1) + 5000, 0];
            if (_aircraft distance _holdingPos < 300) then {
                _aircraft setVariable ['AIR_OP_holdingPosReached', true];
                _aircraft setVariable ['AIR_OP_holdingTime', 0];
                systemChat 'Aircraft has reached bombing holding position';
            };
        };
        
        if (_holdingTime > 60 || _timeComplete) then {
            _missionComplete = true;
        };
    };
    
    case 'airsup': {
        private _inArea = _aircraft distance _targetPos < 1000;
        private _combatTime = _aircraft getVariable ['AIR_OP_combatTime', 0];
        
        private _nearbyAir = _targetPos nearEntities ['Air', 2000];
        private _enemyAir = _nearbyAir select {side _x != side player && side _x != civilian};
        
        if (_inArea) then {
            if (_aircraft getVariable ['AIR_OP_inArea', false]) then {
                _aircraft setVariable ['AIR_OP_combatTime', _combatTime + 2];
            } else {
                _aircraft setVariable ['AIR_OP_inArea', true];
                _aircraft setVariable ['AIR_OP_combatTime', 0];
            };
        } else {
            _aircraft setVariable ['AIR_OP_inArea', false];
        };
        
        if ((count _enemyAir == 0 && _combatTime > 30) || 
            (_combatTime >= 240) || 
            (_timeComplete && _combatTime > 60)) then {
            _missionComplete = true;
        };
    };
    
    default {
        _missionComplete = _timeComplete;
    };
};

_missionComplete
";
    
    // Create the mission data object
    private _missionData = [
        _missionID,        // Mission ID
        _aircraft,         // Aircraft object
        _missionType,      // Mission type
        _targetIndex,      // Target index
        _targetType,       // Target type (LOCATION or HVT)
        _wp,               // Waypoint
        serverTime,        // Start time
        _completionCode    // Completion code
    ];
    
    // Add to active missions
    AIR_OP_activeMissions pushBack _missionData;
    
    // Create marker for mission
    private _markerName = format ["air_mission_marker_%1", _missionID];
    private _marker = createMarker [_markerName, _targetPos];
    
    // Set marker properties based on mission type
    switch (_missionType) do {
        case "recon": {
            _marker setMarkerType "hd_dot";
            _marker setMarkerColor "ColorBlue";
        };
        case "patrol": {
            _marker setMarkerType "hd_dot";
            _marker setMarkerColor "ColorBlue";
        };
        case "cas": {
            _marker setMarkerType "hd_objective";
            _marker setMarkerColor "ColorRed";
        };
        case "bombing": {
            _marker setMarkerType "hd_destroy";
            _marker setMarkerColor "ColorRed";
        };
        case "airsup": {
            _marker setMarkerType "hd_warning";
            _marker setMarkerColor "ColorBlue";
        };
    };
    
    _marker setMarkerText format ["%1: %2", toUpper _missionType, _targetName];
    
    // Add marker to mission data for cleanup
    _missionData pushBack _markerName;
    
    // Initialize mission-specific variables based on type
    switch (_missionType) do {
        case "recon": {
            _aircraft setVariable ["AIR_OP_inArea", false];
            _aircraft setVariable ["AIR_OP_inAreaTime", 0];
        };
        case "patrol": {
            _aircraft setVariable ["AIR_OP_patrolCircuits", 0];
            _aircraft setVariable ["AIR_OP_lastWP", currentWaypoint _group];
        };
        case "cas": {
            // Initialize holding position variables
            _aircraft setVariable ["AIR_OP_holdingPosReached", false];
            _aircraft setVariable ["AIR_OP_holdingTime", 0];
            _aircraft setVariable ["AIR_OP_inArea", false];
        };
        case "bombing": {
            // Initialize holding position variables
            _aircraft setVariable ["AIR_OP_holdingPosReached", false];
            _aircraft setVariable ["AIR_OP_holdingTime", 0];
        };
        case "airsup": {
            _aircraft setVariable ["AIR_OP_inArea", false];
            _aircraft setVariable ["AIR_OP_combatTime", 0];
        };
    };
    
    // Provide feedback
    private _missionDisplayName = "";
    {
        if (_x select 0 == _missionType) exitWith {
            _missionDisplayName = _x select 1;
        };
    } forEach AIR_OP_MISSION_TYPES;
    
    systemChat format ["%1 assigned to %2 mission at %3", getText(configFile >> "CfgVehicles" >> typeOf _aircraft >> "displayName"), _missionDisplayName, _targetName];
    
    // Return mission ID
    _missionID
};
// Function to check mission completion - COMPLETE FIXED VERSION
AIR_OP_fnc_checkMissions = {
    private _completedMissions = [];
    
    {
        private _missionData = _x;
        
        // Skip invalid data
        if (count _missionData < 8) then {
            continue;
        };
        
        // Extract mission info
        _missionData params ["_missionID", "_aircraft", "_missionType", "_targetIndex", "_targetType", "_waypoint", "_startTime", "_completionCode"];
        
        // Check if aircraft still exists
        if (isNull _aircraft) then {
            _completedMissions pushBack [_missionID, false];
            continue;
        };
        
        // Check if mission is complete using completion code
        private _isComplete = false;
        
        try {
            // Try to call the completion code directly with error handling
            _isComplete = [_missionData] call _completionCode;
            
            // Check if it returned a proper value
            if (isNil "_isComplete") then {
                diag_log format ["AIR_OPS: Completion code for mission %1 returned nil", _missionID];
                _isComplete = false;
            };
            
            if (typeName _isComplete != "BOOL") then {
                diag_log format ["AIR_OPS: Completion code for mission %1 returned non-boolean: %2", _missionID, _isComplete];
                _isComplete = false;
            };
        } catch {
            diag_log format ["AIR_OPS: Error executing completion code for mission %1: %2", _missionID, _exception];
            _isComplete = false;
        };
        
        // If complete, add to the list
        if (_isComplete) then {
            diag_log format ["AIR_OPS: Mission %1 (%2) completion detected!", _missionID, _missionType];
            _completedMissions pushBack [_missionID, true]; // Mark for success
        };
    } forEach AIR_OP_activeMissions;
    
    // Process completed missions
    {
        _x params ["_missionID", "_success"];
        [_missionID, _success] call AIR_OP_fnc_completeMission;
    } forEach _completedMissions;
};

// Function to complete a mission
AIR_OP_fnc_completeMission = {
    params ["_missionID", "_success"];
    
    // Find mission in active missions
    private _missionIndex = -1;
    {
        if (_x select 0 == _missionID) exitWith {
            _missionIndex = _forEachIndex;
        };
    } forEach AIR_OP_activeMissions;
    
    if (_missionIndex == -1) exitWith {
        diag_log format ["AIR_OPS: Mission %1 not found for completion", _missionID];
        false
    };
    
    private _missionData = AIR_OP_activeMissions select _missionIndex;
    _missionData params ["_id", "_aircraft", "_missionType", "_targetIndex", "_targetType"];
    
    // Delete marker if it exists
    if (count _missionData > 8) then {
        private _markerName = _missionData select 8;
        if (markerType _markerName != "") then {
            deleteMarker _markerName;
        };
    };
    
    // Find target name for feedback
    private _targetName = "Unknown";
    
    if (_targetType == "LOCATION") then {
        if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
            _targetName = (MISSION_LOCATIONS select _targetIndex) select 1;
        };
    } else {
        // HVT target
        if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
            _targetName = (HVT_TARGETS select _targetIndex) select 1;
        };
    };
    
    // Find mission display name
    private _missionDisplayName = "";
    {
        if (_x select 0 == _missionType) exitWith {
            _missionDisplayName = _x select 1;
        };
    } forEach AIR_OP_MISSION_TYPES;
    
    // Provide feedback based on success
    if (_success) then {
        // Apply mission-specific rewards or effects here
        
        // Notification
        systemChat format ["%1 mission at %2 completed successfully", _missionDisplayName, _targetName];
        
        // For recon missions, provide feedback about intel gained
        if (_missionType == "recon") then {
            hint format ["Intelligence gathering at %1 complete.\nTarget data updated.", _targetName];
        };
        
        // For bombing missions, damage any nearby objects
        if (_missionType == "bombing") then {
            // Find target position
            private _targetPos = [0,0,0];
            
            if (_targetType == "LOCATION") then {
                if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
                    _targetPos = (MISSION_LOCATIONS select _targetIndex) select 3;
                };
            } else {
                if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
                    _targetPos = (HVT_TARGETS select _targetIndex) select 3;
                };
            };
            
            // Apply damage to nearby objects
            if (_targetPos distance [0,0,0] > 10) then {
                private _objsToExplode = _targetPos nearObjects ["House", 100];
                _objsToExplode = _objsToExplode + (_targetPos nearObjects ["Car", 100]);
                _objsToExplode = _objsToExplode + (_targetPos nearObjects ["Tank", 100]);
                
                // Apply explosion effects
                if (count _objsToExplode > 0) then {
                    [_targetPos, _objsToExplode] spawn {
                        params ["_pos", "_objects"];
                        
                        // Create bomb explosion
                        "Bo_GBU12_LGB" createVehicle _pos;
                        
                        sleep 0.5;
                        
                        // Damage nearby objects
                        {
                            if (damage _x < 0.9) then {
                                _x setDamage (damage _x + 0.5);
                            };
                        } forEach _objects;
                        
                        sleep 1;
                        
                        // Secondary explosion
                        "Bo_GBU12_LGB" createVehicle [(_pos select 0) + 15, (_pos select 1) + 15, 0];
                        
                        // For locations, set as destroyed if bombing successful
                        if (_pos distance [0,0,0] > 10) then {
                            // Try to find location reference
                            private _locIndex = -1;
                            private _minDist = 1000;
                            
                            {
                                private _locPos = _x select 3;
                                private _dist = _pos distance _locPos;
                                
                                if (_dist < _minDist && _dist < 200) then {
                                    _minDist = _dist;
                                    _locIndex = _forEachIndex;
                                };
                            } forEach MISSION_LOCATIONS;
                            
                            if (_locIndex != -1) then {
                                // Set location as destroyed
                                [_locIndex] call fnc_handleLocationDestruction;
                            };
                        };
                    };
                };
            };
        };
    } else {
        systemChat format ["%1 mission at %2 failed or aborted", _missionDisplayName, _targetName];
    };
    
    // Remove from active missions
    AIR_OP_activeMissions deleteAt _missionIndex;
    
    // If aircraft still exists, start RTB or loiter waypoint
		if (!isNull _aircraft) then {
			private _currentAircraft = _aircraft; // Store local reference for spawn
			[_currentAircraft] spawn {
				params ["_aircraft"]; // Get aircraft in spawned context
				
				// Get the group safely
				private _group = grpNull;
				private _driver = driver _aircraft;
				
				if (!isNull _driver) then {
					_group = group _driver;
				};
				
				if (!isNull _group) then {
					// Clear existing waypoints
					while {count waypoints _group > 0} do {
						deleteWaypoint [_group, 0];
					};
					
					// Look for loiter marker
					private _loiterPos = if (markerType "air_loiter" != "") then {
						getMarkerPos "air_loiter"
					} else {
						getPos _aircraft
					};
					
					// Add loiter waypoint
					private _wp = _group addWaypoint [_loiterPos, 0];
					_wp setWaypointType "LOITER";
					_wp setWaypointLoiterType "CIRCLE_L";
					_wp setWaypointLoiterRadius 800;
					_wp setWaypointSpeed "NORMAL";
				};
			};
		};
    
    true
};

// Function to get all available targets
AIR_OP_fnc_getAvailableTargets = {
    params ["_targetType", "_requiredIntel"];
    
    private _targets = [];
    
    if (_targetType == "LOCATION") then {
        // Filter locations based on intel level
        {
            private _locationData = _x;
            private _intel = _locationData select 4;
            
            if (_intel >= _requiredIntel) then {
                _targets pushBack [_forEachIndex, _locationData select 1, _locationData select 2, _locationData select 3, _intel];
            };
        } forEach MISSION_LOCATIONS;
    } else {
        // Filter HVTs based on intel level
        {
            private _hvtData = _x;
            private _intel = _hvtData select 4;
            
            if (_intel >= _requiredIntel) then {
                _targets pushBack [_forEachIndex, _hvtData select 1, _hvtData select 2, _hvtData select 3, _intel];
            };
        } forEach HVT_TARGETS;
    };
    
    _targets
};

// Function to cancel active mission for an aircraft
AIR_OP_fnc_cancelMission = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS: Cannot cancel mission for null aircraft";
        false
    };
    
    // Find mission for this aircraft
    private _missionIndex = AIR_OP_activeMissions findIf {(_x select 1) == _aircraft};
    
    if (_missionIndex == -1) exitWith {
        diag_log "AIR_OPS: No active mission found for aircraft";
        false
    };
    
    private _missionData = AIR_OP_activeMissions select _missionIndex;
    private _missionID = _missionData select 0;
    
    // Complete the mission as unsuccessful
    [_missionID, false] call AIR_OP_fnc_completeMission;
    
    systemChat "Mission cancelled. Aircraft returning to default posture.";
    true
};