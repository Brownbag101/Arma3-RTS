// scripts/mission/taskSystemArray.sqf
// Array-based Task Management System for WW2 RTS

// =====================================================================
// LOCATION ARRAY - EDIT THIS TO ADD/MODIFY LOCATIONS
// =====================================================================

// Format of each location entry:
// [
//   "Location ID",            // Unique identifier
//   "Location Name",          // Display name
//   "Location Type",          // Type (e.g., "factory", "port", "airfield", "hq")
//   [x, y, z],                // Position
//   0,                        // Initial intel level (0-100)
//   [                         // Available tasks and rewards for this location
//     ["move_to", "Move To", [["intelligence", 10]]],
//     ["recon", "Recon", [["intelligence", 25]]],
//     ["capture", "Capture", [["manpower", 50], ["iron", 100]]],
//     ["destroy", "Destroy", [["intelligence", 75]]]
//   ],
//   [                         // Briefing texts based on intel level
//     "Unknown location detected. Requires reconnaissance.", // Unknown (0-25%)
//     "Enemy facility identified. Further intel needed.",    // Basic (25-75%)
//     "Full intel gathered on enemy facility. Ready to act." // Complete (75-100%)
//   ],
//   false,                    // Initially captured by player? (default: false)
//   ""                        // Optional: Object name to use as reference point
// ]

// Task locations array - add/edit locations here
MISSION_LOCATIONS = [
    // Location 1 - Port Facility
    [
        "loc_port_1",                  // ID
        "Dover Harbor",                // Name
        "port",                        // Type
        [1572,7152,0],               // Position
        100,                             // Intel level
        [                              // Available tasks
            ["move_to", "Move To", [["training", 10]]],
            ["recon", "Recon", [["intelligence", 25]]],
            ["capture", "Capture", [["manpower", 100], ["oil", 50], ["rubber", 25]]],
            ["destroy", "Destroy", [["intelligence", 50]]],
			["patrol", "Patrol", [["training", 10]]]
        ],
        [                              // Briefing texts
            "Unknown coastal facility detected. Reconnaissance required to identify.",
            "Enemy port facility identified at Dover Harbor. It appears to be a major supply point for Channel operations. Limited defenses observed, but full details are unclear.",
            "Dover Harbor is a major Axis supply port. Intelligence indicates a garrison of approximately one platoon with light anti-aircraft emplacements. Capturing this facility would secure valuable shipping capacity."
        ],
        false,                         // Not captured
        "Location_1"                   // Reference object
    ],
    
    // Location 2 - Factory
    [
        "loc_factory_1",               // ID
        "Birmingham Factory Complex",  // Name
        "factory",                     // Type
        [1663.55,7075.32,0],               // Position
        100,                             // Intel level
        [                              // Available tasks
            ["move_to", "Move To", [["intelligence", 10]]],
            ["recon", "Recon", [["intelligence", 25]]],
            ["capture", "Capture", [["rubber", 75], ["iron", 150], ["oil", 50]]],
            ["destroy", "Destroy", [["intelligence", 75]]],
			["patrol", "Patrol", [["training", 10]]]
        ],
        [                              // Briefing texts
            "Unknown industrial facility detected. Reconnaissance required.",
            "Enemy factory complex identified in Birmingham. Appears to be producing armored vehicles. Moderate defenses observed.",
            "Birmingham Factory Complex is manufacturing Panzer IV tanks. Intelligence indicates heavy machine gun emplacements and a company-strength garrison. Capturing this facility intact would provide significant production capacity."
        ],
        false,                         // Not captured
        "Location_2"                   // Reference object
    ],
    
    // Location 3 - Airfield
    [
        "loc_airfield_1",              // ID
        "RAF Northolt",                // Name
        "airfield",                    // Type
        [698.417,12118.3,0],               // Position
        100,                             // Intel level
        [                              // Available tasks
            ["move_to", "Move To", [["intelligence", 10]]],
            ["recon", "Recon", [["intelligence", 25]]],
            ["capture", "Capture", [["manpower", 125], ["fuel", 100], ["aluminum", 75]]],
            ["destroy", "Destroy", [["intelligence", 100]]]
        ],
        [                              // Briefing texts
            "Unknown airfield detected. Reconnaissance required.",
            "Enemy-occupied airfield identified at former RAF Northolt. Several aircraft visible on the ground. Strong defenses likely.",
            "RAF Northolt is now serving as a forward Luftwaffe base with Me-109 fighters and Ju-88 bombers. Intelligence indicates significant anti-aircraft defenses and a full company of infantry protection. Capturing this airfield would provide a strategic air base."
        ],
        false,                         // Not captured
        "Location_3"                   // Reference object
    ],
    
    // Location 4 - HQ
    [
        "loc_hq_1",                    // ID
        "German Command Post",         // Name
        "hq",                          // Type
        [1897.28,7150.2,0],               // Position
        100,                             // Intel level
        [                              // Available tasks
            ["move_to", "Move To", [["intelligence", 10]]],
            ["recon", "Recon", [["intelligence", 50]]],
            ["capture", "Capture", [["manpower", 150], ["intelligence", 200]]],
            ["destroy", "Destroy", [["intelligence", 150]]],
			["patrol", "Patrol", [["training", 10]]]
        ],
        [                              // Briefing texts
            "Unknown command facility detected. High-value target.",
            "German command post identified. Appears to be a regional headquarters coordinating local Axis forces. Heavy defenses observed.",
            "German regional headquarters confirmed. Intelligence indicates presence of senior officers including Generalmajor Heinrich Mueller. Facility is protected by elite SS guards and defensive fortifications. Capturing this HQ would severely disrupt enemy command capabilities."
        ],
        false,                         // Not captured
        "Location_4"                   // Reference object
    ]
];

// =====================================================================
// CONFIGURATION VALUES - EDIT AS NEEDED
// =====================================================================

// Intel level thresholds
TASK_INTEL_UNKNOWN = 0;    // 0-25%
TASK_INTEL_BASIC = 25;     // 25-75%
TASK_INTEL_COMPLETE = 75;  // 75-100%

// All available task types with required intel levels
TASK_TYPES = [
    ["move_to", "Move To Location", 0],        // Always available
    ["recon", "Gather Intelligence", 0],       // Always available
    ["patrol", "Patrol Area", 25],             // Requires basic intel
    ["capture", "Capture Location", 50],       // Requires basic intel
    ["destroy", "Destroy Location", 50],       // Requires basic intel
    ["defend", "Defend Location", 0]           // Only for player-owned locations
];

// POW Camp location (can be updated at runtime)
TASK_POW_CAMP_POS = [0, 0, 0];

// =====================================================================
// GLOBAL VARIABLES - DO NOT EDIT BELOW THIS LINE
// =====================================================================

// Initialize location objects array
if (isNil "MISSION_locationObjects") then {
    MISSION_locationObjects = [];
};

// Initialize active tasks array if not already defined
if (isNil "MISSION_activeTasks") then {
    MISSION_activeTasks = [];
};

// UI status
if (isNil "MISSION_taskUIOpen") then {
    MISSION_taskUIOpen = false;
};

// Selected location and task
if (isNil "MISSION_selectedLocation") then {
    MISSION_selectedLocation = -1;
};

if (isNil "MISSION_selectedTask") then {
    MISSION_selectedTask = "";
};

// Operation Name
if (isNil "MISSION_operationName") then {
    MISSION_operationName = "Unnamed";
};

// Variable to track what type of target is selected (location or HVT)
if (isNil "MISSION_selectedTargetType") then {
    MISSION_selectedTargetType = "LOCATION";
};

// Index for HVT selection
if (isNil "MISSION_selectedHVT") then {
    MISSION_selectedHVT = -1;
};

// =====================================================================
// CORE FUNCTIONS
// =====================================================================

// Background task checking loop
fnc_taskCheckLoop = {
    while {true} do {
        // Check for task completion
        [] call fnc_checkTasksCompletion;
        
        sleep 5;
    };
};

// Function to initialize the task system
fnc_initTaskSystem = {
    // Find any reference objects for locations
    [] call fnc_findReferenceObjects;
    
    // Create map markers for all locations
    [] call fnc_createLocationMarkers;
    
    // Add task button to menu if it doesn't exist
    [] call fnc_addTaskMenuItem;
    
    // Initialize task checking loop - FIX: Proper spawn syntax
    [] spawn {
        while {true} do {
            // Check for task completion
            call fnc_checkTasksCompletion;
            sleep 5;
        };
    };
    
    systemChat "Task System initialized!";
    diag_log "Task System initialized!";
};

// Function to find reference objects for locations
fnc_findReferenceObjects = {
    {
        private _locationIndex = _forEachIndex;
        private _refObjName = _x select 8;
        
        if (_refObjName != "") then {
            private _refObj = missionNamespace getVariable [_refObjName, objNull];
            
            if (!isNull _refObj) then {
                // Store the reference object
                MISSION_locationObjects set [_locationIndex, _refObj];
                
                // Optionally update the position if reference object exists
                private _pos = getPos _refObj;
                (MISSION_LOCATIONS select _locationIndex) set [3, _pos];
                
                diag_log format ["Found reference object for location %1: %2 at position %3", _locationIndex, _refObjName, _pos];
            } else {
                // Store empty object
                MISSION_locationObjects set [_locationIndex, objNull];
                diag_log format ["Reference object not found for location %1: %2", _locationIndex, _refObjName];
            };
        } else {
            // Store empty object
            MISSION_locationObjects set [_locationIndex, objNull];
        };
    } forEach MISSION_LOCATIONS;
};

// Function to create map markers for all locations
fnc_createLocationMarkers = {
    {
        private _locationIndex = _forEachIndex;
        _x params ["_id", "_name", "_type", "_pos", "_intel", "_tasks", "_briefings", "_captured"];
        
        // Create marker name
        private _markerName = format ["task_location_%1", _locationIndex];
        
        // Create marker
        private _marker = createMarkerLocal [_markerName, _pos];
        
        // Set marker properties based on intel level and type
        [_locationIndex] call fnc_updateLocationMarker;
    } forEach MISSION_LOCATIONS;
};

// Function to update a location's marker based on intel level
fnc_updateLocationMarker = {
    params ["_locationIndex"];
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index for marker update: %1", _locationIndex];
    };
    
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    _locationData params ["_id", "_name", "_type", "_pos", "_intel", "_tasks", "_briefings", "_captured"];
    
    // Check if location is destroyed (position 9 in the array)
    private _isDestroyed = false;
    if (count _locationData > 9) then {
        _isDestroyed = _locationData select 9;
    };
    
    // Get marker name
    private _markerName = format ["task_location_%1", _locationIndex];
    
    // Set marker properties based on status
    private _markerType = "mil_unknown";
    private _markerColor = "ColorBlack";
    private _markerText = "?";
    private _markerAlpha = 1;
    
    // Handle destroyed locations first
    if (_isDestroyed) then {
        _markerColor = "ColorBlack";
        _markerText = format ["%1 (DESTROYED)", _type];
        _markerAlpha = 0.6;
        
        switch (_type) do {
            case "factory": { _markerType = "loc_Stack"; };
            case "port": { _markerType = "loc_Stack"; };
            case "airfield": { _markerType = "loc_Bunker"; };
            case "hq": { _markerType = "loc_Bunker"; };
            default { _markerType = "loc_Ruin"; };
        };
    } else {
        // Handle normal locations as before
        if (_captured) then {
            // Player controlled location
            _markerColor = "ColorGreen";
            _markerText = _type;
            
            switch (_type) do {
                case "factory": { _markerType = "loc_Stack"; };
                case "port": { _markerType = "loc_Stack"; };
                case "airfield": { _markerType = "loc_Bunker"; };
                case "hq": { _markerType = "loc_Bunker"; };
                default { _markerType = "loc_Ruin"; };
            };
        } else {
            // Enemy controlled location
            if (_intel >= TASK_INTEL_COMPLETE) then {
                // Full intel
                _markerColor = "ColorRed";
                _markerText = _type;
                
                switch (_type) do {
                    case "factory": { _markerType = "loc_Stack"; };
                    case "port": { _markerType = "loc_Stack"; };
                    case "airfield": { _markerType = "loc_Bunker"; };
                    case "hq": { _markerType = "loc_Bunker"; };
                    default { _markerType = "loc_Ruin"; };
                };
            } else {
                if (_intel >= TASK_INTEL_BASIC) then {
                    // Basic intel
                    _markerColor = "ColorOrange";
                    _markerText = _type;
                    _markerType = "mil_unknown";
                } else {
                    // Unknown
                    _markerColor = "ColorBlack";
                    _markerText = "?";
                    _markerType = "mil_unknown";
                };
            };
        };
    };
    
    // Update marker
    _markerName setMarkerTypeLocal _markerType;
    _markerName setMarkerColorLocal _markerColor;
    _markerName setMarkerTextLocal _markerText;
    _markerName setMarkerAlpha _markerAlpha;
};

// Function to get the briefing text based on intel level
fnc_getLocationBriefing = {
    params ["_locationIndex"];
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        "Invalid location"
    };
    
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    _locationData params ["_id", "_name", "_type", "_pos", "_intel", "_tasks", "_briefings"];
    
    // Determine which briefing to use based on intel level
    private _briefingIndex = 0;
    
    if (_intel >= TASK_INTEL_COMPLETE) then {
        _briefingIndex = 2;
    } else {
        if (_intel >= TASK_INTEL_BASIC) then {
            _briefingIndex = 1;
        };
    };
    
    // Check if we have a briefing for this level
    if (_briefingIndex < count _briefings) then {
        _briefings select _briefingIndex
    } else {
        "No briefing available"
    };
};

// Function to modify a location's intel level
fnc_modifyLocationIntel = {
    params ["_locationIndex", "_deltaIntel"];
    
    // Additional debug
    diag_log format ["fnc_modifyLocationIntel called with index: %1 (type: %2), delta: %3 (type: %4)", 
        _locationIndex, typeName _locationIndex, _deltaIntel, typeName _deltaIntel];
    
    // Type safety - ensure we have proper number types
    private _locIndex = 0;
    private _deltaValue = 0;
    
    if (typeName _locationIndex == "SCALAR") then {
        _locIndex = _locationIndex;
    } else {
        _locIndex = parseNumber (str _locationIndex);
        diag_log format ["Converting location index to number: %1", _locIndex];
    };
    
    if (typeName _deltaIntel == "SCALAR") then {
        _deltaValue = _deltaIntel;
    } else {
        _deltaValue = parseNumber (str _deltaIntel);
        diag_log format ["Converting delta intel to number: %1", _deltaValue];
    };
    
    if (_locIndex < 0 || _locIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index for intel modification: %1", _locIndex];
        false
    };
    
    private _locationData = MISSION_LOCATIONS select _locIndex;
    private _currentIntel = 0;
    
    // Safely get current intel
    if (count _locationData > 4) then {
        _currentIntel = _locationData select 4;
        
        // Type safety for current intel
        if (typeName _currentIntel != "SCALAR") then {
            _currentIntel = parseNumber (str _currentIntel);
            diag_log format ["Converting current intel to number: %1", _currentIntel];
        };
    } else {
        diag_log format ["Warning: Location data has invalid structure: %1", _locationData];
    };
    
    private _newIntel = (_currentIntel + _deltaValue) min 100 max 0;
    diag_log format ["Intel calculation: %1 + %2 = %3", _currentIntel, _deltaValue, _newIntel];
    
    // Get intel levels with full try-catch for safety
    private _oldIntelLevel = "unknown";
    private _newIntelLevel = "unknown";
    
    try {
        _oldIntelLevel = [_currentIntel] call fnc_getIntelLevel;
    } catch {
        diag_log format ["Error getting old intel level: %1", _exception];
    };
    
    try {
        _newIntelLevel = [_newIntel] call fnc_getIntelLevel;
    } catch {
        diag_log format ["Error getting new intel level: %1", _exception];
    };
    
    // Update intel value in location data
    _locationData set [4, _newIntel];
    
    // Check if intel level changed
    if (_oldIntelLevel != _newIntelLevel) then {
        diag_log format ["Intel level changed from %1 to %2", _oldIntelLevel, _newIntelLevel];
        
        // Intel level crossed a threshold, update marker
        [_locIndex] call fnc_updateLocationMarker;
        
        // Notify player if intel increased
        if (_newIntelLevel == "basic" && _oldIntelLevel == "unknown") then {
            private _locationType = _locationData select 2;
            hint format ["Basic intelligence gathered on %1 location!", _locationType];
            systemChat format ["Initial intelligence gathered on %1 location.", _locationType];
        };
        
        if (_newIntelLevel == "complete" && _oldIntelLevel != "complete") then {
            private _locationType = _locationData select 2;
            hint format ["Full intelligence gathered on %1 location!", _locationType];
            systemChat format ["Comprehensive intelligence gathered on %1 location.", _locationType];
        };
    };
    
    true
};

// Function to get intel level category from percentage
fnc_getIntelLevel = {
    params ["_intelPercent"];
    
    // Force to number type
    private _intelValue = 0;
    
    // Type safety
    if (typeName _intelPercent == "SCALAR") then {
        _intelValue = _intelPercent;
    } else {
        // Try to parse it as a number, with fallback to 0
        _intelValue = parseNumber (str _intelPercent);
        diag_log format ["Warning: Intel percent wasn't a number: %1, converted to %2", _intelPercent, _intelValue];
    };
    
    // Make sure thresholds are numbers too
    private _basicThreshold = TASK_INTEL_BASIC;
    private _completeThreshold = TASK_INTEL_COMPLETE;
    
    if (typeName _basicThreshold != "SCALAR") then {
        _basicThreshold = parseNumber (str _basicThreshold);
    };
    
    if (typeName _completeThreshold != "SCALAR") then {
        _completeThreshold = parseNumber (str _completeThreshold);
    };
    
    // Now do the safe comparison with numbers
    if (_intelValue >= _completeThreshold) then {
        "complete"
    } else {
        if (_intelValue >= _basicThreshold) then {
            "basic"
        } else {
            "unknown"
        };
    };
};

// Function to set a location as captured
fnc_setCapturedLocation = {
    params ["_locationIndex", "_isCaptured"];
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index for capture state change: %1", _locationIndex];
        false
    };
    
    // Update captured status
    (MISSION_LOCATIONS select _locationIndex) set [7, _isCaptured];
    
    // Update marker
    [_locationIndex] call fnc_updateLocationMarker;
    
    true
};

// Function to set a location as destroyed
fnc_setDestroyedLocation = {
    params ["_locationIndex"];
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index for destruction: %1", _locationIndex];
        false
    };
    
    // Get reference object
    private _refObj = MISSION_locationObjects select _locationIndex;
    
    // Mark object as destroyed if it exists
    if (!isNil "_refObj" && {!isNull _refObj}) then {
        _refObj setVariable ["destroyed", true, true];
        
        // Add destruction effects
        private _fire = "test_EmptyObjectForFireBig" createVehicle (getPos _refObj);
        _fire attachTo [_refObj, [0, 0, 0]];
    };
    
    // Update marker (keep enemy-controlled)
    [_locationIndex] call fnc_updateLocationMarker;
    
    true
};

// =====================================================================
// TASK CREATION AND MANAGEMENT CORE FUNCTIONS
// =====================================================================

// Function to create a task
fnc_createTask = {
    params ["_locationIndex", "_taskType", "_assignedUnits"];
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index for task creation: %1", _locationIndex];
        ""
    };
    
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    _locationData params ["_id", "_name", "_type", "_pos", "_intel", "_availableTasks"];
    
    // Get task type info
    private _taskTypeIndex = TASK_TYPES findIf {(_x select 0) == _taskType};
    if (_taskTypeIndex == -1) exitWith {
        diag_log format ["Invalid task type: %1", _taskType];
        ""
    };
    
    private _taskTypeName = (TASK_TYPES select _taskTypeIndex) select 1;
    
    // Create unique task ID
    private _taskId = format ["task_%1_%2_%3", _locationIndex, _taskType, round(serverTime)];
    
    // Generate task description
			private _taskDescription = [
			format ["Operation %1: %2 - %3", MISSION_operationName, _taskTypeName, _name],     // Title
			format ["Your orders: %1 the enemy %2 at %3.", toLower _taskTypeName, _type, _name],  // Description
			format ["Op %1: %2 - %3", MISSION_operationName, _taskTypeName, _name]      // HUD
];
    
    // Clear any previous tasks from these units
    {
        // Get current task for this unit
        private _currentTask = currentTask _x;
        if (!isNull _currentTask) then {
            // Unassign the current task from this unit explicitly
            [_x] call BIS_fnc_taskCurrent;
            diag_log format ["Unassigned previous task from %1", name _x];
        };
    } forEach _assignedUnits;
    
    // Create the task - log diagnostics
    diag_log format ["Creating task: %1 at position %2", _taskId, _pos];
    
    // Create task only for selected units (not whole side)
    private _taskResult = [
        _assignedUnits,  // Assign ONLY to these units 
        _taskId,
        _taskDescription,
        _pos,
        "CREATED",
        10,
        true,
        "default"
    ] call BIS_fnc_taskCreate;
    
    diag_log format ["Task creation result: %1", _taskResult];
    
    // If task creation failed, exit
    if (_taskResult isEqualTo "") exitWith {
        diag_log "Task creation failed";
        ""
    };
    
    // Set as current task
    [_taskId] call BIS_fnc_taskSetCurrent;
    diag_log "Successfully set as current task";
    
    // Create visible marker for Zeus
    private _markerName = format ["zeus_task_marker_%1", _taskId];
    private _marker = createMarker [_markerName, _pos];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorBlue";
    _marker setMarkerText _taskTypeName;
    diag_log format ["Created visible marker for Zeus: %1", _markerName];
    
    // Add Zeus curator icon for z1
    private _curatorModule = missionNamespace getVariable ["z1", objNull];
    private _taskIcon = "";
    
    // Select appropriate icon based on task type
    switch (_taskType) do {
        case "move_to": { _taskIcon = "\A3\ui_f\data\map\markers\military\flag_ca.paa"; };
        case "recon": { _taskIcon = "\A3\ui_f\data\map\markers\military\recon_ca.paa"; };
        case "patrol": { _taskIcon = "\A3\ui_f\data\map\markers\military\circle_ca.paa"; };
        case "capture": { _taskIcon = "\A3\ui_f\data\map\markers\military\end_ca.paa"; };
        case "destroy": { _taskIcon = "\A3\ui_f\data\map\markers\military\destroy_ca.paa"; };
        case "defend": { _taskIcon = "\A3\ui_f\data\map\markers\military\flag_ca.paa"; };
        default { _taskIcon = "\A3\ui_f\data\map\markers\military\objective_ca.paa"; };
    };
    
    // Store icon ID for later removal
    private _iconID = -1;
    
    // Add curator icon if module exists
    if (!isNull _curatorModule) then {
        private _iconText = format ["Op %1: %2", MISSION_operationName, _taskTypeName];
		_iconID = [_curatorModule, [_taskIcon, [0, 0.3, 0.6, 1], _pos, 1, 1, 0, _iconText], false] call BIS_fnc_addCuratorIcon;
        diag_log format ["Created Zeus curator icon for task %1 with ID: %2", _taskId, _iconID];
    } else {
        diag_log "Warning: Could not find Zeus module 'z1' for curator icon";
    };
    
    // Store icon ID in task object for later removal
    private _iconData = [_curatorModule, _iconID];
    
    // Create task object with all necessary data
    private _taskObject = [
        _taskId,                 // Task ID
        _locationIndex,          // Location index
        _taskType,               // Task type
        _assignedUnits,          // Assigned units
        serverTime,              // Creation time
        "CREATED",               // Status
        [],                      // Triggers
        {},                      // Completion condition code (will be filled below)
        _markerName,             // Store marker name for cleanup
        _iconData                // Store curator icon data [module, iconID]
    ];
    
    // Create completion condition based on task type
    private _completionCode = {};
    private _triggers = [];
    
    switch (_taskType) do {
        case "move_to": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_locationIndex", "_taskType", "_assignedUnits"];
                
                private _locationData = MISSION_LOCATIONS select _locationIndex;
                private _pos = _locationData select 3;
                
                // Task is complete if any assigned unit is within 100m of target
                private _anyUnitPresent = false;
                {
                    if (!isNull _x && {alive _x} && {_x distance _pos < 100}) exitWith {
                        systemChat format ["Unit %1 has reached objective area", name _x];
                        diag_log format ["Task completion triggered by %1 at %2m from objective", name _x, _x distance _pos];
                        _anyUnitPresent = true;
                        
                        // Add intel gain when unit reaches destination
                        private _availableTasks = _locationData select 5;
                        {
                            if (count _x >= 3 && (_x select 0) == "move_to") then {
                                private _rewards = _x select 2;
                                {
                                    if (count _x >= 2 && (_x select 0) == "intelligence") then {
                                        private _intelReward = _x select 1;
                                        if (typeName _intelReward == "SCALAR" && _intelReward > 0) then {
                                            // Use exactly the configured reward amount (not multiplied)
                                            [_locationIndex, _intelReward] call fnc_modifyLocationIntel;
                                            diag_log format ["Move completion intel gain: +%1 for location %2", _intelReward, _locationIndex];
                                        };
                                    };
                                } forEach _rewards;
                            };
                        } forEach _availableTasks;
                    };
                } forEach _assignedUnits;
                
                _anyUnitPresent
            };
        };
        case "recon": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_locationIndex", "_taskType", "_assignedUnits"];
                
                private _locationData = MISSION_LOCATIONS select _locationIndex;
                private _pos = _locationData select 3;
                private _intel = _locationData select 4;
                
                // For debugging
                diag_log format ["Checking recon task completion: Location %1, Current intel: %2/100", _locationIndex, _intel];
                
                // Increase intel if unit is in the area
                private _unitInArea = false;
                {
                    if (!isNull _x && {alive _x} && {_x distance _pos < 200}) exitWith {
                        _unitInArea = true;
                    };
                } forEach _assignedUnits;
                
                if (_unitInArea && random 1 > 0.7) then { // 30% chance per check when unit is present
                    [_locationIndex, 1] call fnc_modifyLocationIntel;
                    diag_log format ["Unit present in recon area, intel increased to %1", 
                        (MISSION_LOCATIONS select _locationIndex) select 4];
                };
                
                // Task complete when intel reaches 100%
                _intel >= 100
            };
            
            // Create better intel trigger using the new function
            private _trig = [_locationIndex, _pos] call fnc_setupReconTrigger;
            _triggers pushBack _trig;
            
            // Also add the original trigger for backward compatibility
            private _oldTrig = createTrigger ["EmptyDetector", _pos, false];
            _oldTrig setTriggerArea [200, 200, 0, false];
            
            // Use exact side of player for better compatibility
            private _playerSide = side player;
            _oldTrig setTriggerActivation [str _playerSide, "PRESENT", false];
            _oldTrig setTriggerStatements [
                "this", 
                format ["[%1, 1] call fnc_modifyLocationIntel; diag_log 'Intel trigger activated';", _locationIndex],
                ""
            ];
            
            _triggers pushBack _oldTrig;
        };
        case "patrol": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_locationIndex", "_taskType", "_assignedUnits", "_startTime"];
                
                private _locationData = MISSION_LOCATIONS select _locationIndex;
                private _pos = _locationData select 3;
                
                // Patrol is complete after 5 minutes in area
                private _timeInArea = serverTime - _startTime;
                private _anyUnitPresent = false;
                
                {
                    if (!isNull _x && {alive _x} && {_x distance _pos < 200}) exitWith {
                        _anyUnitPresent = true;
                    };
                } forEach _assignedUnits;
                
                diag_log format ["Patrol task: %1 time elapsed, unit present: %2", _timeInArea, _anyUnitPresent];
                
                (_timeInArea > 30) && _anyUnitPresent
            };
        };
        case "capture": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_locationIndex", "_taskType", "_assignedUnits"];
                
                private _locationData = MISSION_LOCATIONS select _locationIndex;
                private _pos = _locationData select 3;
                
                // Enhanced logging for capture task evaluation
                diag_log format ["Evaluating capture completion for task %1 at location %2", _taskId, _locationIndex];
                
                // Capture is complete when location area is clear of enemies and friendly unit is present
                private _nearEnemies = _pos nearEntities [["Man", "Car", "Tank"], 200];
                _nearEnemies = _nearEnemies select {side _x != side player && side _x != civilian};
                
                private _friendlyPresent = false;
                {
                    if (!isNull _x && {alive _x} && {_x distance _pos < 100}) exitWith {
                        _friendlyPresent = true;
                        diag_log format ["Friendly unit %1 detected at %2m from objective", name _x, _x distance _pos];
                    };
                } forEach _assignedUnits;
                
                diag_log format ["Capture task check: %1 enemies, friendly present: %2", count _nearEnemies, _friendlyPresent];
                
                // Add some debug visuals for easier testing
                if (_friendlyPresent && count _nearEnemies == 0) then {
                    if (isServer) then {
                        diag_log "Capture conditions met!";
                        
                        
                    };
                } else {
                    // Remove marker if conditions no longer met
                    if (!isNil "CAPTURE_DEBUG_MARKER") then {
                        deleteMarker "CAPTURE_DEBUG_MARKER";
                        CAPTURE_DEBUG_MARKER = nil;
                    };
                };
                
                // Return true if conditions are met - very simple and direct check
                (count _nearEnemies == 0) && _friendlyPresent
            };
            
            // Create an enhanced capture trigger
            private _captureTrig = createTrigger ["EmptyDetector", _pos, false];
            _captureTrig setTriggerArea [200, 200, 0, false];
            _captureTrig setTriggerActivation [str(side player), "PRESENT", false];
            
            // Tag the trigger for later identification and cleanup
            _captureTrig setVariable ["captureTaskTrigger", true];
            _captureTrig setVariable ["associatedTask", _taskId];
            _captureTrig setVariable ["locationIndex", _locationIndex];
            
            _captureTrig setTriggerStatements [
                // Condition: Player units present, no enemy units
                "this && {({side _x != side player && side _x != civilian && alive _x} count thisList) == 0}",
                // Activation: Show feedback message and create debug marker
                format [
                    "
                    if (isServer) then {
                        systemChat 'Area secured. Hold position to capture.';
                        hint 'Area secured. Hold position to capture.';
                        
                        
                    };
                    ",
                    _pos
                ],
                // Deactivation: Remove marker if conditions no longer met
                "
                if (!isNil 'CAPTURE_DEBUG_MARKER') then {
                    deleteMarker 'CAPTURE_DEBUG_MARKER';
                    CAPTURE_DEBUG_MARKER = nil;
                    diag_log 'Removed capture debug marker';
                };
                "
            ];
            
            _triggers pushBack _captureTrig;
        };
        case "destroy": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_locationIndex", "_taskType", "_assignedUnits"];
                
                private _locationData = MISSION_LOCATIONS select _locationIndex;
                private _refObj = MISSION_locationObjects select _locationIndex;
                
                // Check if destruction target was destroyed
                if (!isNil "_refObj" && {!isNull _refObj}) then {
                    _refObj getVariable ["destroyed", false]
                } else {
                    false
                };
            };
            
            // Create trigger for player-initiated destruction (e.g., explosives)
            private _trig = createTrigger ["EmptyDetector", _pos, false];
            _trig setTriggerArea [50, 50, 0, false];
            _trig setTriggerActivation [str(side player), "PRESENT", false];
            _trig setTriggerStatements [
                "this && {({_x distance thisTrigger < 50} count (allMissionObjects 'TimeBombCore') > 0)}",
                format ["[%1] call fnc_setDestroyedLocation; diag_log 'Destruction trigger activated';", _locationIndex],
                ""
            ];
            
            _triggers pushBack _trig;
        };
        case "defend": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_locationIndex", "_taskType", "_assignedUnits", "_startTime"];
                
                private _locationData = MISSION_LOCATIONS select _locationIndex;
                private _pos = _locationData select 3;
                
                // Defense is complete after 10 minutes with no enemies in area
                private _timeDefending = serverTime - _startTime;
                private _nearEnemies = _pos nearEntities [["Man", "Car", "Tank"], 300];
                _nearEnemies = _nearEnemies select {side _x != side player};
                
                diag_log format ["Defense task: %1 time elapsed, %2 enemies in area", _timeDefending, count _nearEnemies];
                
                (_timeDefending > 600) && (count _nearEnemies == 0)
            };
        };
    };
    
    // Set the completion code
    _taskObject set [7, _completionCode];
    
    // Set the triggers
    _taskObject set [6, _triggers];
    
    // Add task to active tasks
    MISSION_activeTasks pushBack _taskObject;
    
    // Return the task ID
    _taskId
};

// Function to complete a task - MODIFIED WITH FACTORY RESOURCE BONUSES
fnc_completeTask = {
    params ["_taskId", "_success"];
    
    // Find task in active tasks
    private _taskIndex = MISSION_activeTasks findIf {(count _x > 0) && {(_x select 0) == _taskId}};
    if (_taskIndex == -1) exitWith {
        diag_log format ["Task not found: %1", _taskId];
        false
    };
    
    private _taskObj = MISSION_activeTasks select _taskIndex;
    
    // Safely extract task data
    private _locationIndex = -1;
    private _taskType = "";
    private _assignedUnits = [];
    private _markerName = "";
    private _iconData = [objNull, -1];
    
    if (count _taskObj > 1) then { _locationIndex = _taskObj select 1; };
    if (count _taskObj > 2) then { _taskType = _taskObj select 2; };
    if (count _taskObj > 3) then { _assignedUnits = _taskObj select 3; };
    if (count _taskObj > 8) then { _markerName = _taskObj select 8; };
    if (count _taskObj > 9) then { _iconData = _taskObj select 9; };
    
    // Handle bad task data
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index in task: %1", _taskId];
        false
    };
    
    // Get location data
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    
    // Safe extraction of location data
    private _locId = "";
    private _name = "Unknown Location";
    private _type = "facility";
    private _pos = [0,0,0];
    private _intel = 0;
    private _availableTasks = [];
    
    if (count _locationData > 0) then { _locId = _locationData select 0; };
    if (count _locationData > 1) then { _name = _locationData select 1; };
    if (count _locationData > 2) then { _type = _locationData select 2; };
    if (count _locationData > 3) then { _pos = _locationData select 3; };
    if (count _locationData > 4) then { _intel = _locationData select 4; };
    if (count _locationData > 5) then { _availableTasks = _locationData select 5; };
    
    // Update task state
    private _state = if (_success) then {"SUCCEEDED"} else {"FAILED"};
    
    // Set task state correctly - FIX: Only pass taskId and state
    [_taskId, _state] call BIS_fnc_taskSetState;
    
    // If successful, give rewards
    if (_success) then {
        // Find task type name for messaging
        private _taskTypeName = _taskType;
        private _taskTypeIndex = TASK_TYPES findIf {(count _x > 0) && {(_x select 0) == _taskType}};
        if (_taskTypeIndex != -1 && {count (TASK_TYPES select _taskTypeIndex) > 1}) then {
            _taskTypeName = (TASK_TYPES select _taskTypeIndex) select 1;
        };
        
        // Clear notification and feedback
        hint format ["✓ Task Complete: %1 at %2", _taskTypeName, _name];
        systemChat format ["Task '%1 at %2' completed successfully!", _taskTypeName, _name];
        
        // Find rewards for this task type
        private _taskReward = [];
        private _intelReward = 0;
        
        {
            if (count _x >= 3) then {
                private _tType = _x select 0;
                
                if (_tType == _taskType) then {
                    _taskReward = _x select 2;
                    diag_log format ["Found matching reward for %1: %2", _taskType, _taskReward];
                    
                    // Look for intelligence reward specifically
                    {
                        if (count _x >= 2) then {
                            private _resourceType = _x select 0;
                            private _amount = _x select 1;
                            
                            if (_resourceType == "intelligence") then {
                                _intelReward = _amount;
                            };
                        };
                    } forEach _taskReward;
                };
            };
        } forEach _availableTasks;
        
        // Special handling for move_to task type - directly add intelligence
        if (_taskType == "move_to" && _intelReward > 0) then {
            // Directly modify location intel
            diag_log format ["Adding %1 intel directly for move_to task at location %2", _intelReward, _locationIndex];
            [_locationIndex, _intelReward] call fnc_modifyLocationIntel;
            systemChat format ["Gained %1 intelligence about %2.", _intelReward, _name];
        };
        
        // Apply other rewards with feedback
        {
            if (count _x >= 2) then {
                private _resourceType = _x select 0;
                private _amount = _x select 1;
                
                // Skip intelligence for move_to as we handled it separately
                if (_taskType == "move_to" && _resourceType == "intelligence") then {
                    continue;
                };
                
                // Ensure amount is a number
                if (typeName _amount != "SCALAR") then {
                    _amount = parseNumber (str _amount);
                    diag_log format ["Converted non-scalar amount: %1 to %2", _x select 1, _amount];
                };
                
                // Use economy system to add resources
                if (!isNil "RTS_fnc_modifyResource") then {
                    [_resourceType, _amount] call RTS_fnc_modifyResource;
                    systemChat format ["Received %1 %2 for completing task.", _amount, _resourceType];
                    diag_log format ["Added resource reward: %1 %2", _amount, _resourceType];
                } else {
                    diag_log "WARNING: RTS_fnc_modifyResource is not defined, cannot give rewards";
                    systemChat format ["Error: Could not add %1 %2 (economy system unavailable)", _amount, _resourceType];
                };
            };
        } forEach _taskReward;
        
        // =============================================
        // FACTORY RESOURCE SYSTEM INTEGRATION - START
        // =============================================
        
        // Handle capture/destroy effects with factory resource bonuses
        if (_taskType == "capture") then {
            // Mark location as captured
            [_locationIndex, true] call fnc_setCapturedLocation;
            
            // Apply resource bonuses directly
            if (!isNil "fnc_applyLocationResourceBonus") then {
                diag_log format ["Directly calling resource bonus application for location %1", _locationIndex];
                [_locationIndex] call fnc_applyLocationResourceBonus;
            } else {
                diag_log "WARNING: fnc_applyLocationResourceBonus is not defined";
            };
            
            hint format ["Location captured: %1", _name];
            systemChat "Location has been captured and is now under friendly control.";
        };
        
        if (_taskType == "destroy") then {
            // Remove resource bonuses directly (in case location was captured before)
            if (!isNil "fnc_removeLocationResourceBonus") then {
                diag_log format ["Directly calling resource bonus removal for location %1", _locationIndex];
                [_locationIndex] call fnc_removeLocationResourceBonus;
            };
            
            // Mark location as destroyed
            [_locationIndex] call fnc_setDestroyedLocation;
            
            hint format ["Location destroyed: %1", _name];
            systemChat "Location has been destroyed. Enemy can no longer use it.";
        };
        
        // =============================================
        // FACTORY RESOURCE SYSTEM INTEGRATION - END
        // =============================================
        
    } else {
        // Failed task feedback
        hint format ["✗ Task Failed: %1 at %2", _taskType, _name];
        systemChat format ["The operation at %1 has failed!", _name];
    };
    
    // Clean up
    private _triggers = [];
    if (count _taskObj > 6) then { _triggers = _taskObj select 6; };
    
    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach _triggers;
    
    // Delete Zeus marker if it exists
    if (_markerName != "") then {
        if (markerType _markerName != "") then {
            deleteMarker _markerName;
            diag_log format ["Deleted Zeus marker: %1", _markerName];
        };
    };
    
    // Remove Zeus curator icon if it exists
    if (!isNil "_iconData" && {count _iconData >= 2}) then {
        _iconData params ["_curatorModule", "_iconID"];
        
        if (!isNull _curatorModule && _iconID != -1) then {
            [_curatorModule, _iconID] call BIS_fnc_removeCuratorIcon;
            diag_log format ["Removed Zeus curator icon ID: %1", _iconID];
        };
    };
    
    // Delete the task properly
    [_taskId] call BIS_fnc_deleteTask;
    
    // Remove from active tasks
    MISSION_activeTasks deleteAt _taskIndex;
    
    // Log completion
    diag_log format ["Task %1 completed with result: %2", _taskId, _success];
    
    true
};

// Function to check task completion
fnc_checkTasksCompletion = {
    private _completedTasks = [];
    
    {
        // Safely extract task information
        private _taskObj = _x;
        private _taskId = "";
        private _locationIndex = -1;
        private _taskType = "";
        private _assignedUnits = [];
        private _completionCode = {};
        
        // Handle possible missing array elements safely
        if (count _taskObj > 0) then { _taskId = _taskObj select 0; };
        if (count _taskObj > 1) then { _locationIndex = _taskObj select 1; };
        if (count _taskObj > 2) then { _taskType = _taskObj select 2; };
        if (count _taskObj > 3) then { _assignedUnits = _taskObj select 3; };
        if (count _taskObj > 7) then { _completionCode = _taskObj select 7; };
        
        // Skip if missing critical information
        if (_taskId == "" || _completionCode isEqualTo {}) then {
            diag_log format ["Invalid task data: %1", _taskObj];
            continue;
        };
        
        // Ensure we have valid units (removes any null or dead units)
        _assignedUnits = _assignedUnits select {!isNull _x && alive _x};
        
        // Skip check if all units are gone
        if (count _assignedUnits == 0) then {
            diag_log format ["Task %1: All assigned units are dead or null, will fail task", _taskId];
            _completedTasks pushBack [_taskId, false]; // Mark for failure
        } else {
            // Check if any assigned units are near the objective (for move_to debug)
            if (_taskType == "move_to" && _locationIndex != -1) then {
                if (_locationIndex < count MISSION_LOCATIONS) then {
                    private _locationData = MISSION_LOCATIONS select _locationIndex;
                    if (count _locationData > 3) then {
                        private _pos = _locationData select 3;
                        
                        // Sort units by distance to objective
                        private _sortedUnits = [_assignedUnits, [], {_x distance _pos}, "ASCEND"] call BIS_fnc_sortBy;
                        
                        // Log closest unit for debugging
                        if (count _sortedUnits > 0) then {
                            private _unit = _sortedUnits select 0;
                            private _distance = _unit distance _pos;
                            if (_distance < 150) then {
                                diag_log format ["Task %1 (%2): Closest unit %3 is %4m from objective", 
                                    _taskId, _taskType, name _unit, round _distance];
                            };
                        };
                    };
                };
            };
            
            // Check if task is complete using its completion criteria - safely
            private _isComplete = false;
            
            private _fnc_safeCall = {
                params ["_code", "_params", ["_default", false]];
                private "_result";
                _result = _default;
                
                private _success = false;
                if (!isNil "_code" && !isNil "_params") then {
                    _result = _params call _code;
                    _success = true;
                };
                
                [_success, _result]
            };
            
            private _callResult = [_completionCode, [_taskObj], false] call _fnc_safeCall;
            
            if (_callResult select 0) then {
                _isComplete = _callResult select 1;
                
                if (_isComplete) then {
                    diag_log format ["Task %1 (%2) completion detected!", _taskId, _taskType];
                    _completedTasks pushBack [_taskId, true]; // Mark for success
                };
            } else {
                diag_log format ["Error in completion code for task %1", _taskId];
            };
        };
    } forEach MISSION_activeTasks;
    
    // Process completed tasks
    {
        _x params ["_taskId", "_success"];
        [_taskId, _success] call fnc_completeTask;
    } forEach _completedTasks;
};

// =====================================================================
// CORE INITIALIZATION FUNCTION
// =====================================================================

// Function to initialize the task system
fnc_initTaskSystem = {
    // Find any reference objects for locations
    [] call fnc_findReferenceObjects;
    
    // Create map markers for all locations
    [] call fnc_createLocationMarkers;
    
    // Add task button to menu if it doesn't exist
    [] call fnc_addTaskMenuItem;
    
    // Ensure MISSION_activeTasks is initialized
    if (isNil "MISSION_activeTasks") then {
        MISSION_activeTasks = [];
    };
    
    // Initialize task checking loop with proper error handling
    [] spawn {
        while {true} do {
            try {
                // Check for task completion
                call fnc_checkTasksCompletion;
            } catch {
                diag_log format ["Error in task checking loop: %1", _exception];
                systemChat "Warning: Task system encountered an error. Check RPT logs.";
            };
            sleep 5;
        };
    };
    
    systemChat "Task System initialized!";
    diag_log "Task System initialized!";
};

// =====================================================================
// HELPER FUNCTIONS FOR TASKS
// =====================================================================

// Function to set a location as captured
fnc_setCapturedLocation = {
    params ["_locationIndex", "_isCaptured"];
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index for capture state change: %1", _locationIndex];
        false
    };
    
    // Update captured status
    (MISSION_LOCATIONS select _locationIndex) set [7, _isCaptured];
    
    // Update marker
    [_locationIndex] call fnc_updateLocationMarker;
    
    true
};

// Function to set a location as destroyed
fnc_setDestroyedLocation = {
    params ["_locationIndex"];
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index for destruction: %1", _locationIndex];
        false
    };
    
    // Get reference object
    private _refObj = MISSION_locationObjects select _locationIndex;
    
    // Mark object as destroyed if it exists
    if (!isNil "_refObj" && {!isNull _refObj}) then {
        _refObj setVariable ["destroyed", true, true];
        
        // Add destruction effects
        private _fire = "test_EmptyObjectForFireBig" createVehicle (getPos _refObj);
        _fire attachTo [_refObj, [0, 0, 0]];
    };
    
    // Update marker (keep enemy-controlled)
    [_locationIndex] call fnc_updateLocationMarker;
    
    true
};

// Function to modify a location's intel level
fnc_modifyLocationIntel = {
    params ["_locationIndex", "_deltaIntel"];
    
    // Additional debug
    diag_log format ["fnc_modifyLocationIntel called with index: %1 (type: %2), delta: %3 (type: %4)", 
        _locationIndex, typeName _locationIndex, _deltaIntel, typeName _deltaIntel];
    
    // Type safety - ensure we have proper number types
    if (typeName _locationIndex != "SCALAR") then {
        _locationIndex = parseNumber (str _locationIndex);
        diag_log format ["Converting location index to number: %1", _locationIndex];
    };
    
    if (typeName _deltaIntel != "SCALAR") then {
        _deltaIntel = parseNumber (str _deltaIntel);
        diag_log format ["Converting delta intel to number: %1", _deltaIntel];
    };
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index for intel modification: %1", _locationIndex];
        false
    };
    
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    private _currentIntel = _locationData select 4;
    
    // Type safety for current intel
    if (typeName _currentIntel != "SCALAR") then {
        _currentIntel = parseNumber (str _currentIntel);
        diag_log format ["Converting current intel to number: %1", _currentIntel];
    };
    
    private _newIntel = (_currentIntel + _deltaIntel) min 100 max 0;
    diag_log format ["Intel calculation: %1 + %2 = %3", _currentIntel, _deltaIntel, _newIntel];
    
    // Store old intel level to check for threshold crossings
    private _oldIntelLevel = [_currentIntel] call fnc_getIntelLevel;
    
    // Update intel
    _locationData set [4, _newIntel];
    
    // Check if intel level changed
    private _newIntelLevel = [_newIntel] call fnc_getIntelLevel;
    if (_oldIntelLevel != _newIntelLevel) then {
        // Intel level crossed a threshold, update marker
        [_locationIndex] call fnc_updateLocationMarker;
        
        // Notify player if intel increased
        //if (_newIntelLevel > _oldIntelLevel && _deltaIntel > 0) then {
        //    private _locationType = _locationData select 2;
        //    hint format ["Intelligence level increased for %1 location!", _locationType];
        //    systemChat format ["New intelligence gathered on %1 location.", _locationType];
        //};
    };
    
    true
};

// Function to get intel level category from percentage
fnc_getIntelLevel = {
    params ["_intelPercent"];
    
    // Type safety
    if (typeName _intelPercent != "SCALAR") then {
        _intelPercent = parseNumber (str _intelPercent);
    };
    
    if (_intelPercent >= TASK_INTEL_COMPLETE) then {
        "complete"
    } else {
        if (_intelPercent >= TASK_INTEL_BASIC) then {
            "basic"
        } else {
            "unknown"
        };
    };
};

// =====================================================================
// USER INTERFACE
// =====================================================================

// Function to add task button to menu
fnc_addTaskMenuItem = {
    // Check if menu buttons exists
    if (isNil "RTS_menuButtons") exitWith {
        systemChat "Error: RTS_menuButtons not found. Cannot add task menu item.";
    };
    
    // Check if task is already in the menu
    private _index = RTS_menuButtons findIf {(_x select 0) == "tasks"};
    
    if (_index == -1) then {
        // Add tasks to menu buttons
        RTS_menuButtons pushBack [
            "tasks", 
            "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\map_ca.paa", 
            "Operations", 
            "Plan and execute military operations"
        ];
        
        systemChat "Added Operations button to the menu.";
    };
};

// Function to open the Task UI
fnc_openTaskUI = {
    if (dialog) then {closeDialog 0};
    createDialog "RscDisplayEmpty";
    
    private _display = findDisplay -1;
    
    if (isNull _display) exitWith {
        diag_log "Failed to create Task UI";
        systemChat "Error: Could not create operations interface";
        false
    };
    
    // Set flag
    MISSION_taskUIOpen = true;
    
    // ===== CREATE BACKGROUND PANELS =====
    // Create background - use higher control ID (9000+) to ensure it's on top
    private _background = _display ctrlCreate ["RscText", 9000];
    _background ctrlSetPosition [0.1 * safezoneW + safezoneX, 0.05 * safezoneH + safezoneY, 0.8 * safezoneW, 0.75 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title row background - spanning full width
    private _titleRow = _display ctrlCreate ["RscText", 9001];
    _titleRow ctrlSetPosition [0.1 * safezoneW + safezoneX, 0.05 * safezoneH + safezoneY, 0.8 * safezoneW, 0.05 * safezoneH];
    _titleRow ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _titleRow ctrlCommit 0;

    // Create main title - left side
    private _title = _display ctrlCreate ["RscText", 9002];
    _title ctrlSetPosition [0.11 * safezoneW + safezoneX, 0.05 * safezoneH + safezoneY, 0.2 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetText "Operations Command";
    _title ctrlCommit 0;

    // Create operation name label - center left
    private _opNameLabel = _display ctrlCreate ["RscText", 9003];
    _opNameLabel ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.05 * safezoneH + safezoneY, 0.15 * safezoneW, 0.05 * safezoneH];
    _opNameLabel ctrlSetText "Operation Name:";
    _opNameLabel ctrlCommit 0;

    // Create operation name input field - center
    private _opNameInput = _display ctrlCreate ["RscEdit", 9004];
    _opNameInput ctrlSetPosition [0.48 * safezoneW + safezoneX, 0.055 * safezoneH + safezoneY, 0.18 * safezoneW, 0.04 * safezoneH];
    _opNameInput ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.8];
    _opNameInput ctrlSetText MISSION_operationName;
    _opNameInput ctrlCommit 0;
    
    // ===== ADD TARGET TYPE SELECTOR =====
    // Create target type selector - more prominent position
    private _targetTypeLabel = _display ctrlCreate ["RscText", 9005];
    _targetTypeLabel ctrlSetPosition [0.12 * safezoneW + safezoneX, 0.115 * safezoneH + safezoneY, 0.1 * safezoneW, 0.03 * safezoneH];
    _targetTypeLabel ctrlSetText "Target Type:";
    _targetTypeLabel ctrlSetTextColor [1, 1, 1, 1];
    _targetTypeLabel ctrlCommit 0;
    
    // Create location button - more visible styling
    private _locationBtn = _display ctrlCreate ["RscButton", 9006];
    _locationBtn ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.115 * safezoneH + safezoneY, 0.15 * safezoneW, 0.03 * safezoneH];
    _locationBtn ctrlSetText "LOCATIONS";
    _locationBtn ctrlSetTextColor [1, 1, 1, 1];
    _locationBtn ctrlSetBackgroundColor (if (MISSION_selectedTargetType == "LOCATION") then {[0.3, 0.3, 0.7, 1]} else {[0.2, 0.2, 0.2, 1]});
    _locationBtn ctrlSetEventHandler ["ButtonClick", "
        MISSION_selectedTargetType = 'LOCATION'; 
        [] call fnc_updateTargetTypeButtons; 
        [] call fnc_updateTaskUI;
        [true] call fnc_toggleLocationMarkers;
        [false] call fnc_toggleHVTMarkers;
        systemChat 'Switched to Locations view';
    "];
    _locationBtn ctrlCommit 0;
    
    // Create HVT button
    private _hvtBtn = _display ctrlCreate ["RscButton", 9007];
    _hvtBtn ctrlSetPosition [0.38 * safezoneW + safezoneX, 0.115 * safezoneH + safezoneY, 0.22 * safezoneW, 0.03 * safezoneH];
    _hvtBtn ctrlSetText "HIGH-VALUE TARGETS";
    _hvtBtn ctrlSetTextColor [1, 1, 1, 1];
    _hvtBtn ctrlSetBackgroundColor (if (MISSION_selectedTargetType == "HVT") then {[0.3, 0.3, 0.7, 1]} else {[0.2, 0.2, 0.2, 1]});
    _hvtBtn ctrlSetEventHandler ["ButtonClick", "
    MISSION_selectedTargetType = 'HVT'; 
    [] call fnc_updateTargetTypeButtons; 
    [] call fnc_updateTaskUI;
    [false] call fnc_toggleLocationMarkers;
    [] call fnc_forceRefreshHVTMarkers;
    [true] call fnc_toggleHVTMarkers;
    systemChat 'Switched to High-Value Targets view';
	"];
    _hvtBtn ctrlCommit 0;
    
    // Store buttons in uiNamespace for updating
    uiNamespace setVariable ["TASK_locationBtn", _locationBtn];
    uiNamespace setVariable ["TASK_hvtBtn", _hvtBtn];
    
    // Create unit selection combo - right side
    private _unitCombo = _display ctrlCreate ["RscCombo", 9401]; // Using specific high ID for z-order
    _unitCombo ctrlSetPosition [0.67 * safezoneW + safezoneX, 0.055 * safezoneH + safezoneY, 0.22 * safezoneW, 0.04 * safezoneH];
    _unitCombo ctrlCommit 0;

    // Add available units/groups
    [] call fnc_populateUnitCombo;
    
    // ===== CREATE MAP CONTROL =====
    // Create map control
    private _map = _display ctrlCreate ["RscMapControl", 9002];
    _map ctrlSetPosition [0.12 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.5 * safezoneW, 0.57 * safezoneH];
    _map ctrlSetBackgroundColor [0.969, 0.957, 0.949, 1.0];
    _map ctrlCommit 0;
    
    // ===== CREATE INFO PANELS =====
    // Create info panel
    private _infoPanel = _display ctrlCreate ["RscText", 9100];
    _infoPanel ctrlSetPosition [0.63 * safezoneW + safezoneX, 0.12 * safezoneH + safezoneY, 0.25 * safezoneW, 0.3 * safezoneH];
    _infoPanel ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _infoPanel ctrlCommit 0;
    
    // Create intel bar background
    private _intelBarBg = _display ctrlCreate ["RscText", 9102];
    _intelBarBg ctrlSetPosition [0.64 * safezoneW + safezoneX, 0.17 * safezoneH + safezoneY, 0.23 * safezoneW, 0.02 * safezoneH];
    _intelBarBg ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _intelBarBg ctrlCommit 0;
    
    // Create intel bar
    private _intelBar = _display ctrlCreate ["RscProgress", 9103];
    _intelBar ctrlSetPosition [0.64 * safezoneW + safezoneX, 0.17 * safezoneH + safezoneY, 0.23 * safezoneW, 0.02 * safezoneH];
    _intelBar progressSetPosition 0;
    _intelBar ctrlSetTextColor [0.2, 0.6, 1, 1];
    _intelBar ctrlCommit 0;
    
    // Create location info text
    private _infoText = _display ctrlCreate ["RscStructuredText", 9104];
    _infoText ctrlSetPosition [0.64 * safezoneW + safezoneX, 0.2 * safezoneH + safezoneY, 0.23 * safezoneW, 0.21 * safezoneH];
    _infoText ctrlSetStructuredText parseText "Select a target on the map.";
    _infoText ctrlCommit 0;
    
    // ===== CREATE TASK PANEL =====
    // Create task panel
    private _taskPanel = _display ctrlCreate ["RscText", 9200];
    _taskPanel ctrlSetPosition [0.63 * safezoneW + safezoneX, 0.42 * safezoneH + safezoneY, 0.25 * safezoneW, 0.35 * safezoneH]; // Increased height
    _taskPanel ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _taskPanel ctrlCommit 0;
    
    // Create task panel title
    private _taskTitle = _display ctrlCreate ["RscText", 9201];
    _taskTitle ctrlSetPosition [0.63 * safezoneW + safezoneX, 0.42 * safezoneH + safezoneY, 0.25 * safezoneW, 0.04 * safezoneH];
    _taskTitle ctrlSetText "Available Tasks";
    _taskTitle ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _taskTitle ctrlCommit 0;
    
    // ===== CREATE TASK BUTTONS =====
    // Create task buttons placeholder - they will be created in updateTaskUI
    // We'll create up to 8 buttons (more than enough for either locations or HVTs)
    private _buttonHeight = 0.04 * safezoneH;
    private _buttonMargin = 0.01 * safezoneH;
    private _buttonY = 0.47 * safezoneH + safezoneY;
    
    for "_i" from 0 to 7 do {
        private _button = _display ctrlCreate ["RscButton", 9300 + _i];
        _button ctrlSetPosition [
            0.64 * safezoneW + safezoneX,
            _buttonY + (_i * (_buttonHeight + _buttonMargin)),
            0.23 * safezoneW,
            _buttonHeight
        ];
        _button ctrlSetText "";
        _button ctrlEnable false;
        _button ctrlShow false;
        _button ctrlCommit 0;
    };
    
    // ===== CREATE CONTROL BUTTONS =====
    // Create control buttons at bottom
    private _confirmButton = _display ctrlCreate ["RscButton", 9500];
    _confirmButton ctrlSetPosition [0.30 * safezoneW + safezoneX, 0.73 * safezoneH + safezoneY, 0.18 * safezoneW, 0.04 * safezoneH]; 
    _confirmButton ctrlSetText "Confirm Operation";
    _confirmButton ctrlSetBackgroundColor [0.2, 0.6, 0.2, 1];
    _confirmButton ctrlEnable false;
    _confirmButton ctrlSetEventHandler ["ButtonClick", "[] call fnc_confirmTask"];
    _confirmButton ctrlCommit 0;

    private _cancelButton = _display ctrlCreate ["RscButton", 9501];
    _cancelButton ctrlSetPosition [0.12 * safezoneW + safezoneX, 0.73 * safezoneH + safezoneY, 0.15 * safezoneW, 0.04 * safezoneH];
    _cancelButton ctrlSetText "Cancel";
    _cancelButton ctrlSetBackgroundColor [0.6, 0.2, 0.2, 1];
    _cancelButton ctrlSetEventHandler ["ButtonClick", "closeDialog 0"];
    _cancelButton ctrlCommit 0;
    
    // ===== MAP INTERACTION =====
    // Add map click handler
    _map ctrlAddEventHandler ["MouseButtonClick", {
        params ["_control", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];
        
        if (_button == 0) then { // Left click
            private _worldPos = _control ctrlMapScreenToWorld [_xPos, _yPos];
            
            // Different handling based on target type
            if (MISSION_selectedTargetType == "LOCATION") then {
                // Find closest location
                private _closestIndex = -1;
                private _closestDist = 1000000;
                
                {
                    private _locationPos = _x select 3;
                    private _dist = _worldPos distance _locationPos;
                    
                    if (_dist < _closestDist && _dist < 300) then {
                        _closestDist = _dist;
                        _closestIndex = _forEachIndex;
                    };
                } forEach MISSION_LOCATIONS;
                
                if (_closestIndex != -1) then {
                    [_closestIndex] call fnc_selectLocation;
                };
            } else {
                // Find closest HVT
                private _closestIndex = -1;
                private _closestDist = 1000000;
                
                {
                    private _hvtPos = _x select 3;
                    private _dist = _worldPos distance _hvtPos;
                    
                    if (_dist < _closestDist && _dist < 300) then {
                        _closestDist = _dist;
                        _closestIndex = _forEachIndex;
                    };
                } forEach HVT_TARGETS;
                
                if (_closestIndex != -1) then {
                    [_closestIndex] call fnc_selectHVT;
                };
            };
        };
    }];
    
    // Set initial marker visibility based on the selected target type
    if (MISSION_selectedTargetType == "LOCATION") then {
        [true] call fnc_toggleLocationMarkers;
        [false] call fnc_toggleHVTMarkers;
    } else {
        [false] call fnc_toggleLocationMarkers;
        [true] call fnc_toggleHVTMarkers;
    };
    
    // ===== DIALOG CLOSURE =====
    // Add handler for dialog closure
    _display displayAddEventHandler ["Unload", {
        MISSION_taskUIOpen = false;
        
        // Save operation name before closing
        private _opNameInput = findDisplay -1 displayCtrl 9004;
        if (!isNull _opNameInput) then {
            MISSION_operationName = ctrlText _opNameInput;
        };
        
        // Reset selected location and task
        MISSION_selectedLocation = -1;
        MISSION_selectedHVT = -1;
        MISSION_selectedTask = "";
    }];
    
    // Start UI update loop
    [] spawn {
        while {MISSION_taskUIOpen && !isNull findDisplay -1} do {
            call fnc_updateTaskUI;
            sleep 0.5;
        };
    };
};

// Function to populate unit combo box
fnc_populateUnitCombo = {
    private _display = findDisplay -1;
    private _unitCombo = _display displayCtrl 9401;
    
    // Clear combo box
    lbClear _unitCombo;
    
    // Add local player group
    private _playerGroup = group player;
    private _index = _unitCombo lbAdd format ["%1 (%2 members)", groupId _playerGroup, count units _playerGroup];
    
    // Store the group as a variable name that can be retrieved later
    private _varName = format ["TASK_GROUP_%1", groupId _playerGroup];
    missionNamespace setVariable [_varName, _playerGroup];
    _unitCombo lbSetData [_index, _varName];
    
    // Add individual units from player's group
    {
        private _unitIndex = _unitCombo lbAdd format ["  - %1 (%2)", name _x, getText (configFile >> "CfgVehicles" >> typeOf _x >> "displayName")];
        
        // Store the unit as a variable name
        private _unitVarName = format ["TASK_UNIT_%1_%2", groupId (group _x), name _x];
        missionNamespace setVariable [_unitVarName, _x];
        _unitCombo lbSetData [_unitIndex, _unitVarName];
    } forEach units _playerGroup;
    
    // Get any other player-side groups
    private _allGroups = allGroups select {side _x == side player};
    
    {
        private _group = _x;
        
        // Skip player's own group (already added)
        if (_group != _playerGroup) then {
            private _grpVarName = format ["TASK_GROUP_%1", groupId _group];
            missionNamespace setVariable [_grpVarName, _group];
            
            private _groupIndex = _unitCombo lbAdd format ["%1 (%2 members)", groupId _group, count units _group];
            _unitCombo lbSetData [_groupIndex, _grpVarName];
            
            
        };
    } forEach _allGroups;
    
    // Log for debugging
    diag_log format ["Populated unit combo with %1 entries", lbSize _unitCombo];
    
    // Select first item by default
    if (lbSize _unitCombo > 0) then {
        _unitCombo lbSetCurSel 0;
    };
};

// Function to select a location on the map
fnc_selectLocation = {
    params ["_locationIndex"];
    
    private _display = findDisplay -1;
    
    // Safety check for valid display
    if (isNull _display) exitWith {
        diag_log "fnc_selectLocation: Display is null!";
    };
    
    // Safety check for valid location index
    if (isNil "_locationIndex" || _locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["fnc_selectLocation: Invalid location index: %1", _locationIndex];
        
        // Update info text to show error
        private _infoText = _display displayCtrl 9104;
        if (!isNull _infoText) then {
            _infoText ctrlSetStructuredText parseText "<t color='#FF0000'>Error: Invalid location selected.</t>";
        };
    };
    
    // Check if location is destroyed before proceeding
    private _isDestroyed = false;
    try {
        _isDestroyed = [_locationIndex] call fnc_isLocationDestroyed;
    } catch {
        diag_log format ["Error checking destroyed status in selectLocation: %1", _exception];
    };
    
    if (_isDestroyed) exitWith {
        // Provide feedback and prevent selection
        private _infoText = _display displayCtrl 9104;
        
        if (!isNull _infoText) then {
            private _locationData = MISSION_LOCATIONS select _locationIndex;
            private _locationName = "Unknown";
            
            if (count _locationData > 1) then {
                _locationName = _locationData select 1;
            };
            
            _infoText ctrlSetStructuredText parseText format [
                "<t size='1.2'>%1</t><br/>" +
                "<t color='#FF0000'>DESTROYED</t><br/><br/>" +
                "This location has been destroyed and is no longer available for operations.",
                _locationName
            ];
        };
        
        // Disable all task buttons
        {
            _x params ["_taskId", "_taskName", "_requiredIntel"];
            private _button = _display displayCtrl (9300 + _forEachIndex);
            if (!isNull _button) then {
                _button ctrlEnable false;
                _button ctrlSetBackgroundColor [0.2, 0.2, 0.2, 0.5];
            };
        } forEach TASK_TYPES;
        
        // Update confirm button
        private _confirmButton = _display displayCtrl 9500;
        if (!isNull _confirmButton) then {
            _confirmButton ctrlEnable false;
        };
        
        // Set selected location to -1 to indicate no valid selection
        MISSION_selectedLocation = -1;
        MISSION_selectedTask = "";
    };
    
    // Safe extraction of location data
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    
    // Error handling for invalid location data
    if (count _locationData < 7) exitWith {
        diag_log format ["fnc_selectLocation: Location data at index %1 is incomplete", _locationIndex];
        
        private _infoText = _display displayCtrl 9104;
        if (!isNull _infoText) then {
            _infoText ctrlSetStructuredText parseText "<t color='#FF0000'>Error: Location data is corrupted.</t>";
        };
    };
    
    // Safely extract parameters with defaults
    private _id = _locationData param [0, "unknown_id"];
    private _name = _locationData param [1, "Unknown Location"];
    private _type = _locationData param [2, "unknown"];
    private _pos = _locationData param [3, [0,0,0]];
    private _intel = _locationData param [4, 0];
    private _tasks = _locationData param [5, []];
    private _briefings = _locationData param [6, []];
    private _captured = _locationData param [7, false];
    
    // Update selected location
    MISSION_selectedLocation = _locationIndex;
    
    // Update intel bar
    private _intelBar = _display displayCtrl 9103;
    if (!isNull _intelBar) then {
        _intelBar progressSetPosition (_intel / 100);
    };
    
    // Update info text
    private _infoText = _display displayCtrl 9104;
    if (!isNull _infoText) then {
        private _briefing = "No information available.";
        
        try {
            _briefing = [_locationIndex] call fnc_getLocationBriefing;
        } catch {
            diag_log format ["Error getting briefing: %1", _exception];
        };
        
        private _intelLevel = "unknown";
        try {
            _intelLevel = [_intel] call fnc_getIntelLevel;
        } catch {
            diag_log format ["Error getting intel level: %1", _exception];
        };
        
        private _intelColor = switch (_intelLevel) do {
            case "complete": { "#00FF00" }; // Green
            case "basic": { "#FFFF00" }; // Yellow
            default { "#FF0000" }; // Red
        };
        
        _infoText ctrlSetStructuredText parseText format [
            "<t size='1.2'>%1</t><br/>" +
            "<t color='%2'>Intelligence: %3%4</t><br/><br/>" +
            "%5",
            _name,
            _intelColor,
            round _intel,
            "%",
            _briefing
        ];
    };
	
	// Make sure to update available task buttons for this location
    private _buttonCount = 0;
    {
        _x params ["_taskId", "_taskName", "_rewards"];
        
        if (_buttonCount < 8) then { // Limit to 8 buttons
            private _button = _display displayCtrl (9300 + _buttonCount);
            
            if (!isNull _button) then {
                // Show the button
                _button ctrlShow true;
                _button ctrlSetText _taskName;
                _button setVariable ["taskType", _taskId];
                
                // Enable or disable based on intel
                private _taskTypeIndex = TASK_TYPES findIf {(_x select 0) == _taskId};
                private _requiredIntel = 0;
                
                if (_taskTypeIndex != -1) then {
                    _requiredIntel = (TASK_TYPES select _taskTypeIndex) select 2;
                };
                
                private _enabled = _intel >= _requiredIntel;
                
                // Special case for 'defend' - only for player-controlled locations
                if (_taskId == "defend") then {
                    _enabled = _enabled && _captured;
                };
                
                // Special cases for capture/destroy - only for enemy-controlled locations
                if (_taskId == "capture" || _taskId == "destroy") then {
                    _enabled = _enabled && !_captured;
                };
                
                _button ctrlEnable _enabled;
                
                // Update button color if selected
                if (MISSION_selectedTask == _taskId) then {
                    _button ctrlSetBackgroundColor [0.3, 0.3, 0.7, 1];
                } else {
                    _button ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
                };
                
                // Add click handler
                _button ctrlRemoveAllEventHandlers "ButtonClick";
                _button ctrlSetEventHandler ["ButtonClick", format ["['%1'] call fnc_selectTask", _taskId]];
                
                _buttonCount = _buttonCount + 1;
            };
        };
    } forEach _tasks;
    
    // Update available tasks
    {
        _x params ["_taskId", "_taskName", "_requiredIntel"];
        private _button = _display displayCtrl (9300 + _forEachIndex);
        
        if (!isNull _button) then {
            // Enable button if:
            // 1. We have enough intel
            // 2. Special case for 'defend' - only available for player-controlled locations
            private _enabled = _intel >= _requiredIntel;
            
            if (_taskId == "defend") then {
                _enabled = _enabled && _captured;
            };
            
            if (_taskId == "capture" || _taskId == "destroy") then {
                _enabled = _enabled && !_captured;
            };
            
            _button ctrlEnable _enabled;
            
            // Update button color if selected
            if (MISSION_selectedTask == _taskId) then {
                _button ctrlSetBackgroundColor [0.3, 0.3, 0.7, 1];
            } else {
                _button ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
            };
        };
    } forEach TASK_TYPES;
    
    // Update confirm button
    private _confirmButton = _display displayCtrl 9500;
    if (!isNull _confirmButton) then {
        _confirmButton ctrlEnable (MISSION_selectedTask != "");
    };
};

// Function to select a task
fnc_selectTask = {
    params ["_taskType"];
    
    private _display = findDisplay -1;
    
    // Update selected task
    MISSION_selectedTask = _taskType;
    
    // Update task buttons - FIXED control IDs
    {
        _x params ["_taskId", "_taskName", "_requiredIntel"];
        private _button = _display displayCtrl (9300 + _forEachIndex);
        
        if (_taskId == _taskType) then {
            _button ctrlSetBackgroundColor [0.3, 0.3, 0.7, 1];
        } else {
            _button ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
        };
    } forEach TASK_TYPES;
    
    // Update confirm button
    private _confirmButton = _display displayCtrl 9500;
    _confirmButton ctrlEnable (MISSION_selectedLocation != -1);
};

// Function to confirm and create task
fnc_confirmTask = {
    private _display = findDisplay -1;
    private _opNameInput = _display displayCtrl 9004;
    MISSION_operationName = ctrlText _opNameInput;
    
    // Get selected unit(s)
    private _unitCombo = _display displayCtrl 9401;
    private _selIndex = lbCurSel _unitCombo;
    
    if (_selIndex == -1) exitWith {
        hint "No unit selected for task assignment.";
    };
    
    private _varName = _unitCombo lbData _selIndex;
    private _assignedUnits = [];
    
    // Debug info
    diag_log format ["Selected variable name: %1", _varName];
    
    // Get the stored object or group from the variable
    private _selectedObject = missionNamespace getVariable [_varName, objNull];
    
    diag_log format ["Selected object: %1 (type: %2)", _selectedObject, typeName _selectedObject];
    
    if (isNull _selectedObject) exitWith {
        hint format ["Error: Could not find unit or group: %1", _varName];
    };
    
    // If group was selected, assign to all units in group
    if (_selectedObject isEqualType grpNull) then {
        _assignedUnits = units _selectedObject;
        diag_log format ["Group selected with %1 units", count _assignedUnits];
    } else {
        // Single unit selected
        _assignedUnits = [_selectedObject];
        diag_log format ["Single unit selected: %1", name _selectedObject];
    };
    
    // Check for empty assigned units
    if (count _assignedUnits == 0) exitWith {
        hint "Error: No units available for this assignment.";
    };
    
    // Create the task - based on target type
    private _taskId = "";
    
    if (MISSION_selectedTargetType == "LOCATION") then {
        // Create location task
        _taskId = [MISSION_selectedLocation, MISSION_selectedTask, _assignedUnits] call fnc_createTask;
    } else {
        // Create HVT task
        _taskId = [MISSION_selectedHVT, MISSION_selectedTask, _assignedUnits] call fnc_createHVTTask;
    };
    
    if (_taskId != "") then {
        // Close the dialog
        closeDialog 0;
        
        // Get target name and task type for feedback
        private _targetName = "";
        private _targetType = "";
        private _taskTypeText = "";
        
        if (MISSION_selectedTargetType == "LOCATION") then {
            private _locationData = MISSION_LOCATIONS select MISSION_selectedLocation;
            _targetName = _locationData select 1;
            _targetType = _locationData select 2;
            
            // Get task type name
            private _taskTypeIndex = TASK_TYPES findIf {(_x select 0) == MISSION_selectedTask};
            if (_taskTypeIndex != -1) then {
                _taskTypeText = (TASK_TYPES select _taskTypeIndex) select 1;
            };
        } else {
            private _hvtData = HVT_TARGETS select MISSION_selectedHVT;
            _targetName = _hvtData select 1;
            _targetType = _hvtData select 2;
            
            // Find task name in HVT tasks
            {
                if (_x select 0 == MISSION_selectedTask) exitWith {
                    _taskTypeText = _x select 1;
                };
            } forEach (_hvtData select 5);
        };
        
        // Provide feedback
        hint format ["New task created: %1 at %2", _taskTypeText, _targetName];
        systemChat format ["New orders issued to %1: %2 the %3 at %4.", 
            if (_selectedObject isEqualType grpNull) then {groupId _selectedObject} else {name _selectedObject},
            _taskTypeText,
            _targetType,
            _targetName
        ];
    } else {
        hint "Error creating task. Please try again.";
    };
};

// Function to update task UI
fnc_updateTaskUI = {
    private _display = findDisplay -1;
    
    // Clear all task buttons first
    for "_i" from 0 to 7 do {
        private _button = _display displayCtrl (9300 + _i);
        if (!isNull _button) then {
            _button ctrlShow false;
            _button ctrlEnable false;
            _button ctrlSetText "";
            _button setVariable ["taskType", ""];
        };
    };
    
    // Update based on target type
    if (MISSION_selectedTargetType == "LOCATION") then {
        // If a location is selected, update its info
        if (MISSION_selectedLocation != -1) then {
            // Show the location info
            [MISSION_selectedLocation] call fnc_selectLocation;
            
            // Make sure the task buttons for locations are showing
            if (MISSION_selectedLocation >= 0 && MISSION_selectedLocation < count MISSION_LOCATIONS) then {
                private _locationData = MISSION_LOCATIONS select MISSION_selectedLocation;
                private _intel = _locationData select 4;
                private _tasks = _locationData select 5;
                private _captured = _locationData select 7;
                
                // Update available task buttons
                private _buttonCount = 0;
                {
                    _x params ["_taskId", "_taskName", "_rewards"];
                    private _button = _display displayCtrl (9300 + _buttonCount);
                    
                    if (!isNull _button) then {
                        // Show the button
                        _button ctrlShow true;
                        _button ctrlSetText _taskName;
                        _button setVariable ["taskType", _taskId];
                        
                        // Enable button if we have enough intel
                        private _requiredIntel = 0;
                        {
                            if (_x select 0 == _taskId) exitWith {
                                _requiredIntel = _x select 2;
                            };
                        } forEach TASK_TYPES;
                        
                        // Enable or disable based on intel and special cases
                        private _enabled = _intel >= _requiredIntel;
                        
                        // Special case for 'defend' - only for player-controlled locations
                        if (_taskId == "defend") then {
                            _enabled = _enabled && _captured;
                        };
                        
                        // Special cases for capture/destroy - only for enemy-controlled locations
                        if (_taskId == "capture" || _taskId == "destroy") then {
                            _enabled = _enabled && !_captured;
                        };
                        
                        _button ctrlEnable _enabled;
                        
                        // Update button color if selected
                        if (MISSION_selectedTask == _taskId) then {
                            _button ctrlSetBackgroundColor [0.3, 0.3, 0.7, 1];
                        } else {
                            _button ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
                        };
                        
                        // Set event handler
                        _button ctrlSetEventHandler ["ButtonClick", format ["['%1'] call fnc_selectTask", _taskId]];
                        
                        _buttonCount = _buttonCount + 1;
                    };
                } forEach _tasks;
                
                // Update confirm button
                private _confirmButton = _display displayCtrl 9500;
                if (!isNull _confirmButton) then {
                    _confirmButton ctrlEnable (MISSION_selectedTask != "");
                };
            };
        };
    } else {
        // If an HVT is selected, update its info
        if (MISSION_selectedHVT != -1) then {
            [MISSION_selectedHVT] call fnc_selectHVT;
        };
    };
};


// Function to update target type button visuals
fnc_updateTargetTypeButtons = {
    private _locationBtn = uiNamespace getVariable ["TASK_locationBtn", controlNull];
    private _hvtBtn = uiNamespace getVariable ["TASK_hvtBtn", controlNull];
    
    if (!isNull _locationBtn && !isNull _hvtBtn) then {
        _locationBtn ctrlSetBackgroundColor (if (MISSION_selectedTargetType == "LOCATION") then {[0.3, 0.3, 0.7, 1]} else {[0.2, 0.2, 0.2, 1]});
        _hvtBtn ctrlSetBackgroundColor (if (MISSION_selectedTargetType == "HVT") then {[0.3, 0.3, 0.7, 1]} else {[0.2, 0.2, 0.2, 1]});
    };
};

// Function to select an HVT
fnc_selectHVT = {
    params ["_hvtIndex"];
    
    private _display = findDisplay -1;
    
    // Safety check for valid display
    if (isNull _display) exitWith {
        diag_log "fnc_selectHVT: Display is null!";
    };
    
    // Safety check for valid HVT index
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        diag_log format ["fnc_selectHVT: Invalid HVT index: %1", _hvtIndex];
        
        // Update info text to show error
        private _infoText = _display displayCtrl 9104;
        if (!isNull _infoText) then {
            _infoText ctrlSetStructuredText parseText "<t color='#FF0000'>Error: Invalid target selected.</t>";
        };
    };
    
    // Check if HVT is eliminated
    private _isEliminated = (HVT_TARGETS select _hvtIndex) select 8;
    
    if (_isEliminated) exitWith {
        // Provide feedback and prevent selection
        private _infoText = _display displayCtrl 9104;
        
        if (!isNull _infoText) then {
            private _hvtData = HVT_TARGETS select _hvtIndex;
            private _displayName = "Unknown";
            
            if (count _hvtData > 1) then {
                _displayName = _hvtData select 1;
            };
            
            _infoText ctrlSetStructuredText parseText format [
                "<t size='1.2'>%1</t><br/>" +
                "<t color='#FF0000'>ELIMINATED</t><br/><br/>" +
                "This target has been eliminated and is no longer available for operations.",
                _displayName
            ];
        };
        
        // Disable all task buttons
        for "_i" from 0 to 7 do {
            private _button = _display displayCtrl (9300 + _i);
            if (!isNull _button) then {
                _button ctrlShow false;
                _button ctrlEnable false;
            };
        };
        
        // Update confirm button
        private _confirmButton = _display displayCtrl 9500;
        if (!isNull _confirmButton) then {
            _confirmButton ctrlEnable false;
        };
        
        // Set selected HVT to -1 to indicate no valid selection
        MISSION_selectedHVT = -1;
        MISSION_selectedTask = "";
    };
    
    // Safe extraction of HVT data
    private _hvtData = HVT_TARGETS select _hvtIndex;
    
    // Error handling for invalid HVT data
    if (count _hvtData < 7) exitWith {
        diag_log format ["fnc_selectHVT: HVT data at index %1 is incomplete", _hvtIndex];
        
        private _infoText = _display displayCtrl 9104;
        if (!isNull _infoText) then {
            _infoText ctrlSetStructuredText parseText "<t color='#FF0000'>Error: Target data is corrupted.</t>";
        };
    };
    
    // Safely extract parameters with defaults
    private _varName = _hvtData param [0, "unknown_id"];
    private _displayName = _hvtData param [1, "Unknown Target"];
    private _type = _hvtData param [2, "unknown"];
    private _pos = _hvtData param [3, [0,0,0]];
    private _intel = _hvtData param [4, 0];
    private _tasks = _hvtData param [5, []];
    private _briefings = _hvtData param [6, []];
    private _captured = _hvtData param [7, false];
    
    // Update selected HVT
    MISSION_selectedHVT = _hvtIndex;
    
    // Update intel bar
    private _intelBar = _display displayCtrl 9103;
    if (!isNull _intelBar) then {
        _intelBar progressSetPosition (_intel / 100);
    };
    
    // Update info text
    private _infoText = _display displayCtrl 9104;
    if (!isNull _infoText) then {
        private _briefing = "No information available.";
        
        try {
            _briefing = [_hvtIndex] call fnc_getHVTBriefing;
        } catch {
            diag_log format ["Error getting HVT briefing: %1", _exception];
        };
        
        private _intelLevel = "unknown";
        try {
            _intelLevel = [_intel] call fnc_getHVTIntelLevel;
        } catch {
            diag_log format ["Error getting intel level: %1", _exception];
        };
        
        private _intelColor = switch (_intelLevel) do {
            case "complete": { "#00FF00" }; // Green
            case "basic": { "#FFFF00" }; // Yellow
            default { "#FF0000" }; // Red
        };
        
        private _statusText = if (_captured) then {
            "<t color='#00FF00'>CAPTURED</t>"
        } else {
            "<t color='#FF0000'>ACTIVE</t>"
        };
        
        _infoText ctrlSetStructuredText parseText format [
            "<t size='1.2'>%1</t><br/>" +
            "<t color='%2'>Intelligence: %3%4</t> - %5<br/><br/>" +
            "%6",
            _displayName,
            _intelColor,
            round _intel,
            "%",
            _statusText,
            _briefing
        ];
    };
    
    // Update available tasks - clear existing buttons first
    for "_i" from 0 to 7 do {
        private _button = _display displayCtrl (9300 + _i);
        if (!isNull _button) then {
            _button ctrlShow false;
            _button ctrlEnable false;
            _button ctrlSetText "";
            _button setVariable ["taskType", ""];
        };
    };
    
    // Show task buttons based on available tasks for this HVT
    private _buttonCount = 0;
    
    {
        _x params ["_taskId", "_taskName", "_rewards"];
        
        if (_buttonCount < 8) then { // Make sure we don't exceed available buttons
            private _button = _display displayCtrl (9300 + _buttonCount);
            
            if (!isNull _button) then {
                // Show the button
                _button ctrlShow true;
                _button ctrlSetText _taskName;
                _button setVariable ["taskType", _taskId];
                
                // Enable or disable based on intel and status
                private _enabled = _intel >= HVT_INTEL_BASIC; // Require at least basic intel
                
                // Special case for 'capture' - can't capture an eliminated or already captured target
                if (_taskId == "capture") then {
                    _enabled = _enabled && !_captured;
                };
                
                // Can't 'kill' a captured target
                if (_taskId == "kill") then {
                    _enabled = _enabled && !_captured;
                };
                
                _button ctrlEnable _enabled;
                
                // Update button color if selected
                if (MISSION_selectedTask == _taskId) then {
                    _button ctrlSetBackgroundColor [0.3, 0.3, 0.7, 1];
                } else {
                    _button ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
                };
                
                // Add click handler
                _button ctrlSetEventHandler ["ButtonClick", format ["['%1'] call fnc_selectTask", _taskId]];
                
                _buttonCount = _buttonCount + 1;
            };
        };
    } forEach _tasks;
    
    // Update confirm button
    private _confirmButton = _display displayCtrl 9500;
    if (!isNull _confirmButton) then {
        _confirmButton ctrlEnable (MISSION_selectedTask != "");
    };
};

// =====================================================================
// HELPER FUNCTIONS FOR EXTERNAL USE
// =====================================================================

fnc_handleLocationDestruction = {
    params ["_locationIndex"];
    
    // Extra error handling
    if (isNil "_locationIndex") exitWith {
        diag_log "ERROR: locationIndex is nil in fnc_handleLocationDestruction";
        false
    };
    
    // Ensure valid location index with better error handling
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["handleLocationDestruction: Invalid location index: %1", _locationIndex];
        false
    };
    
    // Safely extract location data with error handling
    private _locationData = +MISSION_LOCATIONS select _locationIndex; // Make a copy to avoid reference issues
    
    if (count _locationData < 7) exitWith {
        diag_log format ["ERROR: Location data at index %1 is incomplete: %2", _locationIndex, _locationData];
        false
    };
    
    // Safely extract parameters with defaults
    private _id = _locationData param [0, "unknown_id"];
    private _name = _locationData param [1, "Unknown Location"];
    private _type = _locationData param [2, "unknown"];
    private _pos = _locationData param [3, [0,0,0]];
    private _intel = _locationData param [4, 0];
    private _tasks = _locationData param [5, []];
    private _briefings = _locationData param [6, []];
    private _captured = _locationData param [7, false];
    
    // Log the destruction with safer formatting
    diag_log format ["DESTRUCTION SYSTEM: Location being destroyed: %1 (%2)", _name, _type];
    
    // 1. Find any active destroy tasks for this location and complete them
    private _destroyTasksCompleted = false;
    private _activeTasksForLocation = [];
    
    // First, collect all tasks for this location to avoid modifying while iterating
    {
        private _taskObj = _x;
        private _taskId = "";
        private _taskLocIndex = -1;
        private _taskType = "";
        
        // Extract task data safely
        if (count _taskObj > 0) then { _taskId = _taskObj select 0; };
        if (count _taskObj > 1) then { _taskLocIndex = _taskObj select 1; };
        if (count _taskObj > 2) then { _taskType = _taskObj select 2; };
        
        if (_taskLocIndex == _locationIndex) then {
            _activeTasksForLocation pushBack [_taskId, _taskType];
        };
    } forEach MISSION_activeTasks;
    
    // Now process these tasks outside the loop
    {
        _x params ["_taskId", "_taskType"];
        
        if (_taskType == "destroy") then {
            diag_log format ["DESTRUCTION SYSTEM: Completing destroy task %1 for location %2", _taskId, _locationIndex];
            
            // Mark task as completed
            [_taskId, true] call fnc_completeTask;
            _destroyTasksCompleted = true;
        } else {
            // For any other task type, fail it
            diag_log format ["DESTRUCTION SYSTEM: Failing non-destroy task %1 for location %2", _taskId, _locationIndex];
            [_taskId, false] call fnc_completeTask;
        };
    } forEach _activeTasksForLocation;
    
    // 3. Remove any resource benefits
    if (!isNil "fnc_removeLocationResourceBonus") then {
        [_locationIndex] call fnc_removeLocationResourceBonus;
        diag_log format ["DESTRUCTION SYSTEM: Resource bonuses removed for location: %1", _name];
    };
    
    // 4. Update marker to show destroyed state
    private _markerName = format ["task_location_%1", _locationIndex];
    if (markerType _markerName != "") then {
        _markerName setMarkerColor "ColorBlack";
        _markerName setMarkerAlpha 0.6;
        _markerName setMarkerText format ["%1 (DESTROYED)", _type];
        diag_log format ["DESTRUCTION SYSTEM: Updated marker for destroyed location: %1", _markerName];
    };
    
    // 5. Mark location as permanently destroyed in data array
    // Create a new array with proper size and copy original values
    private _newLocationData = [];
    
    // Copy original data
    for "_i" from 0 to ((count _locationData) - 1) do {
        if (_i < count _locationData) then {
            _newLocationData set [_i, _locationData select _i];
        };
    };
    
    // Ensure the new array is at least 7 elements long
    while {count _newLocationData < 7} do {
        _newLocationData pushBack "";
    };
    
    // Set not captured
    if (count _newLocationData > 7) then {
        _newLocationData set [7, false];
    } else {
        _newLocationData pushBack false;
    };
    
    // Ensure we have 10 elements for the destroyed flag
    while {count _newLocationData < 10} do {
        _newLocationData pushBack "";
    };
    
    // Set destroyed flag at position 9
    _newLocationData set [9, true];
    
    // Update the location in the MISSION_LOCATIONS array
    MISSION_LOCATIONS set [_locationIndex, _newLocationData];
    
    // 7. Mark the reference object as destroyed
    private _refObj = objNull;
    if (count MISSION_locationObjects > _locationIndex) then {
        _refObj = MISSION_locationObjects select _locationIndex;
    };
    
    if (!isNil "_refObj" && {!isNull _refObj}) then {
        // Set the critical variable that the task completion code looks for
        _refObj setVariable ["destroyed", true, true];
        
        // Ensure the object appears damaged
        if (damage _refObj < 0.9) then {
            _refObj setDamage 1;
        };
        
        // Add visual effects if not already present
        if (isNil {_refObj getVariable "destruction_effect"}) then {
            private _fire = "test_EmptyObjectForFireBig" createVehicle (getPos _refObj);
            _fire attachTo [_refObj, [0, 0, 0]];
            _refObj setVariable ["destruction_effect", _fire, true];
            diag_log "DESTRUCTION SYSTEM: Created destruction effect (fire)";
        };
    };
    
    // 8. Notify player
    if (hasInterface) then {
        private _msg = format ["%1 has been completely destroyed. This location is no longer available for operations.", _name];
        hint _msg;
        systemChat _msg;
    };
    
    diag_log "DESTRUCTION SYSTEM: Location destruction process completed successfully";
    true
};

// Function to add intel to a location by ID
fnc_addIntelToLocationById = {
    params ["_locationId", "_amount"];
    
    private _locationIndex = MISSION_LOCATIONS findIf {(_x select 0) == _locationId};
    
    if (_locationIndex != -1) then {
        [_locationIndex, _amount] call fnc_modifyLocationIntel;
        true
    } else {
        diag_log format ["Location not found with ID: %1", _locationId];
        false
    };
};

// Function to create a POW camp
fnc_createPOWCamp = {
    params ["_position"];
    
    // Store POW camp position
    TASK_POW_CAMP_POS = _position;
    
    // Create marker
    private _marker = createMarker ["marker_pow_camp", _position];
    _marker setMarkerType "mil_flag";
    _marker setMarkerColor "ColorBlue";
    _marker setMarkerText "POW Camp";
    
    systemChat "POW Camp established.";
};

// Function to deliver a POW
fnc_deliverPOW = {
    params ["_unit", "_isHighValue"];
    
    if (_unit distance TASK_POW_CAMP_POS > 50) exitWith {
        systemChat "POW must be delivered to the POW camp.";
        false
    };
    
    // Give intel reward based on value
    private _intelAmount = if (_isHighValue) then {50} else {10};
    
    // Add intel to all locations
    {
        if (!(_x select 7)) then { // Only for enemy locations
            [_forEachIndex, _intelAmount] call fnc_modifyLocationIntel;
        };
    } forEach MISSION_LOCATIONS;
    
    // Delete the POW
    deleteVehicle _unit;
    
    // Give feedback
    if (_isHighValue) then {
        hint "High-value prisoner delivered. Significant intelligence gained!";
        systemChat "Interrogation of high-value prisoner revealed critical intelligence about enemy positions.";
    } else {
        hint "POW delivered. Intelligence gained.";
        systemChat "Interrogation of prisoner provided some intelligence about enemy positions.";
    };
    
    true
};

fnc_setupReconTrigger = {
    params ["_locationIndex", "_pos"];
    
    // Create trigger for intel gathering
    private _trig = createTrigger ["EmptyDetector", _pos, false];
    _trig setTriggerArea [200, 200, 0, false];
    
    // Use exact side of player for better compatibility
    private _playerSide = side player;
    _trig setTriggerActivation [str _playerSide, "PRESENT", false];
    
    // Store the location index in the trigger variable for reference
    _trig setVariable ["locationIndex", _locationIndex];
    
    // Create a safer trigger statement with proper type handling
    _trig setTriggerStatements [
        "this", 
        "
        private _locIndex = thisTrigger getVariable ['locationIndex', -1];
        if (_locIndex >= 0) then {
            private _intelGain = 1;
            private _dice = floor random 3;
            if (_dice == 0) then { _intelGain = 2; };
            if (_dice == 1) then { _intelGain = 1; };
            [_locIndex, _intelGain] call fnc_modifyLocationIntel;
            diag_log format ['Intel trigger activated: +%1 intel for location %2', _intelGain, _locIndex];
        };
        ",
        ""
    ];
    
    _trig
};

fnc_isLocationDestroyed = {
    params ["_locationIndex"];
    
    if (isNil "_locationIndex") exitWith { false };
    if (_locationIndex < 0) exitWith { false };
    if (_locationIndex >= count MISSION_LOCATIONS) exitWith { false };
    
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    
    // Check if location is destroyed (position 9 in the array)
    if (count _locationData > 9) then {
        _locationData select 9
    } else {
        false
    };
};

// Function to show/hide all location markers
fnc_toggleLocationMarkers = {
    params [["_show", true]];
    
    {
        private _markerName = format ["task_location_%1", _forEachIndex];
        if (markerType _markerName != "") then {
            _markerName setMarkerAlphaLocal (if (_show) then {1} else {0});
        };
    } forEach MISSION_LOCATIONS;
    
    systemChat format ["Location markers %1", if (_show) then {"shown"} else {"hidden"}];
};

// Function to create air mission for HVT
fnc_createHVTAirMission = {
    params ["_hvtIndex", "_missionType", "_aircraft"];
    
    if (!isNil "AIR_OP_fnc_createHVTMission") then {
        [_hvtIndex, _missionType, _aircraft] call AIR_OP_fnc_createHVTMission
    } else {
        systemChat "Air Operations system not loaded";
        ""
    };
};

// Function to create air mission for Location
fnc_createLocationAirMission = {
    params ["_locationIndex", "_missionType", "_aircraft"];
    
    if (!isNil "AIR_OP_fnc_createLocationMission") then {
        [_locationIndex, _missionType, _aircraft] call AIR_OP_fnc_createLocationMission
    } else {
        systemChat "Air Operations system not loaded";
        ""
    };
};

// Mission init checks
diag_log "AIR_OPS: Comprehensive mission system update complete";
systemChat "Air Operations enhanced - new mission features available!";

// =====================================================================
// INITIALIZATION - CALL THIS TO START THE SYSTEM
// =====================================================================

// Initialize the task system
[] call fnc_initTaskSystem;