// Virtual Hangar System - Pilot Management
// Handles pilot roster, progression, and assignment
// REWRITTEN VERSION - ALL AI RESTRICTIONS REMOVED

// Initialize pilot roster if not exists
if (isNil "HANGAR_pilotRoster") then {
    HANGAR_pilotRoster = []; // Start with empty roster - pilots will be added externally
};

// Function to get pilot rank name
HANGAR_fnc_getPilotRankName = {
    params ["_rankIndex"];
    
    if (_rankIndex < 0 || _rankIndex >= count HANGAR_pilotRanks) exitWith {"Recruit"};
    
    (HANGAR_pilotRanks select _rankIndex) select 0
};

// Function to get pilot skill multiplier based on rank
HANGAR_fnc_getPilotSkillMultiplier = {
    params ["_rankIndex"];
    
    if (_rankIndex < 0 || _rankIndex >= count HANGAR_pilotRanks) exitWith {1.0};
    
    (HANGAR_pilotRanks select _rankIndex) select 2
};

// Function to add existing unit to pilot roster
HANGAR_fnc_addExistingPilotToRoster = {
    params ["_unit", ["_specialization", "Fighters"]];
    
    if (isNull _unit) exitWith {
        diag_log "PILOT: Cannot add null unit to roster";
        -1
    };
    
    // Check if pilot already exists in roster
    private _existingIndex = -1;
    private _pilotName = name _unit;
    
    {
        if ((_x select 0) == _pilotName) exitWith {
            _existingIndex = _forEachIndex;
        };
    } forEach HANGAR_pilotRoster;
    
    // If pilot already exists, return the existing index
    if (_existingIndex != -1) exitWith {
        systemChat format ["Pilot %1 already in roster", _pilotName];
        diag_log format ["PILOT: Pilot already in roster: %1", _pilotName];
        _existingIndex
    };
    
    // Get unit rank
    private _unitRank = rank _unit;
    private _rankIndex = 0;
    
    // Convert string rank to index
    switch (_unitRank) do {
        case "PRIVATE": { _rankIndex = 0; };
        case "CORPORAL": { _rankIndex = 1; };
        case "SERGEANT": { _rankIndex = 2; };
        case "LIEUTENANT": { _rankIndex = 3; };
        case "CAPTAIN": { _rankIndex = 4; };
        case "MAJOR": { _rankIndex = 5; };
        default { _rankIndex = 0; };
    };
    
    // Create pilot data structure based on existing unit
    private _pilotData = [
        _pilotName,          // Name from unit
        _rankIndex,          // Rank index converted from unit rank
        0,                   // Missions completed (starts at 0)
        0,                   // Kills (starts at 0)
        _specialization,     // Aircraft specialization (parameter)
        objNull              // Currently assigned aircraft (objNull = none)
    ];
    
    // Add to roster
    HANGAR_pilotRoster pushBack _pilotData;
    
    // Return new pilot index
    private _newIndex = (count HANGAR_pilotRoster) - 1;
    
    systemChat format ["Pilot %1 added to roster with rank %2", _pilotName, [_rankIndex] call HANGAR_fnc_getPilotRankName];
    diag_log format ["PILOT: Added to roster: %1 (index: %2, rank: %3)", _pilotName, _newIndex, [_rankIndex] call HANGAR_fnc_getPilotRankName];
    
    _newIndex
};

// Function to update pilot stats
HANGAR_fnc_updatePilotStats = {
    params ["_pilotIndex", "_key", "_value"];
    
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) exitWith {
        diag_log format ["PILOT: Invalid pilot index for stat update: %1", _pilotIndex];
        false
    };
    
    private _pilotData = HANGAR_pilotRoster select _pilotIndex;
    
    switch (_key) do {
        case "missions": {
            // Increment missions count
            _pilotData set [2, (_pilotData select 2) + _value];
            
            // Check if pilot should be promoted
            private _missions = _pilotData select 2;
            private _currentRank = _pilotData select 1;
            private _promoted = false;
            
            for "_i" from (_currentRank + 1) to ((count HANGAR_pilotRanks) - 1) do {
                private _rankData = HANGAR_pilotRanks select _i;
                if (_missions >= (_rankData select 1)) then {
                    _pilotData set [1, _i];
                    private _newRankName = [_i] call HANGAR_fnc_getPilotRankName;
                    systemChat format ["%1 promoted to %2!", _pilotData select 0, _newRankName];
                    diag_log format ["PILOT: Promoted to %1: %2", _newRankName, _pilotData select 0];
                    _promoted = true;
                };
            };
            
            // Return true if promoted
            _promoted
        };
        case "kills": {
            _pilotData set [3, (_pilotData select 3) + _value];
            
            // Maybe add special ace status based on kills?
            if ((_pilotData select 3) >= 5) then {
                systemChat format ["%1 is now an Ace with %2 kills!", _pilotData select 0, _pilotData select 3];
                diag_log format ["PILOT: Ace status achieved for %1 with %2 kills", _pilotData select 0, _pilotData select 3];
                true
            } else {
                false
            }
        };
        case "specialization": {
            _pilotData set [4, _value];
            true
        };
        case "assignment": {
            _pilotData set [5, _value];
            true
        };
    };
};

// Function to get index of a pilot by unit object
HANGAR_fnc_getPilotIndex = {
    params ["_unit"];
    
    if (isNull _unit) exitWith {-1};
    
    private _index = -1;
    private _pilotName = name _unit;
    
    {
        private _name = _x select 0;
        if (_name == _pilotName) exitWith {
            _index = _forEachIndex;
        };
    } forEach HANGAR_pilotRoster;
    
    _index
};

// Function to get pilot data by name
HANGAR_fnc_getPilotByName = {
    params ["_name"];
    
    private _index = -1;
    
    {
        if ((_x select 0) == _name) exitWith {
            _index = _forEachIndex;
        };
    } forEach HANGAR_pilotRoster;
    
    if (_index == -1) exitWith {[]};
    
    HANGAR_pilotRoster select _index
};

// Function to get available pilots (not currently assigned)
HANGAR_fnc_getAvailablePilots = {
    private _available = [];
    
    {
        private _pilotData = _x;
        private _aircraft = _pilotData select 5;
        
        if (isNull _aircraft) then {
            _available pushBack _forEachIndex;
        };
    } forEach HANGAR_pilotRoster;
    
    _available
};

// Function to check if pilot is available and specialization matches
HANGAR_fnc_isPilotAvailableForAircraft = {
    params ["_pilotIndex", "_aircraftType"];
    
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) exitWith {
        diag_log format ["PILOT: Invalid pilot index for availability check: %1", _pilotIndex];
        [false, "Invalid pilot index"]
    };
    
    // Get pilot data
    private _pilotData = HANGAR_pilotRoster select _pilotIndex;
    private _currentAircraft = _pilotData select 5;
    private _specialization = _pilotData select 4;
    
    // Check if pilot is already assigned
    if (!isNull _currentAircraft) exitWith {
        diag_log format ["PILOT: Already assigned: %1", _pilotIndex];
        [false, "Pilot already assigned"]
    };
    
    // Get aircraft category
    private _aircraftCategory = "";
    {
        _x params ["_category", "_aircraftList"];
        
        {
            _x params ["_className", "_displayName", "_crewCount"];
            if (_className == _aircraftType) exitWith {
                _aircraftCategory = _category;
            };
        } forEach _aircraftList;
        
        if (_aircraftCategory != "") exitWith {};
    } forEach HANGAR_aircraftTypes;
    
    // Check if specialization matches
    if (_aircraftCategory != "" && _specialization != _aircraftCategory) exitWith {
        diag_log format ["PILOT: Specialization mismatch - Has: %1, Needs: %2", _specialization, _aircraftCategory];
        [false, format ["Pilot specializes in %1, not %2", _specialization, _aircraftCategory]]
    };
    
    // All checks passed
    [true, ""]
};

// Function to assign a pilot to an aircraft - COMPLETELY REWRITTEN WITHOUT AI RESTRICTIONS
HANGAR_fnc_assignPilotToAircraft = {
    params ["_pilotIndex", "_aircraft", ["_role", "driver"], ["_turretPath", []], ["_isDeployed", false]];
    
    diag_log format ["PILOT: Assigning index %1 to %2 as %3 (Deployed: %4)", 
        _pilotIndex, typeOf _aircraft, _role, _isDeployed];
    
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) exitWith {
        systemChat "Invalid pilot index";
        diag_log format ["PILOT: Invalid index: %1, roster size: %2", _pilotIndex, count HANGAR_pilotRoster];
        objNull
    };
    
    if (isNull _aircraft) exitWith {
        systemChat "Invalid aircraft";
        diag_log "PILOT: Aircraft is null";
        objNull
    };
    
    // Direct check if pilot is available
    private _pilotData = HANGAR_pilotRoster select _pilotIndex;
    private _currentAircraft = _pilotData select 5;
    
    if (!isNull _currentAircraft && {_currentAircraft != _aircraft}) exitWith {
        systemChat "Pilot is already assigned to another aircraft";
        diag_log format ["PILOT: Already assigned to different aircraft: %1", _pilotIndex];
        objNull
    };
    
    // Get pilot data
    private _pilotName = _pilotData select 0;
    private _rankIndex = _pilotData select 1;
    private _rankName = [_rankIndex] call HANGAR_fnc_getPilotRankName;
    
    // Ensure position is on ground and near aircraft
    private _spawnPos = getPosATL _aircraft vectorAdd [3, 3, 0];
    _spawnPos set [2, 0];
    
    diag_log format ["PILOT: Spawning at position: %1", _spawnPos];
    
    // Create the unit
    private _side = side player;
    private _group = createGroup [_side, true];
    private _unit = objNull;
    
    if (isServer) then {
        _unit = _group createUnit ["sab_fl_pilot_green", _spawnPos, [], 0, "NONE"];
    } else {
        _unit = _group createUnit ["sab_fl_pilot_green", _spawnPos, [], 0, "NONE"];
        
        if (isNull _unit) then {
            systemChat "Local unit creation failed, trying server-side creation";
            [_group, "sab_fl_pilot_green", _spawnPos, [], 0, "NONE"] remoteExec ["bis_fnc_spawnUnit", 2];
            sleep 1;
            
            {
                if (_x getVariable ["HANGAR_tempPilot", false]) exitWith {
                    _unit = _x;
                };
            } forEach allUnits;
        };
    };
    
    if (isNull _unit) exitWith {
        systemChat "Failed to create pilot unit! Check class name and server status.";
        diag_log "PILOT: Critical error: Failed to create unit";
        objNull
    };
    
    // Set name and other attributes
    _unit setName _pilotName;
    _unit allowDamage false; // Keep this for safety
    _unit setUnitRank (["PRIVATE", "CORPORAL", "SERGEANT", "LIEUTENANT", "CAPTAIN", "MAJOR"] select 
        (_rankIndex min 5));
    _unit setVariable ["HANGAR_isPilot", true, true];
    _unit setVariable ["HANGAR_pilotIndex", _pilotIndex, true];
    
    // Add protection flags
    _unit setVariable ["HANGAR_essential_set", true, true];
    _unit setVariable ["BIS_enableRandomization", false, true];
    _unit setVariable ["acex_headless_blacklist", true, true];
    
    // Update pilot data to show assigned to this aircraft
    [_pilotIndex, "assignment", _aircraft] call HANGAR_fnc_updatePilotStats;
    
    // Set skill based on rank
    private _skillMultiplier = [_rankIndex] call HANGAR_fnc_getPilotSkillMultiplier;
    _unit setSkill (_skillMultiplier * 0.9); // Higher base skill
    
    // CRITICAL CHANGE: Always enable ALL AI functionality regardless of deployment status
    // No more differentiation between view model and deployed pilots
    _unit enableAI "ALL"; 
    _unit enableAI "TARGET";
    _unit enableAI "AUTOTARGET"; 
    _unit enableAI "MOVE";
    _unit enableAI "ANIM";
    _unit enableAI "FSM";
    _unit enableAI "PATH";
    _unit enableAI "TEAMSWITCH";
    _unit enableAI "COVER";
    _unit enableAI "SUPPRESSION";
    _unit enableAI "AIMINGERROR";
    _unit enableAI "WEAPONAIM";
    
    // Set behavior
    _unit setBehaviour "COMBAT";
    _unit setCombatMode "RED";
    _unit allowFleeing 0;
    _unit setCaptive false; // Never captive
    
    // Log pilot AI status
    systemChat format ["✅ AI ENABLED for pilot %1", _pilotName];
    diag_log format ["PILOT: Created pilot %1 with FULL AI CAPABILITIES", _pilotName];
    
    // Set aircraft variables
    _aircraft setVariable ["HANGAR_deployed", _isDeployed, true];
    _aircraft setVariable ["HANGAR_pilotIndex", _pilotIndex, true];
    
    // Store reference globally
    missionNamespace setVariable [format ["HANGAR_pilot_%1", _pilotIndex], _unit, true];
    
    // Move into vehicle
    switch (_role) do {
        case "driver": { _unit moveInDriver _aircraft; };
        case "gunner": { _unit moveInGunner _aircraft; };
        case "commander": { _unit moveInCommander _aircraft; };
        case "turret": { _unit moveInTurret [_aircraft, _turretPath]; };
        case "cargo": { _unit moveInCargo _aircraft; };
    };
    
    // Check if pilot got in
    [_unit, _aircraft, _role, _turretPath, _pilotIndex, _isDeployed] spawn {
        params ["_unit", "_aircraft", "_role", "_turretPath", "_pilotIndex", "_isDeployed"];
        
        sleep 1;
        
        if (vehicle _unit == _aircraft) then {
            diag_log "PILOT: Successfully entered aircraft";
            
            // Start the engine if deployed
            if (_isDeployed) then {
                _aircraft engineOn true;
                systemChat format ["%1 is now piloting the aircraft with full combat capabilities", name _unit];
            } else {
                systemChat format ["%1 is now assigned to the aircraft with full combat capabilities", name _unit];
            };
        } else {
            // Emergency teleport
            diag_log "PILOT: EMERGENCY - Failed to enter vehicle, trying direct teleport";
            
            switch (_role) do {
                case "driver": { _unit moveInDriver _aircraft; };
                case "gunner": { _unit moveInGunner _aircraft; };
                case "commander": { _unit moveInCommander _aircraft; };
                case "turret": { _unit moveInTurret [_aircraft, _turretPath]; };
                case "cargo": { _unit moveInCargo _aircraft; };
            };
            
            sleep 0.5;
            
            if (vehicle _unit == _aircraft) then {
                diag_log "PILOT: Emergency teleport successful";
                
                if (_isDeployed) then {
                    _aircraft engineOn true;
                }
            } else {
                systemChat "Failed to place pilot in aircraft";
                diag_log "PILOT: Failed to place in aircraft even after teleport attempt";
                deleteVehicle _unit;
                [_pilotIndex, "assignment", objNull] call HANGAR_fnc_updatePilotStats;
            };
        };
    };
    
    _unit
};

// Function to assign pilot to a stored aircraft (for UI)
HANGAR_fnc_assignPilotToStoredAircraft = {
    params ["_pilotIndex", "_aircraftIndex", ["_role", "driver"], ["_turretPath", []]];
    
    // Direct checks with detailed logging
    diag_log format ["PILOT: Assigning to stored aircraft - Pilot: %1, Aircraft: %2", _pilotIndex, _aircraftIndex];
    
    // Validate pilot index
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) exitWith {
        systemChat "Invalid pilot index";
        diag_log format ["PILOT: Invalid pilot index: %1, Roster size: %2", _pilotIndex, count HANGAR_pilotRoster];
        false
    };
    
    // Validate aircraft index
    if (_aircraftIndex < 0 || _aircraftIndex >= count HANGAR_storedAircraft) exitWith {
        systemChat "Invalid aircraft index";
        diag_log format ["PILOT: Invalid aircraft index: %1, Aircraft count: %2", _aircraftIndex, count HANGAR_storedAircraft];
        false
    };
    
    // Get aircraft type and check specialization
    private _record = HANGAR_storedAircraft select _aircraftIndex;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
    
    // Get the pilot data
    private _pilotData = HANGAR_pilotRoster select _pilotIndex;
    private _pilotName = _pilotData select 0;
    private _specialization = _pilotData select 4;
    private _currentAssignment = _pilotData select 5;
    
    // Check if pilot is available in any other aircraft's crew lists
    private _alreadyAssigned = false;
    for "_i" from 0 to ((count HANGAR_storedAircraft) - 1) do {
        if (_i != _aircraftIndex) then {
            private _otherRecord = HANGAR_storedAircraft select _i;
            private _otherCrew = _otherRecord select 5;
            
            {
                _x params ["_crewPilotIndex"];
                if (_crewPilotIndex == _pilotIndex) exitWith {
                    _alreadyAssigned = true;
                    systemChat format ["%1 is already in the crew of another aircraft", _pilotName];
                    diag_log format ["PILOT: Cannot assign - found in crew of aircraft %1", _i];
                };
            } forEach _otherCrew;
            
            if (_alreadyAssigned) exitWith {};
        };
    };
    
    if (_alreadyAssigned) exitWith { false };
    
    // Check if specialization matches
    private _aircraftCategory = "";
    {
        _x params ["_category", "_aircraftList"];
        
        {
            _x params ["_className"];
            if (_className == _type) exitWith {
                _aircraftCategory = _category;
                diag_log format ["PILOT: Aircraft %1 is category: %2", _type, _category];
            };
        } forEach _aircraftList;
        
        if (_aircraftCategory != "") exitWith {};
    } forEach HANGAR_aircraftTypes;
    
    if (_aircraftCategory != "" && _specialization != "" && _specialization != _aircraftCategory) then {
        private _proceed = false;
        
        // Ask if player wants to proceed with wrong specialization
        systemChat format ["WARNING: %1 is specialized in %2, not %3", _pilotName, _specialization, _aircraftCategory];
        
        // For now, allow it as a failsafe but warn the player
        _proceed = true;
        
        if (!_proceed) exitWith {
            diag_log format ["PILOT: Assignment canceled - specialization mismatch"];
            false
        };
    };
    
    // Add pilot to aircraft crew if not already there
    private _existingCrewIndex = -1;
    {
        _x params ["_crewPilotIndex"];
        if (_crewPilotIndex == _pilotIndex) exitWith {
            _existingCrewIndex = _forEachIndex;
        };
    } forEach _crew;
    
    // If not already in crew, add
    if (_existingCrewIndex == -1) then {
        private _pilotAssignment = [_pilotIndex, _role, _turretPath];
        _crew pushBack _pilotAssignment;
        diag_log format ["PILOT: Added new crew entry for pilot %1", _pilotName];
    } else {
        // Update existing entry
        _crew set [_existingCrewIndex, [_pilotIndex, _role, _turretPath]];
        diag_log format ["PILOT: Updated existing crew entry for pilot %1", _pilotName];
    };
    
    // CRITICAL: Update the pilot's aircraft reference in the roster
    if (!isNull HANGAR_viewedAircraft && 
        (HANGAR_viewedAircraft getVariable ["HANGAR_storageIndex", -1]) == _aircraftIndex) then {
        // Store the viewed aircraft reference
        _pilotData set [5, HANGAR_viewedAircraft];
        diag_log format ["PILOT: Updated roster entry for pilot %1 - assigned to viewed aircraft", _pilotName];
    } else {
        // If not viewing, set to deployed instance if deployed
        if (_isDeployed && !isNull _deployedInstance) then {
            _pilotData set [5, _deployedInstance];
            diag_log format ["PILOT: Updated roster entry for pilot %1 - assigned to deployed aircraft", _pilotName];
        } else {
            // Not deployed, just mark as assigned but with null aircraft
            // This is critical to ensure correct tracking
            _pilotData set [5, objNull];
            diag_log format ["PILOT: Updated roster entry for pilot %1 - marked as assigned", _pilotName];
        };
    };
    
    systemChat format ["%1 assigned to %2 as %3", 
        _pilotName, 
        _displayName,
        switch (_role) do {
            case "driver": {"Pilot"};
            case "gunner": {"Gunner"};
            case "commander": {"Commander"};
            case "turret": {format ["Turret Gunner %1", _turretPath]};
            case "cargo": {"Crew"};
            default {"Crew"};
        }
    ];
    
    diag_log format ["PILOT: Successfully assigned pilot %1 to stored aircraft %2", 
        _pilotName, 
        _displayName
    ];
    
    // Also update in viewed aircraft if this is the one being viewed
    if (!isNull HANGAR_viewedAircraft) then {
        private _viewedIndex = HANGAR_viewedAircraft getVariable ["HANGAR_storageIndex", -1];
        if (_viewedIndex == _aircraftIndex) then {
            [_pilotIndex, HANGAR_viewedAircraft, _role, _turretPath, false] call HANGAR_fnc_assignPilotToAircraft;
        };
    };
    
    // Also update in deployed instance if deployed
    if (_isDeployed && !isNull _deployedInstance) then {
        [_pilotIndex, _deployedInstance, _role, _turretPath, true] call HANGAR_fnc_assignPilotToAircraft;
    };
    
    true
};

// Function to handle returning a pilot to roster
HANGAR_fnc_returnPilotToRoster = {
    params ["_unit"];
    
    if (isNull _unit) exitWith {
        diag_log "PILOT: Cannot return null unit to roster";
        false
    };
    
    // Get pilot index
    private _pilotIndex = _unit getVariable ["HANGAR_pilotIndex", -1];
    
    if (_pilotIndex < 0) exitWith {
        systemChat "Unit is not a managed pilot";
        diag_log "PILOT: Unit is not a managed pilot";
        false
    };
    
    // Update pilot assignment
    [_pilotIndex, "assignment", objNull] call HANGAR_fnc_updatePilotStats;
    
    // Delete the unit
    private _name = name _unit;
    deleteVehicle _unit;
    
    systemChat format ["%1 has returned to the pilot roster", _name];
    diag_log format ["PILOT: Returned to roster: %1", _name];
    true
};

// Return all crew members from an aircraft to roster
HANGAR_fnc_returnCrewToRoster = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {
        diag_log "PILOT: Cannot return crew from null aircraft";
        false
    };
    
    // Get all crew
    private _crew = crew _aircraft;
    
    // Return each crew member to roster
    {
        if (_x getVariable ["HANGAR_isPilot", false]) then {
            [_x] call HANGAR_fnc_returnPilotToRoster;
        };
    } forEach _crew;
    
    true
};

// Add global function for emergency AI enablement
HANGAR_fnc_enableAllPilotAI = {
    { 
        if (_x getVariable ["HANGAR_isPilot", false]) then { 
            _x enableAI "ALL"; 
            _x enableAI "TARGET"; 
            _x enableAI "AUTOTARGET"; 
            _x setBehaviour "COMBAT"; 
            _x setCombatMode "RED"; 
            systemChat format ["Re-enabled AI for pilot: %1", name _x]; 
        }; 
    } forEach allUnits;
};

// Add as missionNamespace function for easy debug console access
missionNamespace setVariable ["enableAllPilotAI", HANGAR_fnc_enableAllPilotAI, true];

// Functions for external systems to use
// Add a specific unit as a pilot to the roster
fnc_addPilotToHangarRoster = {
    params ["_unit", ["_specialization", "Fighters"]];
    [_unit, _specialization] call HANGAR_fnc_addExistingPilotToRoster
};

// Return a specific unit to the roster
fnc_returnPilotToHangarRoster = {
    params ["_unit"];
    [_unit] call HANGAR_fnc_returnPilotToRoster
};

// Add this to ensure pilots are actually created with AI
[] spawn {
    diag_log "PILOT: Starting emergency AI activation watchdog";
    
    while {true} do {
        {
            if (_x getVariable ["HANGAR_isPilot", false]) then {
                // Ensure ALL AI is always enabled for all pilots
                _x enableAI "ALL";
                _x enableAI "TARGET";
                _x enableAI "AUTOTARGET";
                _x enableAI "MOVE";
                _x enableAI "FSM";
                _x enableAI "PATH";
                
                // Ensure combat settings
                _x setBehaviour "COMBAT";
                _x setCombatMode "RED";
                _x allowFleeing 0;
                _x setCaptive false;
                
                // Re-enable simulation if needed
                if (!simulationEnabled _x) then {
                    _x enableSimulationGlobal true;
                };
            };
        } forEach allUnits;
        
        sleep 30; // Check every 30 seconds to avoid too much overhead
    };
};