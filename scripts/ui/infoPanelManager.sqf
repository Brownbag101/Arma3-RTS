// Info Panel Manager
// Handles creation and updating of unit info panels

// Initialize array to store info controls
if (isNil "RTSUI_infoControls") then { RTSUI_infoControls = []; };

// Info panel types and their script paths
RTSUI_infoPanelTypes = [
    // Unit info panels
    ["name", "scripts\ui\infoPanels\nameInfo.sqf"],
    ["rank", "scripts\ui\infoPanels\rankInfo.sqf"],
    ["health", "scripts\ui\infoPanels\healthInfo.sqf"],
    ["fatigue", "scripts\ui\infoPanels\fatigueInfo.sqf"],
    ["weapon", "scripts\ui\infoPanels\weaponInfo.sqf"],
    ["ammo", "scripts\ui\infoPanels\ammoInfo.sqf"],
    ["stance", "scripts\ui\infoPanels\stanceInfo.sqf"],
    
    // Squad info panels
    ["squad", "scripts\ui\infoPanels\squadInfo.sqf"],
    ["groupStatus", "scripts\ui\infoPanels\groupStatusInfo.sqf"],
    ["squadTask", "scripts\ui\infoPanels\squadTaskInfo.sqf"], // New squad task panel
    
    // Vehicle info panels
    ["vehicleType", "scripts\ui\infoPanels\vehicleNameInfo.sqf"],
    ["vehicleHealth", "scripts\ui\infoPanels\vehicleHealthInfo.sqf"],
    ["vehicleFuel", "scripts\ui\infoPanels\vehicleFuelInfo.sqf"],
    ["vehicleAmmo", "scripts\ui\infoPanels\vehicleAmmoInfo.sqf"],
    ["vehicleWeapon", "scripts\ui\infoPanels\vehicleWeaponInfo.sqf"],
    ["vehicleCargoInfo", "scripts\ui\infoPanels\vehicleCargoInfo.sqf"]
];

// Entity type-specific info panels
RTSUI_unitInfoPanels = ["name", "rank", "health", "ammo", "weapon", "weaponsList", "fatigue", "stance"];
RTSUI_vehicleInfoPanels = ["vehicleType", "vehicleHealth", "vehicleFuel", "vehicleAmmo", "vehicleWeapon", "vehicleCargoInfo"];
RTSUI_squadInfoPanels = ["groupStatus", "squadTask", "squad"]; // Updated to include the task panel
RTSUI_defaultInfoPanels = ["name", "health"];


// Clear all info panels
fnc_clearInfoPanels = {
    {
        _x ctrlShow false;
        _x ctrlSetText "";
    } forEach RTSUI_infoControls;
};

// Create info panels - Fixed version that ensures array is initialized
fnc_createInfoPanels = {
    params ["_display"];
    
    systemChat "Creating info panels...";
    
    // Initialize array if it doesn't exist
    if (isNil "RTSUI_infoControls") then {
        RTSUI_infoControls = [];
        systemChat "Initialized RTSUI_infoControls array";
    };
    
    // Clear existing panels
    {
        ctrlDelete _x;
    } forEach RTSUI_infoControls;
    
    // Reset array
    RTSUI_infoControls = [];
    
    // Create text controls for each info type
    {
        _x params ["_infoType", "_scriptPath"];
        
        systemChat format ["Creating panel: %1", _infoType];
        
        private _ctrl = _display ctrlCreate ["RscText", -1];
        _ctrl ctrlSetPosition [
            safezoneX + 0.01,
            safezoneY + safezoneH - 0.29 + (_forEachIndex * 0.035),
            0.58,
            0.04
        ];
        _ctrl ctrlSetFont "PuristaMedium";
        _ctrl setVariable ["infoType", _infoType];
        _ctrl setVariable ["scriptPath", _scriptPath];
        _ctrl ctrlCommit 0;
        
        RTSUI_infoControls pushBack _ctrl;
        
        systemChat format ["Created panel: %1 with script %2", _infoType, _scriptPath];
    } forEach RTSUI_infoPanelTypes;
    
    systemChat format ["Total info controls created: %1", count RTSUI_infoControls];
    
    // Check if controls were actually created
    if (count RTSUI_infoControls == 0) then {
        systemChat "CRITICAL ERROR: No info controls were created! Check RTSUI_infoPanelTypes array.";
        systemChat format ["Panel types array: %1", RTSUI_infoPanelTypes];
    } else {
        systemChat format ["Successfully created %1 info controls", count RTSUI_infoControls];
    };
};

// Get panels based on entity type
fnc_getInfoPanelsForEntityType = {
    params ["_entity"];
    
    private _panels = RTSUI_defaultInfoPanels;
    
    switch (true) do {
        case (_entity isKindOf "CAManBase"): {
            _panels = RTSUI_unitInfoPanels;
        };
        case (_entity isKindOf "LandVehicle" || _entity isKindOf "Air" || _entity isKindOf "Ship"): {
            _panels = RTSUI_vehicleInfoPanels;
        };
        default {
            // Use default panels
        };
    };
    
    _panels
};

// Update all info panels for a unit - Fixed and debugged version
fnc_updateInfoPanels = {
    params ["_unit"];
    
    systemChat "UpdateInfoPanels called";
    
    // First, hide all panels and clear their text to reset the state
    {
        private _ctrl = _x;
        _ctrl ctrlShow false;
        _ctrl ctrlSetText "";
    } forEach RTSUI_infoControls;
    
    // Exit early if null unit
    if (isNull _unit) exitWith {
        systemChat "UpdateInfoPanels: Null unit, exiting";
    };
    
    // Determine entity type directly
    private _entityType = "NONE";
    
    // First check if it's a squad selection based on global variables
    private _lastEntityType = missionNamespace getVariable ["RTSUI_lastEntityType", ""];
    private _lastSelectionType = missionNamespace getVariable ["RTSUI_lastSelectionType", ""];
    
    if (_lastEntityType == "SQUAD" || _lastSelectionType == "SQUAD") then {
        _entityType = "SQUAD";
        systemChat "UpdateInfoPanels: Using SQUAD entity type";
    } else {
        // Single entity selection logic
        if (_unit isKindOf "CAManBase") then {
            _entityType = "MAN";
            systemChat "UpdateInfoPanels: Using MAN entity type";
        } else {
            if (_unit isKindOf "LandVehicle" || _unit isKindOf "Air" || _unit isKindOf "Ship") then {
                _entityType = "VEHICLE";
                systemChat "UpdateInfoPanels: Using VEHICLE entity type";
            } else {
                _entityType = "OBJECT";
                systemChat "UpdateInfoPanels: Using OBJECT entity type";
            };
        };
    };
    
    // Store the entity type
    missionNamespace setVariable ["RTSUI_lastEntityType", _entityType];
    
    // Define strict allowed panels for each entity type - USING ORIGINAL PANEL TYPES FOR NOW
    private _allowedPanels = switch (_entityType) do {
        case "MAN": {
            ["name", "rank", "health", "ammo", "weapon", "fatigue"]
        };
        case "VEHICLE": {
            ["vehicleType", "vehicleHealth", "vehicleFuel", "vehicleAmmo", "vehicleWeapon", "vehicleCargoInfo"]
        };
        case "SQUAD": {
            ["groupStatus", "squadTask", "squad"]
        };
        case "MIXED": {
            ["name", "health"]
        };
        default {
            []
        };
    };
    
    systemChat format ["UpdateInfoPanels: Using panels: %1", _allowedPanels];
    
    // Create array to track panels that should be shown
    private _panelsToShow = [];
    private _processedPanelTypes = [];
    
    // Determine which panels to show based on entity type
    {
        private _ctrl = _x;
        private _infoType = _ctrl getVariable ["infoType", ""];
        private _scriptPath = _ctrl getVariable ["scriptPath", ""];
        
        // Reset to default script path for consistent handling
        private _defaultPath = "";
        {
            _x params ["_type", "_path"];
            if (_type == _infoType) then {
                _defaultPath = _path;
                _ctrl setVariable ["scriptPath", _path];
            };
        } forEach RTSUI_infoPanelTypes;
        
        // Only process if this panel type is in our allowed list
        if (_infoType in _allowedPanels && !(_infoType in _processedPanelTypes) && !isNull _ctrl) then {
            _processedPanelTypes pushBack _infoType;
            
            // Get updated script path
            _scriptPath = _ctrl getVariable ["scriptPath", ""];
            
            if (_scriptPath != "") then {
                // Debug info about each panel we're processing
                systemChat format ["Processing panel: %1 with script: %2", _infoType, _scriptPath];
                
                // Execute the panel update script
                [_ctrl, _unit] call compile preprocessFileLineNumbers _scriptPath;
                _ctrl ctrlShow true; // Make sure it's visible
                _panelsToShow pushBack _ctrl;
                
                systemChat format ["Panel %1 processed", _infoType];
            } else {
                systemChat format ["Panel %1 has no script path!", _infoType];
            };
        };
    } forEach RTSUI_infoControls;
    
    systemChat format ["Total panels to show: %1", count _panelsToShow];
    
    // Sort panels by their original index to maintain order
    _panelsToShow = [_panelsToShow, [], {
        private _index = RTSUI_infoControls find _x;
        if (_index == -1) then { 999 } else { _index };
    }] call BIS_fnc_sortBy;
    
    // Reposition all panels to create continuous display
    private _visibleIndex = 0;
    {
        private _ctrl = _x;
        private _pos = ctrlPosition _ctrl;
        
        // Get info type for debugging
        private _infoType = _ctrl getVariable ["infoType", "unknown"];
        
        // Set new position
        _ctrl ctrlSetPosition [
            _pos select 0,
            safezoneY + safezoneH - 0.29 + (_visibleIndex * 0.035),
            _pos select 2,
            _pos select 3
        ];
        _ctrl ctrlCommit 0;
        systemChat format ["Positioned panel %1 at index %2", _infoType, _visibleIndex];
        _visibleIndex = _visibleIndex + 1;
    } forEach _panelsToShow;
    
    
};

// Update a specific panel by name
fnc_updateSpecificPanel = {
    params ["_entity", "_panelName"];
    
    // Exit if there's no entity
    if (isNull _entity) exitWith {};
    
    // Find the control for this panel type
    private _found = false;
    {
        private _ctrl = _x;
        private _infoType = _ctrl getVariable ["infoType", ""];
        private _scriptPath = _ctrl getVariable ["scriptPath", ""];
        
        if (_infoType == _panelName && _scriptPath != "" && !isNull _ctrl) then {
            // Execute the panel update script with the control and entity
            [_ctrl, _entity] call compile preprocessFileLineNumbers _scriptPath;
            _found = true;
        };
    } forEach RTSUI_infoControls;
    
    // If the panel wasn't found among visible controls, it might need to be first created
    if (!_found) then {
        // Force a complete info panel update for the entity
        [_entity] call fnc_updateInfoPanels;
    };
};

// Debug function to show all available panels and their current state
fnc_debugInfoPanels = {
    systemChat "======= INFO PANEL DEBUG =======";
    systemChat format ["Current entity type: %1", RTSUI_lastEntityType];
    systemChat format ["Entity class: %1", typeOf RTSUI_selectedUnit];
    systemChat format ["Selection type: %1", RTSUI_lastSelectionType];
    
    {
        _x params ["_infoType", "_scriptPath"];
        private _active = _infoType in ([RTSUI_selectedUnit] call fnc_getInfoPanelsForEntityType);
        systemChat format ["Panel: %1 | Script: %2 | Active: %3", _infoType, _scriptPath, _active];
    } forEach RTSUI_infoPanelTypes;
    
    // Check all controls
    systemChat "--- CONTROL STATUS ---";
    {
        private _ctrl = _x;
        private _infoType = _ctrl getVariable ["infoType", ""];
        private _visible = ctrlVisible _ctrl;
        private _text = ctrlText _ctrl;
        
        systemChat format ["Control: %1 | Visible: %2 | Text: %3", _infoType, _visible, _text];
    } forEach RTSUI_infoControls;
    
    systemChat "============================";
};

// Add key handler to trigger debug (Ctrl+I)
[] spawn {
    waitUntil {!isNull findDisplay 312};
    
    (findDisplay 312) displayAddEventHandler ["KeyDown", {
        params ["_display", "_key", "_shift", "_ctrl", "_alt"];
        
        // Ctrl+I (Key 23 is I)
        if (_key == 23 && _ctrl) then {
            call fnc_debugInfoPanels;
            true
        } else {
            false
        };
    }];
};