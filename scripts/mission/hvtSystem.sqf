// scripts/mission/hvtSystem.sqf
// High-Value Target (HVT) System for WW2 RTS

// =====================================================================
// HVT CONFIGURATION VALUES - EDIT AS NEEDED
// =====================================================================

// Debugging info
systemChat "HVT System initializing...";
diag_log "=====================================";
diag_log "HVT SYSTEM INITIALIZATION STARTED";
diag_log "=====================================";

// Intel level thresholds - matching the task system
HVT_INTEL_UNKNOWN = 0;    // 0-25%
HVT_INTEL_BASIC = 25;     // 25-75%
HVT_INTEL_COMPLETE = 75;  // 75-100%

// Intel decay rate (per minute) if target is not captured
// GAMEPLAY VARIABLE - Adjust this to change how quickly intel becomes outdated
HVT_INTEL_DECAY_RATE = 1; // Intelligence points lost per minute

// Time between intel decay checks (in seconds)
// GAMEPLAY VARIABLE - Lower values mean more frequent checks but higher performance impact
HVT_DECAY_CHECK_INTERVAL = 60; // Check every minute

// HVT refresh rate for position updates (in seconds)
// GAMEPLAY VARIABLE - Lower values give more accurate tracking but higher performance impact
HVT_POSITION_REFRESH_RATE = 5; // Update positions every 5 seconds

// Percentage chance of intel decay occurring during each check
// GAMEPLAY VARIABLE - Lower values make intel more persistent
HVT_DECAY_CHANCE = 75; // 75% chance of decay during each check

// =====================================================================
// HVT TARGET ARRAY - EDIT THIS TO ADD/MODIFY TARGETS
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

// HVT targets array - default initialization with test targets
HVT_TARGETS = [
    // Test HVT 1 - Enemy Officer
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
    
    // Test HVT 2 - Enemy Ship
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

// Target types with specific icon mappings
HVT_TARGET_ICONS = [
    ["officer", "o_hq"], 
    ["scientist", "o_hq"],
    ["ship", "o_naval"],
    ["vehicle", "o_armor"],
    ["plane", "o_plane"],
    ["supply", "o_support"]
];

// =====================================================================
// GLOBAL VARIABLES - DO NOT EDIT BELOW THIS LINE
// =====================================================================

// Track marker IDs
if (isNil "HVT_markers") then { HVT_markers = []; };

// Track active HVT tasks
if (isNil "HVT_activeTasks") then { HVT_activeTasks = []; };

// Track last position updates
if (isNil "HVT_lastPositions") then { HVT_lastPositions = []; };

// Track the last time intel decay was checked
if (isNil "HVT_lastDecayCheck") then { HVT_lastDecayCheck = time; };

// Track helper objects for HVTs
if (isNil "HVT_helperObjects") then { HVT_helperObjects = []; };

// =====================================================================
// HELPER FUNCTIONS - MUST BE DEFINED BEFORE USE
// =====================================================================

// Function to get intel level category from percentage
fnc_getHVTIntelLevel = {
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

// Helper object functions - MUST BE DEFINED FIRST
fnc_createHVTHelperObjects = {
    systemChat "Creating HVT helper objects...";
    
    // Clear any existing helper objects
    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach HVT_helperObjects;
    
    // Reset array
    HVT_helperObjects = [];
    HVT_markers = []; // Also reset markers to be safe
    
    // Create helper objects for each HVT
    {
        private _hvtIndex = _forEachIndex;
        private _varName = _x select 0;
        private _displayName = _x select 1;
        private _type = _x select 2;
        
        // Debug the unit identity first
        systemChat format ["Processing HVT: %1 (%2) - Type: %3", _displayName, _varName, _type];
        
        // Get the actual unit/vehicle
        private _unit = missionNamespace getVariable [_varName, objNull];
        
        if (!isNull _unit) then {
            systemChat format ["Found unit %1 at position %2", _varName, getPos _unit];
            
            // Create invisible helper object
            private _helperType = "Land_HelipadEmpty_F"; // Completely invisible object
            private _helper = createVehicle [_helperType, [0,0,0], [], 0, "NONE"];
            
            // Attach to the HVT unit
            _helper attachTo [_unit, [0, 0, 0]];
            
            // Store in array
            HVT_helperObjects set [_hvtIndex, _helper];
            
            // Generate a unique marker name
            private _markerName = format ["hvt_marker_%1", _hvtIndex];
            
            // Delete existing marker if it exists
            if (markerType _markerName != "") then {
                deleteMarkerLocal _markerName;
            };
            
            // Create marker on the helper
            private _marker = createMarkerLocal [_markerName, getPos _helper];
            
            // Set marker properties based on HVT type
            private _intel = _x select 4;
            private _captured = _x select 7;
            private _eliminated = _x select 8;
            
            // Default markers for unknown
            private _markerType = "mil_unknown";
            private _markerColor = "ColorBlack";
            private _markerText = "?";
            
            // Only show full details if we have enough intel
            if (_intel >= HVT_INTEL_COMPLETE) then {
                // Full intel - use type-specific markers
                _markerColor = "ColorRed";
                _markerText = _displayName;
                
                // Choose marker based on unit type
                if (_type == "officer" || _type == "scientist") then {
                    // For personnel, use a triangle/headshot icon
                    _markerType = "mil_triangle";
                    _markerName setMarkerSizeLocal [1.2, 1.2];
                } else { 
                    if (_type == "ship") then {
                        // For ships, use a naval icon
                        _markerType = "mil_triangle_noShadow";
                        _markerColor = "ColorBlue";
                    } else {
                        // Default for other types
                        _markerType = "mil_objective";
                    };
                };
            } else { 
                if (_intel >= HVT_INTEL_BASIC) then {
                    // Basic intel - show type but not details
                    _markerColor = "ColorOrange";
                    _markerText = _type;
                    _markerType = "mil_unknown";
                };
            };
            
            // Handle capture and elimination states
            if (_eliminated) then {
                _markerColor = "ColorBlack";
                _markerText = format ["%1 (ELIMINATED)", _displayName];
                _markerType = "mil_destroy";
            } else {
                if (_captured) then {
                    _markerColor = "ColorGreen";
                    _markerText = format ["%1 (CAPTURED)", _displayName];
                    _markerType = "mil_end";
                };
            };
            
            // Apply marker properties
            _markerName setMarkerTypeLocal _markerType;
            _markerName setMarkerColorLocal _markerColor;
            _markerName setMarkerTextLocal _markerText;
            
            // Store marker name
            HVT_markers pushBack _markerName;
            
            systemChat format ["Created helper for %1 with marker type %2", _displayName, _markerType];
        } else {
            systemChat format ["WARNING: Could not find unit for HVT: %1", _varName];
            // Add placeholder to keep array indices aligned
            HVT_helperObjects set [_hvtIndex, objNull];
            HVT_markers pushBack "";
        };
    } forEach HVT_TARGETS;
};

// Function to update helper positions and markers
fnc_updateHVTHelperPositions = {
    {
        private _hvtIndex = _forEachIndex;
        private _helper = if (_hvtIndex < count HVT_helperObjects) then { HVT_helperObjects select _hvtIndex } else { objNull };
        
        if (!isNull _helper) then {
            // Get position from helper
            private _pos = getPos _helper;
            
            // Update HVT data position
            (HVT_TARGETS select _hvtIndex) set [3, _pos];
            
            // Update marker
            private _markerName = if (_hvtIndex < count HVT_markers) then { HVT_markers select _hvtIndex } else { "" };
            
            if (_markerName != "") then {
                _markerName setMarkerPosLocal _pos;
            };
        } else {
            // Try to recreate helper if it's missing
            private _hvtData = HVT_TARGETS select _hvtIndex;
            private _varName = _hvtData select 0;
            private _unit = missionNamespace getVariable [_varName, objNull];
            
            if (!isNull _unit) then {
                // Create invisible helper object
                private _helperType = "Land_HelipadEmpty_F";
                private _helper = createVehicle [_helperType, [0,0,0], [], 0, "NONE"];
                
                // Attach to the HVT unit
                _helper attachTo [_unit, [0, 0, 0]];
                
                // Store in array
                HVT_helperObjects set [_hvtIndex, _helper];
                
                systemChat format ["Recreated helper for HVT: %1", _hvtData select 1];
            };
        };
    } forEach HVT_TARGETS;
};

// Function to force a refresh of all HVT markers
fnc_forceRefreshHVTMarkers = {
    // Regenerate all helper objects
    call fnc_createHVTHelperObjects;
    
    // Force update
    call fnc_updateHVTHelperPositions;
    
    systemChat "HVT markers refreshed";
};

// Function to force refresh for a single HVT
fnc_forceSingleHVTRefresh = {
    params ["_varName"];
    
    // Find the HVT index
    private _hvtIndex = -1;
    {
        if (_x select 0 == _varName) exitWith {
            _hvtIndex = _forEachIndex;
        };
    } forEach HVT_TARGETS;
    
    if (_hvtIndex == -1) exitWith {
        systemChat format ["HVT not found: %1", _varName];
    };
    
    // Get the unit
    private _unit = missionNamespace getVariable [_varName, objNull];
    if (isNull _unit) exitWith {
        systemChat format ["Unit not found: %1", _varName];
    };
    
    // Get existing helper
    private _helper = if (_hvtIndex < count HVT_helperObjects) then {
        HVT_helperObjects select _hvtIndex
    } else {
        objNull
    };
    
    // If helper exists, delete it
    if (!isNull _helper) then {
        deleteVehicle _helper;
    };
    
    // Create new helper
    private _helperType = "Land_HelipadEmpty_F";
    private _helper = createVehicle [_helperType, [0,0,0], [], 0, "NONE"];
    _helper attachTo [_unit, [0, 0, 0]];
    
    // Update helper array
    HVT_helperObjects set [_hvtIndex, _helper];
    
    // Generate marker name
    private _markerName = format ["hvt_marker_%1", _hvtIndex];
    
    // Delete existing marker
    if (markerType _markerName != "") then {
        deleteMarkerLocal _markerName;
    };
    
    // Create new marker
    private _marker = createMarkerLocal [_markerName, getPos _helper];
    
    // Get HVT data
    private _hvtData = HVT_TARGETS select _hvtIndex;
    private _displayName = _hvtData select 1;
    private _type = _hvtData select 2;
    private _intel = _hvtData select 4;
    
    // Set marker type based on HVT type
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
    
    // Update markers array
    if (_hvtIndex < count HVT_markers) then {
        HVT_markers set [_hvtIndex, _markerName];
    } else {
        HVT_markers pushBack _markerName;
    };
    
    systemChat format ["Refreshed marker for %1 as type %2", _displayName, _type];
};

// Function to show/hide all HVT markers
fnc_toggleHVTMarkers = {
    params [["_show", true]];
    
    {
        private _markerName = _x;
        if (_markerName != "") then {
            _markerName setMarkerAlphaLocal (if (_show) then {1} else {0});
        };
    } forEach HVT_markers;
    
    systemChat format ["HVT markers %1", if (_show) then {"shown"} else {"hidden"}];
};

// =====================================================================
// CORE FUNCTIONS
// =====================================================================

// Initialize the HVT system
fnc_initHVTSystem = {
    // Find and initialize all HVT units
    systemChat "Finding HVT units...";
    call fnc_findHVTUnits;
    
    // Force the position update immediately for each HVT
    {
        private _hvtIndex = _forEachIndex;
        private _varName = _x select 0;
        private _displayName = _x select 1;
        
        // Get the unit
        private _unit = missionNamespace getVariable [_varName, objNull];
        
        if (!isNull _unit) then {
            // Get current position and store it
            private _pos = getPos _unit;
            (HVT_TARGETS select _hvtIndex) set [3, _pos];
            systemChat format ["Set initial position for %1: %2", _displayName, _pos];
        };
    } forEach HVT_TARGETS;
    
    // Create map markers for all HVTs
    systemChat "Creating HVT markers...";
    call fnc_createHVTMarkers;
    
    // Initialize position tracking
    systemChat "Initializing position tracking...";
    call fnc_initPositionTracking;
    
    // Initialize intel decay system
    call fnc_initIntelDecay;
    
    // Log initialization
    systemChat "High-Value Target System initialized!";
    diag_log "HVT System initialized!";
};

// Find all HVT units in the mission
fnc_findHVTUnits = {
    {
        private _hvtIndex = _forEachIndex;
        private _varName = _x select 0;
        
        // Try to find the unit/vehicle in the mission
        private _unit = missionNamespace getVariable [_varName, objNull];
        
        if (!isNull _unit) then {
            // Store initial position
            private _pos = getPos _unit;
            (HVT_TARGETS select _hvtIndex) set [3, _pos];
            
            // Initialize last position
            if (count HVT_lastPositions <= _hvtIndex) then {
                HVT_lastPositions set [_hvtIndex, _pos];
            } else {
                HVT_lastPositions pushBack _pos;
            };
            
            diag_log format ["HVT System: Found target %1 (%2) at position %3", _varName, _x select 1, _pos];
        } else {
            diag_log format ["HVT System: Warning - Could not find target %1 in mission!", _varName];
        };
    } forEach HVT_TARGETS;
};

// Initialize position tracking for mobile HVTs
fnc_initPositionTracking = {
    // First create helper objects
    call fnc_createHVTHelperObjects;
    
    // Start position update loop
    [] spawn {
        while {true} do {
            // Update helper positions
            call fnc_updateHVTHelperPositions;
            
            // Wait for next update
            sleep HVT_POSITION_REFRESH_RATE;
        };
    };
};

// Create map markers for all HVTs (Traditional method as backup)
fnc_createHVTMarkers = {
    systemChat "Creating HVT markers...";
    
    {
        private _hvtIndex = _forEachIndex;
        _x params ["_varName", "_displayName", "_type", "_pos", "_intel", "_tasks", "_briefings", "_captured", "_eliminated"];
        
        // Debug the unit
        private _unit = missionNamespace getVariable [_varName, objNull];
        if (!isNull _unit) then {
            systemChat format ["Found HVT unit: %1 at position %2", _varName, getPos _unit];
            // Force update position to the actual unit position
            _pos = getPos _unit;
            (HVT_TARGETS select _hvtIndex) set [3, _pos];
        } else {
            systemChat format ["WARNING: Could not find HVT unit: %1", _varName];
        };
        
        // Create marker name
        private _markerName = format ["hvt_marker_%1", _hvtIndex];
        
        // Create marker
        private _marker = createMarkerLocal [_markerName, _pos];
        _marker setMarkerPos _pos; // Explicitly set position
        
        // Set marker properties based on intel level and type
        private _markerType = "mil_unknown";
        private _markerColor = "ColorBlack";
        private _markerText = "?";
        
        // Handle different intel levels
        if (_intel >= HVT_INTEL_COMPLETE) then {
            _markerColor = "ColorRed";
            _markerText = _displayName;
            
            if (_type == "officer") then {
                _markerType = "mil_triangle";
            } else {
                if (_type == "ship") then {
                    _markerType = "mil_triangle_noShadow";
                    _markerColor = "ColorBlue";
                } else {
                    _markerType = "mil_objective";
                };
            };
        } else {
            if (_intel >= HVT_INTEL_BASIC) then {
                _markerColor = "ColorOrange";
                _markerText = _type;
                _markerType = "mil_unknown";
            };
        };
        
        // Handle capture/elimination status
        if (_eliminated) then {
            _markerColor = "ColorBlack";
            _markerText = format ["%1 (ELIMINATED)", _displayName];
            _markerType = "mil_destroy";
        } else {
            if (_captured) then {
                _markerColor = "ColorGreen";
                _markerText = format ["%1 (CAPTURED)", _displayName];
                _markerType = "mil_end";
            };
        };
        
        // Apply the marker properties
        _markerName setMarkerTypeLocal _markerType;
        _markerName setMarkerColorLocal _markerColor;
        _markerName setMarkerTextLocal _markerText;
        _markerName setMarkerPos _pos;
        
        // Store marker name
        if (count HVT_markers <= _hvtIndex) then {
            HVT_markers set [_hvtIndex, _markerName];
        } else {
            HVT_markers pushBack _markerName;
        };
        
        systemChat format ["Created HVT marker: %1 at position %2", _markerName, _pos];
    } forEach HVT_TARGETS;
};

// Initialize intel decay system
fnc_initIntelDecay = {
    // Start intel decay check loop
    [] spawn {
        while {true} do {
            // Check for intel decay
            call fnc_checkIntelDecay;
            
            // Wait for next check
            sleep HVT_DECAY_CHECK_INTERVAL;
        };
    };
};

// Check for intel decay
fnc_checkIntelDecay = {
    // Calculate time elapsed since last check
    private _currentTime = time;
    private _elapsedTime = _currentTime - HVT_lastDecayCheck;
    private _elapsedMinutes = _elapsedTime / 60;
    
    // Update last decay check time
    HVT_lastDecayCheck = _currentTime;
    
    // Skip if elapsed time is too small
    if (_elapsedMinutes < 0.5) exitWith {};
    
    // Calculate decay amount based on elapsed time
    private _decayAmount = _elapsedMinutes * HVT_INTEL_DECAY_RATE;
    
    // Apply decay to each HVT
    {
        private _hvtIndex = _forEachIndex;
        private _hvtData = _x;
        private _captured = _hvtData select 7;
        private _eliminated = _hvtData select 8;
        
        // Only decay intel for targets that are not captured or eliminated
        if (!_captured && !_eliminated) then {
            // Randomize decay based on chance
            if (random 100 < HVT_DECAY_CHANCE) then {
                // Apply intel decay
                [_hvtIndex, -_decayAmount] call fnc_modifyHVTIntel;
            };
        };
    } forEach HVT_TARGETS;
};

// Function to modify HVT intel level
fnc_modifyHVTIntel = {
    params ["_hvtIndex", "_deltaIntel"];
    
    // Ensure valid HVT index
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        diag_log format ["Invalid HVT index for intel modification: %1", _hvtIndex];
        false
    };
    
    private _hvtData = HVT_TARGETS select _hvtIndex;
    private _currentIntel = _hvtData select 4;
    
    // Calculate new intel value (clamped between 0-100)
    private _newIntel = (_currentIntel + _deltaIntel) min 100 max 0;
    
    // Store old intel level to check for threshold crossings
    private _oldIntelLevel = [_currentIntel] call fnc_getHVTIntelLevel;
    
    // Update intel
    _hvtData set [4, _newIntel];
    
    // Check if intel level changed
    private _newIntelLevel = [_newIntel] call fnc_getHVTIntelLevel;
    if (_oldIntelLevel != _newIntelLevel) then {
        // Intel level crossed a threshold, update marker
        [_hvtIndex] call fnc_forceSingleHVTRefresh;
        
        // Log the intel level change
        diag_log format ["HVT intel level changed for %1: %2 to %3", 
            _hvtData select 1, _oldIntelLevel, _newIntelLevel];
    };
    
    // If this was a significant intel gain, provide feedback
    if (_deltaIntel > 5) then {
        systemChat format ["Intelligence on %1 increased.", _hvtData select 1];
    };
    
    // If this was a significant intel loss, provide feedback
    if (_deltaIntel < -5) then {
        systemChat format ["Intelligence on %1 is becoming outdated.", _hvtData select 1];
    };
    
    true
};

// Function to get the briefing text based on intel level
fnc_getHVTBriefing = {
    params ["_hvtIndex"];
    
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        "Invalid target"
    };
    
    private _hvtData = HVT_TARGETS select _hvtIndex;
    _hvtData params ["_varName", "_displayName", "_type", "_pos", "_intel", "_tasks", "_briefings"];
    
    // Determine which briefing to use based on intel level
    private _briefingIndex = 0;
    
    if (_intel >= HVT_INTEL_COMPLETE) then {
        _briefingIndex = 2;
    } else {
        if (_intel >= HVT_INTEL_BASIC) then {
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

// Function to mark a HVT as captured
fnc_setCapturedHVT = {
    params ["_hvtIndex", "_isCaptured"];
    
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        diag_log format ["Invalid HVT index for capture state change: %1", _hvtIndex];
        false
    };
    
    // Update captured status
    (HVT_TARGETS select _hvtIndex) set [7, _isCaptured];
    
    // Update marker
    [_hvtIndex] call fnc_forceSingleHVTRefresh;
    
    // If captured, also disable the actual unit
    if (_isCaptured) then {
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
    };
    
    true
};

// Function to mark a HVT as eliminated
fnc_setEliminatedHVT = {
    params ["_hvtIndex"];
    
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        diag_log format ["Invalid HVT index for elimination: %1", _hvtIndex];
        false
    };
    
    // Update eliminated status
    (HVT_TARGETS select _hvtIndex) set [8, true];
    
    // Also set captured to false
    (HVT_TARGETS select _hvtIndex) set [7, false];
    
    // Update marker
    [_hvtIndex] call fnc_forceSingleHVTRefresh;
    
    true
};

// =====================================================================
// TASK INTEGRATION FUNCTIONS
// =====================================================================

// Create HVT task - similar to existing task system
fnc_createHVTTask = {
    params ["_hvtIndex", "_taskType", "_assignedUnits"];
    
    // Safety checks
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        diag_log format ["Invalid HVT index for task creation: %1", _hvtIndex];
        ""
    };
    
    private _hvtData = HVT_TARGETS select _hvtIndex;
    _hvtData params ["_varName", "_displayName", "_type", "_pos", "_intel", "_tasks"];
    
    // Find task name and rewards
    private _taskName = "";
    private _rewards = [];
    
    {
        if (_x select 0 == _taskType) exitWith {
            _taskName = _x select 1;
            _rewards = _x select 2;
        };
    } forEach _tasks;
    
    if (_taskName == "") exitWith {
        diag_log format ["Task type %1 not found for HVT %2", _taskType, _displayName];
        ""
    };
    
    // Get unit object
    private _unit = missionNamespace getVariable [_varName, objNull];
    if (isNull _unit) exitWith {
        diag_log format ["HVT unit %1 not found for task", _varName];
        ""
    };
    
    // Generate unique task ID
    private _taskId = format ["hvt_task_%1_%2_%3", _hvtIndex, _taskType, round(serverTime)];
    
    // Generate task description
    private _taskDescription = [
        format ["Operation %1: %2 - %3", 
            missionNamespace getVariable ["MISSION_operationName", "Unnamed"], 
            _taskName, 
            _displayName
        ],
        format ["Your orders: %1 the %2 %3.", toLower _taskName, _type, _displayName],
        format ["Op: %1 - %2", _taskName, _displayName]
    ];
    
    // Create the task - integrate with BIS task system
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
        diag_log "HVT task creation failed";
        ""
    };
    
    // Set as current task
    [_taskId] call BIS_fnc_taskSetCurrent;
    
    // Create visible marker for Zeus
    private _markerName = format ["zeus_hvt_marker_%1", _taskId];
    private _marker = createMarker [_markerName, _pos];
    _marker setMarkerType "mil_objective";
    _marker setMarkerColor "ColorBlue";
    _marker setMarkerText _taskName;
    
    // Add Zeus curator icon if z1 exists
    private _curatorModule = missionNamespace getVariable ["z1", objNull];
    private _taskIcon = "\A3\ui_f\data\map\markers\military\objective_ca.paa";
    
    // Select appropriate icon based on task type
    switch (_taskType) do {
        case "track": { _taskIcon = "\A3\ui_f\data\map\markers\military\recon_ca.paa"; };
        case "kill": { _taskIcon = "\A3\ui_f\data\map\markers\military\destroy_ca.paa"; };
        case "capture": { _taskIcon = "\A3\ui_f\data\map\markers\military\end_ca.paa"; };
        case "attack": { _taskIcon = "\A3\ui_f\data\map\markers\military\destroy_ca.paa"; };
        default { _taskIcon = "\A3\ui_f\data\map\markers\military\objective_ca.paa"; };
    };
    
    // Add curator icon if module exists
    private _iconID = -1;
    if (!isNull _curatorModule) then {
        private _iconText = format ["Op: %1 - %2", _taskName, _displayName];
        _iconID = [_curatorModule, _taskIcon, [0, 0.3, 0.6, 1], _pos, 1, 1, 0, _iconText, false] call BIS_fnc_addCuratorIcon;
    };
    
    // Store icon data for later removal
    private _iconData = [_curatorModule, _iconID];
    
    // Create HVT task object with necessary data
    private _taskObject = [
        _taskId,             // Task ID
        _hvtIndex,           // HVT index
        _taskType,           // Task type
        _assignedUnits,      // Assigned units
        serverTime,          // Creation time
        "CREATED",           // Status
        _unit,               // Target unit
        {},                  // Completion condition (will be set below)
        _markerName,         // Zeus marker name
        _iconData            // Zeus icon data
    ];
    
    // Create completion condition based on task type
    private _completionCode = {};
    
    switch (_taskType) do {
        case "track": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_hvtIndex", "_taskType", "_assignedUnits", "_startTime", "_status", "_targetUnit"];
                
                // Check if any assigned unit is near the target for long enough
                private _trackingTime = 120; // 2 minutes of tracking
                private _trackingRadius = 200; // 200m tracking radius
                
                // Get current position of target
                private _targetPos = getPos _targetUnit;
                
                // Check if any assigned unit is within range
                private _unitInRange = false;
                {
                    if (!isNull _x && {alive _x} && {_x distance _targetPos < _trackingRadius}) exitWith {
                        _unitInRange = true;
                    };
                } forEach _assignedUnits;
                
                if (_unitInRange) then {
                    // If unit is in range, give intel
                    [_hvtIndex, 5] call fnc_modifyHVTIntel;
                };
                
                // Task is complete when sufficient intel is gathered
                private _hvtData = HVT_TARGETS select _hvtIndex;
                private _intel = _hvtData select 4;
                
                _intel >= 100
            };
        };
        
        case "kill": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_hvtIndex", "_taskType", "_assignedUnits", "_startTime", "_status", "_targetUnit"];
                
                // Task is complete when target is dead
                !alive _targetUnit
            };
        };
        
        case "capture": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_hvtIndex", "_taskType", "_assignedUnits", "_startTime", "_status", "_targetUnit"];
                
                // Task is complete when target is neutralized and a friendly unit is close
                private _isCaptured = false;
                
                if (alive _targetUnit && {_targetUnit getVariable ["isSurrendered", false]}) then {
                    // Check if a friendly unit is close
                    private _friendlyNearby = false;
                    {
                        if (!isNull _x && {alive _x} && {_x distance _targetUnit < 10}) exitWith {
                            _friendlyNearby = true;
                        };
                    } forEach _assignedUnits;
                    
                    if (_friendlyNearby) then {
                        // Mark as captured
                        [_hvtIndex, true] call fnc_setCapturedHVT;
                        _isCaptured = true;
                    };
                };
                
                // Also consider a dead target a 'failed' capture
                if (!alive _targetUnit) then {
                    // Mark as eliminated
                    [_hvtIndex, true] call fnc_setEliminatedHVT;
                    _isCaptured = false;
                    
                    // Return false to signal failed task
                    false
                } else {
                    // Return capture status
                    _isCaptured
                };
            };
        };
        
        case "attack": {
            _completionCode = {
                params ["_taskObj"];
                _taskObj params ["_taskId", "_hvtIndex", "_taskType", "_assignedUnits", "_startTime", "_status", "_targetUnit"];
                
                // Task is complete when target is severely damaged or destroyed
                (!alive _targetUnit) || (damage _targetUnit > 0.75)
            };
        };
    };
    
    // Set the completion code
    _taskObject set [7, _completionCode];
    
    // Add task to active tasks
    HVT_activeTasks pushBack _taskObject;
    
    // Return the task ID
    _taskId
};

// Function to complete a HVT task
fnc_completeHVTTask = {
    params ["_taskId", "_success"];
    
    // Find task in active tasks
    private _taskIndex = HVT_activeTasks findIf {(_x select 0) == _taskId};
    if (_taskIndex == -1) exitWith {
        diag_log format ["HVT task not found: %1", _taskId];
        false
    };
    
    private _taskObj = HVT_activeTasks select _taskIndex;
    _taskObj params ["_taskId", "_hvtIndex", "_taskType", "_assignedUnits", "_startTime", "_status", "_targetUnit", "_completionCode", "_markerName", "_iconData"];
    
    // Get HVT data
    private _hvtData = HVT_TARGETS select _hvtIndex;
    private _displayName = _hvtData select 1;
    private _type = _hvtData select 2;
    private _tasks = _hvtData select 5;
    
    // Update task state
    private _state = if (_success) then {"SUCCEEDED"} else {"FAILED"};
    [_taskId, _state] call BIS_fnc_taskSetState;
    
    // If successful, give rewards
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
            
            // Use economy system to add resources
            if (!isNil "RTS_fnc_modifyResource") then {
                [_resourceType, _amount] call RTS_fnc_modifyResource;
                systemChat format ["Received %1 %2 for completing task.", _amount, _resourceType];
            };
        } forEach _rewards;
        
        // Update HVT status based on task type
        switch (_taskType) do {
            case "kill": {
                [_hvtIndex] call fnc_setEliminatedHVT;
                hint format ["Target eliminated: %1", _displayName];
                systemChat format ["%1 has been eliminated.", _displayName];
            };
            case "capture": {
                [_hvtIndex, true] call fnc_setCapturedHVT;
                hint format ["Target captured: %1", _displayName];
                systemChat format ["%1 has been captured and is awaiting interrogation.", _displayName];
            };
            case "attack": {
                [_hvtIndex] call fnc_setEliminatedHVT;
                hint format ["Target destroyed: %1", _displayName];
                systemChat format ["%1 has been destroyed.", _displayName];
            };
        };
    } else {
        // Failed task feedback
        hint format ["✗ Task Failed: %1 - %2", _taskType, _displayName];
        systemChat format ["The operation targeting %1 has failed!", _displayName];
    };
    
    // Clean up
    // Delete Zeus marker
    if (_markerName != "") then {
        if (markerType _markerName != "") then {
            deleteMarker _markerName;
        };
    };
    
    // Remove Zeus curator icon
    if (!isNil "_iconData" && {count _iconData >= 2}) then {
        _iconData params ["_curatorModule", "_iconID"];
        
        if (!isNull _curatorModule && _iconID != -1) then {
            [_curatorModule, _iconID] call BIS_fnc_removeCuratorIcon;
        };
    };
    
    // Delete the task
    [_taskId] call BIS_fnc_deleteTask;
    
    // Remove from active tasks
    HVT_activeTasks deleteAt _taskIndex;
    
    true
};

// Function to check HVT task completion
fnc_checkHVTTasksCompletion = {
    private _completedTasks = [];
    
    {
        private _taskObj = _x;
        private _taskId = _taskObj select 0;
        private _completionCode = _taskObj select 7;
        
        // Skip if missing critical information
        if (_taskId == "" || _completionCode isEqualTo {}) then {
            diag_log format ["Invalid HVT task data: %1", _taskObj];
            continue;
        };
        
        // Check if task is complete using its completion criteria
        private _isComplete = _taskObj call _completionCode;
        
        if (_isComplete) then {
            diag_log format ["HVT task %1 completion detected!", _taskId];
            _completedTasks pushBack [_taskId, true]; // Mark for success
        };
    } forEach HVT_activeTasks;
    
    // Process completed tasks
    {
        _x params ["_taskId", "_success"];
        [_taskId, _success] call fnc_completeHVTTask;
    } forEach _completedTasks;
};

// =====================================================================
// HELPER FUNCTIONS FOR EXTERNAL USE
// =====================================================================

// Add intel to HVT by index
fnc_addHVTIntelByIndex = {
    params ["_hvtIndex", "_amount"];
    [_hvtIndex, _amount] call fnc_modifyHVTIntel;
};

// Add intel to HVT by variable name
fnc_addHVTIntelByName = {
    params ["_varName", "_amount"];
    
    private _hvtIndex = HVT_TARGETS findIf {(_x select 0) == _varName};
    
    if (_hvtIndex != -1) then {
        [_hvtIndex, _amount] call fnc_modifyHVTIntel;
        true
    } else {
        diag_log format ["HVT target not found with name: %1", _varName];
        false
    };
};

// =====================================================================
// INITIALIZATION - CALL THIS TO START THE SYSTEM
// =====================================================================

// Visual feedback on HVT availability
if (count HVT_TARGETS > 0) then {
    {
        private _varName = _x select 0;
        private _displayName = _x select 1;
        private _unit = missionNamespace getVariable [_varName, objNull];
        
        if (!isNull _unit) then {
            systemChat format ["Found HVT: %1 (%2)", _displayName, _varName];
        } else {
            systemChat format ["Warning: HVT not found in mission: %1 (%2)", _displayName, _varName];
        };
    } forEach HVT_TARGETS;
} else {
    systemChat "Warning: No HVT targets defined!";
};

// Start the system with a slight delay to ensure initialization
[] spawn {
    sleep 2; // Give the mission time to fully initialize
    systemChat "Starting HVT System...";
    [] call fnc_initHVTSystem;
    systemChat "HVT System is now active!";
    
    // Start task checking loop
    [] spawn {
        while {true} do {
            call fnc_checkHVTTasksCompletion;
            sleep 5;
        };
    };
    
    // Force a refresh of specific units to ensure proper markers
    sleep 5;
    ["hvt_1"] call fnc_forceSingleHVTRefresh;
    ["bismark"] call fnc_forceSingleHVTRefresh;
};