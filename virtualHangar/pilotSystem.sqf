// REPLACE THE ENTIRE pilotSystem.sqf FILE WITH THIS VERSION
// This fixes all potential issues in one go

// Virtual Hangar System - Pilot Management
// Handles pilot roster, progression, and assignment

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
    
    if (isNull _unit) exitWith {-1};
    
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
    diag_log format ["Added pilot to roster: %1 (index: %2, rank: %3)", _pilotName, _newIndex, [_rankIndex] call HANGAR_fnc_getPilotRankName];
    
    _newIndex
};

// Function to update pilot stats
HANGAR_fnc_updatePilotStats = {
    params ["_pilotIndex", "_key", "_value"];
    
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) exitWith {false};
    
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
                    diag_log format ["Pilot %1 promoted to %2", _pilotData select 0, _newRankName];
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
                diag_log format ["Pilot %1 is now an Ace with %2 kills", _pilotData select 0, _pilotData select 3];
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

// FIXED - Function to check if pilot is available
// This now ALWAYS returns a boolean
HANGAR_fnc_isPilotAvailable = {
    params ["_pilotIndex"];
    
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) exitWith {
        diag_log format ["isPilotAvailable: Invalid index %1", _pilotIndex];
        false
    };
    
    private _pilotData = HANGAR_pilotRoster select _pilotIndex;
    private _aircraft = _pilotData select 5;
    
    // Make sure we return a boolean
    private _result = isNull _aircraft;
    
    // Debug
    diag_log format ["isPilotAvailable: Pilot %1 available: %2", _pilotIndex, _result];
    
    // Return the boolean
    _result
};

// Function to assign a pilot to an aircraft
HANGAR_fnc_assignPilotToAircraft = {
    params ["_pilotIndex", "_aircraft", ["_role", "driver"], ["_turretPath", []]];
    
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) exitWith {
        systemChat "Invalid pilot index";
        objNull
    };
    
    if (isNull _aircraft) exitWith {
        systemChat "Invalid aircraft";
        objNull
    };
    
    // Direct check if pilot is available
    private _pilotData = HANGAR_pilotRoster select _pilotIndex;
    private _currentAircraft = _pilotData select 5;
    
    if (!isNull _currentAircraft) exitWith {
        systemChat "Pilot is already assigned to an aircraft";
        objNull
    };
    
    // Get pilot data
    private _pilotName = _pilotData select 0;
    private _rankIndex = _pilotData select 1;
    private _rankName = [_rankIndex] call HANGAR_fnc_getPilotRankName;
    
    // Use marker position for pilot spawn
    private _spawnPos = HANGAR_pilotSpawnPosition;
    
    // Create the unit
    private _side = side player;
    private _group = createGroup [_side, true];
    private _unit = _group createUnit ["LIB_UK_Pilot", _spawnPos, [], 0, "NONE"];
    
    // Set name and other attributes
    _unit setName _pilotName;
    _unit setUnitRank getText (configFile >> "CfgRanks" >> str _rankIndex >> "displayName");
    _unit setVariable ["HANGAR_isPilot", true, true];
    _unit setVariable ["HANGAR_pilotIndex", _pilotIndex, true];
    
    // Update pilot data to show assigned to this aircraft
    [_pilotIndex, "assignment", _aircraft] call HANGAR_fnc_updatePilotStats;
    
    // Set skill based on rank
    private _skillMultiplier = [_rankIndex] call HANGAR_fnc_getPilotSkillMultiplier;
    _unit setSkill (_skillMultiplier * 0.7); // Base skill of 0.7 modified by rank
    
    // Make unit temporarily editable in Zeus
    private _curator = getAssignedCuratorLogic player;
    if (!isNull _curator) then {
        _curator addCuratorEditableObjects [[_unit], false];
    };
    
    // Set pilot movement
    HANGAR_pilotRunning = true;
    
    // Have the pilot run to aircraft
    _unit doMove (getPos _aircraft);
    _unit setSpeedMode "FULL";
    
    // Wait until pilot is near aircraft
    [_unit, _aircraft, _role, _turretPath, _pilotIndex] spawn {
        params ["_unit", "_aircraft", "_role", "_turretPath", "_pilotIndex"];
        
        waitUntil {
            sleep 0.5;
            (_unit distance _aircraft < 5) || !alive _unit || !alive _aircraft
        };
        
        if (alive _unit && alive _aircraft) then {
            // Determine assignment method based on role
            switch (_role) do {
                case "driver": {
                    _unit assignAsDriver _aircraft;
                    [_unit] orderGetIn true;
                };
                case "gunner": {
                    _unit assignAsGunner _aircraft;
                    [_unit] orderGetIn true;
                };
                case "commander": {
                    _unit assignAsCommander _aircraft;
                    [_unit] orderGetIn true;
                };
                case "turret": {
                    _unit assignAsTurret [_aircraft, _turretPath];
                    [_unit] orderGetIn true;
                };
                case "cargo": {
                    _unit assignAsCargo _aircraft;
                    [_unit] orderGetIn true;
                };
            };
            
            // Wait until pilot is in the aircraft
            waitUntil {
                sleep 0.5;
                vehicle _unit == _aircraft || !alive _unit || !alive _aircraft
            };
            
            if (alive _unit && alive _aircraft && vehicle _unit == _aircraft) then {
                // Make unit and aircraft not editable
                private _curator = getAssignedCuratorLogic player;
                if (!isNull _curator) then {
                    _curator removeCuratorEditableObjects [[_unit], true];
                    _curator removeCuratorEditableObjects [[_aircraft], true];
                };
                
                // Mark aircraft as deployed
                _aircraft setVariable ["HANGAR_deployed", true, true];
                _aircraft setVariable ["HANGAR_pilotIndex", _pilotIndex, true];
                
                systemChat format ["%1 is now piloting the aircraft", name _unit];
                diag_log format ["Pilot %1 now in aircraft", name _unit];
            };
        };
        
        HANGAR_pilotRunning = false;
    };
    
    // Return the created unit
    _unit
};

// COMPLETELY REWRITTEN FUNCTION
// Function to assign pilot to a stored aircraft (for UI)
HANGAR_fnc_assignPilotToStoredAircraft = {
    params ["_pilotIndex", "_aircraftIndex", ["_role", "driver"], ["_turretPath", []]];
    
    // Direct checks with detailed logging
    diag_log format ["ASSIGN PILOT TO STORED AIRCRAFT - Pilot: %1, Aircraft: %2", _pilotIndex, _aircraftIndex];
    
    // Validate pilot index
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) exitWith {
        systemChat "Invalid pilot index";
        diag_log format ["Invalid pilot index: %1, Roster size: %2", _pilotIndex, count HANGAR_pilotRoster];
        false
    };
    
    // Validate aircraft index
    if (_aircraftIndex < 0 || _aircraftIndex >= count HANGAR_storedAircraft) exitWith {
        systemChat "Invalid aircraft index";
        diag_log format ["Invalid aircraft index: %1, Aircraft count: %2", _aircraftIndex, count HANGAR_storedAircraft];
        false
    };
    
    // Check if pilot is available - direct check without function call
    private _pilotData = HANGAR_pilotRoster select _pilotIndex;
    private _pilotAircraft = _pilotData select 5;
    
    if (!isNull _pilotAircraft) exitWith {
        systemChat "Pilot is already assigned to an aircraft";
        diag_log format ["Pilot %1 is already assigned to aircraft %2", _pilotIndex, _pilotAircraft];
        false
    };
    
    // Add pilot to aircraft crew
    private _pilotAssignment = [_pilotIndex, _role, _turretPath];
    
    // Update stored aircraft
    private _record = HANGAR_storedAircraft select _aircraftIndex;
    private _crew = _record select 5;
    _crew pushBack _pilotAssignment;
    
    systemChat format ["%1 assigned to %2", 
        (HANGAR_pilotRoster select _pilotIndex) select 0, 
        (HANGAR_storedAircraft select _aircraftIndex) select 1
    ];
    
    diag_log format ["Successfully assigned pilot %1 to stored aircraft %2", 
        (HANGAR_pilotRoster select _pilotIndex) select 0, 
        (HANGAR_storedAircraft select _aircraftIndex) select 1
    ];
    
    // Also update in viewed aircraft if this is the one being viewed
    if (!isNull HANGAR_viewedAircraft) then {
        private _viewedIndex = HANGAR_selectedAircraftIndex;
        if (_viewedIndex == _aircraftIndex) then {
            [_pilotIndex, HANGAR_viewedAircraft, _role, _turretPath] call HANGAR_fnc_assignPilotToAircraft;
        };
    };
    
    true
};

// Function to handle returning a pilot to roster
HANGAR_fnc_returnPilotToRoster = {
    params ["_unit"];
    
    if (isNull _unit) exitWith {false};
    
    // Get pilot index
    private _pilotIndex = _unit getVariable ["HANGAR_pilotIndex", -1];
    
    if (_pilotIndex < 0) exitWith {
        systemChat "Unit is not a managed pilot";
        false
    };
    
    // Update pilot assignment
    [_pilotIndex, "assignment", objNull] call HANGAR_fnc_updatePilotStats;
    
    // Delete the unit
    private _name = name _unit;
    deleteVehicle _unit;
    
    systemChat format ["%1 has returned to the pilot roster", _name];
    diag_log format ["Pilot %1 returned to roster", _name];
    true
};

// When an aircraft is stored, return all crew members to roster
HANGAR_fnc_returnCrewToRoster = {
    params ["_aircraft"];
    
    if (isNull _aircraft) exitWith {false};
    
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

// Create trigger to return pilots to roster if near hangar
if (isServer) then {
    private _returnTrigger = createTrigger ["EmptyDetector", HANGAR_viewPosition, false];
    _returnTrigger setTriggerArea [500, 500, 0, false, 100];
    _returnTrigger setTriggerActivation ["ANY", "PRESENT", true];
    _returnTrigger setTriggerStatements [
        "this && {({_x getVariable ['HANGAR_isPilot', false] && vehicle _x == _x} count thisList) > 0}",
        "
            {
                if (_x getVariable ['HANGAR_isPilot', false] && vehicle _x == _x) then {
                    private _pilotIndex = _x getVariable ['HANGAR_pilotIndex', -1];
                    if (_pilotIndex >= 0) then {
                        private _name = name _x;
                        [_pilotIndex, 'assignment', objNull] call HANGAR_fnc_updatePilotStats;
                        deleteVehicle _x;
                        systemChat format ['%1 has returned to the pilot roster', _name];
                    };
                };
            } forEach thisList;
        ",
        ""
    ];
    _returnTrigger setTriggerInterval 2;
};

// HANDLE ZEUS EDITABILITY FOR MANAGED OBJECTS
// Create a repeating check to handle Zeus editability
[] spawn {
    // Wait until Zeus interface is initialized
    waitUntil {!isNull (findDisplay 312)};
    sleep 1;
    
    // Log that we're starting the monitor
    diag_log "Starting Virtual Hangar Zeus editability monitor";
    
    // Continuous check
    while {true} do {
        // Get curator logic
        private _curator = getAssignedCuratorLogic player;
        
        if (!isNull _curator) then {
            // Find all managed objects
            {
                // If object is a pilot or managed aircraft
                if (_x getVariable ["HANGAR_isPilot", false] || 
                    _x getVariable ["HANGAR_managedAircraft", false]) then {
                    
                    // If it's somehow editable, remove it
                    if (_x in curatorEditableObjects _curator) then {
                        _curator removeCuratorEditableObjects [[_x], true];
                    };
                };
            } forEach (allUnits + vehicles);
        };
        
        // Check every 5 seconds
        sleep 5;
    };
};

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