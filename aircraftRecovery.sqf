// FINAL Aircraft Recovery with Correct Specialization Assignment
// Place this in the trigger's activation field or call via trigger activation

// Recovery script
params ["_trigger", "_detectedObjects"];

// Log who tripped the trigger
diag_log format ["RECOVERY: Trigger activated with %1 objects", count _detectedObjects];

// Process all detected objects
private _recoveredCount = 0;
private _newPilots = 0;
private _existingCount = 0;

{
    private _vehicle = _x;
    
    // Check if it's an aircraft
    if (_vehicle isKindOf "Air") then {
        diag_log format ["RECOVERY: Processing aircraft %1 (Type: %2)", _vehicle, typeOf _vehicle];
        
        // Get crew info for debugging
        private _realCrew = crew _vehicle;
        diag_log format ["RECOVERY: Aircraft has %1 crew members", count _realCrew];
        
        // IMPORTANT: Check if this is already one of our tracked aircraft
        private _storageIndex = _vehicle getVariable ["HANGAR_storageIndex", -1];
        private _isTrackedAircraft = _storageIndex >= 0 && _vehicle getVariable ["HANGAR_deployed", false];
        
        if (_isTrackedAircraft) then {
            // This is one of our existing aircraft - handle normally
            private _record = HANGAR_storedAircraft select _storageIndex;
            
            // Update status
            _record set [7, false]; // isDeployed = false
            _record set [8, objNull]; // deployedInstance = objNull
            
            // Update fuel and damage status before returning
            private _fuel = fuel _vehicle;
            private _damage = damage _vehicle;
            
            _record set [2, _fuel]; // Update fuel
            _record set [3, _damage]; // Update damage
            
            // Update weapons state
            private _weaponsData = [];
            private _weapons = weapons _vehicle;
            {
                private _weapon = _x;
                private _ammo = _vehicle ammo _weapon;
                private _weaponName = getText (configFile >> "CfgWeapons" >> _weapon >> "displayName");
                _weaponsData pushBack [_weapon, _ammo, _weaponName];
            } forEach _weapons;
            
            _record set [4, _weaponsData]; // Update weapons data
            
            // CRITICAL FIX: CLEAR the crew array before optionally adding pilots back
            _record set [5, []]; // Empty the crew array completely
            
            // Log crew clearing
            diag_log format ["RECOVERY: Cleared crew array for aircraft record at index %1", _storageIndex];
            
            // Update crew status - pilots remain in the roster
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    private _pilotIndex = _x getVariable ["HANGAR_pilotIndex", -1];
                    if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
                        // Update pilot's aircraft assignment
                        (HANGAR_pilotRoster select _pilotIndex) set [5, objNull];
                        
                        // Increment missions count
                        [_pilotIndex, "missions", 1] call HANGAR_fnc_updatePilotStats;
                        
                        diag_log format ["RECOVERY: Updated pilot %1 (index %2), removed aircraft assignment", name _x, _pilotIndex];
                    };
                };
            } forEach crew _vehicle;
            
            // Remove from deployed aircraft array
            HANGAR_deployedAircraft = HANGAR_deployedAircraft - [_vehicle];
            
            // ROBUST CREW EXTRACTION - Force everyone out first
            {
                _x action ["Eject", _vehicle];
                unassignVehicle _x;
                moveOut _x;
            } forEach crew _vehicle;
            
            // Check if anyone is still inside
            if (count crew _vehicle > 0) then {
                diag_log "RECOVERY: WARNING - Crew still in vehicle after moveOut commands";
            } else {
                diag_log "RECOVERY: All crew successfully exited vehicle";
            };
            
            // Delete each crew member individually with verification
            {
                private _crewMember = _x;
                private _crewName = name _crewMember;
                
                // Make sure the unit is not in any vehicle
                if (vehicle _crewMember != _crewMember) then {
                    unassignVehicle _crewMember;
                    moveOut _crewMember;
                };
                
                // Force immediate teleport away from vehicle
                _crewMember setPosASL [(getPosASL _vehicle select 0) + 10, (getPosASL _vehicle select 1) + 10, 0];
                
                // Delete the unit
                diag_log format ["RECOVERY: Deleting crew member: %1", _crewName];
                deleteVehicle _crewMember;
                
                // Verify deletion
                if (!isNull _crewMember) then {
                    diag_log format ["RECOVERY: WARNING - Failed to delete crew member: %1", _crewName];
                } else {
                    diag_log format ["RECOVERY: Successfully deleted crew member: %1", _crewName];
                };
            } forEach _realCrew;
            
            // Delete the vehicle
            deleteVehicle _vehicle;
            
            systemChat format ["%1 has returned to the hangar", _record select 1];
            diag_log format ["RECOVERY: Existing aircraft %1 updated and returned to hangar", _record select 1];
            
            _existingCount = _existingCount + 1;
        } else {
            // This is a new/dynamic aircraft - process differently
            diag_log "RECOVERY: Processing as new/dynamic aircraft";
            
            // Get the basic aircraft info
            private _type = typeOf _vehicle;
            private _displayName = getText (configFile >> "CfgVehicles" >> _type >> "displayName");
            private _fuel = fuel _vehicle;
            private _damage = damage _vehicle;
            
            // Store weapons and ammo state
            private _weaponsData = [];
            private _weapons = weapons _vehicle;
            {
                private _weapon = _x;
                private _ammo = _vehicle ammo _weapon;
                private _weaponName = getText (configFile >> "CfgWeapons" >> _weapon >> "displayName");
                _weaponsData pushBack [_weapon, _ammo, _weaponName];
            } forEach _weapons;
            
            // Determine aircraft category using the central function
_specialization = [_type] call HANGAR_fnc_determineAircraftCategory;
diag_log format ["RECOVERY: Determined category %1 for aircraft type %2", _specialization, _type];

// Get aircraft data from master list
private _aircraftInfo = [_type] call HANGAR_fnc_findAircraftInMasterList;

// Set display name and crew count from master list if available
if (count _aircraftInfo > 0) then {
    _aircraftInfo params ["_className", "_masterDisplayName", "_masterCrewCount"];
    
    // Use master list data (it's more accurate)
    _displayName = _masterDisplayName;
    
    // Add to HANGAR_aircraftTypes if not already there
    [_type, _displayName, _masterCrewCount] call HANGAR_fnc_addAircraftToTypes;
} else {
    // Not in master list, add with guessed category
    [_type, _displayName, 1] call HANGAR_fnc_addAircraftToTypes;
};
            
            // CRUCIAL: Get crew members out of vehicle
            {
                _x action ["Eject", _vehicle];
                unassignVehicle _x;
                moveOut _x;
                
                // Force immediate teleport away from vehicle
                _x setPosASL [(getPosASL _vehicle select 0) + 10, (getPosASL _vehicle select 1) + 10, 0];
            } forEach _realCrew;
            
            // Wait a moment to ensure exit is complete
            sleep 0.5;
            
            // Check if anyone is still inside
            if (count crew _vehicle > 0) then {
                diag_log "RECOVERY: WARNING - Crew still in vehicle after moveOut commands";
            } else {
                diag_log "RECOVERY: All crew successfully exited vehicle";
            };
            
            // Process each crew member using the standard function WITH CORRECT SPECIALIZATION
            private _pilotNames = [];
            {
                private _unit = _x;
                private _unitName = name _unit;
                
                // CRITICAL FIX: Use the correct specialization!
                private _pilotIndex = [_unit, _specialization] call fnc_addPilotToHangarRoster;
                
                if (_pilotIndex >= 0) then {
                    diag_log format ["RECOVERY: Added/found pilot %1 with index %2 and specialization %3", 
                        _unitName, _pilotIndex, _specialization];
                    _newPilots = _newPilots + 1;
                    
                    // Add to name list for reporting
                    _pilotNames pushBack _unitName;
                } else {
                    diag_log format ["RECOVERY: Failed to add pilot %1 to roster", _unitName];
                };
                
                // Delete the unit
                diag_log format ["RECOVERY: Deleting crew member: %1", _unitName];
                deleteVehicle _unit;
                
                // Verify deletion
                if (!isNull _unit) then {
                    diag_log format ["RECOVERY: WARNING - Failed to delete crew member: %1", _unitName];
                } else {
                    diag_log format ["RECOVERY: Successfully deleted crew member: %1", _unitName];
                };
            } forEach _realCrew;
            
            // Create aircraft record WITH EMPTY CREW ARRAY
            private _aircraftRecord = [
                _type,              // Type
                _displayName,       // Display name
                _fuel,              // Fuel level
                _damage,            // Damage level 
                _weaponsData,       // Weapons data
                [],                 // EMPTY CREW ARRAY - Key fix!
                [],                 // No custom data
                false,              // Not deployed anymore
                objNull             // No deployed instance
            ];
            
            // Add to hangar storage
            HANGAR_storedAircraft pushBack _aircraftRecord;
            
            // Notify about aircraft recovery with crew details
            if (count _pilotNames > 0) then {
                systemChat format ["%1 (%2) recovered, pilots added to roster: %3", 
                    _displayName, _specialization, _pilotNames joinString ", "];
            } else {
                systemChat format ["%1 recovered without crew", _displayName];
            };
            
            diag_log format ["RECOVERY: New aircraft %1 (%2) recovered to hangar with EMPTY CREW ARRAY", 
                _displayName, _type];
            
            // Delete the vehicle (crew already deleted)
            deleteVehicle _vehicle;
            
            _recoveredCount = _recoveredCount + 1;
        };
    };
} forEach _detectedObjects;

// Provide summary notification
if (_recoveredCount > 0 || _existingCount > 0) then {
    private _message = format ["%1 total aircraft processed", _recoveredCount + _existingCount];
    
    if (_recoveredCount > 0) then {
        _message = _message + format [" (%1 new)", _recoveredCount];
    };
    
    if (_existingCount > 0) then {
        _message = _message + format [" (%1 returned)", _existingCount];
    };
    
    if (_newPilots > 0) then {
        _message = _message + format [" with %1 new pilots added to roster", _newPilots];
    };
    
    systemChat _message;
    
    diag_log format ["RECOVERY: Summary - %1 new aircraft, %2 returned aircraft, %3 new pilots", 
        _recoveredCount, _existingCount, _newPilots];
    
    // Hint with more details
    hint parseText format [
        "<t size='1.2' color='#8cff9b' align='center'>Aircraft Recovery</t><br/><br/>" +
        "<t align='left'>New Aircraft: %1</t><br/>" +
        "<t align='left'>Returned Aircraft: %2</t><br/>" +
        "<t align='left'>New Pilots: %3</t><br/><br/>" +
        "<t size='0.8' align='center'>Aircraft have been added to the hangar inventory</t>",
        _recoveredCount,
        _existingCount,
        _newPilots
    ];
};