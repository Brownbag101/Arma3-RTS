// Air Operations Tasks
// Defines task types and behaviors for air missions
// ENHANCED VERSION WITH IMPROVED COMBAT FUNCTIONS

// === GAMEPLAY VARIABLES - MISSION PARAMETERS ===
// Adjust these values to modify mission behavior
AIR_OP_CAS_DETECTION_RADIUS = 1000;      // How far to look for targets during CAS (meters)
AIR_OP_BOMBING_BOMBS_PER_RUN = 8;       // Number of bombs dropped per bombing mission
AIR_OP_RECON_INTEL_GAIN = 10;           // Intel gained from reconnaissance missions
AIR_OP_AIRSUP_DETECTION_RADIUS = 3000;  // Air superiority search radius (meters)
AIR_OP_PATROL_RADIUS = 1000;            // Patrol circuit radius (meters)



// Function to disable combat AI and set passive behavior
AIR_OP_fnc_disableCombatAI = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS TASK: Cannot disable combat AI for null aircraft";
        false
    };
    
    // Apply to all crew members
    {
        if (_x getVariable ["HANGAR_isPilot", false]) then {
            // Keep essential AI enabled
            _x enableAI "MOVE";
            _x enableAI "PATH";
            _x enableAI "FSM";
            
            // Disable combat-related AI functions
            _x disableAI "TARGET";
            _x disableAI "AUTOTARGET";
            _x disableAI "SUPPRESSION";
            _x disableAI "COVER";
            
            // Set passive behavior
            _x setBehaviour "CARELESS";
            _x setCombatMode "BLUE";
            _x allowFleeing 0;
            
            systemChat format ["Combat AI disabled for pilot: %1", name _x];
            diag_log format ["AIR_OPS TASK: Disabled combat AI for pilot: %1", name _x];
        };
    } forEach crew _aircraft;
    
    // Also set group behavior
    private _driver = driver _aircraft;
    if (!isNull _driver) then {
        private _group = group _driver;
        _group setBehaviour "CARELESS";
        _group setCombatMode "BLUE";
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
    
    // Base intel gain from gameplay variable
    private _intelGain = AIR_OP_RECON_INTEL_GAIN;
    
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
    private _nearbyAir = _targetPos nearEntities ["Air", AIR_OP_PATROL_RADIUS];
    private _enemyAir = _nearbyAir select {side _x != side player && side _x != civilian};
    
    // Check for enemy ground units
    private _nearbyGround = _targetPos nearEntities [["Man", "Car", "Tank"], AIR_OP_PATROL_RADIUS];
    private _enemyGround = _nearbyGround select {side _x != side player && side _x != civilian};
    
    // Check for enemy naval units
    private _nearbyNaval = _targetPos nearEntities [["Ship", "Boat"], AIR_OP_PATROL_RADIUS];
    private _enemyNaval = _nearbyNaval select {side _x != side player && side _x != civilian};
    
    // Combine all enemy targets
    private _allEnemies = _enemyAir + _enemyGround + _enemyNaval;
    
    // If enemies are detected, engage
    if (count _allEnemies > 0) then {
        private _driver = driver _aircraft;
        
        if (!isNull _driver) then {
            private _group = group _driver;
            
            // Clear existing waypoints
            while {count waypoints _group > 0} do {
                deleteWaypoint [_group, 0];
            };
            
            // Get closest enemy
            _allEnemies = [_allEnemies, [], {_aircraft distance _x}, "ASCEND"] call BIS_fnc_sortBy;
            private _enemy = _allEnemies select 0;
            
            // Create SAD waypoint
            private _wp = _group addWaypoint [getPos _enemy, 0];
            _wp setWaypointType "SAD";
            _wp setWaypointBehaviour "COMBAT";
            _wp setWaypointCombatMode "RED";
            
            // Notification
            systemChat format ["Patrol aircraft engaging enemies near %1", 
                if (_targetType == "LOCATION") then {
                    (MISSION_LOCATIONS select _targetIndex) select 1
                } else {
                    (HVT_TARGETS select _targetIndex) select 1
                }
            ];
            
            diag_log format ["AIR_OPS TASK: Patrol aircraft engaging %1 enemies", count _allEnemies];
            
            // Force reveal of targets to the group
            {
                _group reveal [_x, 4];
            } forEach _allEnemies;
        };
    } else {
        // No enemies - create a patrol pattern around the target
        private _driver = driver _aircraft;
        
        if (!isNull _driver) then {
            private _group = group _driver;
            private _waypointCount = count waypoints _group;
            
            // Only create new waypoints if we don't have enough
            if (_waypointCount <= 1) then {
                // Clear existing waypoints
                while {count waypoints _group > 0} do {
                    deleteWaypoint [_group, 0];
                };
                
                // Create a patrol circle around the target
                private _radius = AIR_OP_PATROL_RADIUS;
                private _altitude = 300 + (random 200); // Random altitude between 300-500m
                
                for "_i" from 0 to 3 do {
                    private _angle = _i * 90;
                    private _wpPos = [
                        (_targetPos select 0) + (_radius * sin(_angle)),
                        (_targetPos select 1) + (_radius * cos(_angle)),
                        _altitude
                    ];
                    
                    private _wp = _group addWaypoint [_wpPos, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointBehaviour "AWARE";
                    _wp setWaypointCombatMode "YELLOW";
                    _wp setWaypointSpeed "NORMAL";
                    
                    if (_i == 3) then {
                        _wp setWaypointType "CYCLE";
                    };
                };
                
                diag_log "AIR_OPS TASK: Created patrol pattern waypoints";
            };
        };
        
        // Ordinary patrol - just gain some intel if we're in the area
        if (_aircraft distance _targetPos < 500) then {
            if (random 1 > 0.7) then { // 30% chance per check
                [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_reconIntelGain;
            };
        };
    };
    
    true
};

// REPLACEMENT FOR THE CAS SECTION IN airOperationsTasks.sqf
// Find the AIR_OP_fnc_performCAS function and replace it with this version

// === GAMEPLAY VARIABLES - ATTACK PARAMETERS ===
AIR_OP_ATTACK_DISTANCE = 400;      // Distance to target when weapons fire (meters)
AIR_OP_ATTACK_ALTITUDE = 300;      // Approach altitude for attack run (meters)
AIR_OP_DIVE_ANGLE = 20;           // Steepness of attack dive (degrees)

// COMPLETELY REWRITTEN: Function to perform close air support with proper attack profile
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
    
    // Detect all possible targets around the target area
    private _searchRadius = AIR_OP_CAS_DETECTION_RADIUS;
    
    // Land targets
    private _nearbyGround = _targetPos nearEntities [["Man", "Car", "Tank", "Static"], _searchRadius];
    private _enemyGround = _nearbyGround select {side _x != side player && side _x != civilian};
    
    // Sea targets
    private _nearbyNaval = _targetPos nearEntities [["Ship", "Boat"], _searchRadius];
    private _enemyNaval = _nearbyNaval select {side _x != side player && side _x != civilian};
    
    // Combine targets
    private _allEnemies = _enemyGround + _enemyNaval;
    
    // Set up CAS run if enemies found
    if (count _allEnemies > 0) then {
        // Sort targets by priority
        _allEnemies = [_allEnemies, [], {
            private _dist = _targetPos distance _x;
            private _priority = switch (true) do {
                case (_x isKindOf "Tank"): { 10 };
                case (_x isKindOf "Car"): { 20 };
                case (_x isKindOf "Ship"): { 30 };
                case (_x isKindOf "Boat"): { 35 };
                case (_x isKindOf "Static"): { 40 };
                case (_x isKindOf "Man"): { 50 };
                default { 100 };
            };
            _priority + (_dist / 100)
        }, "ASCEND"] call BIS_fnc_sortBy;
        
        // Get driver and group
        private _driver = driver _aircraft;
        
        if (!isNull _driver) then {
            private _group = group _driver;
            
            // Clear existing waypoints
            while {count waypoints _group > 0} do {
                deleteWaypoint [_group, 0];
            };
            
            // Get the highest priority targets
            private _targetCount = (count _allEnemies) min 3;
            private _primaryTargets = _allEnemies select [0, _targetCount];
            private _primaryTarget = _primaryTargets select 0;
            private _targetPosition = getPos _primaryTarget;
            
            // Create attack run waypoints
            
            // Step 1: Calculate approach position at proper distance and altitude
            private _dirFromTarget = _targetPosition getDir (getPos _aircraft); // Direction from target to aircraft
            private _approachDist = 2000; // Approach from 2km away
            private _approachPos = [
                (_targetPosition select 0) + (_approachDist * sin(_dirFromTarget)),
                (_targetPosition select 1) + (_approachDist * cos(_dirFromTarget)),
                AIR_OP_ATTACK_ALTITUDE // Set altitude for approach
            ];
            
            // Step 2: Create approach waypoint
            private _wpApproach = _group addWaypoint [_approachPos, 0];
            _wpApproach setWaypointType "MOVE";
            _wpApproach setWaypointBehaviour "AWARE"; 
            _wpApproach setWaypointCombatMode "GREEN";
            _wpApproach setWaypointSpeed "NORMAL";
            _wpApproach setWaypointStatements ["true", 
                format ["vehicle this flyInHeight %1; systemChat 'Aircraft beginning attack run';", AIR_OP_ATTACK_ALTITUDE]
            ];
            
            // Step 3: Create attack waypoint
            private _attackPos = _targetPosition;
            private _wpAttack = _group addWaypoint [_attackPos, 0];
            _wpAttack setWaypointType "DESTROY";
            _wpAttack setWaypointBehaviour "COMBAT";
            _wpAttack setWaypointCombatMode "RED";
            _wpAttack setWaypointSpeed "NORMAL";
            
            // Step 4: Create egress waypoint
            private _egressPos = [
                (_targetPosition select 0) + (_approachDist * sin(_dirFromTarget + 180)),
                (_targetPosition select 1) + (_approachDist * cos(_dirFromTarget + 180)),
                AIR_OP_ATTACK_ALTITUDE
            ];
            private _wpEgress = _group addWaypoint [_egressPos, 0];
            _wpEgress setWaypointType "MOVE";
            _wpEgress setWaypointBehaviour "AWARE";
            _wpEgress setWaypointCombatMode "YELLOW";
            
            // Force reveal targets to group
            {
                _group reveal [_x, 4];
                
                // Mark target for visualization
                if (_x isKindOf "AllVehicles" && !(_x isKindOf "Man")) then {
                    private _marker = createMarker [format ["CAS_target_%1", random 9999], getPos _x];
                    _marker setMarkerType "mil_objective";
                    _marker setMarkerColor "ColorRed";
                    _marker setMarkerSize [0.5, 0.5];
                    _marker setMarkerText "CAS TARGET";
                    
                    // Delete marker after 2 minutes
                    [_marker] spawn {
                        params ["_marker"];
                        sleep 120;
                        deleteMarker _marker;
                    };
                };
            } forEach _primaryTargets;
            
            // Start the attack monitoring process
            [_aircraft, _primaryTarget, _targetPosition, _allEnemies] spawn {
                params ["_aircraft", "_primaryTarget", "_targetPosition", "_allTargets"];
                
                if (isNull _aircraft) exitWith {};
                
                // Initialize attack variables
                private _attacked = false;
                private _attackDistance = AIR_OP_ATTACK_DISTANCE;
                private _lastDistance = 99999;
                private _closingOn = true;
                
                // Main attack monitoring loop
                while {alive _aircraft && !_attacked} do {
                    // Update target position if needed
                    if (alive _primaryTarget) then {
                        _targetPosition = getPos _primaryTarget;
                    };
                    
                    // Calculate current distance to target
                    private _distance = _aircraft distance _targetPosition;
                    
                    // Determine if we're closing on target or moving away
                    if (_distance > _lastDistance) then {
                        _closingOn = false;
                    } else {
                        _closingOn = true;
                    };
                    _lastDistance = _distance;
                    
                    // DEBUG MESSAGE
                    // systemChat format ["Attack monitoring: Distance %1m, Closing: %2", round _distance, _closingOn];
                    
                    // Check if within attack distance and still closing
                    if (_distance < _attackDistance && _closingOn) then {
                        // LAUNCH WEAPONS!
                        systemChat "Aircraft executing weapons release!";
                        
                        // EXECUTE ATTACK
                        // 1. Get all available weapons
                        private _allWeapons = weapons _aircraft;
                        private _mainWeapons = _allWeapons select {
                            private _weaponType = (configFile >> "CfgWeapons" >> _x >> "cursor") call BIS_fnc_getCfgData;
                            !isNil "_weaponType" && (_weaponType == "rocket" || _weaponType == "missile" || _weaponType == "bomb")
                        };
                        
                        // If no main weapons found, use all weapons
                        if (count _mainWeapons == 0) then {
                            _mainWeapons = _allWeapons;
                        };
                        
                        // Ensure target tracking for all targets
                        {
                            if (alive _x) then {
                                // Force reveal to AI
                                (group driver _aircraft) reveal [_x, 4];
                                
                                // Fire main weapons at priority targets
                                if (_forEachIndex < 3) then {
                                    {
                                        _aircraft fireAtTarget [_x, _x];
                                        sleep 0.2;
                                    } forEach _mainWeapons;
                                };
                            };
                        } forEach _allTargets;
                        
                        // SPECIAL HANDLING FOR NAVAL TARGETS
                        private _navalTargets = _allTargets select {_x isKindOf "Ship" || _x isKindOf "Boat"};
                        if (count _navalTargets > 0) then {
                            {
                                if (alive _x) then {
                                    // Repeatedly fire at naval targets
                                    for "_i" from 1 to 5 do {
                                        {
                                            _aircraft fireAtTarget [_x, _x];
                                            sleep 0.3;
                                        } forEach _mainWeapons;
                                    };
                                };
                            } forEach _navalTargets;
                        };
                        
                        _attacked = true;
                    };
                    
                    // Exit if aircraft is RTB
                    if (_aircraft getVariable ["AIR_OP_RTB", false]) exitWith {
                        systemChat "Attack run aborted - aircraft returning to base";
                    };
                    
                    sleep 0.5;
                };
                
                // Final message after attack
                if (_attacked) then {
                    systemChat "Attack run complete";
                    
                    // Create some visual effects for the attack
                    if (!isNull _primaryTarget && alive _primaryTarget) then {
                        private _targetPos = getPos _primaryTarget;
                        "SmallSecondary" createVehicle _targetPos;
                        sleep 0.5;
                        "HelicopterExploSmall" createVehicle _targetPos;
                    };
                };
            };
            
            // Notification
            systemChat format ["CAS aircraft executing attack run on targets near %1", _targetName];
            diag_log format ["AIR_OPS TASK: CAS executing attack run with %1 priority targets", count _primaryTargets];
        };
    } else {
        // No enemies found - run a patrol pattern
        [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_performPatrol;
        
        // Occasionally gain intel while patrolling
        if (random 1 > 0.7) then {
            [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_reconIntelGain;
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
        _wp1 setWaypointBehaviour "COMBAT";
        _wp1 setWaypointSpeed "NORMAL";
        
        // Create target waypoint
        private _wp2 = _group addWaypoint [_targetPos, 0];
        _wp2 setWaypointType "DESTROY";
        _wp2 setWaypointBehaviour "COMBAT";
        
        // Create exit waypoint
        private _exitPos = [
            (_targetPos select 0) + _approachDist * sin(_approachDir + 180),
            (_targetPos select 1) + _approachDist * cos(_approachDir + 180),
            300 // Set altitude
        ];
        
        private _wp3 = _group addWaypoint [_exitPos, 0];
        _wp3 setWaypointType "MOVE";
        _wp3 setWaypointBehaviour "COMBAT";
        
        // Notification
        systemChat format ["Bombing aircraft approaching %1", _targetName];
        
        // Schedule bombing effects
        [_targetPos, _specialization, _pilotSkill, _aircraft] spawn {
            params ["_pos", "_specialization", "_pilotSkill", "_aircraft"];
            
            sleep 5; // Wait for approach
            
            // Check if our aircraft still exists
            if (isNull _aircraft || !alive _aircraft) exitWith {};
            
            // Different bombing effects based on aircraft type
            private _bombCount = AIR_OP_BOMBING_BOMBS_PER_RUN;
            switch (_specialization) do {
                case "Bombers": { _bombCount = AIR_OP_BOMBING_BOMBS_PER_RUN * 1.5 }; // Heavy bombers drop more bombs
                case "Fighters": { _bombCount = AIR_OP_BOMBING_BOMBS_PER_RUN * 0.5 }; // Fighter-bombers drop fewer
            };
            
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
                
                // Create damage zone
                private _nearbyObjects = _bombPos nearEntities [["Man", "Car", "Tank", "Ship", "Boat", "House"], 30];
                {
                    if (alive _x) then {
                        // Calculate damage based on distance
                        private _dist = _x distance _bombPos;
                        private _damage = 1 - (_dist / 30); // 1.0 at center, 0.0 at 30m
                        
                        // Apply more damage to direct hits
                        if (_dist < 10) then {
                            _damage = _damage * 2;
                        };
                        
                        // Cap damage at 1.0
                        _damage = _damage min 1.0;
                        
                        // Apply damage
                        _x setDamage ((damage _x) + _damage);
                    };
                } forEach _nearbyObjects;
                
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

// ENHANCED: Function to perform air superiority mission
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
    
    // Larger radius for air superiority (meters)
    private _searchRadius = AIR_OP_AIRSUP_DETECTION_RADIUS;
    
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
            
            // Force reveal of targets to the group
            {
                _group reveal [_x, 4];
                
                // Create marker for tracking
                private _marker = createMarker [format ["AIRSUP_target_%1", random 9999], getPos _x];
                _marker setMarkerType "mil_triangle";
                _marker setMarkerColor "ColorRed";
                _marker setMarkerSize [0.5, 0.5];
                _marker setMarkerText "ENEMY AIR";
                
                // Delete marker after 2 minutes
                [_marker] spawn {
                    params ["_marker"];
                    sleep 120;
                    deleteMarker _marker;
                };
            } forEach _enemyAir;
            
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
    
    // Get aircraft status - don't try to execute missions for dead aircraft
    if (!alive _aircraft) exitWith {
        diag_log format ["AIR_OPS TASK: Aircraft is not alive, cannot execute mission %1", _missionType];
        false
    };
    
    // Get RTB status - don't execute missions for aircraft returning to base
    if (_aircraft getVariable ["AIR_OP_RTB", false]) exitWith {
        diag_log format ["AIR_OPS TASK: Aircraft is RTB, not executing mission %1", _missionType];
        false
    };
    
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

// Add emergency repair and refuel function
AIR_OP_fnc_emergencyRepairRefuel = {
    private _count = 0;
    
    // Process all deployed aircraft
    {
        if (!isNull _x && alive _x) then {
            // Fix aircraft
            _x setDamage 0;
            _x setFuel 1;
            
            // Re-enable all systems
            _x setVehicleAmmo 1;
            
            // Re-enable all pilots
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    _x enableAI "ALL";
                    _x setBehaviour "COMBAT";
                    _x setCombatMode "RED";
                };
            } forEach crew _x;
            
            _count = _count + 1;
            systemChat format ["Repaired and refueled: %1", getText(configFile >> "CfgVehicles" >> typeOf _x >> "displayName")];
        };
    } forEach HANGAR_deployedAircraft;
    
    systemChat format ["Emergency repairs completed on %1 aircraft", _count];
    _count
};

// Add to mission namespace for easy access from debug console
missionNamespace setVariable ["enableAllAircraftAI", AIR_OP_fnc_emergencyEnableAllPilots, true];
missionNamespace setVariable ["repairAllAircraft", AIR_OP_fnc_emergencyRepairRefuel, true];