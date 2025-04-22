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

// SIMPLIFIED POSITION-BASED CAS FUNCTION
// Executes an attack run on a fixed position rather than enemy units
AIR_OP_fnc_performCAS = {
    params ["_aircraft", "_targetIndex", "_targetType"];
    
    if (isNull _aircraft) exitWith {
        diag_log "AIR_OPS TASK: Cannot perform CAS with null aircraft";
        false
    };
    
    // Check if aircraft is already busy
    if (_aircraft getVariable ["AIR_OP_BUSY_ATTACKING", false]) exitWith {
        diag_log format ["AIR_OPS TASK: Aircraft %1 already busy with attack run - skipping", _aircraft];
        false
    };
    
    // Set busy flag
    _aircraft setVariable ["AIR_OP_BUSY_ATTACKING", true, true];
    
    // Get target position - ignoring all enemy detection
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
        _aircraft setVariable ["AIR_OP_BUSY_ATTACKING", false, true];
        diag_log "AIR_OPS TASK: Invalid target position for CAS";
        false
    };
    
    // Get driver and group
    private _driver = driver _aircraft;
    
    if (!isNull _driver) then {
        private _group = group _driver;
        
        // IMPORTANT: Disable targeting for all crew members
        {
            if (_x getVariable ["HANGAR_isPilot", false]) then {
                _x disableAI "TARGET";
                _x disableAI "AUTOTARGET";
                _x setBehaviour "CARELESS";
                _x setCombatMode "BLUE";
            };
        } forEach crew _aircraft;
        
        // Set group behavior
        _group setBehaviour "CARELESS";
        _group setCombatMode "BLUE";
        
        // Clear existing waypoints
        while {count waypoints _group > 0} do {
            deleteWaypoint [_group, 0];
        };
        
        // Calculate proper attack vector
        private _aircraftPos = getPos _aircraft;
        private _currentAlt = _aircraftPos select 2;
        
        // === GAMEPLAY VARIABLES === 
        private _attackAltitude = 300;     // Attack altitude in meters
        private _approachDist = 4000;      // Distance from target for approach
        private _weaponReleaseDist = 800;  // Distance for weapon release
        
        // Use aircraft's current position to determine approach direction
        private _approachDir = (_aircraftPos getDir _targetPos);
        
        // Calculate opposite approach vector (approaching FROM this direction)
        private _attackDir = (_approachDir + 180) % 360;
        
        // CRITICAL: Create an initial "move away" waypoint if too close
        private _distToTarget = _aircraftPos distance _targetPos;
        
        if (_distToTarget < 4000) then {
            // Calculate a position 6km away from target in opposite direction of attack
            private _moveAwayPos = [
                (_targetPos select 0) + (sin(_attackDir) * 6000),
                (_targetPos select 1) + (cos(_attackDir) * 6000),
                _attackAltitude + 200
            ];
            
            private _wpMoveAway = _group addWaypoint [_moveAwayPos, 0];
            _wpMoveAway setWaypointType "MOVE";
            _wpMoveAway setWaypointBehaviour "CARELESS";
            _wpMoveAway setWaypointCombatMode "BLUE";
            _wpMoveAway setWaypointSpeed "FULL";
            _wpMoveAway setWaypointStatements ["true", "vehicle this flyInHeight " + str (_attackAltitude + 200) + "; systemChat 'Moving to attack position...'"];
            
            // Store approach vector for later steps
            _aircraft setVariable ["AIR_OP_ATTACK_DIR", _attackDir];
            
            diag_log format ["AIR_OPS TASK: Initial position too close, moving away to %1", _moveAwayPos];
        };
        
        // Calculate waypoint positions for attack run
        // 1. Approach position - CLEARLY away from target
        private _approachPos = [
            (_targetPos select 0) + (sin(_attackDir) * _approachDist),
            (_targetPos select 1) + (cos(_attackDir) * _approachDist),
            _attackAltitude + 200
        ];
        
        // 2. Attack start position
        private _attackStartPos = [
            (_targetPos select 0) + (sin(_attackDir) * 2000),
            (_targetPos select 1) + (cos(_attackDir) * 2000),
            _attackAltitude
        ];
        
        // 3. Weapons release position
        private _releasePos = [
            (_targetPos select 0) + (sin(_attackDir) * _weaponReleaseDist),
            (_targetPos select 1) + (cos(_attackDir) * _weaponReleaseDist),
            _attackAltitude - 50
        ];
        
        // 4. Target position
        private _finalTargetPos = _targetPos;
        
        // 5. Egress position
        private _egressPos = [
            (_targetPos select 0) - (sin(_attackDir) * 3000),
            (_targetPos select 1) - (cos(_attackDir) * 3000),
            _attackAltitude + 100
        ];
        
        // Create approach waypoint
        private _wpApproach = _group addWaypoint [_approachPos, 0];
        _wpApproach setWaypointType "MOVE";
        _wpApproach setWaypointBehaviour "CARELESS";
        _wpApproach setWaypointCombatMode "BLUE";
        _wpApproach setWaypointSpeed "NORMAL";
        _wpApproach setWaypointStatements ["true", "vehicle this flyInHeight " + str (_attackAltitude + 100) + "; systemChat 'Beginning attack approach...'"];
        
        // Create attack start waypoint
        private _wpAttackStart = _group addWaypoint [_attackStartPos, 0];
        _wpAttackStart setWaypointType "MOVE";
        _wpAttackStart setWaypointBehaviour "CARELESS";
        _wpAttackStart setWaypointCombatMode "BLUE";
        _wpAttackStart setWaypointSpeed "LIMITED";
        _wpAttackStart setWaypointStatements ["true", "vehicle this flyInHeight " + str _attackAltitude + "; systemChat 'Starting attack run...'"];
        
        // Create weapons release waypoint
        private _wpRelease = _group addWaypoint [_releasePos, 0];
        _wpRelease setWaypointType "MOVE";
        _wpRelease setWaypointBehaviour "CARELESS";
        _wpRelease setWaypointCombatMode "BLUE";
        _wpRelease setWaypointSpeed "LIMITED";
        _wpRelease setWaypointStatements ["true", "systemChat 'Weapons release position...'"];
        
        // Create target waypoint
        private _wpTarget = _group addWaypoint [_finalTargetPos, 0];
        _wpTarget setWaypointType "MOVE";
        _wpTarget setWaypointBehaviour "CARELESS";
        _wpTarget setWaypointCombatMode "BLUE";
        _wpTarget setWaypointSpeed "LIMITED";
        
        // Create egress waypoint
        private _wpEgress = _group addWaypoint [_egressPos, 0];
        _wpEgress setWaypointType "MOVE";
        _wpEgress setWaypointBehaviour "CARELESS";
        _wpEgress setWaypointCombatMode "BLUE";
        _wpEgress setWaypointSpeed "NORMAL";
        _wpEgress setWaypointStatements ["true", "systemChat 'Attack run complete, egressing'; (vehicle this) setVariable ['AIR_OP_BUSY_ATTACKING', false, true];"];
        
        // Create a marker at the target position
        private _marker = createMarker [format ["CAS_target_%1", random 9999], _targetPos];
        _marker setMarkerType "mil_destroy";
        _marker setMarkerColor "ColorRed";
        _marker setMarkerSize [1, 1];
        _marker setMarkerText "CAS TARGET";
        
        // Delete marker after 3 minutes
        [_marker] spawn {
            params ["_marker"];
            sleep 180;
            deleteMarker _marker;
        };
        
        // Start tracking the attack run and handle weapons release
        [_aircraft, _targetPos, _weaponReleaseDist] spawn {
            params ["_aircraft", "_targetPos", "_weaponReleaseDist"];
            
            private _timeoutStart = time;
            private _maxTimeout = 300; // 5 minute timeout
            private _weaponsFired = false;
            private _explosionsCreated = false;
            
            // Debug log
            diag_log format ["AIR_OPS TASK: Starting attack monitoring for target at %1", _targetPos];
            
            while {alive _aircraft && time - _timeoutStart < _maxTimeout} do {
                private _distance = _aircraft distance _targetPos;
                
                // Check if we're at weapons release distance and haven't fired yet
                if (_distance <= _weaponReleaseDist && !_weaponsFired) then {
                    // Get all available weapons
                    private _allWeapons = weapons _aircraft;
                    private _mainWeapons = [];
                    
                    // Try to identify offensive weapons
                    {
                        private _weaponName = toLower _x;
                        if (_weaponName find "cannon" > -1 || 
                            _weaponName find "rocket" > -1 || 
                            _weaponName find "missile" > -1 || 
                            _weaponName find "bomb" > -1 || 
                            _weaponName find "mg" > -1) then {
                            _mainWeapons pushBack _x;
                        };
                    } forEach _allWeapons;
                    
                    // If no weapons identified, use all weapons
                    if (count _mainWeapons == 0) then {
                        _mainWeapons = _allWeapons;
                    };
                    
                    // Fire all weapons at the position
                    systemChat "Aircraft releasing weapons!";
                    diag_log format ["AIR_OPS TASK: Firing weapons at position %1", _targetPos];
                    
                    // Create a temporary target for aiming
                    private _targetObj = "Land_HelipadEmpty_F" createVehicle _targetPos;
                    
                    // Execute firing
                    {
                        for "_i" from 1 to 5 do {
                            _aircraft fireAtTarget [_targetObj, _x];
                            sleep 0.3;
                        };
                    } forEach _mainWeapons;
                    
                    // Mark as fired
                    _weaponsFired = true;
                    
                    // Schedule target deletion
                    [_targetObj] spawn {
                        params ["_obj"];
                        sleep 30;
                        deleteVehicle _obj;
                    };
                };
                
                // Create explosions when very close to target
                if (_distance < 200 && !_explosionsCreated) then {
                    systemChat "Impact at target!";
                    
                    // Create a series of explosions
                    [_targetPos] spawn {
                        params ["_pos"];
                        
                        "Bo_GBU12_LGB" createVehicle _pos;
                        sleep 1;
                        "HelicopterExploBig" createVehicle [(_pos select 0) + 15, (_pos select 1) + 10, 0];
                        sleep 0.5;
                        "Bo_GBU12_LGB" createVehicle [(_pos select 0) - 20, (_pos select 1) + 5, 0];
                        sleep 0.3;
                        "HelicopterExploSmall" createVehicle [(_pos select 0) - 5, (_pos select 1) - 15, 0];
                    };
                    
                    _explosionsCreated = true;
                    
                    // If attacking a location, chance to mark as destroyed
                    if (random 1 > 0.5) then {
                        // Try to find matching location
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
                
                // If we've passed the target and fired, we're done
                if (_weaponsFired && _distance > 1500 && _aircraft getVariable ["wpIndex", 0] >= 4) then {
                    systemChat "Attack run successfully completed";
                    _aircraft setVariable ["AIR_OP_BUSY_ATTACKING", false, true];
                    break;
                };
                
                // Exit if RTB
                if (_aircraft getVariable ["AIR_OP_RTB", false]) exitWith {
                    systemChat "Attack run aborted - aircraft returning to base";
                    _aircraft setVariable ["AIR_OP_BUSY_ATTACKING", false, true];
                };
                
                sleep 1;
            };
            
            // Always clear busy flag at end
            _aircraft setVariable ["AIR_OP_BUSY_ATTACKING", false, true];
            
            // Re-enable targeting after attack run
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    _x enableAI "TARGET";
                    _x enableAI "AUTOTARGET";
                };
            } forEach crew _aircraft;
            
            // Timeout message if needed
            if (time - _timeoutStart >= _maxTimeout) then {
                systemChat "Attack run timed out";
                diag_log "AIR_OPS TASK: Attack run timed out";
            };
        };
        
        // Notification
        systemChat format ["CAS aircraft executing attack run on position near %1", _targetName];
        diag_log format ["AIR_OPS TASK: CAS mission started on position near %1", _targetName];
    } else {
        // No driver, release busy flag
        _aircraft setVariable ["AIR_OP_BUSY_ATTACKING", false, true];
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

// FIXED: Function to execute a specific mission type with proper busy state handling
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
    
    // === CRITICAL FIX: Check busy state before executing combat missions ===
    // For combat missions, only attempt if not already in an attack
    if (_missionType in ["cas", "bombing", "airsup"] && _aircraft getVariable ["AIR_OP_BUSY_ATTACKING", false]) exitWith {
        diag_log format ["AIR_OPS TASK: Aircraft busy with attack run, skipping %1 execution", _missionType];
        true // Return true so we don't log failure
    };
    
    // === CRITICAL FIX: Rate limiting for mission execution ===
    // Only execute effects periodically, not every monitoring cycle
    private _lastExecutionTime = _aircraft getVariable ["AIR_OP_LAST_EXECUTION", 0];
    private _currentTime = time;
    
    // === GAMEPLAY VARIABLE - MISSION EXECUTION FREQUENCY ===
    private _executionInterval = switch (_missionType) do {
        case "recon": { 10 };    // Every 10 seconds
        case "patrol": { 15 };   // Every 15 seconds
        case "cas": { 30 };      // Every 30 seconds
        case "bombing": { 45 };  // Every 45 seconds
        case "airsup": { 20 };   // Every 20 seconds
        default { 15 };          // Default interval
    };
    
    // Skip execution if not enough time has passed since last execution
    if (_currentTime - _lastExecutionTime < _executionInterval) exitWith {
        // We're still in cooldown, silently skip
        true
    };
    
    // Update last execution time
    _aircraft setVariable ["AIR_OP_LAST_EXECUTION", _currentTime];
    
    // Execute appropriate mission function based on type
    switch (_missionType) do {
        case "recon": {
            // Set in-area status if not already set
            if (isNil {_aircraft getVariable "AIR_OP_inArea"}) then {
                _aircraft setVariable ["AIR_OP_inArea", false];
                _aircraft setVariable ["AIR_OP_inAreaTime", 0];
            };
            
            // Execute intelligence gathering effect with reduced frequency
            if (random 1 > 0.7) then { // 30% chance to execute
                [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_reconIntelGain;
            };
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
            
            // Execute CAS function - CRITICAL FIX: only if we're in the target area
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
            
            // Only execute CAS function if we're in the area
            if (_targetPos distance _aircraft < 1000) then {
                [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_performCAS;
            };
        };
        
        case "bombing": {
            // Initialize bombing variables
            if (isNil {_aircraft getVariable "AIR_OP_bombsDropped"}) then {
                _aircraft setVariable ["AIR_OP_bombsDropped", false];
            };
            
            // Execute bombing function only if bombs not already dropped
            if (!(_aircraft getVariable ["AIR_OP_bombsDropped", false])) then {
                [_aircraft, _targetIndex, _targetType] call AIR_OP_fnc_performBombing;
            };
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