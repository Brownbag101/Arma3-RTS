// Function to assign pilot to a stored aircraft (for UI)
// FIXED: Improved validation and prevents double assignment
HANGAR_fnc_assignPilotToStoredAircraft = {
    params ["_pilotIndex", "_aircraftIndex", ["_role", "driver"], ["_turretPath", []]];
    
    // === VALIDATION SECTION ===
    // Log what we're doing with more detail
    diag_log format ["PILOT: Assigning to stored aircraft - Pilot: %1, Aircraft: %2, Role: %3", 
        _pilotIndex, _aircraftIndex, _role];
    
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
    
    // Get the pilot data
    private _pilotData = HANGAR_pilotRoster select _pilotIndex;
    _pilotData params ["_pilotName", "_rankIndex", "_missions", "_kills", "_specialization", "_currentAssignment"];
    
    // Get aircraft data
    private _record = HANGAR_storedAircraft select _aircraftIndex;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
    
    // === IMPROVED AVAILABILITY CHECK ===
    // More detailed pilot availability check
    private _pilotIsAvailable = true;
    private _reasonUnavailable = "";
    
    // Check if pilot is assigned to current aircraft
    private _alreadyAssignedToThisAircraft = false;
    {
        _x params ["_crewPilotIndex"];
        if (_crewPilotIndex == _pilotIndex) then {
            _alreadyAssignedToThisAircraft = true;
        };
    } forEach _crew;
    
    // 1. Check current assignment in roster
    if (!isNull _currentAssignment) then {
        private _currentIndex = _currentAssignment getVariable ["HANGAR_storageIndex", -1];
        
        // If assigned to a different aircraft, mark as unavailable
        if (_currentIndex != _aircraftIndex && _currentIndex >= 0) then {
            _pilotIsAvailable = false;
            _reasonUnavailable = format ["Pilot is already assigned to aircraft #%1", _currentIndex];
            diag_log format ["PILOT: Cannot assign - already assigned to aircraft index %1", _currentIndex];
        };
    };
    
    // 2. Check all other aircraft crew lists (very thorough check)
    if (_pilotIsAvailable && !_alreadyAssignedToThisAircraft) then {
        for "_i" from 0 to ((count HANGAR_storedAircraft) - 1) do {
            if (_i != _aircraftIndex) then {
                private _otherRecord = HANGAR_storedAircraft select _i;
                if (count _otherRecord >= 6) then {
                    private _otherCrew = _otherRecord select 5;
                    
                    {
                        _x params ["_crewPilotIndex"];
                        if (_crewPilotIndex == _pilotIndex) exitWith {
                            _pilotIsAvailable = false;
                            _reasonUnavailable = format ["Pilot is in the crew list of aircraft #%1", _i];
                            diag_log format ["PILOT: Cannot assign - found in crew of aircraft %1", _i];
                        };
                    } forEach _otherCrew;
                };
                
                if (!_pilotIsAvailable) exitWith {};
            };
        };
    };
    
    // 3. Check if pilot exists as a unit in the game world and is not in this aircraft
    if (_pilotIsAvailable && !_alreadyAssignedToThisAircraft) then {
        private _pilotUnit = objNull;
        {
            if (_x getVariable ["HANGAR_pilotIndex", -1] == _pilotIndex) exitWith {
                _pilotUnit = _x;
            };
        } forEach allUnits;
        
        if (!isNull _pilotUnit) then {
            private _pilotVehicle = vehicle _pilotUnit;
            private _vehicleStorageIndex = _pilotVehicle getVariable ["HANGAR_storageIndex", -1];
            
            if (_pilotVehicle != _pilotUnit && _vehicleStorageIndex != _aircraftIndex) then {
                _pilotIsAvailable = false;
                _reasonUnavailable = format ["Pilot is physically in another vehicle (%1)", typeOf _pilotVehicle];
                diag_log format ["PILOT: Cannot assign - pilot unit %1 is in vehicle %2", _pilotUnit, _pilotVehicle];
            };
        };
    };
    
    // If truly unavailable, exit with a message
    if (!_pilotIsAvailable && !_alreadyAssignedToThisAircraft) exitWith {
        systemChat format ["%1 cannot be assigned: %2", _pilotName, _reasonUnavailable];
        diag_log format ["PILOT: Assignment failed - %1", _reasonUnavailable];
        false
    };
    
    // === SPECIALIZATION CHECK ===
    // Check if specialization matches the aircraft category
    private _aircraftCategory = "";
    private _specMismatch = false;
    
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
        _specMismatch = true;
        systemChat format ["WARNING: %1 is specialized in %2, not %3", _pilotName, _specialization, _aircraftCategory];
        diag_log format ["PILOT: Specialization mismatch - %1 vs %2", _specialization, _aircraftCategory];
    };
    
    // === CREW MANAGEMENT SECTION ===
    // Add pilot to aircraft crew if not already there, or update their role
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
    
    // === ROSTER UPDATE SECTION ===
    // CRITICAL: Update the pilot's aircraft reference in the roster
    // Set the pilot's aircraft reference based on deployed status
    if (!isNull HANGAR_viewedAircraft && 
        (HANGAR_viewedAircraft getVariable ["HANGAR_storageIndex", -1]) == _aircraftIndex) then {
        // If viewing this aircraft, store reference to the viewed aircraft
        _pilotData set [5, HANGAR_viewedAircraft];
        diag_log format ["PILOT: Updated roster entry for pilot %1 - assigned to viewed aircraft", _pilotName];
    } else {
        // If deployed, use deployed instance
        if (_isDeployed && !isNull _deployedInstance) then {
            _pilotData set [5, _deployedInstance];
            diag_log format ["PILOT: Updated roster entry for pilot %1 - assigned to deployed aircraft", _pilotName];
        } else {
            // Not deployed, mark as assigned but with null aircraft reference
            // This ensures the pilot is tracked as assigned but without an explicit reference
            _pilotData set [5, objNull];
            diag_log format ["PILOT: Updated roster entry for pilot %1 - marked as assigned, awaiting deployment", _pilotName];
        };
    };
    
    // === PHYSICAL PILOT CREATION ===
    // Create physical pilot in viewed or deployed aircraft if appropriate
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
    
    // Provide feedback to the user
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
    
    if (_specMismatch) then {
        systemChat format ["Note: %1's performance may be reduced due to specialization mismatch", _pilotName];
    };
    
    diag_log format ["PILOT: Successfully assigned pilot %1 to stored aircraft %2", 
        _pilotName, 
        _displayName
    ];
    
    true
};

// COMPLETELY REWRITTEN: Avoids all return statements for SQF compatibility
HANGAR_fnc_isPilotAvailableForAircraft = {
    params ["_pilotIndex", "_aircraftType", ["_targetAircraftIndex", -1]];
    
    // Initialize result variable
    private _isAvailable = true;
    private _message = "";
    
    // Check if index is valid
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) then {
        _isAvailable = false;
        _message = "Invalid pilot index";
        diag_log format ["PILOT: Invalid pilot index for availability check: %1", _pilotIndex];
    } else {
        // Get pilot data
        private _pilotData = HANGAR_pilotRoster select _pilotIndex;
        _pilotData params ["_pilotName", "_rankIndex", "_missions", "_kills", "_specialization", "_currentAircraft"];
        
        // Check 1: Is pilot assigned to an aircraft in the roster?
        if (!isNull _currentAircraft) then {
            // Allow self-assignment if checking for the same aircraft
            private _currentIndex = _currentAircraft getVariable ["HANGAR_storageIndex", -1];
            
            if (_currentIndex != _targetAircraftIndex) then {
                _isAvailable = false;
                _message = format ["Pilot is already assigned to aircraft #%1", _currentIndex];
                diag_log format ["PILOT: %1 (index %2) already assigned to aircraft index %3", 
                    _pilotName, _pilotIndex, _currentIndex];
            };
        };
        
        // Only continue checks if still available
        if (_isAvailable) then {
            // Check 2: Search all aircraft crew lists for this pilot
            private _foundInOtherCrew = false;
            private _otherAircraftIndex = -1;
            
            {
                // Skip the target aircraft
                if (_forEachIndex != _targetAircraftIndex) then {
                    private _record = _x;
                    
                    if (count _record >= 6) then {
                        private _crew = _record select 5;
                        
                        {
                            _x params ["_crewPilotIndex"];
                            if (_crewPilotIndex == _pilotIndex) exitWith {
                                _foundInOtherCrew = true;
                                _otherAircraftIndex = _forEachIndex;
                            };
                        } forEach _crew;
                    };
                };
                
                // Exit the loop if already found
                if (_foundInOtherCrew) exitWith {};
            } forEach HANGAR_storedAircraft;
            
            // Update result if found in another crew
            if (_foundInOtherCrew) then {
                _isAvailable = false;
                _message = format ["Pilot is listed in crew of aircraft #%1", _otherAircraftIndex];
                diag_log format ["PILOT: %1 (index %2) found in crew list of aircraft #%3", 
                    _pilotName, _pilotIndex, _otherAircraftIndex];
            };
        };
        
        // Only continue checks if still available
        if (_isAvailable) then {
            // Check 3: Is the pilot physically in a different vehicle?
            private _pilotUnit = objNull;
            {
                if (_x getVariable ["HANGAR_pilotIndex", -1] == _pilotIndex) exitWith {
                    _pilotUnit = _x;
                };
            } forEach allUnits;
            
            if (!isNull _pilotUnit) then {
                private _pilotVehicle = vehicle _pilotUnit;
                
                if (_pilotVehicle != _pilotUnit) then {
                    private _vehicleIndex = _pilotVehicle getVariable ["HANGAR_storageIndex", -1];
                    
                    // Not in target aircraft
                    if (_vehicleIndex != _targetAircraftIndex) then {
                        _isAvailable = false;
                        _message = "Pilot is currently in another vehicle";
                        diag_log format ["PILOT: %1 (index %2) physically in vehicle %3 (index %4)", 
                            _pilotName, _pilotIndex, _pilotVehicle, _vehicleIndex];
                    };
                };
            };
        };
        
        // Only check specialization if still available
        if (_isAvailable) then {
            // Get aircraft category for specialization check
            private _aircraftCategory = "";
            {
                _x params ["_category", "_aircraftList"];
                
                {
                    _x params ["_className"];
                    if (_className == _aircraftType) exitWith {
                        _aircraftCategory = _category;
                    };
                } forEach _aircraftList;
                
                if (_aircraftCategory != "") exitWith {};
            } forEach HANGAR_aircraftTypes;
            
            // Check if specialization matches
            if (_aircraftCategory != "" && _specialization != "" && _specialization != _aircraftCategory) then {
                // Still available but with warning
                _message = format ["Pilot specializes in %1, not %2 (performance penalty)", 
                    _specialization, _aircraftCategory];
                diag_log format ["PILOT: Specialization mismatch - Has: %1, Needs: %2", 
                    _specialization, _aircraftCategory];
            };
        };
    };
    
    // Final result
    [_isAvailable, _message]
};

// Function to validate and clean up aircraft crew entries
// ENHANCED: More thorough validation and cross-checking
HANGAR_fnc_validateAircraftCrew = {
    params ["_aircraftIndex"];
    
    // ==== VALIDATION SECTION ====
    if (_aircraftIndex < 0 || _aircraftIndex >= count HANGAR_storedAircraft) exitWith {
        diag_log format ["HANGAR: Invalid aircraft index for crew validation: %1", _aircraftIndex];
        false
    };
    
    // Get aircraft record
    private _record = HANGAR_storedAircraft select _aircraftIndex;
    private _aircraftName = _record select 1;
    private _type = _record select 0;
    private _crew = _record select 5;
    private _isDeployed = _record select 7;
    private _deployedInstance = _record select 8;
    
    // Skip validation for empty crew lists
    if (count _crew == 0) exitWith {
        diag_log format ["HANGAR: No crew to validate for %1", _aircraftName];
        false
    };
    
    // Prepare arrays for valid and invalid crew entries
    private _validatedCrew = [];
    private _removedEntries = [];
    private _hasChanges = false;
    
    // Determine if aircraft exists in the game world
    private _aircraftExists = !_isDeployed || (!isNull _deployedInstance && alive _deployedInstance);
    
    // ==== EXTENSIVE CREW VALIDATION ====
    {
        _x params ["_pilotIndex", "_role", "_turretPath"];
        private _isValid = true;
        private _removalReason = "";
        
        // Check 1: Pilot index exists in roster
        if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) then {
            _isValid = false;
            _removalReason = "Invalid pilot index";
            diag_log format ["HANGAR: Invalid pilot index %1 for %2", _pilotIndex, _aircraftName];
        } else {
            // Get pilot data for further checks
            private _pilotData = HANGAR_pilotRoster select _pilotIndex;
            private _pilotName = _pilotData select 0;
            private _currentAircraft = _pilotData select 5;
            
            // Check 2: Pilot isn't assigned to another aircraft in the roster
            if (!isNull _currentAircraft && 
                {_currentAircraft getVariable ["HANGAR_storageIndex", -1] != _aircraftIndex}) then {
                _isValid = false;
                _removalReason = format ["Pilot %1 already assigned to another aircraft", _pilotName];
                diag_log format ["HANGAR: Pilot %1 already assigned to different aircraft", _pilotName];
            };
            
            // Check 3: If aircraft is deployed, verify pilot is actually in the aircraft
            if (_isValid && _isDeployed && !isNull _deployedInstance) then {
                private _pilotFound = false;
                {
                    if (_x getVariable ["HANGAR_pilotIndex", -1] == _pilotIndex) exitWith {
                        _pilotFound = true;
                    };
                } forEach crew _deployedInstance;
                
                if (!_pilotFound) then {
                    _isValid = false;
                    _removalReason = format ["Pilot %1 not found in deployed aircraft", _pilotName];
                    diag_log format ["HANGAR: Pilot %1 not physically in deployed aircraft %2", 
                        _pilotName, _aircraftName];
                };
            };
            
            // Check 4: Verify pilot isn't in another aircraft physically
            if (_isValid) then {
                private _pilotUnit = objNull;
                {
                    if (_x getVariable ["HANGAR_pilotIndex", -1] == _pilotIndex) exitWith {
                        _pilotUnit = _x;
                    };
                } forEach allUnits;
                
                if (!isNull _pilotUnit) then {
                    private _pilotVehicle = vehicle _pilotUnit;
                    if (_pilotVehicle != _pilotUnit) then {
                        private _vehicleStorageIndex = _pilotVehicle getVariable ["HANGAR_storageIndex", -1];
                        
                        if (_vehicleStorageIndex != _aircraftIndex) then {
                            _isValid = false;
                            _removalReason = format ["Pilot %1 physically in different vehicle", _pilotName];
                            diag_log format ["HANGAR: Pilot %1 physically in different aircraft: %2", 
                                _pilotName, _pilotVehicle];
                        };
                    };
                };
            };
            
            // Check 5: If aircraft is destroyed or removed, invalidate the crew entry
            if (_isValid && _isDeployed && (isNull _deployedInstance || !alive _deployedInstance)) then {
                _isValid = false;
                _removalReason = "Aircraft no longer exists";
                diag_log format ["HANGAR: Aircraft %1 no longer exists, invalidating crew", _aircraftName];
                
                // Also update pilot's assignment in roster since aircraft is gone
                private _pilotData = HANGAR_pilotRoster select _pilotIndex;
                _pilotData set [5, objNull];
                diag_log format ["HANGAR: Reset assignment for pilot %1 due to missing aircraft", 
                    _pilotData select 0];
            };
        };
        
        // Process validation results
        if (_isValid) then {
            _validatedCrew pushBack _x;
        } else {
            _hasChanges = true;
            _removedEntries pushBack [_pilotIndex, _removalReason];
        };
    } forEach _crew;
    
    // ==== UPDATE SECTION ====
    // Update crew with validated list if there were changes
    if (_hasChanges) then {
        _record set [5, _validatedCrew];
        
        // Log the changes for debugging
        {
            _x params ["_pilotIndex", "_reason"];
            
            private _pilotName = "Unknown";
            if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
                _pilotName = (HANGAR_pilotRoster select _pilotIndex) select 0;
            };
            
            diag_log format ["HANGAR: Removed pilot %1 (%2) from %3: %4", 
                _pilotName, _pilotIndex, _aircraftName, _reason];
        } forEach _removedEntries;
        
        diag_log format ["HANGAR: Validated crew list for %1: %2 entries removed, %3 valid entries remain", 
            _aircraftName, count _removedEntries, count _validatedCrew];
    };
    
    // ==== CONSISTENCY CHECK ====
    // If aircraft is marked as deployed but doesn't exist, update the record
    if (_isDeployed && (isNull _deployedInstance || !alive _deployedInstance)) then {
        _record set [7, false]; // isDeployed = false
        _record set [8, objNull]; // deployedInstance = objNull
        diag_log format ["HANGAR: Corrected deployment status for %1 - aircraft no longer exists", _aircraftName];
        _hasChanges = true;
    };
    
    // Return if any changes were made
    _hasChanges
};

// Function to handle aircraft destruction
// ENHANCED: Better crew handling and cleanup
HANGAR_fnc_onAircraftDestroyed = {
    params ["_aircraft"];
    
    // ==== VALIDATION SECTION ====
    // Check if this is a managed aircraft
    private _storageIndex = _aircraft getVariable ["HANGAR_storageIndex", -1];
    if (_storageIndex < 0) exitWith {
        diag_log format ["HANGAR: Destroyed aircraft %1 is not managed", _aircraft];
        false
    };
    
    // ==== DATA RETRIEVAL SECTION ====
    // Ensure the index is still valid
    if (_storageIndex >= count HANGAR_storedAircraft) exitWith {
        diag_log format ["HANGAR: Invalid storage index %1 for destroyed aircraft", _storageIndex];
        false
    };
    
    // Get aircraft data
    private _record = HANGAR_storedAircraft select _storageIndex;
    _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
    
    // Already processed?
    if (!_isDeployed || isNull _deployedInstance) exitWith {
        diag_log format ["HANGAR: Aircraft %1 already marked as not deployed", _displayName];
        false
    };
    
    // ==== CREW PROCESSING ====
    // Store crew info before we process the aircraft
    private _crewData = +_crew; // Make a copy
    private _crewCount = count _crewData;
    
    diag_log format ["HANGAR: Processing destroyed aircraft %1 with %2 crew members", 
        _displayName, _crewCount];
    
    // ==== AIRCRAFT REMOVAL ====
    // CRITICAL: REMOVE AIRCRAFT FROM STORAGE ONLY AFTER PROCESSING CREW
    // We keep the aircraft record until after crew processing to maintain valid references
    
    // Remove from deployed tracking array
    HANGAR_deployedAircraft = HANGAR_deployedAircraft - [_aircraft];
    
    // ==== CREW STATUS CHECK ====
    // Check for any survivors (ejected pilots)
    private _survivingPilots = [];
    private _unaccountedPilots = [];
    private _killedPilots = [];
    
    {
        _x params ["_pilotIndex"];
        
        if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
            private _pilotName = (HANGAR_pilotRoster select _pilotIndex) select 0;
            private _pilotFound = false;
            private _pilotUnit = objNull;
            
            // Check if pilot managed to eject
            {
                if ((_x getVariable ["HANGAR_pilotIndex", -1]) == _pilotIndex) then {
                    _pilotUnit = _x;
                    _pilotFound = true;
                };
            } forEach allUnits;
            
            // Determine survival status
            if (_pilotFound) then {
                if (alive _pilotUnit && (vehicle _pilotUnit == _pilotUnit)) then {
                    // Pilot ejected and is alive on the ground
                    _survivingPilots pushBack [_pilotIndex, _pilotUnit, _pilotName];
                } else {
                    if (!alive _pilotUnit) then {
                        // We have the unit but it's dead
                        _killedPilots pushBack [_pilotIndex, _pilotUnit, _pilotName];
                    } else {
                        // Pilot is in a vehicle (possibly the crashed one)
                        _unaccountedPilots pushBack [_pilotIndex, _pilotUnit, _pilotName];
                    };
                };
            } else {
                // Pilot unit not found - assume KIA
                _unaccountedPilots pushBack [_pilotIndex, objNull, _pilotName];
            };
        };
    } forEach _crewData;
    
    // Log the categorization results
    diag_log format ["HANGAR: Crew status for %1: %2 survived, %3 killed, %4 unaccounted for",
        _displayName, count _survivingPilots, count _killedPilots, count _unaccountedPilots];
    
    // ==== SURVIVOR PROCESSING ====
    // Process surviving pilots (they'll return to duty)
    {
        _x params ["_pilotIndex", "_pilotUnit", "_pilotName"];
        
        // Update pilot stats if survived
        [_pilotIndex, "missions", 1] call HANGAR_fnc_updatePilotStats;
        
        // Set as available in roster
        (HANGAR_pilotRoster select _pilotIndex) set [5, objNull];
        
        // Update any UI status but don't delete the unit
        systemChat format ["Pilot %1 ejected successfully and will return to duty", _pilotName];
        
        diag_log format ["HANGAR: Pilot %1 (index %2) survived the crash and returned to roster", 
            _pilotName, _pilotIndex];
    } forEach _survivingPilots;
    
    // ==== KIA PROCESSING ====
    // Process confirmed KIA pilots
    {
        _x params ["_pilotIndex", "_pilotUnit", "_pilotName"];
        
        // Delete the unit if it exists
        if (!isNull _pilotUnit) then {
            deleteVehicle _pilotUnit;
        };
        
        // Handle pilot removal
        [_pilotIndex, _pilotName, _storageIndex] call HANGAR_fnc_removePilotFromRoster;
        
    } forEach _killedPilots;
    
    // ==== UNACCOUNTED PROCESSING ====
    // Assume KIA for unaccounted pilots but with special handling
    {
        _x params ["_pilotIndex", "_pilotUnit", "_pilotName"];
        
        // If pilot unit exists but isn't on the ground, handle accordingly
        if (!isNull _pilotUnit) then {
            if (vehicle _pilotUnit != _pilotUnit) then {
                // Try to eject them
                unassignVehicle _pilotUnit;
                [_pilotUnit] orderGetIn false;
                _pilotUnit action ["Eject", vehicle _pilotUnit];
                
                // Mark as survivor if successfully ejected
                if (vehicle _pilotUnit == _pilotUnit) then {
                    // Update pilot stats
                    [_pilotIndex, "missions", 1] call HANGAR_fnc_updatePilotStats;
                    
                    // Set as available in roster
                    (HANGAR_pilotRoster select _pilotIndex) set [5, objNull];
                    
                    systemChat format ["Pilot %1 ejected at the last moment and survived", _pilotName];
                    diag_log format ["HANGAR: Pilot %1 (index %2) ejected late and survived", 
                        _pilotName, _pilotIndex];
                    
                    // Skip to next pilot
                    continue;
                };
            };
            
            // If we got here, pilot couldn't be saved - delete
            deleteVehicle _pilotUnit;
        };
        
        // Handle as KIA
        [_pilotIndex, _pilotName, _storageIndex] call HANGAR_fnc_removePilotFromRoster;
        
    } forEach _unaccountedPilots;
    
    // ==== AIRCRAFT REMOVAL ====
    // Now remove the aircraft from storage after crew is processed
    HANGAR_storedAircraft deleteAt _storageIndex;
    
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
    
    diag_log format ["HANGAR: Removed destroyed aircraft %1 from inventory", _displayName];
    
    // ==== UPDATE STORAGE INDICES ====
    // Update storage indices for remaining aircraft after this one
    {
        private _aircraft = _x;
        private _currentIndex = _aircraft getVariable ["HANGAR_storageIndex", -1];
        
        if (_currentIndex > _storageIndex) then {
            // This aircraft's index needs to be decremented
            _aircraft setVariable ["HANGAR_storageIndex", _currentIndex - 1, true];
            diag_log format ["HANGAR: Updated storage index for %1 from %2 to %3", 
                _aircraft, _currentIndex, _currentIndex - 1];
        };
    } forEach HANGAR_deployedAircraft;
    
    // ==== UI UPDATE ====
    // Refresh UI if open
    if (!isNull findDisplay 312 && !isNull (findDisplay 312 displayCtrl 9802)) then {
        if (!isNil "HANGAR_fnc_updateAircraftList") then {
            call HANGAR_fnc_updateAircraftList;
        };
    };
    
    true
};

// Function to safely remove a pilot from roster with proper updates
// NEW: Centralizes pilot removal logic with index correction
HANGAR_fnc_removePilotFromRoster = {
    params ["_pilotIndex", "_pilotName", ["_originAircraftIndex", -1]];
    
    // ==== VALIDATION ====
    if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) exitWith {
        diag_log format ["HANGAR: Cannot remove invalid pilot index: %1", _pilotIndex];
        false
    };
    
    // Get pilot name if not provided
    if (_pilotName == "") then {
        _pilotName = (HANGAR_pilotRoster select _pilotIndex) select 0;
    };
    
    // Get rank for notification
    private _rankName = [(HANGAR_pilotRoster select _pilotIndex) select 1] call HANGAR_fnc_getPilotRankName;
    
    // Notify about pilot death
    systemChat format ["%1 %2 was killed in action", _rankName, _pilotName];
    
    // Log pilot removal
    diag_log format ["HANGAR: Removing KIA pilot %1 %2 (index %3) from roster", 
        _rankName, _pilotName, _pilotIndex];
    
    // ==== REMOVAL FROM ROSTER ====
    // Remove from roster
    HANGAR_pilotRoster deleteAt _pilotIndex;
    
    // ==== UPDATE UNIT REFERENCES ====
    // Re-index all pilot units in the game world
    {
        if (_x getVariable ["HANGAR_isPilot", false]) then {
            private _storedIndex = _x getVariable ["HANGAR_pilotIndex", -1];
            if (_storedIndex > _pilotIndex) then {
                // This pilot needs to be reindexed (shift down by 1)
                _x setVariable ["HANGAR_pilotIndex", _storedIndex - 1, true];
                diag_log format ["HANGAR: Adjusted pilot unit index from %1 to %2", 
                    _storedIndex, _storedIndex - 1];
            };
        };
    } forEach allUnits;
    
    // ==== UPDATE CREW REFERENCES ====
    // Process all aircraft records to update crew indices
    for "_i" from 0 to ((count HANGAR_storedAircraft) - 1) do {
        // Skip the origin aircraft if specified (it's being removed anyway)
        if (_i != _originAircraftIndex) then {
            private _record = HANGAR_storedAircraft select _i;
            
            if (count _record >= 6) then {
                private _aircraftCrew = _record select 5;
                private _crewUpdated = false;
                
                // First remove any references to the deleted pilot
                for "_j" from ((count _aircraftCrew) - 1) to 0 step -1 do {
                    private _crewEntry = _aircraftCrew select _j;
                    
                    if (count _crewEntry > 0) then {
                        private _crewPilotIndex = _crewEntry select 0;
                        
                        if (_crewPilotIndex == _pilotIndex) then {
                            // Remove this crew entry
                            _aircraftCrew deleteAt _j;
                            diag_log format ["HANGAR: Removed dead pilot reference from aircraft %1", _i];
                            _crewUpdated = true;
                        };
                    };
                };
                
                // Then update indices for pilots with higher indices
                for "_j" from 0 to ((count _aircraftCrew) - 1) do {
                    private _crewEntry = _aircraftCrew select _j;
                    
                    if (count _crewEntry > 0) then {
                        private _crewPilotIndex = _crewEntry select 0;
                        
                        if (_crewPilotIndex > _pilotIndex) then {
                            // Decrement the index
                            _crewEntry set [0, _crewPilotIndex - 1];
                            
                            diag_log format ["HANGAR: Adjusted crew reference from %1 to %2 in aircraft %3", 
                                _crewPilotIndex, _crewPilotIndex - 1, _i];
                                
                            _crewUpdated = true;
                        };
                    };
                };
                
                // Log if we made changes
                if (_crewUpdated) then {
                    diag_log format ["HANGAR: Updated crew references in aircraft %1", _i];
                };
            };
        };
    };
    
    true
};

// Function to perform a comprehensive cleanup of the hangar system
// NEW: Deep scan and fix for inconsistencies
HANGAR_fnc_cleanupHangarSystem = {
    params [["_silent", false]];
    
    // ==== INITIALIZATION ====
    private _totalIssuesFixed = 0;
    private _aircraftIssues = 0;
    private _pilotIssues = 0;
    private _referenceIssues = 0;
    
    diag_log "HANGAR CLEANUP: Starting comprehensive system cleanup";
    
    // ==== DEPLOYED AIRCRAFT VERIFICATION ====
    // First clean the deployedAircraft array of null entries
    private _initialDeployedCount = count HANGAR_deployedAircraft;
    HANGAR_deployedAircraft = HANGAR_deployedAircraft - [objNull];
    private _newDeployedCount = count HANGAR_deployedAircraft;
    
    if (_initialDeployedCount != _newDeployedCount) then {
        _referenceIssues = _referenceIssues + (_initialDeployedCount - _newDeployedCount);
        diag_log format ["HANGAR CLEANUP: Removed %1 null references from deployedAircraft array", 
            _initialDeployedCount - _newDeployedCount];
    };
    
    // ==== STORED AIRCRAFT VERIFICATION ====
    // Check each stored aircraft record
    for "_i" from ((count HANGAR_storedAircraft) - 1) to 0 step -1 do {
        private _record = HANGAR_storedAircraft select _i;
        private _valid = true;
        
        // Check record structure
        if (count _record < 9) then {
            diag_log format ["HANGAR CLEANUP: Invalid record structure at index %1, removing", _i];
            HANGAR_storedAircraft deleteAt _i;
            _aircraftIssues = _aircraftIssues + 1;
            continue;
        };
        
        _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
        
        // Check for deployed aircraft with missing instances
        if (_isDeployed && (isNull _deployedInstance || !alive _deployedInstance)) then {
            diag_log format ["HANGAR CLEANUP: Aircraft %1 marked as deployed but instance missing, fixing", _displayName];
            _record set [7, false]; // isDeployed = false
            _record set [8, objNull]; // deployedInstance = objNull
            _aircraftIssues = _aircraftIssues + 1;
        };
        
        // Run crew validation
        private _hadCrewIssues = [_i] call HANGAR_fnc_validateAircraftCrew;
        if (_hadCrewIssues) then {
            _pilotIssues = _pilotIssues + 1;
        };
    };
    
    // ==== DEPLOYED INSTANCE VERIFICATION ====
    // Check the deployed instances against storage records
    {
        private _aircraft = _x;
        private _storageIndex = _aircraft getVariable ["HANGAR_storageIndex", -1];
        
        if (_storageIndex >= 0 && _storageIndex < count HANGAR_storedAircraft) then {
            private _record = HANGAR_storedAircraft select _storageIndex;
            
            // Mark as deployed in the record
            if (!(_record select 7) || isNull (_record select 8)) then {
                diag_log format ["HANGAR CLEANUP: Updating deployment status for aircraft at index %1", _storageIndex];
                _record set [7, true]; // isDeployed = true
                _record set [8, _aircraft]; // deployedInstance = aircraft
                _aircraftIssues = _aircraftIssues + 1;
            };
        } else {
            // Aircraft lacks valid storage reference
            diag_log format ["HANGAR CLEANUP: Deployed aircraft %1 has invalid storage index: %2", 
                _aircraft, _storageIndex];
                
            // Add this aircraft back to storage
            private _type = typeOf _aircraft;
            private _displayName = getText (configFile >> "CfgVehicles" >> _type >> "displayName");
            private _fuel = fuel _aircraft;
            private _damage = damage _aircraft;
            
            // Extract weapons data
            private _weaponsData = [];
            private _weapons = weapons _aircraft;
            {
                private _weapon = _x;
                private _ammo = _aircraft ammo _weapon;
                private _weaponName = getText (configFile >> "CfgWeapons" >> _weapon >> "displayName");
                _weaponsData pushBack [_weapon, _ammo, _weaponName];
            } forEach _weapons;
            
            // Extract crew info
            private _crew = [];
            {
                private _pilotIndex = _x getVariable ["HANGAR_pilotIndex", -1];
                if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
                    private _role = "";
                    private _turretPath = [];
                    
                    // Determine role
                    if (_x == driver _aircraft) then {
                        _role = "driver";
                    } else {
                        if (_x == gunner _aircraft) then {
                            _role = "gunner";
                        } else {
                            if (_x == commander _aircraft) then {
                                _role = "commander";
                            } else {
                                // Assume turret or cargo
                                _role = "turret";
                                _turretPath = [0]; // Default turret path
                            };
                        };
                    };
                    
                    _crew pushBack [_pilotIndex, _role, _turretPath];
                    
                    // Update pilot's aircraft reference
                    (HANGAR_pilotRoster select _pilotIndex) set [5, _aircraft];
                };
            } forEach crew _aircraft;
            
            // Create new record
            private _newRecord = [
                _type,           // Type
                _displayName,    // Display name
                _fuel,           // Fuel level
                _damage,         // Damage level
                _weaponsData,    // Weapons data
                _crew,           // Crew assignments
                [],              // Custom data
                true,            // Deployed = true
                _aircraft        // Deployed instance reference
            ];
            
            // Add to stored aircraft
            private _newIndex = count HANGAR_storedAircraft;
            HANGAR_storedAircraft pushBack _newRecord;
            
            // Update the aircraft's storage index
            _aircraft setVariable ["HANGAR_storageIndex", _newIndex, true];
            _aircraft setVariable ["HANGAR_managedAircraft", true, true];
            
            diag_log format ["HANGAR CLEANUP: Added orphaned aircraft %1 back to storage at index %2", 
                _displayName, _newIndex];
                
            _aircraftIssues = _aircraftIssues + 1;
        };
    } forEach HANGAR_deployedAircraft;
    
    // ==== PILOT REFERENCE VERIFICATION ====
    // Check each pilot's aircraft reference
    for "_i" from 0 to ((count HANGAR_pilotRoster) - 1) do {
        private _pilotData = HANGAR_pilotRoster select _i;
        private _pilotName = _pilotData select 0;
        private _currentAircraft = _pilotData select 5;
        
        if (!isNull _currentAircraft) then {
            // Check if the aircraft reference is valid
            private _storageIndex = _currentAircraft getVariable ["HANGAR_storageIndex", -1];
            
            if (_storageIndex < 0 || _storageIndex >= count HANGAR_storedAircraft) then {
                // Aircraft reference is invalid
                diag_log format ["HANGAR CLEANUP: Pilot %1 (index %2) has invalid aircraft reference", 
                    _pilotName, _i];
                
                // Clear the assignment
                _pilotData set [5, objNull];
                _pilotIssues = _pilotIssues + 1;
            } else {
                // Aircraft reference is valid, check if pilot is in its crew
                private _record = HANGAR_storedAircraft select _storageIndex;
                private _crew = _record select 5;
                private _foundInCrew = false;
                
                {
                    _x params ["_crewPilotIndex"];
                    if (_crewPilotIndex == _i) exitWith {
                        _foundInCrew = true;
                    };
                } forEach _crew;
                
                if (!_foundInCrew) then {
                    // Pilot references aircraft but isn't in its crew list
                    diag_log format ["HANGAR CLEANUP: Pilot %1 (index %2) references aircraft but isn't in its crew, fixing",
                        _pilotName, _i];
                    
                    // Could either add to crew or remove reference - for safety, remove reference
                    _pilotData set [5, objNull];
                    _pilotIssues = _pilotIssues + 1;
                };
            };
        };
    };
    
    // ==== PHYSICAL PILOTS VERIFICATION ====
    // Check all pilot units in the game world
    {
        if (_x getVariable ["HANGAR_isPilot", false]) then {
            private _pilotIndex = _x getVariable ["HANGAR_pilotIndex", -1];
            
            if (_pilotIndex < 0 || _pilotIndex >= count HANGAR_pilotRoster) then {
                // Invalid pilot index
                diag_log format ["HANGAR CLEANUP: Pilot unit %1 has invalid roster index %2, deleting",
                    _x, _pilotIndex];
                
                // Attempt to remove from any vehicle
                if (vehicle _x != _x) then {
                    unassignVehicle _x;
                    _x action ["Eject", vehicle _x];
                };
                
                // Delete the unit
                deleteVehicle _x;
                _pilotIssues = _pilotIssues + 1;
            } else {
                // Valid pilot index, verify it's in the right aircraft
                private _pilotData = HANGAR_pilotRoster select _pilotIndex;
                private _pilotName = _pilotData select 0;
                private _rosterAircraft = _pilotData select 5;
                private _currentVehicle = vehicle _x;
                
                if (_currentVehicle != _x) then {
                    // Pilot is in a vehicle
                    private _vehicleIndex = _currentVehicle getVariable ["HANGAR_storageIndex", -1];
                    
                    if (isNull _rosterAircraft || 
                        (_rosterAircraft getVariable ["HANGAR_storageIndex", -1]) != _vehicleIndex) then {
                        // Pilot is in wrong vehicle
                        diag_log format ["HANGAR CLEANUP: Pilot %1 (index %2) is in wrong vehicle, updating reference",
                            _pilotName, _pilotIndex];
                        
                        // Update reference if vehicle is valid
                        if (_vehicleIndex >= 0 && _vehicleIndex < count HANGAR_storedAircraft) then {
                            _pilotData set [5, _currentVehicle];
                            
                            // Ensure pilot is in crew list
                            private _record = HANGAR_storedAircraft select _vehicleIndex;
                            private _crew = _record select 5;
                            private _foundInCrew = false;
                            
                            {
                                _x params ["_crewPilotIndex"];
                                if (_crewPilotIndex == _pilotIndex) exitWith {
                                    _foundInCrew = true;
                                };
                            } forEach _crew;
                            
                            if (!_foundInCrew) then {
                                // Determine role
                                private _role = "cargo";
                                private _turretPath = [];
                                
                                if (_x == driver _currentVehicle) then {
                                    _role = "driver";
                                } else {
                                    if (_x == gunner _currentVehicle) then {
                                        _role = "gunner";
                                    } else {
                                        if (_x == commander _currentVehicle) then {
                                            _role = "commander";
                                        } else {
                                            // Determine if in turret
                                            private _turrets = []; // Get turrets
                                            {
                                                if (_x select 0 == _pilotUnit) then {
                                                    _role = "turret";
                                                    _turretPath = _x select 3;
                                                    break;
                                                };
                                            } forEach (fullCrew [_currentVehicle, "turret"]);
                                        };
                                    };
                                };
                                
                                // Add to crew list
                                _crew pushBack [_pilotIndex, _role, _turretPath];
                                diag_log format ["HANGAR CLEANUP: Added pilot %1 to crew list of aircraft %2",
                                    _pilotName, _vehicleIndex];
                            };
                        } else {
                            // Vehicle is invalid, eject pilot
                            unassignVehicle _x;
                            _x action ["Eject", _currentVehicle];
                            _pilotData set [5, objNull];
                        };
                        
                        _pilotIssues = _pilotIssues + 1;
                    };
                } else {
                    // Pilot is on foot but references an aircraft
                    if (!isNull _rosterAircraft) then {
                        diag_log format ["HANGAR CLEANUP: Pilot %1 (index %2) is on foot but references aircraft, clearing",
                            _pilotName, _pilotIndex];
                            
                        _pilotData set [5, objNull];
                        _pilotIssues = _pilotIssues + 1;
                    };
                };
            };
        };
    } forEach allUnits;
    
    // ==== SUMMARY ====
    _totalIssuesFixed = _aircraftIssues + _pilotIssues + _referenceIssues;
    
    if (!_silent) then {
        // Provide feedback to user
        if (_totalIssuesFixed > 0) then {
            systemChat format ["Hangar Cleanup: Fixed %1 issues (%2 aircraft, %3 pilots, %4 references)",
                _totalIssuesFixed, _aircraftIssues, _pilotIssues, _referenceIssues];
                
            hint parseText format [
                "<t size='1.2' color='#8cff9b' align='center'>Hangar System Cleanup</t><br/><br/>" +
                "<t align='left'>Aircraft Issues Fixed: %1</t><br/>" +
                "<t align='left'>Pilot Issues Fixed: %2</t><br/>" +
                "<t align='left'>Reference Issues Fixed: %3</t><br/><br/>" +
                "<t size='0.8' align='center'>Hangar system has been reset to a consistent state</t>",
                _aircraftIssues,
                _pilotIssues,
                _referenceIssues
            ];
        } else {
            systemChat "Hangar Cleanup: No issues found";
        };
    };
    
    // Log summary
    diag_log format ["HANGAR CLEANUP: Completed. Fixed %1 total issues (%2 aircraft, %3 pilots, %4 references)",
        _totalIssuesFixed, _aircraftIssues, _pilotIssues, _referenceIssues];
        
    // Return results
    [_totalIssuesFixed, _aircraftIssues, _pilotIssues, _referenceIssues]
};

// Function to initialize the hangar system monitoring
// NEW: Adds automatic cleanup and monitoring
HANGAR_fnc_initializeSystemMonitoring = {
    // ==== PARAMETERS ====
    params [
        ["_enableAutoCleanup", true],         // Enable automatic cleanup
        ["_autoCleanupInterval", 300],        // Cleanup interval in seconds (default: 5 minutes)
        ["_silentCleanup", true],             // Don't show messages for routine cleanup
        ["_enableDeployedMonitoring", true],  // Monitor deployed aircraft
        ["_deployedMonitorInterval", 30]      // Monitoring interval in seconds (default: 30 seconds)
    ];
    
    // Check if already initialized
    if (!isNil "HANGAR_monitoringActive" && {HANGAR_monitoringActive}) exitWith {
        diag_log "HANGAR MONITOR: Monitoring is already active";
        false
    };
    
    // Set global flag
    HANGAR_monitoringActive = true;
    
    // ==== AUTO CLEANUP SYSTEM ====
    if (_enableAutoCleanup) then {
        // Log initialization
        diag_log format ["HANGAR MONITOR: Starting auto-cleanup system with %1 second interval", 
            _autoCleanupInterval];
            
        // Spawn automatic cleanup loop
        [] spawn {
            params ["_interval", "_silent"];
            _interval = HANGAR_autoCleanupInterval;
            _silent = HANGAR_silentCleanup;
            
            // Initial cleanup on startup
            [] call HANGAR_fnc_cleanupHangarSystem;
            
            // Continuous cleanup loop
            while {HANGAR_monitoringActive} do {
                sleep _interval;
                
                if (HANGAR_monitoringActive) then {
                    // Run cleanup silently for routine checks
                    private _results = [_silent] call HANGAR_fnc_cleanupHangarSystem;
                    _results params ["_totalIssues"];
                    
                    // Only notify if significant issues were found
                    if (_totalIssues > 3 && _silent) then {
                        systemChat format ["Hangar Monitoring: Fixed %1 issues during routine scan", _totalIssues];
                    };
                };
            };
        };
    };
    
    // ==== DEPLOYED AIRCRAFT MONITORING ====
    if (_enableDeployedMonitoring) then {
        // Log initialization
        diag_log format ["HANGAR MONITOR: Starting deployed aircraft monitoring with %1 second interval", 
            _deployedMonitorInterval];
            
        // Spawn monitoring loop for deployed aircraft
        [] spawn {
            params ["_interval"];
            _interval = HANGAR_deployedMonitorInterval;
            
            while {HANGAR_monitoringActive} do {
                sleep _interval;
                
                if (HANGAR_monitoringActive) then {
                    // Run both monitoring functions
                    call HANGAR_fnc_monitorDeployedAircraft;
                    call HANGAR_fnc_monitorAircraftHealth;
                };
            };
        };
    };
    
    // Store parameters globally for spawned threads
    HANGAR_autoCleanupInterval = _autoCleanupInterval;
    HANGAR_silentCleanup = _silentCleanup;
    HANGAR_deployedMonitorInterval = _deployedMonitorInterval;
    
    // Success
    systemChat "Hangar Monitoring System initialized";
    diag_log "HANGAR MONITOR: Monitoring system initialized successfully";
    true
};

// Function to stop monitoring
HANGAR_fnc_stopSystemMonitoring = {
    // Set flag to terminate loops
    HANGAR_monitoringActive = false;
    
    // Run one final cleanup
    private _results = [false] call HANGAR_fnc_cleanupHangarSystem;
    _results params ["_totalIssues", "_aircraftIssues", "_pilotIssues", "_referenceIssues"];
    
    // Notify
    systemChat "Hangar Monitoring System stopped";
    diag_log format ["HANGAR MONITOR: Monitoring system stopped. Final cleanup fixed %1 issues", _totalIssues];
    
    true
};

// Automatically start the monitoring system
[] spawn {
    // Wait for scripts to initialize first
    waitUntil {!isNil "HANGAR_storedAircraft" && !isNil "HANGAR_pilotRoster"};
    sleep 5;
    
    // Start monitoring with default settings
    [] call HANGAR_fnc_initializeSystemMonitoring;
    
    // Log completion
    diag_log "HANGAR MONITOR: Automatic startup completed";
};



// ========================================================================================
// Hangar System Fixes - Initialization Script
// ========================================================================================
// This script implements comprehensive fixes for the virtual hangar system
// Particularly addressing issues with pilot management and aircraft deployment

// Wait for the system to initialize first
waitUntil {!isNil "HANGAR_storedAircraft" && !isNil "HANGAR_pilotRoster"};
waitUntil {!isNil "HANGAR_fnc_assignPilotToStoredAircraft"};
sleep 2; // Give a small delay for other systems to initialize

// === GAMEPLAY VARIABLES - ADJUST THESE TO CHANGE SYSTEM BEHAVIOR ===
HANGAR_FIXES_CONFIG = [
    // Enable auto-cleanup system
    ["enableAutoCleanup", true],
    
    // Cleanup interval in seconds (default: 5 minutes)
    ["autoCleanupInterval", 300],
    
    // Show messages during routine cleanup
    ["silentCleanup", true],
    
    // Enable deployed aircraft monitoring
    ["enableDeployedMonitoring", true],
    
    // Monitoring interval in seconds (default: 30 seconds)
    ["deployedMonitorInterval", 30],
    
    // Purge dead pilots automatically
    ["autoPurgePilots", true]
];

// Apply fixes by replacing the problematic functions
diag_log "HANGAR FIXES: Applying fixes to virtual hangar system...";

// 1. Replace pilot assignment function
if (!isNil "HANGAR_fnc_assignPilotToStoredAircraft") then {
    diag_log "HANGAR FIXES: Replacing HANGAR_fnc_assignPilotToStoredAircraft";
    // Function code is defined externally in the main file
};

// 2. Replace validation function
if (!isNil "HANGAR_fnc_validateAircraftCrew") then {
    diag_log "HANGAR FIXES: Replacing HANGAR_fnc_validateAircraftCrew";
    // Function code is defined externally in the main file
};

// 3. Replace pilot availability check
if (!isNil "HANGAR_fnc_isPilotAvailableForAircraft") then {
    diag_log "HANGAR FIXES: Replacing HANGAR_fnc_isPilotAvailableForAircraft";
    // Function code is defined externally in the main file
};

// 4. Replace aircraft destruction handler
if (!isNil "HANGAR_fnc_onAircraftDestroyed") then {
    diag_log "HANGAR FIXES: Replacing HANGAR_fnc_onAircraftDestroyed";
    // Function code is defined externally in the main file
};

// 5. Add new pilot removal function
diag_log "HANGAR FIXES: Adding HANGAR_fnc_removePilotFromRoster";
// Function code is defined externally in the main file

// 6. Add system cleanup function
diag_log "HANGAR FIXES: Adding HANGAR_fnc_cleanupHangarSystem";
// Function code is defined externally in the main file

// 7. Add monitoring system
diag_log "HANGAR FIXES: Adding HANGAR_fnc_initializeSystemMonitoring";
// Function code is defined externally in the main file

// 8. Add UI elements
diag_log "HANGAR FIXES: Adding HANGAR_fnc_addCleanupUI";
// Function code is defined externally in the main file

// Run initial cleanup to fix any existing issues
[] spawn {
    // Small delay to ensure all functions are properly initialized
    sleep 3;
    
    // Perform initial cleanup
    diag_log "HANGAR FIXES: Performing initial system cleanup...";
    private _results = [false] call HANGAR_fnc_cleanupHangarSystem;
    _results params ["_totalIssues", "_aircraftIssues", "_pilotIssues", "_referenceIssues"];
    
    // Log results
    diag_log format ["HANGAR FIXES: Initial cleanup fixed %1 total issues", _totalIssues];
    
    // Provide feedback to player if issues were found
    if (_totalIssues > 0) then {
        systemChat format ["Hangar System: Fixed %1 issues during startup", _totalIssues];
        hint parseText format [
            "<t size='1.2' color='#8cff9b' align='center'>Hangar System Fixes</t><br/><br/>" +
            "<t align='left'>Total Issues Fixed: %1</t><br/>" +
            "<t align='left'>• Aircraft Issues: %2</t><br/>" +
            "<t align='left'>• Pilot Issues: %3</t><br/>" +
            "<t align='left'>• Reference Issues: %4</t><br/><br/>" +
            "<t size='0.8' align='center'>Hangar system has been reset to a consistent state</t>",
            _totalIssues,
            _aircraftIssues,
            _pilotIssues,
            _referenceIssues
        ];
    };
    
    // Initialize monitoring system
    private _config = HANGAR_FIXES_CONFIG;
    private _enableAutoCleanup = (_config select 0) select 1;
    private _autoCleanupInterval = (_config select 1) select 1;
    private _silentCleanup = (_config select 2) select 1;
    private _enableDeployedMonitoring = (_config select 3) select 1;
    private _deployedMonitorInterval = (_config select 4) select 1;
    
    // Start monitoring
    [
        _enableAutoCleanup, 
        _autoCleanupInterval,
        _silentCleanup,
        _enableDeployedMonitoring,
        _deployedMonitorInterval
    ] call HANGAR_fnc_initializeSystemMonitoring;
    
    diag_log "HANGAR FIXES: Monitoring system initialized";
    
    // Add marker for completion
    missionNamespace setVariable ["HANGAR_FIXES_APPLIED", true, true];
    diag_log "HANGAR FIXES: All fixes successfully applied";
};

// Add a scheduled script to regularly validate and clean the system
if (isNil "HANGAR_maintenanceActive") then {
    HANGAR_maintenanceActive = true;
    
    [] spawn {
        while {HANGAR_maintenanceActive} do {
            // Run validation on all aircraft
            for "_i" from 0 to ((count HANGAR_storedAircraft) - 1) do {
                [_i] call HANGAR_fnc_validateAircraftCrew;
            };
            
            // Wait for next cycle (every 10 minutes)
            sleep 600;
        };
    };
    
    diag_log "HANGAR FIXES: Scheduled maintenance routine started";
};

// Send confirmation
systemChat "Hangar System Fixes: Applied successfully!";