// Return To Base Control Function
// Sends selected aircraft back to base

AIR_OP_fnc_returnToBase = {
    // Use the currently selected aircraft or the one passed as parameter
    params [["_aircraft", AIR_OP_selectedAircraft]];
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected for RTB command";
        diag_log "AIR_OPS RTB: No aircraft selected";
        false
    };
    
    // First, cancel any active mission
    private _hasMission = false;
    {
        if ((_x select 1) == _aircraft) exitWith {
            private _missionID = _x select 0;
            [_missionID, false] call AIR_OP_fnc_completeMission;
            _hasMission = true;
        };
    } forEach AIR_OP_activeMissions;
    
    // Get the driver and group
    private _driver = driver _aircraft;
    if (isNull _driver) exitWith {
        systemChat "Cannot issue RTB - aircraft has no pilot";
        diag_log "AIR_OPS RTB: Aircraft has no driver";
        false
    };
    
    private _group = group _driver;
    if (isNull _group) exitWith {
        systemChat "Cannot issue RTB - pilot has no group";
        diag_log "AIR_OPS RTB: Driver has no group";
        false
    };
    
    // Clear existing waypoints
    while {count waypoints _group > 0} do {
        deleteWaypoint [_group, 0];
    };
    
    // Find base position - use plane_spawn marker or fallback
    private _basePos = if (markerType "plane_spawn" != "") then {
        getMarkerPos "plane_spawn"
    } else {
        // Fallback to hangar view position if defined
        if (!isNil "HANGAR_viewPosition") then {
            HANGAR_viewPosition
        } else {
            // Last resort, use map center
            [worldSize/2, worldSize/2, 0]
        };
    };
    
    // Create RTB waypoint
    private _wp = _group addWaypoint [_basePos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "CARELESS";
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointStatements ["true", "vehicle this land 'LAND'"];
    
    // Create marker for RTB destination
    private _markerName = format ["rtb_marker_%1", round random 9999];
    private _marker = createMarker [_markerName, _basePos];
    _marker setMarkerType "mil_end";
    _marker setMarkerColor "ColorGreen";
    _marker setMarkerText "RTB";
    
    // Remove marker after 60 seconds
    [_markerName] spawn {
        params ["_marker"];
        sleep 60;
        deleteMarker _marker;
    };
    
    // Send feedback
    private _aircraftType = getText (configFile >> "CfgVehicles" >> typeOf _aircraft >> "displayName");
    
    if (_hasMission) then {
        systemChat format ["%1 mission cancelled. Aircraft returning to base.", _aircraftType];
    } else {
        systemChat format ["%1 returning to base.", _aircraftType];
    };
    
    
    
    true
};

// Test function for RTB
AIR_OP_fnc_testRTB = {
    private _deployedAircraft = [] call AIR_OP_fnc_getDeployedAircraft;
    
    if (count _deployedAircraft > 0) then {
        [_deployedAircraft select 0] call AIR_OP_fnc_returnToBase;
    } else {
        systemChat "No deployed aircraft found for RTB test";
    };
};