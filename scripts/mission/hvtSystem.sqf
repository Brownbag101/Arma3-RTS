// scripts/mission/hvtSystem.sqf
// High-Value Target (HVT) System for WW2 RTS - COMPLETE REWRITE

// =====================================================================
// HVT CONFIGURATION VALUES - GAMEPLAY VARIABLES
// =====================================================================

// Debug mode - set to true for additional information
HVT_DEBUG_MODE = true;

// Intel level thresholds
HVT_INTEL_UNKNOWN = 0;    // 0-25%
HVT_INTEL_BASIC = 25;     // 25-75%
HVT_INTEL_COMPLETE = 75;  // 75-100%

// Intel decay rate (per minute) if target is not captured
HVT_INTEL_DECAY_RATE = 1; // Intelligence points lost per minute

// Time between intel decay checks (in seconds)
HVT_DECAY_CHECK_INTERVAL = 60; // Check every minute

// HVT position update rate (in seconds)
HVT_POSITION_REFRESH_RATE = 5; // Update positions every 5 seconds

// Chance of intel decay occurring during each check
HVT_DECAY_CHANCE = 75; // 75% chance of decay during each check

// =====================================================================
// HVT TARGET ARRAY - DEFINE YOUR TARGETS HERE
// =====================================================================

// Format of each HVT entry:
// [
//   "Target Variable Name",    // In-game variable name of the unit/vehicle
//   "Target Display Name",     // Name displayed in UI
//   "Target Type",             // Type (e.g., "officer", "scientist", "ship", "vehicle")
//   [x, y, z],                 // Initial position (will be updated in real-time)
//   0,                         // Initial intel level (0-100)
//   [                          // Available tasks and rewards for this target
//     ["kill", "Eliminate Target", [["intelligence", 50]]],
//     ["capture", "Capture Target", [["intelligence", 100]]]
//   ],
//   [                          // Briefing texts based on intel level
//     "Unknown enemy target detected.",                        // Unknown (0-25%)
//     "Enemy personnel identified. Further intel needed.",     // Basic (25-75%)
//     "Full intel on high-value target. Ready for operation."  // Complete (75-100%)
//   ],
//   false,                     // Initially captured by player? (default: false)
//   false                      // Is target eliminated? (default: false)
// ]

// HVT targets array - GAMEPLAY: Define your targets here
HVT_TARGETS = [
    // Example HVT 1 - Enemy Officer
    [
        "hvt_1",                       // Variable name (must match unit in mission)
        "Colonel Hans Schmidt",        // Display name
        "officer",                     // Type
        [0,0,0],                       // Position (will be updated)
        100,                           // Intel level
        [                              // Available tasks
            ["track", "Track Target", [["intelligence", 15]]],
            ["kill", "Eliminate Target", [["intelligence", 50], ["training", 25]]],
            ["capture", "Capture Target", [["intelligence", 100], ["training", 50]]]
        ],
        [                              // Briefing texts
            "Unknown enemy officer detected in the area. Identity and exact location unknown.",
            "Identified as Colonel Hans Schmidt, commander of local Axis forces. Known to move between outposts regularly.",
            "Colonel Hans Schmidt, senior intelligence officer with knowledge of enemy defenses and upcoming operations. Capturing him alive would provide significant strategic advantage."
        ],
        false,                         // Not captured
        false                          // Not eliminated
    ],
    
    // Example HVT 2 - Enemy Ship
    [
        "bismark",                     // Variable name (must match ship in mission)
        "KMS Bismarck",                // Display name
        "ship",                        // Type
        [0,0,0],                       // Position (will be updated)
        100,                           // Intel level
        [                              // Available tasks
            ["track", "Track Target", [["intelligence", 20]]],
            ["attack", "Attack Target", [["intelligence", 75], ["training", 50]]]
        ],
        [                              // Briefing texts
            "Unknown large enemy vessel detected. Identity and mission unknown.",
            "Identified as the German battleship Bismarck. Reported to be escorting supply convoys.",
            "The Bismarck is transporting critical war materials and high-ranking officers. Destroying it would severely impact enemy operations."
        ],
        false,                         // Not captured
        false                          // Not eliminated
    ]
];

// Target types with specific icon mappings - GAMEPLAY: Configure icon types
HVT_TARGET_ICONS = [
    ["officer", "o_hq"], 
    ["scientist", "o_hq"],
    ["ship", "o_naval"],
    ["vehicle", "o_armor"],
    ["plane", "o_plane"],
    ["supply", "o_support"]
];

// =====================================================================
// GLOBAL VARIABLES - DO NOT EDIT
// =====================================================================

// Create arrays to track system state
HVT_markers = [];             // HVT map markers
HVT_activeTasks = [];         // Active tasks tracking HVTs
HVT_helperObjects = [];       // Invisible helper objects for position tracking
HVT_lastDecayCheck = time;    // Last time intel decay was checked
HVT_lastPositionUpdate = time; // Last time positions were updated

// =====================================================================
// DEBUG HELPER FUNCTIONS
// =====================================================================

// Function to log debug messages
HVT_fnc_logDebug = {
    params ["_message"];
    
    if (HVT_DEBUG_MODE) then {
        diag_log format ["HVT SYSTEM: %1", _message];
        systemChat format ["HVT: %1", _message];
    };
};

// =====================================================================
// CORE INITIALIZATION FUNCTIONS
// =====================================================================

// Initialize the entire HVT system
HVT_fnc_initSystem = {
    ["System initialization started"] call HVT_fnc_logDebug;
    
    // Find all HVT units and initialize their positions
    [] call HVT_fnc_findHVTUnits;
    
    // Create map markers for all HVTs
    [] call HVT_fnc_createMarkers;
    
    // Start position tracking
    [] spawn HVT_fnc_startPositionTracking;
    
    // Start intel decay system
    [] spawn HVT_fnc_startIntelDecay;
    
    // Start task monitoring
    [] spawn HVT_fnc_startTaskMonitoring;
    
    ["System initialization complete"] call HVT_fnc_logDebug;
};

// Find all HVT units in the mission
HVT_fnc_findHVTUnits = {
    ["Finding HVT units"] call HVT_fnc_logDebug;
    
    // Create helper objects array
    HVT_helperObjects = [];
    
    // Process each defined HVT
    {
        private _hvtIndex = _forEachIndex;
        private _varName = _x select 0;
        private _displayName = _x select 1;
        
        // Try to find the unit by variable name
        private _unit = missionNamespace getVariable [_varName, objNull];
        
        if (!isNull _unit) then {
            // Get current position and update in data array
            private _pos = getPos _unit;
            (HVT_TARGETS select _hvtIndex) set [3, _pos];
            
            // Create helper object for tracking
            private _helper = "Land_HelipadEmpty_F" createVehicle [0,0,0];
            _helper attachTo [_unit, [0,0,0]];
            
            // Store in array
            HVT_helperObjects set [_hvtIndex, _helper];
            
            ["Found HVT: " + _displayName + " at position " + str(_pos)] call HVT_fnc_logDebug;
        } else {
            ["WARNING: Could not find HVT: " + _varName] call HVT_fnc_logDebug;
            // Add placeholder to maintain array indices
            HVT_helperObjects set [_hvtIndex, objNull];
        };
    } forEach HVT_TARGETS;
};

// Create markers for all HVTs
HVT_fnc_createMarkers = {
    ["Creating HVT markers"] call HVT_fnc_logDebug;
    
    // Initialize markers array
    HVT_markers = [];
    
    // Create a marker for each HVT
    {
        private _hvtIndex = _forEachIndex;
        private _displayName = _x select 1;
        private _type = _x select 2;
        private _pos = _x select 3;
        private _intel = _x select 4;
        private _captured = _x select 7;
        private _eliminated = _x select 8;
        
        // Create marker name
        private _markerName = format ["hvt_marker_%1", _hvtIndex];
        
        // Create marker
        private _marker = createMarkerLocal [_markerName, _pos];
        
        // Set marker properties based on status and intel
        if (_eliminated) then {
            _markerName setMarkerTypeLocal "mil_destroy";
            _markerName setMarkerColorLocal "ColorBlack";
            _markerName setMarkerTextLocal format ["%1 (ELIMINATED)", _displayName];
        } else {
            if (_captured) then {
                _markerName setMarkerTypeLocal "mil_end";
                _markerName setMarkerColorLocal "ColorGreen";
                _markerName setMarkerTextLocal format ["%1 (CAPTURED)", _displayName];
            } else {
                // Set appearance based on intel level
                if (_intel >= HVT_INTEL_COMPLETE) then {
                    if (_type == "officer") then {
                        _markerName setMarkerTypeLocal "mil_triangle";
                        _markerName setMarkerColorLocal "ColorRed";
                        _markerName setMarkerTextLocal _displayName;
                        _markerName setMarkerSizeLocal [1.2, 1.2];
                    } else {
                        if (_type == "ship") then {
                            _markerName setMarkerTypeLocal "mil_triangle_noShadow";
                            _markerName setMarkerColorLocal "ColorBlue";
                            _markerName setMarkerTextLocal _displayName;
                        } else {
                            _markerName setMarkerTypeLocal "mil_objective";
                            _markerName setMarkerColorLocal "ColorRed";
                            _markerName setMarkerTextLocal _displayName;
                        };
                    };
                } else {
                    if (_intel >= HVT_INTEL_BASIC) then {
                        _markerName setMarkerTypeLocal "mil_unknown";
                        _markerName setMarkerColorLocal "ColorOrange";
                        _markerName setMarkerTextLocal _type;
                    } else {
                        _markerName setMarkerTypeLocal "mil_unknown";
                        _markerName setMarkerColorLocal "ColorBlack";
                        _markerName setMarkerTextLocal "?";
                    };
                };
            };
        };
        
        // Store marker name in array
        HVT_markers set [_hvtIndex, _markerName];
        
    } forEach HVT_TARGETS;
};

// Start position tracking loop
HVT_fnc_startPositionTracking = {
    ["Starting position tracking loop"] call HVT_fnc_logDebug;
    
    // Run continuous position update loop
    while {true} do {
        // Update positions
        [] call HVT_fnc_updatePositions;
        
        // Store last update time
        HVT_lastPositionUpdate = time;
        
        // Wait until next update
        sleep HVT_POSITION_REFRESH_RATE;
    };
};

// Update HVT positions and task markers
HVT_fnc_updatePositions = {
    {
        private _hvtIndex = _forEachIndex;
        private _helper = if (_hvtIndex < count HVT_helperObjects) then { 
            HVT_helperObjects select _hvtIndex 
        } else { 
            objNull 
        };
        
        // Only update if helper exists
        if (!isNull _helper) then {
            // Get position from helper
            private _pos = getPos _helper;
            
            // Update HVT data position
            (HVT_TARGETS select _hvtIndex) set [3, _pos];
            
            // Update marker position
            private _markerName = if (_hvtIndex < count HVT_markers) then { 
                HVT_markers select _hvtIndex 
            } else { 
                "" 
            };
            
            if (_markerName != "") then {
                _markerName setMarkerPosLocal _pos;
            };
            
            // Update any task markers for this HVT
            {
                private _taskData = _x;
                
                // Only process tasks for this HVT
                if (count _taskData > 1 && {_taskData select 1 == _hvtIndex}) then {
                    private _taskId = _taskData select 0;
                    private _taskType = _taskData select 2;
                    private _taskMarker = _taskData select 5;
                    private _iconData = _taskData select 6;
                    
                    // Update task marker
                    if (_taskMarker != "" && {markerType _taskMarker != ""}) then {
                        _taskMarker setMarkerPos _pos;
                        ["Updated marker position for task " + _taskId + " to " + str(_pos)] call HVT_fnc_logDebug;
                    };
                    
                    // Update BIS task destination
                    [_taskId, _pos] call BIS_fnc_taskSetDestination;
                    
                    // Update curator icon position if it exists
                    if (!isNil "_iconData" && {count _iconData >= 2}) then {
                        _iconData params ["_module", "_iconID"];
                        
                        if (!isNull _module && _iconID != -1) then {
                            // Remove the old icon
                            [_module, _iconID] call BIS_fnc_removeCuratorIcon;
                            
                            // Get task type to determine icon
                            private _newIcon = "\A3\ui_f\data\map\markers\military\objective_ca.paa";
                            switch (_taskType) do {
                                case "track": { _newIcon = "\A3\ui_f\data\map\markers\military\recon_ca.paa"; };
                                case "kill": { _newIcon = "\A3\ui_f\data\map\markers\military\destroy_ca.paa"; };
                                case "capture": { _newIcon = "\A3\ui_f\data\map\markers\military\end_ca.paa"; };
                                case "attack": { _newIcon = "\A3\ui_f\data\map\markers\military\destroy_ca.paa"; };
                                default { _newIcon = "\A3\ui_f\data\map\markers\military\objective_ca.paa"; };
                            };
                            
                            // Create a new icon with proper text
                            private _iconText = "";
                            private _hvtData = HVT_TARGETS select _hvtIndex;
                            private _displayName = _hvtData select 1;
                            
                            // Get the task name based on task type
                            private _taskName = _taskType;
                            {
                                if (_x select 0 == _taskType) exitWith {
                                    _taskName = _x select 1;
                                };
                            } forEach (_hvtData select 5);
                            
                            // Use the same format as in the original creation
                            _iconText = format ["Op: %1 - %2", _taskName, _displayName];
                            
                            // Create the new icon
                            private _newIconID = [_module, [_newIcon, [0, 0.3, 0.6, 1], _pos, 1, 1, 0, _iconText], false] call BIS_fnc_addCuratorIcon;
                            
                            // Update the icon ID in the task data
                            _iconData set [1, _newIconID];
                            _taskData set [6, _iconData];
                            
                            // Update the task in the active tasks array
                            {
                                if (_x select 0 == _taskId) exitWith {
                                    HVT_activeTasks set [_forEachIndex, _taskData];
                                };
                            } forEach HVT_activeTasks;
                        };
                    };
                };
            } forEach HVT_activeTasks;
        } else {
            // Try to recreate helper if missing
            [] call HVT_fnc_checkAndRecreateHelper;
        };
    } forEach HVT_TARGETS;
};

// Check and recreate helper objects if needed
HVT_fnc_checkAndRecreateHelper = {
    {
        private _hvtIndex = _forEachIndex;
        private _helper = if (_hvtIndex < count HVT_helperObjects) then { 
            HVT_helperObjects select _hvtIndex 
        } else { 
            objNull 
        };
        
        // Check if helper is missing
        if (isNull _helper) then {
            private _hvtData = HVT_TARGETS select _hvtIndex;
            private _varName = _hvtData select 0;
            private _displayName = _hvtData select 1;
            private _unit = missionNamespace getVariable [_varName, objNull];
            
            // Recreate if unit exists
            if (!isNull _unit) then {
                private _helper = "Land_HelipadEmpty_F" createVehicle [0,0,0];
                _helper attachTo [_unit, [0,0,0]];
                
                // Store in array
                HVT_helperObjects set [_hvtIndex, _helper];
                
                ["Recreated helper for " + _displayName] call HVT_fnc_logDebug;
            };
        };
    } forEach HVT_TARGETS;
};

// Start intel decay system
HVT_fnc_startIntelDecay = {
    ["Starting intel decay system"] call HVT_fnc_logDebug;
    
    // Initialize last decay check time
    HVT_lastDecayCheck = time;
    
    // Run continuous decay check loop
    while {true} do {
        // Check for intel decay
        [] call HVT_fnc_processIntelDecay;
        
        // Wait until next check
        sleep HVT_DECAY_CHECK_INTERVAL;
    };
};

// Process intel decay for all HVTs
HVT_fnc_processIntelDecay = {
    // Calculate time since last check
    private _currentTime = time;
    private _elapsedTime = _currentTime - HVT_lastDecayCheck;
    private _elapsedMinutes = _elapsedTime / 60;
    
    // Skip if not enough time has passed
    if (_elapsedMinutes < 0.25) exitWith {};
    
    // Update last check time
    HVT_lastDecayCheck = _currentTime;
    
    // Calculate decay amount
    private _decayAmount = _elapsedMinutes * HVT_INTEL_DECAY_RATE;
    
    // Process each HVT
    {
        private _hvtIndex = _forEachIndex;
        private _captured = _x select 7;
        private _eliminated = _x select 8;
        
        // Only decay intel for active HVTs
        if (!_captured && !_eliminated) then {
            // Random chance to apply decay
            if (random 100 < HVT_DECAY_CHANCE) then {
                [_hvtIndex, -_decayAmount] call HVT_fnc_modifyIntel;
            };
        };
    } forEach HVT_TARGETS;
};

// Start task monitoring loop
HVT_fnc_startTaskMonitoring = {
    ["Starting task monitoring loop"] call HVT_fnc_logDebug;
    
    // Run continuous task check loop
    while {true} do {
        // Check all tasks for completion
        [] call HVT_fnc_checkTasks;
        
        // Wait before next check
        sleep 5;
    };
};

// =====================================================================
// TASK MANAGEMENT FUNCTIONS
// =====================================================================

// Create a task for an HVT
HVT_fnc_createTask = {
    params ["_hvtIndex", "_taskType", "_assignedUnits"];
    
    // Validate HVT index
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        ["Invalid HVT index for task creation: " + str(_hvtIndex)] call HVT_fnc_logDebug;
        ""
    };
    
    // Get HVT data
    private _hvtData = HVT_TARGETS select _hvtIndex;
    _hvtData params ["_varName", "_displayName", "_type", "_pos", "_intel", "_tasks"];
    
    // Find task details
    private _taskName = "";
    private _rewards = [];
    
    {
        if (_x select 0 == _taskType) exitWith {
            _taskName = _x select 1;
            _rewards = _x select 2;
        };
    } forEach _tasks;
    
    if (_taskName == "") exitWith {
        ["Task type " + _taskType + " not found for HVT " + _displayName] call HVT_fnc_logDebug;
        ""
    };
    
    // Find target unit
    private _targetUnit = missionNamespace getVariable [_varName, objNull];
    
    if (isNull _targetUnit) exitWith {
        ["HVT unit " + _varName + " not found"] call HVT_fnc_logDebug;
        ""
    };
    
    // Create unique task ID
    private _taskId = format ["hvt_task_%1_%2_%3", _hvtIndex, _taskType, round(serverTime)];
    
    // Create task description
    private _taskDescription = [
        format ["Operation %1: %2 - %3", 
            missionNamespace getVariable ["MISSION_operationName", "Unnamed"], 
            _taskName, 
            _displayName
        ],
        format ["Your orders: %1 the %2 %3.", toLower _taskName, _type, _displayName],
        format ["Op: %1 - %2", _taskName, _displayName]
    ];
    
    // Create BIS task
    private _taskResult = [
        _assignedUnits,
        _taskId,
        _taskDescription,
        _pos,
        "CREATED",
        10,
        true,
        "default"
    ] call BIS_fnc_taskCreate;
    
    if (_taskResult isEqualTo "") exitWith {
        ["Failed to create task"] call HVT_fnc_logDebug;
        ""
    };
    
    // Set as current task
    [_taskId] call BIS_fnc_taskSetCurrent;
    
    // Create Zeus marker for task
    private _markerName = format ["hvt_task_marker_%1", _taskId];
    private _marker = createMarker [_markerName, _pos];
    _marker setMarkerType "mil_objective";
    
    // Set marker color based on task type
    switch (_taskType) do {
        case "track": { _marker setMarkerColor "ColorBlue"; };
        case "kill": { _marker setMarkerColor "ColorRed"; };
        case "capture": { _marker setMarkerColor "ColorGreen"; };
        case "attack": { _marker setMarkerColor "ColorOrange"; };
        default { _marker setMarkerColor "ColorBlue"; };
    };
    
    _marker setMarkerText _taskName;
    
    // Add Zeus curator icon if possible
    private _curatorModule = missionNamespace getVariable ["z1", objNull];
    private _taskIcon = "\A3\ui_f\data\map\markers\military\objective_ca.paa";
    private _iconID = -1;
    
    // Select icon based on task type
    switch (_taskType) do {
        case "track": { _taskIcon = "\A3\ui_f\data\map\markers\military\recon_ca.paa"; };
        case "kill": { _taskIcon = "\A3\ui_f\data\map\markers\military\destroy_ca.paa"; };
        case "capture": { _taskIcon = "\A3\ui_f\data\map\markers\military\end_ca.paa"; };
        case "attack": { _taskIcon = "\A3\ui_f\data\map\markers\military\destroy_ca.paa"; };
        default { _taskIcon = "\A3\ui_f\data\map\markers\military\objective_ca.paa"; };
    };
    
    // Add icon if curator module exists
    if (!isNull _curatorModule) then {
        private _iconText = format ["Op: %1 - %2", _taskName, _displayName];
        _iconID = [_curatorModule, [_taskIcon, [0, 0.3, 0.6, 1], _pos, 1, 1, 0, _iconText], false] call BIS_fnc_addCuratorIcon;
        
        // Log icon creation result
        if (_iconID != -1) then {
            ["Created curator icon with ID " + str(_iconID) + " for task " + _taskId] call HVT_fnc_logDebug;
        } else {
            ["Failed to create curator icon for task " + _taskId] call HVT_fnc_logDebug;
        };
    } else {
        ["Warning: No curator module found for icon creation"] call HVT_fnc_logDebug;
    };
    
    // Store icon data for later removal
    private _iconData = [_curatorModule, _iconID];
    
    // For capture tasks, set up a trigger
    private _taskTrigger = objNull;
    if (_taskType == "capture") then {
        _taskTrigger = createTrigger ["EmptyDetector", getPos _targetUnit, false];
        _taskTrigger setTriggerArea [30, 30, 0, false];
        _taskTrigger setTriggerActivation ["WEST", "PRESENT", false];
        _taskTrigger setTriggerStatements [
            "this && {({side _x == side player && _x distance thisTrigger < 30} count thisList > 0)}",
            format [
                "
                (objectFromNetId '%1') setCaptive true;
                (objectFromNetId '%1') disableAI 'ALL';
                (objectFromNetId '%1') setVariable ['isSurrendered', true, true];
                systemChat 'Target is surrendering!';
                ",
                netId _targetUnit
            ],
            ""
        ];
        
        // Attach trigger to target
        _taskTrigger attachTo [_targetUnit, [0,0,0]];
    };
    
    // Store task data
    private _taskData = [
        _taskId,        // 0: Task ID
        _hvtIndex,      // 1: HVT index
        _taskType,      // 2: Task type
        _assignedUnits, // 3: Assigned units
        _targetUnit,    // 4: Target unit
        _markerName,    // 5: Marker name
        _iconData,      // 6: Curator icon
        _taskTrigger    // 7: Task trigger (for capture)
    ];
    
    // Add to active tasks
    HVT_activeTasks pushBack _taskData;
    
    ["Created task: " + _taskId + " for " + _displayName] call HVT_fnc_logDebug;
    
    // Return task ID
    _taskId
};

// Check all tasks for completion
HVT_fnc_checkTasks = {
    private _completedTasks = [];
    
    {
        private _taskData = _x;
        
        // Skip invalid data
        if (count _taskData < 5) then {
            continue;
        };
        
        // Extract task info
        private _taskId = _taskData select 0;
        private _hvtIndex = _taskData select 1;
        private _taskType = _taskData select 2;
        private _assignedUnits = _taskData select 3;
        private _targetUnit = _taskData select 4;
        
        // Skip if invalid HVT
        if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) then {
            continue;
        };
        
        // Check completion based on task type
        private _isComplete = false;
        private _isSuccessful = false;
        
        switch (_taskType) do {
            case "track": {
                // Track is complete when intel reaches 100%
                private _intel = (HVT_TARGETS select _hvtIndex) select 4;
                
                // Add intel if unit is nearby
                if (!isNull _targetUnit) then {
                    {
                        if (!isNull _x && {alive _x} && {_x distance _targetUnit < 200}) exitWith {
                            [_hvtIndex, 1] call HVT_fnc_modifyIntel;
                        };
                    } forEach _assignedUnits;
                };
                
                // Complete when intel reaches 100%
                _isComplete = (_intel >= 100);
                _isSuccessful = _isComplete;
            };
            
            case "kill": {
                // Kill task is complete when target is dead
                _isComplete = (isNull _targetUnit || !alive _targetUnit);
                _isSuccessful = _isComplete;
                
                // Mark as eliminated
                if (_isComplete) then {
                    [_hvtIndex] call HVT_fnc_setEliminated;
                };
            };
            
            case "capture": {
                // Check if target is captured
                private _isSurrendered = !isNull _targetUnit && 
                                          alive _targetUnit && 
                                         {_targetUnit getVariable ["isSurrendered", false]};
                                         
                // Check if friendly unit is nearby
                private _friendlyNearby = false;
                if (_isSurrendered) then {
                    {
                        if (!isNull _x && alive _x && {_x distance _targetUnit < 10}) exitWith {
                            _friendlyNearby = true;
                        };
                    } forEach _assignedUnits;
                };
                
                // Complete if surrendered and friendly nearby
                if (_isSurrendered && _friendlyNearby) then {
                    _isComplete = true;
                    _isSuccessful = true;
                    [_hvtIndex, true] call HVT_fnc_setCaptured;
                };
                
                // Also complete (but fail) if target died
                if (isNull _targetUnit || !alive _targetUnit) then {
                    _isComplete = true;
                    _isSuccessful = false;
                    [_hvtIndex] call HVT_fnc_setEliminated;
                };
            };
            
            case "attack": {
                // Attack is complete when target is heavily damaged or destroyed
                _isComplete = (isNull _targetUnit || !alive _targetUnit || damage _targetUnit > 0.75);
                _isSuccessful = _isComplete;
                
                // Mark as eliminated if complete
                if (_isComplete) then {
                    [_hvtIndex] call HVT_fnc_setEliminated;
                };
            };
            
            default {
                ["Unknown task type: " + _taskType] call HVT_fnc_logDebug;
            };
        };
        
        // Add to completed tasks list
        if (_isComplete) then {
            _completedTasks pushBack [_taskId, _isSuccessful];
        };
        
    } forEach HVT_activeTasks;
    
    // Process all completed tasks
    {
        _x params ["_taskId", "_success"];
        [_taskId, _success] call HVT_fnc_completeTask;
    } forEach _completedTasks;
};

// Complete a task and give rewards
HVT_fnc_completeTask = {
    params ["_taskId", "_success"];
    
    // Find task in active tasks
    private _taskIndex = -1;
    {
        if (_x select 0 == _taskId) exitWith {
            _taskIndex = _forEachIndex;
        };
    } forEach HVT_activeTasks;
    
    if (_taskIndex == -1) exitWith {
        ["Task not found: " + _taskId] call HVT_fnc_logDebug;
        false
    };
    
    private _taskData = HVT_activeTasks select _taskIndex;
    
    // Extract task info
    private _hvtIndex = _taskData select 1;
    private _taskType = _taskData select 2;
    private _markerName = _taskData select 5;
    private _iconData = _taskData select 6;
    private _trigger = _taskData select 7;
    
    // Get HVT data
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        ["Invalid HVT index in task: " + str(_hvtIndex)] call HVT_fnc_logDebug;
        false
    };
    
    private _hvtData = HVT_TARGETS select _hvtIndex;
    private _displayName = _hvtData select 1;
    private _tasks = _hvtData select 5;
    
    // Update task state
    [_taskId, if (_success) then {"SUCCEEDED"} else {"FAILED"}] call BIS_fnc_taskSetState;
    
    // Process rewards if successful
    if (_success) then {
        // Find task rewards
        private _rewards = [];
        {
            if (_x select 0 == _taskType) exitWith {
                _rewards = _x select 2;
            };
        } forEach _tasks;
        
        // Apply rewards
        {
            _x params ["_resourceType", "_amount"];
            
            if (!isNil "RTS_fnc_modifyResource") then {
                [_resourceType, _amount] call RTS_fnc_modifyResource;
                systemChat format ["Received %1 %2 for completing task.", _amount, _resourceType];
            };
        } forEach _rewards;
        
        // Update HVT status and provide feedback
        switch (_taskType) do {
            case "kill": {
                hint format ["Target eliminated: %1", _displayName];
                systemChat format ["%1 has been eliminated.", _displayName];
            };
            case "capture": {
                hint format ["Target captured: %1", _displayName];
                systemChat format ["%1 has been captured.", _displayName];
            };
            case "attack": {
                hint format ["Target destroyed: %1", _displayName];
                systemChat format ["%1 has been destroyed.", _displayName];
            };
            case "track": {
                hint format ["Intelligence on %1 fully gathered", _displayName];
                systemChat "Intelligence gathering complete.";
            };
        };
    } else {
        // Failed task feedback
        hint format ["Task failed: %1", _displayName];
        systemChat format ["The operation against %1 has failed.", _displayName];
    };
    
    // Cleanup
    // Delete marker
    if (_markerName != "" && markerType _markerName != "") then {
        deleteMarker _markerName;
    };
    
    // Remove curator icon
    if (!isNil "_iconData" && count _iconData >= 2) then {
        _iconData params ["_module", "_id"];
        if (!isNull _module && _id != -1) then {
            [_module, _id] call BIS_fnc_removeCuratorIcon;
        };
    };
    
    // Delete trigger
    if (!isNull _trigger) then {
        deleteVehicle _trigger;
    };
    
    // Delete BIS task
    [_taskId] call BIS_fnc_deleteTask;
    
    // Remove from active tasks
    HVT_activeTasks deleteAt _taskIndex;
    
    ["Task " + _taskId + " completed with result: " + str(_success)] call HVT_fnc_logDebug;
    true
};

// =====================================================================
// HVT STATUS MANAGEMENT FUNCTIONS
// =====================================================================

// Modify intel level for an HVT
HVT_fnc_modifyIntel = {
    params ["_hvtIndex", "_deltaIntel"];
    
    // Validate index
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        ["Invalid HVT index for intel modification: " + str(_hvtIndex)] call HVT_fnc_logDebug;
        false
    };
    
    // Get current intel
    private _hvtData = HVT_TARGETS select _hvtIndex;
    private _currentIntel = _hvtData select 4;
    
    // Calculate new intel (clamped to 0-100)
    private _newIntel = (_currentIntel + _deltaIntel) min 100 max 0;
    
    // Store old intel level
    private _oldIntelLevel = [_currentIntel] call HVT_fnc_getIntelLevel;
    
    // Update intel
    _hvtData set [4, _newIntel];
    HVT_TARGETS set [_hvtIndex, _hvtData];
    
    // Check if intel level changed
    private _newIntelLevel = [_newIntel] call HVT_fnc_getIntelLevel;
    
    if (_oldIntelLevel != _newIntelLevel) then {
        // Update marker for new intel level
        [_hvtIndex] call HVT_fnc_updateMarker;
        
        // Provide feedback if intel increased
        if (_newIntelLevel > _oldIntelLevel) then {
            private _displayName = _hvtData select 1;
            systemChat format ["Intelligence on %1 has increased.", _displayName];
        };
    };
    
    true
};

// Get intel level category
HVT_fnc_getIntelLevel = {
    params ["_intelPercent"];
    
    if (_intelPercent >= HVT_INTEL_COMPLETE) then {
        "complete"
    } else {
        if (_intelPercent >= HVT_INTEL_BASIC) then {
            "basic"
        } else {
            "unknown"
        };
    };
};

// Set an HVT as captured
HVT_fnc_setCaptured = {
    params ["_hvtIndex", "_isCaptured"];
    
    // Validate index
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        ["Invalid HVT index for capture: " + str(_hvtIndex)] call HVT_fnc_logDebug;
        false
    };
    
    // Update captured status
    (HVT_TARGETS select _hvtIndex) set [7, _isCaptured];
    
    // Update marker
    [_hvtIndex] call HVT_fnc_updateMarker;
    
    // Get target unit
    private _varName = (HVT_TARGETS select _hvtIndex) select 0;
    private _unit = missionNamespace getVariable [_varName, objNull];
    
    if (!isNull _unit) then {
        _unit setCaptive true;
        
        // If it's a person, make them surrender
        if (_unit isKindOf "Man") then {
            _unit setUnitPos "UP";
            _unit disableAI "ALL";
            _unit setDamage 0; // Heal them
        };
    };
    
    ["HVT " + str(_hvtIndex) + " captured: " + str(_isCaptured)] call HVT_fnc_logDebug;
    true
};

// Set an HVT as eliminated
HVT_fnc_setEliminated = {
    params ["_hvtIndex"];
    
    // Validate index
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        ["Invalid HVT index for elimination: " + str(_hvtIndex)] call HVT_fnc_logDebug;
        false
    };
    
    // Update eliminated status
    (HVT_TARGETS select _hvtIndex) set [8, true];
    (HVT_TARGETS select _hvtIndex) set [7, false]; // Not captured if eliminated
    
    // Update marker
    [_hvtIndex] call HVT_fnc_updateMarker;
    
    // Log
    private _displayName = (HVT_TARGETS select _hvtIndex) select 1;
    ["HVT eliminated: " + _displayName + " (index " + str(_hvtIndex) + ")"] call HVT_fnc_logDebug;
    true
};

// Update marker for an HVT
HVT_fnc_updateMarker = {
    params ["_hvtIndex"];
    
    // Validate index
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        ["Invalid HVT index for marker update: " + str(_hvtIndex)] call HVT_fnc_logDebug;
        false
    };
    
    // Get HVT data
    private _hvtData = HVT_TARGETS select _hvtIndex;
    private _displayName = _hvtData select 1;
    private _type = _hvtData select 2;
    private _pos = _hvtData select 3;
    private _intel = _hvtData select 4;
    private _captured = _hvtData select 7;
    private _eliminated = _hvtData select 8;
    
    // Get marker name
    private _markerName = if (_hvtIndex < count HVT_markers) then {
        HVT_markers select _hvtIndex
    } else {
        format ["hvt_marker_%1", _hvtIndex]
    };
    
    // Delete existing marker if it exists
    if (markerType _markerName != "") then {
        deleteMarkerLocal _markerName;
    };
    
    // Create new marker
    private _marker = createMarkerLocal [_markerName, _pos];
    
    // Set marker properties based on status and intel
    if (_eliminated) then {
        _markerName setMarkerTypeLocal "mil_destroy";
        _markerName setMarkerColorLocal "ColorBlack";
        _markerName setMarkerTextLocal format ["%1 (ELIMINATED)", _displayName];
    } else {
        if (_captured) then {
            _markerName setMarkerTypeLocal "mil_end";
            _markerName setMarkerColorLocal "ColorGreen";
            _markerName setMarkerTextLocal format ["%1 (CAPTURED)", _displayName];
        } else {
            // Set appearance based on intel level
            if (_intel >= HVT_INTEL_COMPLETE) then {
                if (_type == "officer") then {
                    _markerName setMarkerTypeLocal "mil_triangle";
                    _markerName setMarkerColorLocal "ColorRed";
                    _markerName setMarkerTextLocal _displayName;
                    _markerName setMarkerSizeLocal [1.2, 1.2];
                } else {
                    if (_type == "ship") then {
                        _markerName setMarkerTypeLocal "mil_triangle_noShadow";
                        _markerName setMarkerColorLocal "ColorBlue";
                        _markerName setMarkerTextLocal _displayName;
                    } else {
                        _markerName setMarkerTypeLocal "mil_objective";
                        _markerName setMarkerColorLocal "ColorRed";
                        _markerName setMarkerTextLocal _displayName;
                    };
                };
            } else {
                if (_intel >= HVT_INTEL_BASIC) then {
                    _markerName setMarkerTypeLocal "mil_unknown";
                    _markerName setMarkerColorLocal "ColorOrange";
                    _markerName setMarkerTextLocal _type;
                } else {
                    _markerName setMarkerTypeLocal "mil_unknown";
                    _markerName setMarkerColorLocal "ColorBlack";
                    _markerName setMarkerTextLocal "?";
                };
            };
        };
    };
    
    // Update markers array
    if (_hvtIndex < count HVT_markers) then {
        HVT_markers set [_hvtIndex, _markerName];
    } else {
        HVT_markers pushBack _markerName;
    };
    
    true
};

// =====================================================================
// UI INTEGRATION FUNCTIONS
// =====================================================================

// Get briefing text for an HVT
HVT_fnc_getBriefing = {
    params ["_hvtIndex"];
    
    // Validate index
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        "Invalid target"
    };
    
    // Get HVT data
    private _hvtData = HVT_TARGETS select _hvtIndex;
    private _intel = _hvtData select 4;
    private _briefings = _hvtData select 6;
    
    // Determine which briefing to use based on intel level
    private _briefingIndex = 0;
    
    if (_intel >= HVT_INTEL_COMPLETE) then {
        _briefingIndex = 2;
    } else {
        if (_intel >= HVT_INTEL_BASIC) then {
            _briefingIndex = 1;
        };
    };
    
    // Return briefing text
    if (_briefingIndex < count _briefings) then {
        _briefings select _briefingIndex
    } else {
        "No briefing available"
    };
};

// Show/hide HVT markers
HVT_fnc_toggleMarkers = {
    params [["_show", true]];
    
    {
        private _markerName = _x;
        if (_markerName != "") then {
            _markerName setMarkerAlphaLocal (if (_show) then {1} else {0});
        };
    } forEach HVT_markers;
    
    ["HVT markers " + (if (_show) then {"shown"} else {"hidden"})] call HVT_fnc_logDebug;
};

// =====================================================================
// INTERFACE FUNCTIONS FOR EXTERNAL USE
// =====================================================================

// Public interface for creating a task
fnc_createHVTTask = {
    params ["_hvtIndex", "_taskType", "_assignedUnits"];
    [_hvtIndex, _taskType, _assignedUnits] call HVT_fnc_createTask
};

// Public interface for modifying intel
fnc_modifyHVTIntel = {
    params ["_hvtIndex", "_deltaIntel"];
    [_hvtIndex, _deltaIntel] call HVT_fnc_modifyIntel
};

// Public interface for setting HVT as captured
fnc_setCapturedHVT = {
    params ["_hvtIndex", "_isCaptured"];
    [_hvtIndex, _isCaptured] call HVT_fnc_setCaptured
};

// Public interface for setting HVT as eliminated
fnc_setEliminatedHVT = {
    params ["_hvtIndex"];
    [_hvtIndex] call HVT_fnc_setEliminated
};

// Public interface for getting briefing
fnc_getHVTBriefing = {
    params ["_hvtIndex"];
    [_hvtIndex] call HVT_fnc_getBriefing
};

// Public interface for toggling markers
fnc_toggleHVTMarkers = {
    params [["_show", true]];
    [_show] call HVT_fnc_toggleMarkers
};

// Helper function to find HVT index by variable name
fnc_findHVTIndexByName = {
    params ["_varName"];
    
    // Search for HVT with this variable name
    private _hvtIndex = -1;
    {
        if (_x select 0 == _varName) exitWith {
            _hvtIndex = _forEachIndex;
        };
    } forEach HVT_TARGETS;
    
    _hvtIndex
};

// Public interface for adding intel by name
fnc_addHVTIntelByName = {
    params ["_varName", "_amount"];
    
    private _hvtIndex = [_varName] call fnc_findHVTIndexByName;
    
    if (_hvtIndex != -1) then {
        [_hvtIndex, _amount] call HVT_fnc_modifyIntel;
        true
    } else {
        ["HVT not found with name: " + _varName] call HVT_fnc_logDebug;
        false
    };
};

// Public interface for updating a single HVT marker
fnc_forceSingleHVTRefresh = {
    params ["_hvtIndex"];
    
    if (_hvtIndex >= 0 && _hvtIndex < count HVT_TARGETS) then {
        [_hvtIndex] call HVT_fnc_updateMarker;
        true
    } else {
        false
    };
};

// Allow refreshing by name too
fnc_forceSingleHVTRefreshByName = {
    params ["_varName"];
    
    private _hvtIndex = [_varName] call fnc_findHVTIndexByName;
    
    if (_hvtIndex != -1) then {
        [_hvtIndex] call HVT_fnc_updateMarker;
        true
    } else {
        false
    };
};

// Function to force refresh of all HVT markers
fnc_forceRefreshHVTMarkers = {
    {
        [_forEachIndex] call HVT_fnc_updateMarker;
    } forEach HVT_TARGETS;
    
    ["All HVT markers refreshed"] call HVT_fnc_logDebug;
    true
};

// =====================================================================
// START SYSTEM INITIALIZATION
// =====================================================================

// Log system startup
diag_log "=====================================";
diag_log "HVT SYSTEM INITIALIZATION STARTED";
diag_log "=====================================";

// Initialize the system
[] call HVT_fnc_initSystem;

// Compatibility function for taskSystemArray.sqf
fnc_getHVTIntelLevel = {
    params ["_intelPercent"];
    
    // Simply call our internal function
    [_intelPercent] call HVT_fnc_getIntelLevel
};