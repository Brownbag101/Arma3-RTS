// Air Operations Tasks
// Defines task types and behaviors for air missions

// Function to get intel from air reconnaissance
AIR_OP_fnc_reconIntelGain = {
    params ["_aircraft", "_targetIndex", "_targetType"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS TASK: Cannot perform recon with null aircraft";
        false
    };
    
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
    
    // Check for enemy ground units in the area
    private _nearbyGround = _targetPos nearEntities [["Man", "Car", "Tank"], 500];
    private _enemyGround = _nearbyGround select {side _x != side player && side _x != civilian};
    
    // If enemy ground units are detected, engage
    if (count _enemyGround > 0) then {
        private _driver = driver _aircraft;
        
        if (!isNull _driver) then {
            private _group = group _driver;
            
            // Clear existing waypoints
            while {count waypoints _group > 0} do {
                deleteWaypoint [_group, 0];
            };
            
            // Get random enemy ground unit
            private _enemy = selectRandom _enemyGround;
            
            // Create attack waypoint
            private _wp = _group addWaypoint [getPos _enemy, 0];
            _wp setWaypointType "DESTROY";
            _wp setWaypointBehaviour "COMBAT";
            _wp setWaypointCombatMode "RED";
            
            // Notification
            systemChat format ["CAS aircraft engaging %1 enemy units near %2", count _enemyGround, _targetName];
            
            diag_log format ["AIR_OPS TASK: CAS aircraft engaging %1 enemy ground units", count _enemyGround];
            
            // After a delay, apply damage to some random enemy units to simulate air attack
            [_enemyGround] spawn {
                params ["_enemies"];
                
                sleep 5; // Wait for aircraft to approach
                
                private _attackCount = (count _enemies) min 5; // Attack up to 5 targets
                
                for "_i" from 1 to _attackCount do {
                    private _target = selectRandom _enemies;
                    
                    if (!isNull _target && alive _target) then {
                        // Create attack effects
                        private _pos = getPos _target;
                        "SmallSecondary" createVehicle _pos;
                        
                        // Apply damage
                        _target setDamage ((damage _target) + 0.3 + random 0.7);
                        
                        sleep (1 + random 2); // Random delay between attacks
                    };
                };
            };
        };
    } else {
        // No enemies found, cycle the area
        private _driver = driver _aircraft;
        
        if (!isNull _driver) then {
            private _group = group _driver;
            
            // Clear existing waypoints
            while {count waypoints _group > 0} do {
                deleteWaypoint [_group, 0];
            };
            
            // Create a search pattern
            private _radius = 500;
            private _angle = random 360;
            
            for "_i" from 0 to 3 do {
                private _wpPos = [
                    (_targetPos select 0) + _radius * sin(_angle + _i * 90),
                    (_targetPos select 1) + _radius * cos(_angle + _i * 90),
                    0
                ];
                
                private _wp = _group addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointBehaviour "COMBAT";
                _wp setWaypointSpeed "NORMAL";
                
                if (_i == 3) then {
                    _wp setWaypointType "CYCLE";
                };
            };
            
            // Notification
            systemChat format ["CAS aircraft patrolling near %1 - no enemy units detected", _targetName];
            
            diag_log "AIR_OPS TASK: CAS found no enemies, starting search pattern";
        };
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
        private _approachDist = 1000;
        private _approachPos = [
            (_targetPos select 0) + _approachDist * sin(_approachDir),
            (_targetPos select 1) + _approachDist * cos(_approachDir),
            300 // Set altitude
        ];
        
        private _wp1 = _group addWaypoint [_approachPos, 0];
        _wp1 setWaypointType "MOVE";
        _wp1 setWaypointBehaviour "CARELESS";
        _wp1 setWaypointSpeed "NORMAL";
        
        // Create target waypoint
        private _wp2 = _group addWaypoint [_targetPos, 0];
        _wp2 setWaypointType "DESTROY";
        _wp2 setWaypointBehaviour "CARELESS";
        
        // Create exit waypoint
        private _exitPos = [
            (_targetPos select 0) + _approachDist * sin(_approachDir + 180),
            (_targetPos select 1) + _approachDist * cos(_approachDir + 180),
            300 // Set altitude
        ];
        
        private _wp3 = _group addWaypoint [_exitPos, 0];
        _wp3 setWaypointType "MOVE";
        _wp3 setWaypointBehaviour "AWARE";
        
        // Notification
        systemChat format ["Bombing aircraft approaching %1", _targetName];
        
        // Schedule bombing effects
        [_targetPos, _specialization] spawn {
            params ["_pos", "_specialization"];
            
            sleep 5; // Wait for approach
            
            // Different bombing effects based on aircraft type
            private _bombCount = switch (_specialization) do {
                case "Bombers": { 5 }; // Heavy bombers drop more bombs
                case "Fighters": { 2 }; // Fighter-bombers drop fewer
                default { 3 }; // Default
            };
            
            // Create bombing effect
            for "_i" from 1 to _bombCount do {
                // Randomize position slightly
                private _bombPos = [
                    (_pos select 0) + (20 - random 40),
                    (_pos select 1) + (20 - random 40),
                    0
                ];
                
                // Create explosion
                "Bo_GBU12_LGB" createVehicle _bombPos;
                
                
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
    
    // Check for enemy air units in a larger area
    private _nearbyAir = _targetPos nearEntities ["Air", 2000];
    private _enemyAir = _nearbyAir select {side _x != side player && side _x != civilian};
    
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
            systemChat format ["Air superiority fighters engaging enemy aircraft near %1", _targetName];
            
            diag_log format ["AIR_OPS TASK: Air superiority engaging %1 enemy air units", count _enemyAir];
            
            // Schedule damage to enemy aircraft for visual feedback
            [_enemyAir] spawn {
                params ["_enemies"];
                
                sleep 10; // Wait for engagement
                
                {
                    if (!isNull _x && alive _x) then {
                        // Damage effects
                        private _pos = getPos _x;
                        "HelicopterExploSmall" createVehicle _pos;
                        
                        // Apply damage
                        _x setHit ["engine", 0.5 + random 0.5];
                        
                        sleep (2 + random 3);
                    };
                } forEach _enemies;
            };
        };
    } else {
        // No enemies found, set up a patrol pattern
        private _driver = driver _aircraft;
        
        if (!isNull _driver) then {
            private _group = group _driver;
            
            // Clear existing waypoints
            while {count waypoints _group > 0} do {
                deleteWaypoint [_group, 0];
            };
            
            // Create a patrol pattern
            private _radius = 1000;
            private _angle = random 360;
            
            for "_i" from 0 to 3 do {
                private _wpPos = [
                    (_targetPos select 0) + _radius * sin(_angle + _i * 90),
                    (_targetPos select 1) + _radius * cos(_angle + _i * 90),
                    500 // Higher altitude for air superiority
                ];
                
                private _wp = _group addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointBehaviour "COMBAT";
                _wp setWaypointSpeed "NORMAL";
                
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
    
    // Set the correct status variable on aircraft based on mission type
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
            
            // CAS function already called from completion code
        };
        
        case "bombing": {
            // Initialize bombing variables
            if (isNil {_aircraft getVariable "AIR_OP_bombsDropped"}) then {
                _aircraft setVariable ["AIR_OP_bombsDropped", false];
            };
            
            // Bombing function already called from completion code
        };
        
        case "airsup": {
            // Initialize air superiority variables
            if (isNil {_aircraft getVariable "AIR_OP_combatTime"}) then {
                _aircraft setVariable ["AIR_OP_inArea", false];
                _aircraft setVariable ["AIR_OP_combatTime", 0];
            };
            
            // Air superiority function already called from completion code
        };
        
        default {
            diag_log format ["AIR_OPS TASK: Unknown mission type: %1", _missionType];
        };
    };
    
    true
};