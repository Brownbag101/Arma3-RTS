// Return To Base Control Function
// Completely rewritten to properly handle RTB behavior

// === GAMEPLAY VARIABLES - RTB PARAMETERS ===
AIR_OP_RTB_ALTITUDE = 500;        // Altitude for RTB flight (meters)
AIR_OP_RTB_SPEED = "NORMAL";      // Speed for RTB (LIMITED, NORMAL, FULL)

// Function to handle Return To Base command
AIR_OP_fnc_returnToBase = {
    // Get selected aircraft from UI
    private _aircraft = AIR_OP_selectedAircraft;
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected for RTB command";
        diag_log "AIR_OPS RTB: No aircraft selected";
        false
    };
    
    // Cancel any active missions first
    private _activeMission = false;
    private _missionID = "";
    private _missionType = "";
    
    {
        _x params ["_id", "_missionAircraft", "_type"];
        if (_missionAircraft == _aircraft) exitWith {
            _activeMission = true;
            _missionID = _id;
            _missionType = _type;
        };
    } forEach AIR_OP_activeMissions;
    
    if (_activeMission) then {
        // Cancel the mission
        [_missionID, false] call AIR_OP_fnc_completeMission;
        systemChat format ["Cancelled %1 mission, aircraft returning to base", _missionType];
        diag_log format ["AIR_OPS RTB: Cancelled mission %1 (%2)", _missionID, _missionType];
    };
    
    // Mark aircraft as returning to base
    _aircraft setVariable ["AIR_OP_RTB", true, true];
    _aircraft setVariable ["AIR_OP_onMission", false, true];
    
    // CRITICAL: Disable combat AI to prevent re-engaging targets
    if (!isNil "AIR_OP_fnc_disableCombatAI") then {
        [_aircraft] call AIR_OP_fnc_disableCombatAI;
    } else {
        // Fallback if the function isn't available
        {
            if (_x getVariable ["HANGAR_isPilot", false]) then {
                _x disableAI "TARGET";
                _x disableAI "AUTOTARGET";
                _x setCombatMode "BLUE";
                _x setBehaviour "CARELESS";
            };
        } forEach crew _aircraft;
    };
    
    // Get driver and group
    private _driver = driver _aircraft;
    if (isNull _driver) exitWith {
        systemChat "No pilot found in aircraft";
        diag_log "AIR_OPS RTB: No pilot found";
        false
    };
    
    private _group = group _driver;
    if (isNull _group) exitWith {
        systemChat "No valid group for pilot";
        diag_log "AIR_OPS RTB: No valid group";
        false
    };
    
    // Clear all existing waypoints
    while {count waypoints _group > 0} do {
        deleteWaypoint [_group, 0];
    };
    
    // Find RTB position - airfield or loiter marker
    private _rtbPos = [0,0,0];
    private _hasRTBPos = false;
    
    // First check for air_loiter marker
    if (markerType "air_loiter" != "") then {
        _rtbPos = getMarkerPos "air_loiter";
        _rtbPos set [2, AIR_OP_RTB_ALTITUDE];
        _hasRTBPos = true;
        diag_log "AIR_OPS RTB: Using loiter marker for RTB position";
    };
    
    // If no loiter marker, look for airfield marker
    if (!_hasRTBPos && markerType "airfield" != "") then {
        _rtbPos = getMarkerPos "airfield";
        _rtbPos set [2, AIR_OP_RTB_ALTITUDE];
        _hasRTBPos = true;
        diag_log "AIR_OPS RTB: Using airfield marker for RTB position";
    };
    
    // If no markers found, use a default position (center of map)
    if (!_hasRTBPos) then {
        _rtbPos = [worldSize/2, worldSize/2, AIR_OP_RTB_ALTITUDE];
        diag_log "AIR_OPS RTB: No RTB markers found, using map center";
    };
    
    // Create transition waypoint to turn to RTB location
    private _currentPos = getPosASL _aircraft;
    private _dirToRTB = _currentPos getDir _rtbPos;
    private _transitionDist = 1000;
    private _transPos = [
        (_currentPos select 0) + _transitionDist * sin(_dirToRTB),
        (_currentPos select 1) + _transitionDist * cos(_dirToRTB),
        AIR_OP_RTB_ALTITUDE
    ];
    
    private _wp1 = _group addWaypoint [_transPos, 0];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointBehaviour "CARELESS";
    _wp1 setWaypointCombatMode "BLUE";
    _wp1 setWaypointSpeed AIR_OP_RTB_SPEED;
    _wp1 setWaypointStatements ["true", "vehicle this flyInHeight " + str AIR_OP_RTB_ALTITUDE];
    
    // Add main RTB waypoint
    private _wp2 = _group addWaypoint [_rtbPos, 0];
    _wp2 setWaypointType "MOVE";
    _wp2 setWaypointBehaviour "CARELESS";
    _wp2 setWaypointCombatMode "BLUE";
    _wp2 setWaypointSpeed AIR_OP_RTB_SPEED;
    
    // Add loiter waypoint at RTB position
    private _wp3 = _group addWaypoint [_rtbPos, 0];
    _wp3 setWaypointType "LOITER";
    _wp3 setWaypointLoiterType "CIRCLE_L";
    _wp3 setWaypointLoiterRadius 800;
    _wp3 setWaypointBehaviour "CARELESS";
    _wp3 setWaypointCombatMode "BLUE";
    _wp3 setWaypointSpeed "LIMITED";
    
    // Set current waypoint explicitly
    _group setCurrentWaypoint _wp1;
    
    // Force aircraft to follow the waypoint
    _aircraft doMove _transPos;
    _aircraft flyInHeight AIR_OP_RTB_ALTITUDE;
    
    // Create RTB marker
    private _markerName = format ["RTB_marker_%1_%2", _aircraft, round(time)];
    private _marker = createMarker [_markerName, _rtbPos];
    _marker setMarkerType "mil_end";
    _marker setMarkerColor "ColorBlue";
    _marker setMarkerText "RTB";
    
    // Schedule marker deletion
    [_markerName] spawn {
        params ["_marker"];
        sleep 300; // Delete after 5 minutes
        deleteMarker _marker;
    };
    
    // Monitor RTB process
    [_aircraft, _rtbPos, _markerName] spawn {
        params ["_aircraft", "_rtbPos", "_markerName"];
        
        private _startTime = time;
        private _timeout = 600; // 10 minute timeout
        private _lastPos = getPosASL _aircraft;
        private _stuckCounter = 0;
        
        while {!isNull _aircraft && alive _aircraft && time - _startTime < _timeout} do {
            // Check if aircraft is moving
            private _currentPos = getPosASL _aircraft;
            private _moving = _lastPos distance _currentPos > 10;
            _lastPos = _currentPos;
            
            // If not moving, increment stuck counter
            if (!_moving) then {
                _stuckCounter = _stuckCounter + 1;
                
                // If stuck for 10 checks (30 seconds), force movement
                if (_stuckCounter > 10) then {
                    // Apply emergency fix
                    private _driver = driver _aircraft;
                    if (!isNull _driver) then {
                        private _group = group _driver;
                        
                        // Clear waypoints
                        while {count waypoints _group > 0} do {
                            deleteWaypoint [_group, 0];
                        };
                        
                        // Create new waypoint directly to RTB
                        private _wp = _group addWaypoint [_rtbPos, 0];
                        _wp setWaypointType "MOVE";
                        _wp setWaypointBehaviour "CARELESS";
                        _wp setWaypointSpeed "FULL";
                        
                        // Force movement
                        _aircraft doMove _rtbPos;
                        _aircraft flyInHeight AIR_OP_RTB_ALTITUDE;
                        
                        systemChat "Aircraft movement stalled - applying emergency fix";
                        diag_log "AIR_OPS RTB: Aircraft stuck, applying emergency fix";
                    };
                    
                    _stuckCounter = 0;
                };
            } else {
                _stuckCounter = 0;
            };
            
            // Check if aircraft has reached RTB position
            if (_aircraft distance _rtbPos < 800) then {
                // Aircraft has reached RTB area
                if (markerType _markerName != "") then {
                    deleteMarker _markerName;
                };
                
                systemChat "Aircraft has reached RTB position";
                diag_log "AIR_OPS RTB: Aircraft reached RTB position";
                
                // Add a loiter waypoint if there's none
                private _driver = driver _aircraft;
                if (!isNull _driver) then {
                    private _group = group _driver;
                    private _hasLoiter = false;
                    
                    // Check if any waypoint is LOITER
                    {
                        if (waypointType _x == "LOITER") exitWith {
                            _hasLoiter = true;
                        };
                    } forEach waypoints _group;
                    
                    // Add loiter if none exists
                    if (!_hasLoiter) then {
                        private _wp = _group addWaypoint [_rtbPos, 0];
                        _wp setWaypointType "LOITER";
                        _wp setWaypointLoiterType "CIRCLE_L";
                        _wp setWaypointLoiterRadius 800;
                    };
                };
                
                // Reset RTB flag
                _aircraft setVariable ["AIR_OP_RTB", false, true];
                break;
            };
            
            sleep 3; // Check every 3 seconds
        };
        
        // Cleanup timeout
        if (time - _startTime >= _timeout) then {
            systemChat "RTB timeout reached";
            diag_log "AIR_OPS RTB: Timeout reached";
            
            // Reset RTB flag
            _aircraft setVariable ["AIR_OP_RTB", false, true];
            
            if (markerType _markerName != "") then {
                deleteMarker _markerName;
            };
        };
        
        // Check if aircraft was destroyed
        if (isNull _aircraft || !alive _aircraft) then {
            diag_log "AIR_OPS RTB: Aircraft was destroyed during RTB";
            
            if (markerType _markerName != "") then {
                deleteMarker _markerName;
            };
        };
    };
    
    systemChat "Aircraft returning to base";
    true
};