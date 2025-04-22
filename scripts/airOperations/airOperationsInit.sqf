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
    ["Recon", ["recon", "patrol", "cas", "bombing"]],                             // Recon aircraft capabilities
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

// === ZEUS 3D MARKERS SYSTEM ===
// Initializes dynamic 3D markers visible in Zeus

if (hasInterface) then {
    [] spawn {
        // Initialize array for storing mission marker data
        if (isNil "AIR_OP_3D_MARKERS") then { AIR_OP_3D_MARKERS = []; };
        
        // === GAMEPLAY VARIABLES - ADJUST MARKER APPEARANCE HERE ===
        AIR_OP_MARKER_SIZE = 1.2;           // Size multiplier for markers
        AIR_OP_MARKER_ALPHA = 0.8;          // Opacity of markers
        AIR_OP_MARKER_PULSE_SPEED = 0.5;    // Speed of size pulsing (higher = faster)
        AIR_OP_LABEL_SIZE = 0.03;           // Size of label text
        AIR_OP_MARKER_MAX_DIST = 5000;      // Maximum distance to show markers
        
        // Add draw3D event handler - continuously runs while game is active
        addMissionEventHandler ["Draw3D", {
            // Only continue if in Zeus interface
            if (isNull findDisplay 312) exitWith {};
            
            // Exit if no markers
            if (count AIR_OP_3D_MARKERS == 0) exitWith {};
            
            // Get current camera position for distance calculations
            private _camPos = getPosVisual curatorCamera;
            
            // Calculate pulsing size factor based on time
            private _pulseFactor = 1 + 0.2 * sin(time * 360 * AIR_OP_MARKER_PULSE_SPEED); 
            
            // Process each marker
            {
                _x params ["_position", "_missionType", "_label", "_activeStatus", "_markerColor"];
                
                // Calculate distance to camera
                private _distance = _position distance _camPos;
                
                // Only draw if within range
                if (_distance < AIR_OP_MARKER_MAX_DIST) then {
                    // Get icon based on mission type
                    private _icon = switch (_missionType) do {
                        case "recon": {"\A3\ui_f\data\map\markers\military\recon_ca.paa"};
                        case "patrol": {"\A3\ui_f\data\map\markers\military\circle_ca.paa"};
                        case "cas": {"\A3\ui_f\data\map\markers\military\destroy_ca.paa"};
                        case "bombing": {"\A3\ui_f\data\map\markers\military\end_ca.paa"};
                        case "airsup": {"\A3\ui_f\data\map\markers\military\warning_ca.paa"};
                        default {"\A3\ui_f\data\map\markers\military\dot_ca.paa"};
                    };
                    
                    // Apply active/inactive appearance
                    private _alpha = if (_activeStatus) then {AIR_OP_MARKER_ALPHA} else {AIR_OP_MARKER_ALPHA * 0.5};
                    private _size = if (_activeStatus) then {AIR_OP_MARKER_SIZE * _pulseFactor} else {AIR_OP_MARKER_SIZE * 0.8};
                    
                    // Draw the icon
                    drawIcon3D [
                        _icon,
                        _markerColor,
                        _position,
                        _size,
                        _size,
                        0,
                        _label,
                        1,
                        AIR_OP_LABEL_SIZE,
                        "PuristaMedium",
                        "center"
                    ];
                };
            } forEach AIR_OP_3D_MARKERS;
        }];
        
        // Wait until all systems are initialized
        waitUntil {!isNil "AIR_OP_activeMissions"};
        
        // Start the marker update loop
        [] spawn {
            while {true} do {
                // Clear the markers array
                AIR_OP_3D_MARKERS = [];
                
                // Add markers for active missions
                {
                    _x params ["_missionID", "_aircraft", "_missionType", "_targetIndex", "_targetType"];
                    
                    // Get target position
                    private _targetPos = [0,0,0];
                    private _targetName = "Unknown";
                    
                    if (_targetType == "LOCATION") then {
                        if (_targetIndex >= 0 && _targetIndex < count MISSION_LOCATIONS) then {
                            _targetPos = (MISSION_LOCATIONS select _targetIndex) select 3;
                            _targetName = (MISSION_LOCATIONS select _targetIndex) select 1;
                        };
                    } else {
                        if (_targetIndex >= 0 && _targetIndex < count HVT_TARGETS) then {
                            _targetPos = (HVT_TARGETS select _targetIndex) select 3;
                            _targetName = (HVT_TARGETS select _targetIndex) select 1;
                        };
                    };
                    
                    // Determine color based on mission type
                    private _markerColor = switch (_missionType) do {
                        case "recon": {[0.2, 0.2, 1, 1]};       // Blue
                        case "patrol": {[0.2, 0.6, 1, 1]};      // Light blue
                        case "cas": {[1, 0.2, 0.2, 1]};         // Red
                        case "bombing": {[1, 0.4, 0, 1]};       // Orange
                        case "airsup": {[0, 0.8, 0.8, 1]};      // Teal
                        default {[1, 1, 1, 1]};                 // White
                    };
                    
                    // Create the label
                    private _label = format ["%1: %2", toUpper _missionType, _targetName];
                    
                    // Get status of aircraft
                    private _isActive = !isNull _aircraft;
                    
                    // Add to markers array
                    AIR_OP_3D_MARKERS pushBack [_targetPos, _missionType, _label, _isActive, _markerColor];
                } forEach AIR_OP_activeMissions;
                
                // Update every 2 seconds
                sleep 2;
            };
        };
        
        diag_log "AIR_OPS: 3D Zeus markers system initialized";
    };
};

// Initialize mission execution checking
[] spawn {
    // Wait for all systems to be loaded
    waitUntil {!isNil "AIR_OP_fnc_executeMission"};
    waitUntil {!isNil "AIR_OP_activeMissions"};
    
    // Start mission effect loop
    while {true} do {
        // Process each active mission
        {
            _x params ["_missionID", "_aircraft", "_missionType", "_targetIndex", "_targetType"];
            
            // Skip invalid missions
            if (isNull _aircraft) then {
                continue;
            };
            
            // Execute mission effects - use try-catch for safety
            try {
                [_missionType, _aircraft, _targetIndex, _targetType] call AIR_OP_fnc_executeMission;
            } catch {
                diag_log format ["AIR_OPS: Error executing mission effects: %1", _exception];
            };
        } forEach AIR_OP_activeMissions;
        
        // Run every 2 seconds
        sleep 2;
    };
};

// Initialize help system for new air operations
AIR_OP_help = {
    // Create help message
    private _helpText = "
<t size='1.5' align='center' color='#88AAFF'>Air Operations Guide</t><br/><br/>
<t size='1.2' color='#AAFFAA'>Mission Types:</t><br/>
<t color='#AAFFAA'>Reconnaissance:</t> Aircraft gathers intel on target area<br/>
<t color='#AAFFAA'>Combat Air Patrol:</t> Aircraft patrols area and engages hostiles<br/>
<t color='#AAFFAA'>Close Air Support:</t> Aircraft provides fire support for ground forces<br/>
<t color='#AAFFAA'>Bombing Run:</t> Aircraft strikes specific target<br/>
<t color='#AAFFAA'>Air Superiority:</t> Aircraft engages enemy aircraft in area<br/><br/>

<t size='1.2' color='#AAFFAA'>Using the Interface:</t><br/>
1. Select an aircraft from the dropdown<br/>
2. Select a target location on the map<br/>
3. Choose a mission type from available options<br/>
4. Click 'Confirm Mission' to issue orders<br/><br/>

<t size='1.2' color='#AAFFAA'>Aircraft Controls:</t><br/>
<t color='#AAFFAA'>Return To Base:</t> Orders aircraft back to base<br/>
<t color='#AAFFAA'>Set Altitude:</t> Adjusts aircraft flying height<br/>
<t color='#AAFFAA'>Set Speed:</t> Controls aircraft velocity<br/>
<t color='#AAFFAA'>Combat Mode:</t> Sets aircraft engagement rules<br/><br/>

<t size='1.2' color='#AAFFAA'>Mission Management:</t><br/>
<t color='#AAFFAA'>Cancel Mission:</t> Aborts current mission<br/>
<t color='#AAFFAA'>Close:</t> Exits the Air Operations interface<br/>
";

    // Display help
    hint parseText _helpText;
};

// Add help button to UI
AIR_OP_fnc_addHelpButton = {
    params ["_display"];
    
    if (isNull _display) exitWith {};
    
    // Create help button
    private _helpButton = _display ctrlCreate ["RscButton", 9503];
    _helpButton ctrlSetPosition [0.68 * safezoneW + safezoneX, 0.70 * safezoneH + safezoneY, 0.07 * safezoneW, 0.04 * safezoneH];
    _helpButton ctrlSetText "Help";
    _helpButton ctrlSetBackgroundColor [0.2, 0.5, 0.7, 1]; // Blue
    _helpButton ctrlSetEventHandler ["ButtonClick", "[] call AIR_OP_help"];
    _helpButton ctrlCommit 0;
};