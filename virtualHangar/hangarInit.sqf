// Virtual Hangar System - Initialization - COMPLETE REWRITE
// Initializes the Virtual Hangar system for aircraft management

// === AIRCRAFT CONFIGURATION ===
// Aircraft categories and types - ADJUST THESE VALUES TO CHANGE AVAILABLE AIRCRAFT
HANGAR_aircraftTypes = [
    ["Transport", [
        ["LIB_C47_RAF", "C-47 Dakota", 1] // [classname, display name, required crew]
    ]],
    ["Fighters", [
        ["sab_fl_spitfire_mk1", "Spitfire Mk.I", 1],
        ["sab_fl_spitfire_mk9", "Spitfire Mk.IX", 1]
    ]],
    ["Recon", [
        ["sab_fl_dh98", "Mosquito", 2]
    ]],
    ["Bombers", [
        ["sab_sw_halifax", "Halifax", 5]
    ]]
];

// === HANGAR CONFIGURATION ===
// Use markers for spawning positions
HANGAR_planeSpawnMarker = "plane_spawn";  // Marker for plane viewing position
HANGAR_pilotSpawnMarker = "pilot_spawn";  // Marker for pilot spawn position

// Debug marker existence
if (markerType HANGAR_planeSpawnMarker == "") then {
    diag_log "WARNING: plane_spawn marker not found!";
    systemChat "WARNING: plane_spawn marker not found - using default position";
} else {
    diag_log format ["plane_spawn marker found at position: %1", getMarkerPos HANGAR_planeSpawnMarker];
};

if (markerType HANGAR_pilotSpawnMarker == "") then {
    diag_log "WARNING: pilot_spawn marker not found!";
    systemChat "WARNING: pilot_spawn marker not found - using default position";
} else {
    diag_log format ["pilot_spawn marker found at position: %1", getMarkerPos HANGAR_pilotSpawnMarker];
};

// Calculate position and direction from markers
HANGAR_viewPosition = if (markerType HANGAR_planeSpawnMarker != "") then {
    getMarkerPos HANGAR_planeSpawnMarker
} else {
    systemChat "WARNING: plane_spawn marker not found!";
    [724.771, 12191.8, 0]  // Fallback position
};

HANGAR_viewDirection = if (markerType HANGAR_planeSpawnMarker != "") then {
    markerDir HANGAR_planeSpawnMarker
} else {
    180  // Fallback direction
};

// Force the pilot spawn position to be a safe location if it exists
HANGAR_pilotSpawnPosition = if (markerType HANGAR_pilotSpawnMarker != "") then {
    private _pos = getMarkerPos HANGAR_pilotSpawnMarker;
    // Make sure the Z coordinate is correct
    _pos set [2, 0];
    _pos
} else {
    // Fallback - use a position near the plane spawn that's definitely safe
    private _fallbackPos = HANGAR_viewPosition vectorAdd [10, 10, 0];
    _fallbackPos set [2, 0];
    systemChat "WARNING: pilot_spawn marker not found - using position near aircraft";
    _fallbackPos
};

// Calculate camera position to be above and behind the plane spawn
private _cameraOffset = [
    -15 * sin(HANGAR_viewDirection),  // X offset (behind)
    -15 * cos(HANGAR_viewDirection),  // Y offset (behind)
    25                                // Z offset (above)
];

HANGAR_cameraPosition = HANGAR_viewPosition vectorAdd _cameraOffset;

// Camera target should be the plane position plus a bit forward
private _targetOffset = [
    50 * sin(HANGAR_viewDirection),  // X offset (forward)
    50 * cos(HANGAR_viewDirection),  // Y offset (forward)
    0                                 // Same height
];

HANGAR_cameraTarget = HANGAR_viewPosition vectorAdd _targetOffset;

// Aircraft deploy positions (markers where aircraft will be moved when deployed)
HANGAR_deployPositions = [
    "hangar_deploy_1",
    "hangar_deploy_2",
    "hangar_deploy_3",
    "hangar_deploy_4",
    "hangar_deploy_5"
];

// Check deploy markers too
{
    if (markerType _x == "") then {
        diag_log format ["WARNING: %1 marker not found!", _x];
        systemChat format ["WARNING: %1 marker not found!", _x];
    } else {
        diag_log format ["Deploy marker %1 found at position: %2", _x, getMarkerPos _x];
    };
} forEach HANGAR_deployPositions;

// Debug the position calculations
diag_log format ["Final pilot spawn position: %1", HANGAR_pilotSpawnPosition];
diag_log format ["Final plane view position: %1", HANGAR_viewPosition];

// === GLOBAL VARIABLES ===
if (isNil "HANGAR_storedAircraft") then { HANGAR_storedAircraft = []; };
if (isNil "HANGAR_viewedAircraft") then { HANGAR_viewedAircraft = objNull; };
if (isNil "HANGAR_selectedCategory") then { HANGAR_selectedCategory = ""; };
if (isNil "HANGAR_uiControls") then { HANGAR_uiControls = []; };
if (isNil "HANGAR_pilotRunning") then { HANGAR_pilotRunning = false; };

// === PILOT CONFIGURATION ===
// Experience levels for pilots
HANGAR_pilotRanks = [
    ["Pilot Officer", 0, 1.0],     // [rank name, min missions, skill multiplier]
    ["Flying Officer", 5, 1.1],     
    ["Flight Lieutenant", 10, 1.2], 
    ["Squadron Leader", 20, 1.3],   
    ["Wing Commander", 35, 1.4],    
    ["Group Captain", 50, 1.5]      
];

// Initialize pilot roster if not exists
if (isNil "HANGAR_pilotRoster") then {
    HANGAR_pilotRoster = []; // Empty roster - pilots will be added as needed
};

// Log initialized positions
diag_log format ["Virtual Hangar initialized with: Plane position: %1, Pilot position: %2, Camera position: %3", 
    HANGAR_viewPosition, HANGAR_pilotSpawnPosition, HANGAR_cameraPosition];

// Load all required modules
[] execVM "scripts\virtualHangar\hangarSystem.sqf";
[] execVM "scripts\virtualHangar\pilotSystem.sqf";
[] execVM "scripts\virtualHangar\hangarUI.sqf";

// Debug function to test pilot creation - FIXED VERSION
HANGAR_fnc_testCreatePilot = {
    diag_log "TESTING PILOT CREATION - FIXED VERSION...";
    
    // Create a simple test pilot data entry
    if (count HANGAR_pilotRoster == 0) then {
        HANGAR_pilotRoster pushBack [
            "Test Pilot",     // Name
            0,                // Rank
            0,                // Missions
            0,                // Kills
            "Fighters",       // Specialization
            objNull           // Aircraft assignment
        ];
        diag_log "Added test pilot to roster";
    };
    
    // Log pilot spawn position
    diag_log format ["Pilot spawn position: %1", HANGAR_pilotSpawnPosition];
    
    // Verify class existence first
    if (!isClass (configFile >> "CfgVehicles" >> "sab_fl_pilot_green")) then {
        systemChat "WARNING: sab_fl_pilot_green class not found in game configuration!";
        diag_log "CRITICAL: sab_fl_pilot_green class does not exist - check addon dependencies";
        
        // Try with a fallback class that definitely exists
        systemChat "Trying with fallback class 'B_Pilot_F'";
        
        private _side = side player;
        private _group = createGroup [_side, true];
        private _unit = _group createUnit ["B_Pilot_F", HANGAR_pilotSpawnPosition, [], 0, "NONE"];
        
        if (!isNull _unit) then {
            _unit setName "TEST PILOT (FALLBACK)";
            systemChat "Test pilot created with fallback class!";
            diag_log format ["Test pilot created with fallback class at position: %1", getPos _unit];
            
            // Delete after 10 seconds
            [_unit] spawn {
                params ["_unit"];
                sleep 10;
                if (!isNull _unit) then {
                    deleteVehicle _unit;
                    systemChat "Test pilot removed";
                };
            };
        } else {
            systemChat "FAILED to create even fallback pilot!";
            diag_log "CRITICAL FAILURE: Cannot create ANY pilot units - game environment issue";
        };
    } else {
        // Class exists, so try to create it
        private _side = side player;
        private _group = createGroup [_side, true];
        private _unit = objNull;
        
        // Try to create unit with more protection against deletion
        if (isServer) then {
            _unit = _group createUnit ["sab_fl_pilot_green", HANGAR_pilotSpawnPosition, [], 0, "CAN_COLLIDE"];
        } else {
            [_group, "sab_fl_pilot_green", HANGAR_pilotSpawnPosition, [], 0, "CAN_COLLIDE"] remoteExec ["bis_fnc_spawnUnit", 2];
            sleep 1;
            
            // Find the newly created unit
            {
                if (_x getVariable ["HANGAR_isTestPilot", false]) exitWith {
                    _unit = _x;
                };
            } forEach (nearestObjects [HANGAR_pilotSpawnPosition, ["Man"], 50]);
        };
        
        if (!isNull _unit) then {
            _unit setName "TEST PILOT";
            _unit setVariable ["HANGAR_isTestPilot", true, true];
            _unit allowDamage false;
            _unit setCaptive true;
            
            // Add protection against cleanup/deletion
            _unit setVariable ["BIS_enableRandomization", false, true];
            _unit setVariable ["acex_headless_blacklist", true, true];
            
            systemChat "Test pilot created successfully!";
            diag_log format ["Test pilot created at position: %1", getPos _unit];
            
            // Delete after 10 seconds
            [_unit] spawn {
                params ["_unit"];
                sleep 10;
                if (!isNull _unit) then {
                    deleteVehicle _unit;
                    systemChat "Test pilot removed";
                } else {
                    systemChat "Test pilot was already deleted by something!";
                    diag_log "WARNING: Test pilot was deleted before cleanup time!";
                };
            };
        } else {
            systemChat "FAILED to create test pilot!";
            diag_log "Failed to create test pilot unit - but class exists!";
        };
    };
};

// Add to menu system if not already integrated
if (!isNil "RTS_menuButtons") then {
    // Check if virtual hangar button already exists
    private _exists = false;
    {
        if (_x select 0 == "hangar") then {
            _exists = true;
        };
    } forEach RTS_menuButtons;
    
    // If not exists, add it by replacing placeholder1
    if (!_exists) then {
        {
            if (_x select 0 == "placeholder1") exitWith {
                RTS_menuButtons set [_forEachIndex, ["hangar", "a3\ui_f\data\igui\cfg\simpletasks\types\plane_ca.paa", "Virtual Hangar", "Manage aircraft and pilots"]];
                systemChat "Virtual Hangar button added to menu";
            };
        } forEach RTS_menuButtons;
    };
};

// Test function available but not automatically called
systemChat "Virtual Hangar system initialized - test function available";
diag_log "Virtual Hangar initialized - call HANGAR_fnc_testCreatePilot manually if testing is needed";