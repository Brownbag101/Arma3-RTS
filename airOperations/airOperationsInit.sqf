// Air Operations System Initialization
// Initializes the Air Operations planning and control system

// === MISSION TYPES CONFIGURATION ===
// === GAMEPLAY VARIABLES - ADJUST MISSION TYPES HERE ===
AIR_OP_MISSION_TYPES = [
    ["recon", "Reconnaissance", "Gather intelligence on target area", 25],     // [id, display name, description, min intel required]
    ["patrol", "Combat Air Patrol", "Patrol and engage hostiles in area", 50],
    ["cas", "Close Air Support", "Provide fire support for ground forces", 75],
    ["bombing", "Bombing Run", "Strike specific target", 75],
    ["airsup", "Air Superiority", "Engage enemy aircraft in area", 50]
];

// === AIRCRAFT TYPE CAPABILITIES ===
// === GAMEPLAY VARIABLES - DEFINE WHAT EACH AIRCRAFT TYPE CAN DO ===
AIR_OP_CAPABILITIES = [
    ["Fighters", ["recon", "patrol", "cas", "airsup"]],         // Fighter aircraft capabilities
    ["Bombers", ["recon", "bombing"]],                          // Bomber aircraft capabilities
    ["Recon", ["recon", "patrol"]],                             // Recon aircraft capabilities
    ["Transport", ["recon"]]                                    // Transport aircraft capabilities
];

// === WAYPOINT PARAMETERS ===
// === GAMEPLAY VARIABLES - MISSION PARAMETERS ===
AIR_OP_WAYPOINT_PARAMS = [
    // [mission type, waypoint type, radius, altitude, speed, behavior, combat mode, loiter type, statements]
    ["recon", "MOVE", 500, 400, "NORMAL", "AWARE", "YELLOW", "", 
        ["true", "systemChat 'Reconnaissance waypoint reached'"]],
    ["patrol", "LOITER", 800, 350, "NORMAL", "COMBAT", "YELLOW", "CIRCLE_L", 
        ["true", "systemChat 'Patrol waypoint reached'"]],
    ["cas", "SAD", 300, 200, "NORMAL", "COMBAT", "RED", "", 
        ["true", "systemChat 'CAS mission assigned'"]],
    ["bombing", "DESTROY", 400, 300, "NORMAL", "COMBAT", "RED", "", 
        ["true", "systemChat 'Bombing run initiated'"]],
    ["airsup", "SAD", 1000, 500, "FULL", "COMBAT", "RED", "", 
        ["true", "systemChat 'Air superiority mission active'"]]
];

// === GLOBAL VARIABLES INITIALIZATION ===
if (isNil "AIR_OP_activeMissions") then { AIR_OP_activeMissions = []; };
if (isNil "AIR_OP_selectedAircraft") then { AIR_OP_selectedAircraft = objNull; };
if (isNil "AIR_OP_selectedTarget") then { AIR_OP_selectedTarget = -1; };
if (isNil "AIR_OP_selectedTargetType") then { AIR_OP_selectedTargetType = "LOCATION"; };
if (isNil "AIR_OP_selectedMission") then { AIR_OP_selectedMission = ""; };
if (isNil "AIR_OP_operationName") then { AIR_OP_operationName = "Overlord"; };
if (isNil "AIR_OP_uiOpen") then { AIR_OP_uiOpen = false; };

// === MISSION TRACKING ARRAY ===
// Format: [missionID, aircraft, missionType, targetIndex, targetType, waypoint, startTime, completionCode]

// === LOAD REQUIRED FILES ===
if (hasInterface) then {
    // Load main system first
    [] execVM "scripts\airOperations\airOperationsSystem.sqf";
    
    // Wait for system to initialize
    waitUntil {!isNil "AIR_OP_fnc_createMission"};
    
    // Then load UI and tasks
    [] execVM "scripts\airOperations\airOperationsUI.sqf";
    [] execVM "scripts\airOperations\airOperationsTasks.sqf";
    
    // Load control functions
    [] execVM "scripts\airOperations\controls\returnToBase.sqf";
    [] execVM "scripts\airOperations\controls\setAltitude.sqf";
    [] execVM "scripts\airOperations\controls\setSpeed.sqf";
    [] execVM "scripts\airOperations\controls\setCombatMode.sqf";
    
    // Add to menu system if it exists
    if (!isNil "RTS_menuButtons") then {
        {
            if (_x select 0 == "placeholder2") exitWith {
                RTS_menuButtons set [_forEachIndex, ["airops", "a3\ui_f\data\igui\cfg\simpletasks\types\plane_ca.paa", "Air Operations", "Manage air missions and aircraft"]];
                systemChat "Air Operations added to menu system";
            };
        } forEach RTS_menuButtons;
    };
    
    // Initialize mission monitoring loop
    [] spawn {
        while {true} do {
            [] call AIR_OP_fnc_checkMissions;
            sleep 5;
        };
    };
    
    systemChat "Air Operations System initialized";
};