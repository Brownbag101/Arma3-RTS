// Virtual Hangar System - Initialization
// Initializes the Virtual Hangar system for aircraft management

// === AIRCRAFT CONFIGURATION ===
// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE AVAILABLE AIRCRAFT ===
HANGAR_aircraftTypes = [
    ["Transport", [
        ["LIB_C47_RAF", "C-47 Dakota", 1] // [classname, display name, required crew]
    ]],
    ["Fighters", [
        ["sab_fl_spitfire_mk1", "Spitfire Mk.I", 1],
        ["sab_fl_spitfire_mk1", "Spitfire Mk.I", 1],
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

// === PILOT RANKS CONFIGURATION ===
// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE RANK PROGRESSIONS ===
HANGAR_pilotRanks = [
    ["Pilot Officer", 0, 1.0],     // [rank name, min missions, skill multiplier]
    ["Flying Officer", 5, 1.1],     
    ["Flight Lieutenant", 10, 1.2], 
    ["Squadron Leader", 20, 1.3],   
    ["Wing Commander", 35, 1.4],    
    ["Group Captain", 50, 1.5]      
];

// === HANGAR CONFIGURATION ===
// Use markers for spawning positions
HANGAR_planeSpawnMarker = "plane_spawn";  // Marker for plane viewing position
HANGAR_pilotSpawnMarker = "pilot_spawn";  // Marker for pilot spawn position

// Debug marker existence
if (markerType HANGAR_planeSpawnMarker == "") then {
    diag_log "INIT: WARNING: plane_spawn marker not found!";
    systemChat "WARNING: plane_spawn marker not found - using default position";
} else {
    diag_log format ["INIT: plane_spawn marker found at position: %1", getMarkerPos HANGAR_planeSpawnMarker];
};

if (markerType HANGAR_pilotSpawnMarker == "") then {
    diag_log "INIT: WARNING: pilot_spawn marker not found!";
    systemChat "WARNING: pilot_spawn marker not found - using default position";
} else {
    diag_log format ["INIT: pilot_spawn marker found at position: %1", getMarkerPos HANGAR_pilotSpawnMarker];
};

// Calculate position and direction from markers
HANGAR_viewPosition = if (markerType HANGAR_planeSpawnMarker != "") then {
    getMarkerPos HANGAR_planeSpawnMarker
} else {
    diag_log "INIT: Using fallback position for aircraft viewing";
    [724.771, 12191.8, 0]  // Fallback position
};

HANGAR_viewDirection = if (markerType HANGAR_planeSpawnMarker != "") then {
    markerDir HANGAR_planeSpawnMarker
} else {
    diag_log "INIT: Using fallback direction for aircraft viewing";
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
    diag_log "INIT: Using fallback pilot spawn near aircraft";
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

// Check deploy markers
{
    if (markerType _x == "") then {
        diag_log format ["INIT: WARNING: %1 marker not found!", _x];
        systemChat format ["WARNING: %1 marker not found - aircraft deployment may not work correctly", _x];
    } else {
        diag_log format ["INIT: Deploy marker %1 found at position: %2", _x, getMarkerPos _x];
    };
} forEach HANGAR_deployPositions;

// Initialize global variables
if (isNil "HANGAR_storedAircraft") then { 
    HANGAR_storedAircraft = []; 
    diag_log "INIT: Created HANGAR_storedAircraft array";
};

if (isNil "HANGAR_viewedAircraft") then { 
    HANGAR_viewedAircraft = objNull; 
    diag_log "INIT: Created HANGAR_viewedAircraft reference";
};

if (isNil "HANGAR_viewedAircraftArray") then { 
    HANGAR_viewedAircraftArray = []; 
    diag_log "INIT: Created HANGAR_viewedAircraftArray";
};

if (isNil "HANGAR_selectedCategory") then { 
    HANGAR_selectedCategory = ""; 
    diag_log "INIT: Created HANGAR_selectedCategory";
};

if (isNil "HANGAR_deployedAircraft") then { 
    HANGAR_deployedAircraft = [];
    diag_log "INIT: Created HANGAR_deployedAircraft array";
};

if (isNil "HANGAR_pilotRoster") then {
    HANGAR_pilotRoster = []; 
    diag_log "INIT: Created HANGAR_pilotRoster array";
};

// Create proper camera focus function if not already defined
if (isNil "fnc_focusCameraOnAirfield") then {
    fnc_focusCameraOnAirfield = {
        // Move camera to the predefined camera position
        if (!isNull curatorCamera) then {
            private _camPos = HANGAR_cameraPosition;
            private _targetPos = HANGAR_viewPosition;
            
            curatorCamera setPosASL [_camPos select 0, _camPos select 1, _camPos select 2];
            curatorCamera setDir HANGAR_viewDirection;
            
            diag_log format ["CAMERA: Moved camera to %1 looking at %2", _camPos, _targetPos];
        } else {
            diag_log "CAMERA: No curator camera found";
        };
    };
    
    diag_log "INIT: Created focusCameraOnAirfield function";
};

// Debug the position calculations
diag_log format ["INIT: Final configuration - View position: %1, Direction: %2, Camera: %3", 
    HANGAR_viewPosition, HANGAR_viewDirection, HANGAR_cameraPosition];

// Load all required modules
[] execVM "scripts\virtualHangar\hangarSystem.sqf";
[] execVM "scripts\virtualHangar\pilotSystem.sqf";
[] execVM "scripts\virtualHangar\hangarUI.sqf";

diag_log "INIT: Loaded all Virtual Hangar modules";

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
                diag_log "INIT: Added Virtual Hangar button to menu";
                systemChat "Virtual Hangar button added to menu";
            };
        } forEach RTS_menuButtons;
    };
};

// Start monitoring deployed aircraft
[] spawn {
    diag_log "INIT: Starting aircraft deployment monitoring...";
    
    // Initial cleanup of view models
    sleep 5;
    private _cleaned = [] call HANGAR_fnc_cleanupViewModels;
    if (_cleaned > 0) then {
        diag_log format ["INIT: Cleaned up %1 stray aircraft models at startup", _cleaned];
    };
    
    // Wait for hangarSystem.sqf to fully load
    waitUntil {!isNil "HANGAR_fnc_monitorDeployedAircraft"};
    
    // Start the monitoring loop
    while {true} do {
        call HANGAR_fnc_monitorDeployedAircraft;
        sleep 30;
    };
};

// Log completion of initialization
systemChat "Virtual Hangar system initialized";
diag_log "INIT: Virtual Hangar system initialization complete";