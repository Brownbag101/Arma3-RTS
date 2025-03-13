// scripts/menu/recruitmentSystem.sqf - Complete file

// Declare all functions in the global scope first
RTS_fnc_getRecruitMarkerPos = {};
RTS_fnc_calculateRecruitmentCost = {};
RTS_fnc_showRecruitmentDialog = {};
RTS_fnc_initiateRecruitment = {};
RTS_fnc_spawnRecruits = {};
RTS_fnc_recruitmentCooldown = {};
RTS_fnc_addRecruitmentResources = {};
RTS_fnc_recruitOrder = {};

// Configuration
RTS_recruitmentConfig = [
    ["unitCost", 1],          // Manpower cost per unit
    ["fuelCost", 10],          // Base fuel cost per unit
    ["cooldownTime", 30],      // Cooldown time in seconds
    ["maxRecruits", 10],       // Maximum number of recruits per batch
    ["planeType", "LIB_C47_RAF"],  // Type of plane to use
    ["unitType", "JMSSA_gb_rifle_rifle"],  // Type of unit to spawn
    ["markerPrefix", "recruit_"]  // Prefix for recruitment markers
];

// Define marker positions directly (this avoids waitUntil issues)
RTS_recruitMarkers = [
    ["spawn", [0, 3000, 500]],
    ["land", [0, 0, 0]],
    ["assembly", [50, 50, 0]],
    ["despawn", [0, -3000, 500]]
];

// Create test markers immediately
if (markerType "recruit_spawn" == "") then {
    private _marker = createMarker ["recruit_spawn", [0, 3000, 500]];
    _marker setMarkerType "mil_start";
    _marker setMarkerText "Recruit Spawn";
};

if (markerType "recruit_land" == "") then {
    private _marker = createMarker ["recruit_land", [0, 0, 0]];
    _marker setMarkerType "mil_landing";
    _marker setMarkerText "Recruit Land";
};

if (markerType "recruit_assembly" == "") then {
    private _marker = createMarker ["recruit_assembly", [50, 50, 0]];
    _marker setMarkerType "mil_dot";
    _marker setMarkerText "Recruit Assembly";
};

if (markerType "recruit_despawn" == "") then {
    private _marker = createMarker ["recruit_despawn", [0, -3000, 500]];
    _marker setMarkerType "mil_end";
    _marker setMarkerText "Recruit Despawn";
};

// Global variable for cooldown
RTS_recruitmentCooldown = false;

// Function to get marker position with fallback
RTS_fnc_getRecruitMarkerPos = {
    params ["_markerType"];
    
    // Validate marker type
    if (isNil "_markerType" || {_markerType == ""}) exitWith {
        diag_log "ERROR: Invalid marker type passed to RTS_fnc_getRecruitMarkerPos";
        [0,0,0]
    };
    
    // Safely get the marker prefix - with better error handling
    private _markerPrefix = "";
    if (!isNil "RTS_recruitmentConfig") then {
        if (count RTS_recruitmentConfig > 6) then {
            private _configEntry = RTS_recruitmentConfig select 6;
            if (count _configEntry > 1) then {
                _markerPrefix = _configEntry select 1;
            };
        };
    };
    
    // Use format instead of + for string concatenation (safer method)
    private _markerName = format ["%1%2", _markerPrefix, _markerType];
    
    // Find fallback position in marker definitions
    private _fallbackPosition = [0,0,0]; // Default fallback
    
    if (!isNil "RTS_recruitMarkers") then {
        {
            if (count _x >= 2) then {
                private _type = _x select 0;
                private _pos = _x select 1;
                if (_type == _markerType) exitWith {
                    _fallbackPosition = _pos;
                };
            };
        } forEach RTS_recruitMarkers;
    };
    
    // Check marker in a safer way
    private _markerExists = false;
    try {
        _markerExists = markerType _markerName != "";
    } catch {
        diag_log format ["ERROR checking marker: %1", _markerName];
        _markerExists = false;
    };
    
    // Use marker if it exists, otherwise use fallback
    if (_markerExists) then {
        getMarkerPos _markerName
    } else {
        // Log warning when using fallback
        systemChat format ["Warning: Marker '%1' not found, using fallback position", _markerName];
        diag_log format ["Using fallback position for %1", _markerName];
        _fallbackPosition
    };
};
// Function to calculate recruitment cost
RTS_fnc_calculateRecruitmentCost = {
    params ["_numUnits"];
    
    private _baseFuelCost = RTS_recruitmentConfig select 1 select 1;
    private _baseManpowerCost = RTS_recruitmentConfig select 0 select 1;
    
    // Calculate fuel cost with increasing cost for more units
    private _totalFuelCost = 0;
    for "_i" from 1 to _numUnits do {
        _totalFuelCost = _totalFuelCost + (_baseFuelCost * (1 + (_i - 1) * 0.1));
    };
    
    // Calculate final manpower cost
    private _totalManpowerCost = _numUnits * _baseManpowerCost;
    
    // Return both costs
    [round _totalManpowerCost, round _totalFuelCost]
};

// Function to show the recruitment selection dialog
RTS_fnc_showRecruitmentDialog = {
    // Close any open dialogs
    if (dialog) then {
        closeDialog 0;
    };
    
    // Create a custom dialog using Zeus display
    private _display = findDisplay 312;
    
    if (isNull _display) exitWith {
        systemChat "Cannot open recruitment dialog - Zeus interface not active";
    };
    
    // Store controls array for cleanup
    RTS_recruitDialogControls = [];
    
    // Create background
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.3 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.4 * safezoneH
    ];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    RTS_recruitDialogControls pushBack _background;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", -1];
    _title ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.3 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.04 * safezoneH
    ];
    _title ctrlSetText "RECRUIT UNITS";
    _title ctrlSetTextColor [1, 1, 1, 1];
    _title ctrlSetBackgroundColor [0.2, 0.3, 0.4, 1];
    _title ctrlCommit 0;
    RTS_recruitDialogControls pushBack _title;
    
    // Get current resources
    private _manpower = ["manpower"] call RTS_fnc_getResource;
    private _fuel = ["fuel"] call RTS_fnc_getResource;
    
    // Create resources text
    private _resourcesText = _display ctrlCreate ["RscText", -1];
    _resourcesText ctrlSetPosition [
        0.31 * safezoneW + safezoneX,
        0.35 * safezoneH + safezoneY,
        0.38 * safezoneW,
        0.04 * safezoneH
    ];
    _resourcesText ctrlSetText format ["Manpower: %1 | Fuel: %2", floor _manpower, floor _fuel];
    _resourcesText ctrlSetTextColor [1, 1, 1, 1];
    _resourcesText ctrlCommit 0;
    RTS_recruitDialogControls pushBack _resourcesText;
    
    // Create slider for unit selection
    private _slider = _display ctrlCreate ["RscSlider", 1901];
    _slider ctrlSetPosition [
        0.31 * safezoneW + safezoneX,
        0.4 * safezoneH + safezoneY,
        0.38 * safezoneW,
        0.04 * safezoneH
    ];
    _slider sliderSetRange [1, RTS_recruitmentConfig select 3 select 1]; // Max recruits from config
    _slider sliderSetPosition 1;
    _slider sliderSetSpeed [1, 1];
    _slider ctrlCommit 0;
    RTS_recruitDialogControls pushBack _slider;
    
    // Create text to show selected number of units
    private _unitCountText = _display ctrlCreate ["RscText", 1902];
    _unitCountText ctrlSetPosition [
        0.31 * safezoneW + safezoneX,
        0.45 * safezoneH + safezoneY,
        0.38 * safezoneW,
        0.04 * safezoneH
    ];
    _unitCountText ctrlSetText "Units to recruit: 1";
    
    // Initial cost calculation
    private _costs = [1] call RTS_fnc_calculateRecruitmentCost;
    _costs params ["_manpowerCost", "_fuelCost"];
    
    // Create cost text
    private _costText = _display ctrlCreate ["RscText", 1903];
    _costText ctrlSetPosition [
        0.31 * safezoneW + safezoneX,
        0.5 * safezoneH + safezoneY,
        0.38 * safezoneW,
        0.04 * safezoneH
    ];
    _costText ctrlSetText format ["Cost: %1 Manpower, %2 Fuel", _manpowerCost, _fuelCost];
    _costText ctrlCommit 0;
    RTS_recruitDialogControls pushBack _costText;
    
    // Add event handler to update text when slider moves
    _slider ctrlAddEventHandler ["SliderPosChanged", {
        params ["_control", "_newValue"];
        private _display = ctrlParent _control;
        private _unitCountText = _display displayCtrl 1902;
        private _costText = _display displayCtrl 1903;
        private _numUnits = round _newValue;
        
        // Update unit count text
        _unitCountText ctrlSetText format ["Units to recruit: %1", _numUnits];
        
        // Update cost text
        private _costs = [_numUnits] call RTS_fnc_calculateRecruitmentCost;
        _costs params ["_manpowerCost", "_fuelCost"];
        _costText ctrlSetText format ["Cost: %1 Manpower, %2 Fuel", _manpowerCost, _fuelCost];
    }];
    _unitCountText ctrlCommit 0;
    RTS_recruitDialogControls pushBack _unitCountText;
    
    // Create confirm button
    private _confirmButton = _display ctrlCreate ["RscButton", 1904];
    _confirmButton ctrlSetPosition [
        0.35 * safezoneW + safezoneX,
        0.57 * safezoneH + safezoneY,
        0.3 * safezoneW,
        0.06 * safezoneH
    ];
    _confirmButton ctrlSetText "CONFIRM RECRUITMENT";
    _confirmButton ctrlSetTextColor [1, 1, 1, 1];
    _confirmButton ctrlSetBackgroundColor [0.2, 0.4, 0.2, 1];
    
    _confirmButton ctrlAddEventHandler ["ButtonClick", {
        private _display = ctrlParent (_this select 0);
        private _slider = _display displayCtrl 1901;
        private _numUnits = round sliderPosition _slider;
        
        [_numUnits] call RTS_fnc_initiateRecruitment;
        
        // Close dialog by deleting all controls
        {
            ctrlDelete _x;
        } forEach RTS_recruitDialogControls;
        RTS_recruitDialogControls = [];
    }];
    _confirmButton ctrlCommit 0;
    RTS_recruitDialogControls pushBack _confirmButton;
    
    // Create cancel button
    private _cancelButton = _display ctrlCreate ["RscButton", 1905];
    _cancelButton ctrlSetPosition [
        0.35 * safezoneW + safezoneX,
        0.64 * safezoneH + safezoneY,
        0.3 * safezoneW,
        0.04 * safezoneH
    ];
    _cancelButton ctrlSetText "CANCEL";
    _cancelButton ctrlSetBackgroundColor [0.4, 0.2, 0.2, 1];
    
    _cancelButton ctrlAddEventHandler ["ButtonClick", {
        // Close dialog by deleting all controls
        {
            ctrlDelete _x;
        } forEach RTS_recruitDialogControls;
        RTS_recruitDialogControls = [];
    }];
    _cancelButton ctrlCommit 0;
    RTS_recruitDialogControls pushBack _cancelButton;
    
    // Create cooldown indicator if on cooldown
    if (RTS_recruitmentCooldown) then {
        private _cooldownText = _display ctrlCreate ["RscText", -1];
        _cooldownText ctrlSetPosition [
            0.35 * safezoneW + safezoneX,
            0.53 * safezoneH + safezoneY,
            0.3 * safezoneW,
            0.04 * safezoneH
        ];
        _cooldownText ctrlSetText "RECRUITMENT ON COOLDOWN";
        _cooldownText ctrlSetTextColor [1, 0.5, 0.5, 1];
        _cooldownText ctrlCommit 0;
        RTS_recruitDialogControls pushBack _cooldownText;
        
        // Disable confirm button during cooldown
        _confirmButton ctrlEnable false;
    };
};

// Main recruitment function
RTS_fnc_initiateRecruitment = {
    params ["_numUnits"];
    
    // Ensure _numUnits is a number and within limits
    _numUnits = round _numUnits;
    if (_numUnits <= 0) exitWith {
        hint "Invalid number of units selected.";
        false
    };
    
    if (_numUnits > (RTS_recruitmentConfig select 3 select 1)) then {
        _numUnits = RTS_recruitmentConfig select 3 select 1;
    };
    
    if (RTS_recruitmentCooldown) exitWith {
        hint "Recruitment is on cooldown. Please wait.";
        false
    };
    
    // Calculate costs
    private _costs = [_numUnits] call RTS_fnc_calculateRecruitmentCost;
    _costs params ["_manpowerCost", "_fuelCost"];
    
    // Get current resources
    private _manpower = ["manpower"] call RTS_fnc_getResource;
    private _fuel = ["fuel"] call RTS_fnc_getResource;
    
    // Check if enough resources
    if (_manpower < _manpowerCost) exitWith {
        hint format ["Not enough manpower. Required: %1, Available: %2", _manpowerCost, floor _manpower];
        false
    };
    
    if (_fuel < _fuelCost) exitWith {
        hint format ["Not enough fuel. Required: %1, Available: %2", _fuelCost, floor _fuel];
        false
    };
    
    // Deduct resources using economy system functions
    ["manpower", -_manpowerCost] call RTS_fnc_modifyResource;
    ["fuel", -_fuelCost] call RTS_fnc_modifyResource;
    
    // Initiate spawning process
    [_numUnits] spawn RTS_fnc_spawnRecruits;
    
    // Start cooldown timer
    [] spawn RTS_fnc_recruitmentCooldown;
    
    hint format ["Recruiting %1 units. Manpower cost: %2, Fuel cost: %3", _numUnits, _manpowerCost, _fuelCost];
    true
};

// ENHANCED SPAWNING FUNCTION WITH IMPROVED LANDING SEQUENCE
// Replace the entire RTS_fnc_spawnRecruits function with this version

RTS_fnc_spawnRecruits = {
    params ["_numUnits"];
    
    private _planeType = RTS_recruitmentConfig select 4 select 1;
    private _unitType = RTS_recruitmentConfig select 5 select 1;
    
    diag_log format ["Spawning plane of type: %1", _planeType];
    diag_log format ["Spawning %1 units of type: %2", _numUnits, _unitType];
    
    // Get marker positions
    private _spawnPos = ["spawn"] call RTS_fnc_getRecruitMarkerPos;
    private _landPos = ["land"] call RTS_fnc_getRecruitMarkerPos;
    private _assemblyPos = ["assembly"] call RTS_fnc_getRecruitMarkerPos;
    private _despawnPos = ["despawn"] call RTS_fnc_getRecruitMarkerPos;
    
    // Ensure landing position is on ground level
    _landPos set [2, 0];
    
    // Log positions for debugging
    diag_log format ["Positions - Spawn: %1, Land: %2, Assembly: %3, Despawn: %4", 
        _spawnPos, _landPos, _assemblyPos, _despawnPos];
    
    // Spawn plane at proper altitude
    private _plane = createVehicle [_planeType, _spawnPos, [], 0, "FLY"];
    _plane setPosASL [_spawnPos#0, _spawnPos#1, (_spawnPos#2) max 300]; // Ensure minimum altitude
    _plane flyInHeight 300;
    
    // Better error handling for plane
    if (isNull _plane) exitWith {
        diag_log "ERROR: Failed to create transport aircraft";
        hint "Failed to create transport aircraft.";
        systemChat "ERROR: Could not create transport aircraft.";
        false
    };
    
    // Create crew for the plane with better group management
    private _planeGroup = createGroup [side player, true];
    private _crew = createVehicleCrew _plane;
    {
        [_x] joinSilent _planeGroup;
    } forEach crew _plane;
    
    _planeGroup setCombatMode "BLUE"; // Prevent engaging targets
    _planeGroup setBehaviour "CARELESS"; // Make flight path more predictable
    
    // Give the plane some initial velocity in the right direction
    private _dir = _plane getDir _landPos;
    _plane setDir _dir;
    _plane setVelocity [(sin _dir) * 50, (cos _dir) * 50, 0];
    
    // Explicitly set waypoints for better control
    private _wp1 = _planeGroup addWaypoint [_landPos getPos [1000, (_landPos getDir _spawnPos)], 0];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointSpeed "NORMAL";
    
    private _wp2 = _planeGroup addWaypoint [_landPos, 0];
    _wp2 setWaypointType "MOVE";
    _wp2 setWaypointSpeed "LIMITED";
    
    // Move plane to landing zone using doMove as backup
    _plane doMove _landPos;
    
    // Notification
    hint "Transport aircraft is en route with new recruits.";
    systemChat "Transport aircraft is en route with new recruits.";
    
    // More detailed debug output
    diag_log format ["Plane created: %1, Crew: %2", _plane, count crew _plane];
    
    // Wait for the plane to approach the landing zone
    // IMPROVED: More detailed approach logic with debug output
    private _timeout = time + 300; // 5 minute timeout
    private _reachedApproach = false;
    
    while {time < _timeout && !_reachedApproach && alive _plane} do {
        private _distance = _plane distance _landPos;
        
        if (_distance < 300) then {
            _reachedApproach = true;
            diag_log format ["Plane has reached approach point: distance = %1m", _distance];
        } else {
            // Periodically log progress
            if (time % 10 < 0.1) then {
                diag_log format ["Plane approaching: distance = %1m, altitude = %2m", 
                    _distance, (getPosASL _plane) select 2];
            };
        };
        
        // Adjust course if needed
        if (time % 30 < 0.1) then {
            _plane doMove _landPos;
            _plane flyInHeight 100;
        };
        
        sleep 1;
    };
    
    // Check if we timed out
    if (time >= _timeout) exitWith {
        diag_log "ERROR: Aircraft approach timed out";
        hint "Transport aircraft failed to reach landing zone.";
        systemChat "Transport aircraft failed to reach landing zone.";
        
        // Clean up
        {deleteVehicle _x} forEach (crew _plane);
        deleteVehicle _plane;
        deleteGroup _planeGroup;
        false
    };
    
    // Exit if plane was destroyed
    if (!alive _plane) exitWith {
        hint "Transport aircraft was destroyed en route.";
        systemChat "Transport aircraft was destroyed en route.";
        false
    };
    
    // IMPROVED LANDING SEQUENCE
    // -------------------------
    diag_log "Beginning landing sequence";
    hint "Transport aircraft is beginning landing approach.";
    systemChat "Transport aircraft is beginning landing approach.";
    
    // Set to land mode
    _plane land "LAND";
    
    // Gradually reduce altitude
    _plane flyInHeight 50;
    sleep 2;
    _plane flyInHeight 20;
    sleep 2;
    _plane flyInHeight 5;
    sleep 1;
    _plane flyInHeight 0;
    
    // Delete waypoints to prevent interference
    while {count waypoints _planeGroup > 0} do {
        deleteWaypoint [_planeGroup, 0];
    };
    
    // Add a landing waypoint
    private _wpLand = _planeGroup addWaypoint [_landPos, 0];
    _wpLand setWaypointType "MOVE";
    _wpLand setWaypointSpeed "LIMITED";
    
    // Force the plane to move to landing position
    _plane doMove _landPos;
    
    // Log landing attempts
    diag_log format ["Landing attempt initiated at position: %1", _landPos];
    
    // Wait for the plane to touch down with improved detection and timeout
    private _landingTimeout = time + 120; // 2 minute timeout for landing
    private _landed = false;
    private _touchedGround = false;
    
    while {time < _landingTimeout && !_landed && alive _plane} do {
        private _altitude = (getPosATL _plane) select 2;
        private _velocity = vectorMagnitude (velocity _plane);
        
        // Check multiple landing conditions
        if (isTouchingGround _plane) then {
            _touchedGround = true;
            diag_log "Aircraft has touched the ground";
        };
        
        if (_altitude < 1) then {
            diag_log format ["Aircraft at low altitude: %1m", _altitude];
        };
        
        // Consider landing complete when low and slow
        if ((_altitude < 1 || _touchedGround) && _velocity < 5) then {
            _landed = true;
            diag_log "Aircraft has landed successfully";
        };
        
        // Log progress every 5 seconds
        if (time % 5 < 0.1) then {
            diag_log format ["Landing progress: altitude = %1m, velocity = %2, touchedGround = %3", 
                _altitude, _velocity, _touchedGround];
        };
        
        // Adjust course periodically
        if (time % 15 < 0.1) then {
            _plane doMove _landPos;
            _plane flyInHeight 0;
        };
        
        sleep 0.5;
    };
    
    // Check if landing was successful
    if (!_landed) then {
        diag_log "WARNING: Normal landing failed, forcing position";
        
        // Force landing if normal procedures failed
        _plane setPosATL [_landPos select 0, _landPos select 1, 0];
        _plane setVelocity [0, 0, 0];
        _landed = true;
    };
    
    // Exit if plane was destroyed during landing
    if (!alive _plane) exitWith {
        hint "Transport aircraft was destroyed during landing.";
        systemChat "Transport aircraft was destroyed during landing.";
        false
    };
    
    // Additional wait to ensure the plane is stable
    sleep 3;
    
    
    
    diag_log "Plane has landed and stopped";
    
    // Notification
    hint "Transport aircraft has landed. Unloading troops...";
    systemChat "Transport aircraft has landed. Unloading troops...";
    
    // TROOP DEPLOYMENT
    // ---------------
    
    // Spawn and unload troops
    private _group = createGroup [side player, true]; // true for deleteWhenEmpty
    
    for "_i" from 1 to _numUnits do {
        private _unit = _group createUnit [_unitType, getPos _plane, [], 0, "NONE"];
        _unit moveInCargo _plane;
        
        // Add custom variables if needed
        _unit setVariable ["RTS_unit", true, true];
    };
    
    // Set group name
    _group setGroupIdGlobal [format ["Recruits %1", round(random 1000)]];
    
    // Make units editable by Zeus
    {
        _x addCuratorEditableObjects [units _group, true];
    } forEach allCurators;
    
    // Wait a brief moment before unloading
    sleep 2;
    
    // Unload troops
    {
        unassignVehicle _x;
        [_x] orderGetIn false;
        _x action ["Eject", _plane];
        sleep 0.5; // Small delay between each unit exiting
    } forEach units _group;
    
    // Wait for all units to exit the plane
    waitUntil {
        sleep 0.5;
        {vehicle _x != _plane} count units _group == count units _group
    };
    
    diag_log "All units have exited the plane";
    
    // Notification
    hint "Troops have disembarked. Moving to assembly point.";
    systemChat "Troops have disembarked. Moving to assembly point.";
    
    // Move troops to assembly point
    _group move _assemblyPos;
    
    // AIRCRAFT DEPARTURE
    // -----------------
    
    // Wait a moment before taking off
    sleep 5;
    
    // Notification
    hint "Transport aircraft is departing.";
    systemChat "Transport aircraft is departing.";
    
    // Clear any remaining waypoints
    while {count waypoints _planeGroup > 0} do {
        deleteWaypoint [_planeGroup, 0];
    };
    
    // Set up departure waypoint
    private _wpDepart = _planeGroup addWaypoint [_despawnPos, 0];
    _wpDepart setWaypointType "MOVE";
    _wpDepart setWaypointSpeed "NORMAL";
    
    // Take off and move plane to despawn point
    _plane flyInHeight 100;
    _plane doMove _despawnPos;
    
    
    
    // Wait for the plane to reach the despawn point or be destroyed
    private _departureTimeout = time + 300; // 5 minute timeout
    
    waitUntil {
        sleep 1;
        (_plane distance _despawnPos < 200) || !(alive _plane) || (time > _departureTimeout)
    };
    
    // Check if the plane is still alive before deleting
    if (alive _plane) then {
        // Delete the plane's crew
        {
            deleteVehicle _x;
        } forEach (crew _plane);
        
        // Delete the plane
        deleteVehicle _plane;
        
        diag_log "Plane and crew have been deleted";
    } else {
        diag_log "Plane was destroyed before reaching despawn point";
    };
    
    // Clean up the group
    deleteGroup _planeGroup;
    
    // Final notification
    hint "New recruits have arrived and are ready for orders.";
    systemChat "New recruits have arrived and are ready for orders.";
    
    diag_log "Recruitment process completed successfully";
    
    // Return success
    true
};

// Function to handle recruitment cooldown
RTS_fnc_recruitmentCooldown = {
    RTS_recruitmentCooldown = true;
    private _cooldownTime = RTS_recruitmentConfig select 2 select 1;
    
    diag_log format ["Starting cooldown for %1 seconds", _cooldownTime];
    
    private _startTime = time;
    private _endTime = _startTime + _cooldownTime;
    
    while {time < _endTime} do {
        private _timeLeft = ceil(_endTime - time);
        
        // Update hint every 5 seconds
        if (_timeLeft % 5 == 0) then {
            hint format ["Recruitment cooling down: %1s remaining", _timeLeft];
        };
        
        sleep 1;
    };
    
    RTS_recruitmentCooldown = false;
    hint "Recruitment is now available again.";
    systemChat "Recruitment is now available again.";
    diag_log "Cooldown ended, recruitment available";
};

// Function to add manpower and fuel manually (for testing)
RTS_fnc_addRecruitmentResources = {
    params [["_manpower", 50], ["_fuel", 100]];
    
    ["manpower", _manpower] call RTS_fnc_modifyResource;
    ["fuel", _fuel] call RTS_fnc_modifyResource;
    
    hint format ["Added %1 manpower and %2 fuel", _manpower, _fuel];
    systemChat format ["Added %1 manpower and %2 fuel", _manpower, _fuel];
};

// Function to handle the recruitment order - main entry point
RTS_fnc_recruitOrder = {
    // First ensure all required markers exist
    call RTS_fnc_ensureRecruitmentMarkers;
    
    // Check if recruitment is on cooldown
    if (RTS_recruitmentCooldown) exitWith {
        private _cooldownTime = RTS_recruitmentConfig select 2 select 1;
        hint format ["Recruitment is on cooldown. Please wait %1 seconds.", _cooldownTime];
        systemChat "Recruitment is on cooldown. Please wait.";
        false
    };
    
    // Check if Zeus interface is active
    if (isNull findDisplay 312) then {
        systemChat "Zeus interface required for recruitment. Press Y to open Zeus.";
    };
    
    // Check if economy system is available
    private _economyAvailable = !isNil "RTS_fnc_getResource";
    if (!_economyAvailable) then {
        systemChat "Warning: Economy system not detected. Resource costs may not apply correctly.";
    };
    
    // Verify recruitment configuration exists
    if (isNil "RTS_recruitmentConfig") exitWith {
        systemChat "ERROR: Recruitment configuration not found!";
        diag_log "Recruitment system error: RTS_recruitmentConfig is nil";
        false
    };
    
    // Log recruitment session start
    diag_log "==== RECRUITMENT SESSION STARTED ====";
    diag_log format ["Current Resources - Manpower: %1, Fuel: %2", 
        ["manpower"] call RTS_fnc_getResource, 
        ["fuel"] call RTS_fnc_getResource
    ];
    
    // Show the recruitment dialog
    [] call RTS_fnc_showRecruitmentDialog;
    
    // Return success
    true
};

// Add test command for direct access
RTS_testRecruitment = {
    [] call RTS_fnc_recruitOrder;
};

// Send immediate confirmation that recruitment system is loaded
systemChat "✓ Recruitment system loaded successfully";

// Return true when script is loaded
true