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
    ["unitCost", 10],          // Manpower cost per unit
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
    
    private _markerName = RTS_recruitmentConfig select 6 select 1 + _markerType;
    private _fallbackPosition = [];
    
    // Find fallback position in marker definitions
    {
        _x params ["_type", "_pos"];
        if (_type == _markerType) exitWith {
            _fallbackPosition = _pos;
        };
    } forEach RTS_recruitMarkers;
    
    // Use marker if it exists, otherwise use fallback
    if (markerType _markerName != "") then {
        getMarkerPos _markerName
    } else {
        // Log warning when using fallback
        systemChat format ["Warning: Marker '%1' not found, using fallback position", _markerName];
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

// Function to spawn recruits and manage plane movement
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
    
    // Spawn plane at spawn position
    private _plane = createVehicle [_planeType, _spawnPos, [], 0, "FLY"];
    _plane flyInHeight 300;
    
    // Create crew for the plane
    createVehicleCrew _plane;
    
    // Move plane to landing zone
    _plane move _landPos;
    
    // Notification
    hint "Transport aircraft is en route with new recruits.";
    systemChat "Transport aircraft is en route with new recruits.";
    
    // Wait for the plane to reach the landing zone
    waitUntil {_plane distance _landPos < 200 || !(alive _plane)};
    
    // Exit if plane was destroyed
    if (!alive _plane) exitWith {
        hint "Transport aircraft was destroyed en route.";
        systemChat "Transport aircraft was destroyed en route.";
    };
    
    // Prepare for landing
    _plane land "LAND";
    _plane flyInHeight 0;
    
    // Notification
    hint "Transport aircraft is beginning landing approach.";
    systemChat "Transport aircraft is beginning landing approach.";
    
    // Wait for the plane to touch down
    waitUntil {isTouchingGround _plane || {(getPos _plane) select 2 < 1} || !(alive _plane)};
    
    // Exit if plane was destroyed
    if (!alive _plane) exitWith {
        hint "Transport aircraft was destroyed during landing.";
        systemChat "Transport aircraft was destroyed during landing.";
    };
    
    // Additional wait to ensure the plane is stable
    sleep 5;
    
    // Ensure the plane comes to a complete stop
    _plane setVelocity [0, 0, 0];
    
    diag_log "Plane has landed";
    
    // Notification
    hint "Transport aircraft has landed. Unloading troops...";
    systemChat "Transport aircraft has landed. Unloading troops...";
    
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
    
    // Wait a moment before taking off
    sleep 5;
    
    // Notification
    hint "Transport aircraft is departing.";
    systemChat "Transport aircraft is departing.";
    
    // Take off and move plane to despawn point
    _plane flyInHeight 100;
    _plane doMove _despawnPos;
    
    // Wait for the plane to reach the despawn point or be destroyed
    waitUntil {
        sleep 1;
        (_plane distance _despawnPos < 200) || !(alive _plane)
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
    
    // Final notification
    hint "New recruits have arrived and are ready for orders.";
    systemChat "New recruits have arrived and are ready for orders.";
    
    diag_log "Recruitment process completed";
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
    [] call RTS_fnc_showRecruitmentDialog;
};

// Add test command for direct access
RTS_testRecruitment = {
    [] call RTS_fnc_recruitOrder;
};

// Send immediate confirmation that recruitment system is loaded
systemChat "✓ Recruitment system loaded successfully";

// Return true when script is loaded
true