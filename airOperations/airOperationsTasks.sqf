// Air Operations Tasks
// Defines task types and behaviors for air missions
// REWRITTEN VERSION - ALL AI RESTRICTIONS REMOVED

// Function to force enable combat AI for aircraft crew
AIR_OP_fnc_enableCombatAI = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {false};
    
    // Apply to all crew members
    {
        if (_x getVariable ["HANGAR_isPilot", false]) then {
            // Enable ALL AI functions
            _x enableAI "ALL";
            _x enableAI "TARGET";
            _x enableAI "AUTOTARGET";
            _x enableAI "MOVE";
            _x enableAI "ANIM";
            _x enableAI "FSM";
            _x enableAI "PATH";
            _x enableAI "TEAMSWITCH";
            _x enableAI "COVER";
            _x enableAI "SUPPRESSION";
            _x enableAI "AIMINGERROR";
            _x enableAI "WEAPONAIM";
            
            // Set combat behavior
            _x setBehaviour "COMBAT";
            _x setCombatMode "RED";
            _x allowFleeing 0;
            _x setCaptive false;
            
            systemChat format ["Combat AI enabled for pilot: %1", name _x];
            diag_log format ["AIR_OPS TASK: Enabled combat AI for pilot: %1", name _x];
        };
    } forEach crew _aircraft;
    
    // Also set group behavior
    private _driver = driver _aircraft;
    if (!isNull _driver) then {
        private _group = group _driver;
        _group setBehaviour "COMBAT";
        _group setCombatMode "RED";
        _group allowFleeing 0;
    };
    
    true
};

// Function to get intel from air reconnaissance
AIR_OP_fnc_reconIntelGain = {
    params ["_aircraft", "_targetIndex", "_targetType"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS TASK: Cannot perform recon with null aircraft";
        false
    };
    
    // Force enable combat AI for aircraft
    [_aircraft] call AIR_OP_fnc_enableCombatAI;
    
    // Get aircraft details for potential bonuses
    private _aircraftDetails = [_aircraft] call AIR_OP_fnc_getAircraftDetails;
    private _specialization = _aircraftDetails select 2;
    
    // Base intel gain
    private _intelGain = 5;
    
    // Bonus for specialized recon aircraft
    if (_specialization == "Recon") then {
        _intelGain = _intelGain * 2;
    };
    
    // Apply intel gain to target
    if (_targetType == "LOCATION") then {
        if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
            [_targetIndex, _intelGain] call fnc_modifyLocationIntel;
            diag_log format ["AIR_OPS TASK: Recon gained %1 intel for location %2", _intelGain, _targetIndex];
            
            // Get location name for feedback
            private _locationName = (MISSION_LOCATIONS select _targetIndex) select 1;
            systemChat format ["Reconnaissance aircraft reporting intel on %1", _locationName];
        };
    } else {
        // HVT target
        if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
            [_targetIndex, _intelGain] call fnc_modifyHVTIntel;
            diag_log format ["AIR_OPS TASK: Recon gained %1 intel for HVT %2", _intelGain, _targetIndex];
            
            // Get HVT name for feedback
            private _hvtName = (HVT_TARGETS select _targetIndex) select 1;
            systemChat format ["Reconnaissance aircraft reporting intel on %1", _hvtName];
        };
    };
    
    true
};

// Function to perform area patrol
AIR_OP_fnc_performPatrol = {
    params ["_aircraft", "_targetIndex", "_targetType"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS TASK: Cannot perform patrol with null aircraft";
        false
    };
    
    // Force enable combat AI for aircraft
    [_aircraft] call AIR_OP_fnc_enableCombatAI;
    
    // Get target position
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
    
    if (_targetPos isEqualTo [0,0,0]) exitWith {
        diag_log "AIR_OPS TASK: Invalid target position for patrol";
        false
    };
    
    // Check for enemy air units in the area
    private _nearbyAir = _targetPos nearEntities ["Air", 1000];
    private _enemyAir = _nearbyAir select {side _x != side player && side _x != civilian};
    
    // If enemy air is detected, engage
    if (count _enemyAir > 0) then {
        private _driver = driver _aircraft;
        
        if (!isNull _driver) then {
            private _group = group _driver;
            
            // Clear existing waypoints
            while {count waypoints _group > 0} do {
                deleteWaypoint [_group, 0];
            };
            
            // Get closest enemy air
            private _enemy = _enemyAir select 0;
            
            // Create SAD waypoint
            private _wp = _group addWaypoint [getPos _enemy, 0];
            _wp setWaypointType "SAD";
            _wp setWaypointBehaviour "COMBAT";
            _wp setWaypointCombatMode "RED";
            
            // Notification
            systemChat format ["Patrol aircraft engaging enemy air units near %1", 
                if (_targetType == "LOCATION") then {
                    (MISSION_LOCATIONS select _targetIndex) select 1
                } else {
                    (HVT_TARGETS select _targetIndex) select 1
                }
            ];
            
            diag_log format ["AIR_OPS TASK: Patrol aircraft engaging %1 enemy air units", count _enemyAir];
        };
    } else {
        // Ordinary patrol - just gain some intel
        if (random 1 > 0.7) then { // 30% chance per check
            [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_reconIntelGain;
        };
    };
    
    true
};

// Function to perform close air support
AIR_OP_fnc_performCAS = {
    params ["_aircraft", "_targetIndex", "_targetType"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS TASK: Cannot perform CAS with null aircraft";
        false
    };
    
    // Force enable combat AI for aircraft
    [_aircraft] call AIR_OP_fnc_enableCombatAI;
    
    // Get target position
    private _targetPos = [0,0,0];
    private _targetName = "Unknown";
    
    if (_targetType == "LOCATION") then {
        if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
            _targetPos = (MISSION_LOCATIONS select _targetIndex) select 3;
            _targetName = (MISSION_LOCATIONS select _targetIndex) select 1;
        };
    } else {
        if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
            _targetPos = (HVT_TARGETS select _targetIndex) select 3;
            _targetName = (HVT_TARGETS select _targetIndex) select 1;
        };
    };
    
    if (_targetPos isEqualTo [0,0,0]) exitWith {
        diag_log "AIR_OPS TASK: Invalid target position for CAS";
        false
    };
            
            
   
    
    true
};

// Function to perform bombing run
AIR_OP_fnc_performBombing = {
    params ["_aircraft", "_targetIndex", "_targetType"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS TASK: Cannot perform bombing with null aircraft";
        false
    };
    
    // Force enable combat AI for aircraft
    [_aircraft] call AIR_OP_fnc_enableCombatAI;
    
    // Get target position
    private _targetPos = [0,0,0];
    private _targetName = "Unknown";
    
    if (_targetType == "LOCATION") then {
        if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
            _targetPos = (MISSION_LOCATIONS select _targetIndex) select 3;
            _targetName = (MISSION_LOCATIONS select _targetIndex) select 1;
        };
    } else {
        if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
            _targetPos = (HVT_TARGETS select _targetIndex) select 3;
            _targetName = (HVT_TARGETS select _targetIndex) select 1;
        };
    };
    
    if (_targetPos isEqualTo [0,0,0]) exitWith {
        diag_log "AIR_OPS TASK: Invalid target position for bombing";
        false
    };
    
    // Get aircraft details for potential bonuses
    private _aircraftDetails = [_aircraft] call AIR_OP_fnc_getAircraftDetails;
    private _specialization = _aircraftDetails select 2;
    
    // Get pilot skill for accuracy
    private _pilotSkill = 0.5; // Default skill
    
    // Try to find the pilot and get their rank
    {
        if (_x getVariable ["HANGAR_isPilot", false]) then {
            private _pilotIndex = _x getVariable ["HANGAR_pilotIndex", -1];
            
            if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
                private _pilotData = HANGAR_pilotRoster select _pilotIndex;
                private _rankIndex = _pilotData select 1;
                
                // Get skill multiplier from rank
                _pilotSkill = [_rankIndex] call HANGAR_fnc_getPilotSkillMultiplier;
                diag_log format ["AIR_OPS TASK: Bomber pilot skill: %1", _pilotSkill];
            };
        };
    } forEach crew _aircraft;
    
    // Set up bombing run
    private _driver = driver _aircraft;
    
    if (!isNull _driver) then {
        private _group = group _driver;
        
        // Clear existing waypoints
        while {count waypoints _group > 0} do {
            deleteWaypoint [_group, 0];
        };
        
        // Create approach waypoint
        private _approachDir = random 360;
        private _approachDist = 1500;
        private _approachPos = [
            (_targetPos select 0) + _approachDist * sin(_approachDir),
            (_targetPos select 1) + _approachDist * cos(_approachDir),
            300 // Set altitude
        ];
        
        private _wp1 = _group addWaypoint [_approachPos, 0];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointBehaviour "COMBAT"; // Changed from CARELESS to COMBAT
        _wp1 setWaypointSpeed "NORMAL";
        
        // Create target waypoint
        private _wp2 = _group addWaypoint [_targetPos, 0];
        _wp2 setWaypointType "DESTROY";
        _wp2 setWaypointBehaviour "COMBAT"; // Changed from CARELESS to COMBAT
        
        // Create exit waypoint
        private _exitPos = [
            (_targetPos select 0) + _approachDist * sin(_approachDir + 180),
            (_targetPos select 1) + _approachDist * cos(_approachDir + 180),
            300 // Set altitude
        ];
        
        private _wp3 = _group addWaypoint [_exitPos, 0];
        _wp3 setWaypointType "MOVE";
        _wp3 setWaypointBehaviour "COMBAT"; // Changed from AWARE to COMBAT
        
        // Notification
        systemChat format ["Bombing aircraft approaching %1", _targetName];
        
        // Schedule bombing effects
        [_targetPos, _specialization, _pilotSkill, _aircraft] spawn {
            params ["_pos", "_specialization", "_pilotSkill", "_aircraft"];
            
            sleep 5; // Wait for approach
            
            // Check if our aircraft still exists
            if (isNull _aircraft || !alive _aircraft) exitWith {};
            
            // Different bombing effects based on aircraft type
            // === GAMEPLAY VARIABLES - ADJUST BOMB COUNTS HERE ===
            private _bombCount = switch (_specialization) do {
                case "Bombers": { 8 }; // Heavy bombers drop more bombs
                case "Fighters": { 3 }; // Fighter-bombers drop fewer
                default { 5 }; // Default
            };
            
            // === GAMEPLAY VARIABLES - ADJUST ACCURACY SETTINGS HERE ===
            // Calculate accuracy based on pilot skill (higher skill = less spread)
            private _maxSpread = 120 - (60 * _pilotSkill); // Between 60-120m spread
            private _delay = 0.5 + random 0.5;
            
            // Create bombing effect
            for "_i" from 1 to _bombCount do {
                // Check if our aircraft still exists
                if (isNull _aircraft || !alive _aircraft) exitWith {};
                
                // Randomize position based on pilot skill
                private _bombPos = [
                    (_pos select 0) + (_maxSpread - random (_maxSpread * 2)),
                    (_pos select 1) + (_maxSpread - random (_maxSpread * 2)),
                    0
                ];
                
                // Create explosion
                "Bo_GBU12_LGB" createVehicle _bombPos;
                
                sleep _delay;
            };
            
            // Notification
            systemChat "Bombs away! Target area hit.";
            
            // For locations, chance to mark as destroyed
            if (random 1 > 0.5) then { // 50% chance
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
    
    true
};

// Function to perform air superiority mission
AIR_OP_fnc_performAirSup = {
    params ["_aircraft", "_targetIndex", "_targetType"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS TASK: Cannot perform air superiority with null aircraft";
        false
    };
    
    // Force enable combat AI for aircraft
    [_aircraft] call AIR_OP_fnc_enableCombatAI;
    
    // Similar to patrol but focuses specifically on enemy aircraft
    private _targetPos = [0,0,0];
    private _targetName = "Unknown";
    
    if (_targetType == "LOCATION") then {
        if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
            _targetPos = (MISSION_LOCATIONS select _targetIndex) select 3;
            _targetName = (MISSION_LOCATIONS select _targetIndex) select 1;
        };
    } else {
        if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
            _targetPos = (HVT_TARGETS select _targetIndex) select 3;
            _targetName = (HVT_TARGETS select _targetIndex) select 1;
        };
    };
    
    if (_targetPos isEqualTo [0,0,0]) exitWith {
        diag_log "AIR_OPS TASK: Invalid target position for air superiority";
        false
    };
    
    // === GAMEPLAY VARIABLES - ADJUST SEARCH RADIUS HERE ===
    private _searchRadius = 3000; // Larger radius for air superiority (meters)
    
    // Check for enemy air units in a larger area
    private _nearbyAir = _targetPos nearEntities ["Air", _searchRadius];
    private _enemyAir = _nearbyAir select {side _x != side player && side _x != civilian};
    
    if (count _enemyAir > 0) then {
        private _driver = driver _aircraft;
        
        if (!isNull _driver) then {
            private _group = group _driver;
            
            // Clear existing waypoints
            while {count waypoints _group > 0} do {
                deleteWaypoint [_group, 0];
            };
            
            // Sort enemies by distance
            _enemyAir = [_enemyAir, [], {_aircraft distance _x}, "ASCEND"] call BIS_fnc_sortBy;
            private _enemy = _enemyAir select 0;
            
            // Create SAD waypoint
            private _wp = _group addWaypoint [getPos _enemy, 0];
            _wp setWaypointType "SAD";
            _wp setWaypointBehaviour "COMBAT";
            _wp setWaypointCombatMode "RED";
            
            // Add a second waypoint to ensure continued hunting
            private _wp2 = _group addWaypoint [_targetPos, 0];
            _wp2 setWaypointType "SAD";
            _wp2 setWaypointBehaviour "COMBAT";
            _wp2 setWaypointCombatMode "RED";
            
            // Notification
            systemChat format ["Air superiority fighters engaging enemy aircraft near %1", _targetName];
            
            diag_log format ["AIR_OPS TASK: Air superiority engaging %1 enemy air units", count _enemyAir];
            
            // Schedule damage to enemy aircraft for visual feedback
            [_enemyAir, _aircraft] spawn {
                params ["_enemies", "_aircraft"];
                
                sleep 10; // Wait for engagement
                
                {
                    // Check if our aircraft still exists
                    if (isNull _aircraft || !alive _aircraft) exitWith {};
                    
                    // Only attack if aircraft is still on this task
                    if (!(_aircraft getVariable ["AIR_OP_onMission", true])) exitWith {};
                    
                    if (!isNull _x && alive _x) then {
                        // Damage effects
                        private _pos = getPos _x;
                        "HelicopterExploSmall" createVehicle _pos;
                        
                        // Apply damage
                        _x setHit ["engine", 0.5 + random 0.5];
                        
                        // Create tracer effect near target
                        for "_i" from 1 to 10 do {
                            private _tracerPos = [
                                (_pos select 0) + (5 - random 10),
                                (_pos select 1) + (5 - random 10),
                                (_pos select 2) + (2 - random 4)
                            ];
                            
                            drop [
                                ["\A3\data_f\cl_basic", 1, 0, 1], "", "Billboard", 
                                1, 0.5, _tracerPos, [0, 0, 0], 1, 0.001, 0.001, 0, 
                                [0.5], [[1, 0.5, 0.3, 1]], [0], 0, 0, "", "", ""
                            ];
                        };
                        
                        sleep (2 + random 3);
                    };
                } forEach _enemies;
            };
        };
    } else {
        // No enemies found, set up a patrol pattern with SAD
        private _driver = driver _aircraft;
        
        if (!isNull _driver) then {
            private _group = group _driver;
            
            // Clear existing waypoints
            while {count waypoints _group > 0} do {
                deleteWaypoint [_group, 0];
            };
            
            // Create a patrol pattern
            private _radius = _searchRadius * 0.5;
            private _angle = random 360;
            
            for "_i" from 0 to 3 do {
                private _wpPos = [
                    (_targetPos select 0) + _radius * sin(_angle + _i * 90),
                    (_targetPos select 1) + _radius * cos(_angle + _i * 90),
                    500 // Higher altitude for air superiority
                ];
                
                private _wp = _group addWaypoint [_wpPos, 0];
                _wp setWaypointType "SAD"; // Search and Destroy instead of MOVE
                _wp setWaypointBehaviour "COMBAT";
                _wp setWaypointCombatMode "RED";
                
                if (_i == 3) then {
                    _wp setWaypointType "CYCLE";
                };
            };
            
            // Notification
            systemChat format ["Air superiority fighters patrolling near %1 - no enemy aircraft detected", _targetName];
            
            diag_log "AIR_OPS TASK: Air superiority found no enemies, starting patrol pattern";
        };
    };
    
    true
};

// Function to execute a specific mission type
AIR_OP_fnc_executeMission = {
    params ["_missionType", "_aircraft", "_targetIndex", "_targetType"];
    
    if (isNull _aircraft) exitWith {
        diag_log format ["AIR_OPS TASK: Cannot execute mission %1 with null aircraft", _missionType];
        false
    };
    
    // Always enable combat AI for the aircraft regardless of mission
    [_aircraft] call AIR_OP_fnc_enableCombatAI;
    
    // Find active mission ID for this aircraft
    private _missionID = "";
    {
        if ((_x select 1) == _aircraft) exitWith {
            _missionID = _x select 0;
        };
    } forEach AIR_OP_activeMissions;
    
    // Skip if no active mission found
    if (_missionID == "") exitWith {
        diag_log "AIR_OPS TASK: No active mission found for aircraft";
        false
    };
    
    // Set the aircraft as being on mission
    _aircraft setVariable ["AIR_OP_onMission", true, true];
    
    // Execute appropriate mission function based on type
    switch (_missionType) do {
        case "recon": {
            // Set in-area status if not already set
            if (isNil {_aircraft getVariable "AIR_OP_inArea"}) then {
                _aircraft setVariable ["AIR_OP_inArea", false];
                _aircraft setVariable ["AIR_OP_inAreaTime", 0];
            };
            
            // Execute intelligence gathering effect
            [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_reconIntelGain;
        };
        
        case "patrol": {
            // Initialize patrol variables if needed
            if (isNil {_aircraft getVariable "AIR_OP_patrolCircuits"}) then {
                _aircraft setVariable ["AIR_OP_patrolCircuits", 0];
                _aircraft setVariable ["AIR_OP_lastWP", currentWaypoint (group driver _aircraft)];
            };
            
            // Execute patrol function
            [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_performPatrol;
        };
        
        case "cas": {
            // Initialize CAS variables
            if (isNil {_aircraft getVariable "AIR_OP_supportTime"}) then {
                _aircraft setVariable ["AIR_OP_inArea", false];
                _aircraft setVariable ["AIR_OP_supportTime", 0];
            };
            
            // Execute CAS function
            [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_performCAS;
        };
        
        case "bombing": {
            // Initialize bombing variables
            if (isNil {_aircraft getVariable "AIR_OP_bombsDropped"}) then {
                _aircraft setVariable ["AIR_OP_bombsDropped", false];
            };
            
            // Execute bombing function
            [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_performBombing;
        };
        
        case "airsup": {
            // Initialize air superiority variables
            if (isNil {_aircraft getVariable "AIR_OP_combatTime"}) then {
                _aircraft setVariable ["AIR_OP_inArea", false];
                _aircraft setVariable ["AIR_OP_combatTime", 0];
            };
            
            // Execute air superiority function
            [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_performAirSup;
        };
        
        default {
            diag_log format ["AIR_OPS TASK: Unknown mission type: %1", _missionType];
        };
    };
    
    true
};

// Add this emergency function to global scope for debug console use
AIR_OP_fnc_emergencyEnableAllPilots = {
    private _count = 0;
    
    // Enable AI for all pilots in all aircraft
    {
        if (_x isKindOf "Air") then {
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    // Enable ALL AI
                    _x enableAI "ALL";
                    _x enableAI "TARGET";
                    _x enableAI "AUTOTARGET"; 
                    _x enableAI "MOVE";
                    _x enableAI "FSM";
                    _x enableAI "PATH";
                    
                    // Set behavior
                    _x setBehaviour "COMBAT";
                    _x setCombatMode "RED";
                    _x allowFleeing 0;
                    _x setCaptive false;
                    
                    _count = _count + 1;
                    
                    // Set group behavior too
                    private _group = group _x;
                    if (!isNull _group) then {
                        _group setBehaviour "COMBAT";
                        _group setCombatMode "RED";
                    };
                };
            } forEach crew _x;
        };
    } forEach vehicles;
    
    systemChat format ["Emergency AI enablement applied to %1 pilots", _count];
    _count
};

// Add to mission namespace for easy access from debug console
missionNamespace setVariable ["enableAllAircraftAI", AIR_OP_fnc_emergencyEnableAllPilots, true];