// Info Panel Manager
// Handles creation and updating of unit info panels

// Initialize array to store info controls
if (isNil "RTSUI_infoControls") then { RTSUI_infoControls = []; };

// UPDATED: Info panel types and their script paths - using combined panels where available
RTSUI_infoPanelTypes = [
    // Combined unit info panels
    ["nameRank", "scripts\ui\infoPanels\nameRankInfo.sqf"],        // Name + Rank
    ["healthStatus", "scripts\ui\infoPanels\healthStatusInfo.sqf"], // Health + Ammo + Fatigue
    ["weapon", "scripts\ui\infoPanels\weaponInfo.sqf"],            // Current weapon
    ["combatStatus", "scripts\ui\infoPanels\combatStatusInfo.sqf"], // Combat mode + Speed
    ["stance", "scripts\ui\infoPanels\stanceInfo.sqf"],            // Stance info
    
    // Squad info panels
    ["squad", "scripts\ui\infoPanels\squadInfo.sqf"],              // Squad name and members
    ["groupStatus", "scripts\ui\infoPanels\groupStatusInfo.sqf"],   // Group health status
    ["squadTask", "scripts\ui\infoPanels\squadTaskInfo.sqf"],       // Squad task info
    
    // Combined vehicle info panels
    ["vehicleType", "scripts\ui\infoPanels\vehicleNameInfo.sqf"],    // Vehicle name
    ["vehicleStatus", "scripts\ui\infoPanels\vehicleStatusInfo.sqf"], // Vehicle Health + Fuel + Combat Mode
    ["vehicleWeapon", "scripts\ui\infoPanels\vehicleWeaponInfo.sqf"], // Vehicle Weapon + Ammo
    ["vehicleCargoInfo", "scripts\ui\infoPanels\vehicleCargoInfo.sqf"] // Vehicle Cargo info
];

// UPDATED: Entity type-specific info panels - using combined panels
RTSUI_unitInfoPanels = ["nameRank", "healthStatus", "weapon", "combatStatus", "stance"];
RTSUI_vehicleInfoPanels = ["vehicleType", "vehicleStatus", "vehicleWeapon", "vehicleCargoInfo"];
RTSUI_squadInfoPanels = ["squad", "groupStatus", "squadTask"]; 
RTSUI_defaultInfoPanels = ["nameRank", "healthStatus"];

// Clear all info panels
fnc_clearInfoPanels = {
    {
        _x ctrlShow false;
        _x ctrlSetText "";
    } forEach RTSUI_infoControls;
};

// Create info panels
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
    
    // Create text controls for each info type with consistent spacing
    {
        _x params ["_infoType", "_scriptPath"];
        
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
    } forEach RTSUI_infoPanelTypes;
    
    systemChat format ["Total info controls created: %1", count RTSUI_infoControls];
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

// Update all info panels for a unit
fnc_updateInfoPanels = {
    params ["_unit"];
    
    // First, hide all panels and clear their text to reset the state
    {
        private _ctrl = _x;
        _ctrl ctrlShow false;
        _ctrl ctrlSetText "";
    } forEach RTSUI_infoControls;
    
    // Exit early if null unit
    if (isNull _unit) exitWith {};
    
    // Determine entity type directly
    private _entityType = "NONE";
    
    // First check if it's a squad selection based on global variables
    private _lastEntityType = missionNamespace getVariable ["RTSUI_lastEntityType", ""];
    private _lastSelectionType = missionNamespace getVariable ["RTSUI_lastSelectionType", ""];
    
    if (_lastEntityType == "SQUAD" || _lastSelectionType == "SQUAD") then {
        _entityType = "SQUAD";
    } else {
        // Single entity selection logic
        if (_unit isKindOf "CAManBase") then {
            _entityType = "MAN";
        } else {
            if (_unit isKindOf "LandVehicle" || _unit isKindOf "Air" || _unit isKindOf "Ship") then {
                _entityType = "VEHICLE";
            } else {
                _entityType = "OBJECT";
            };
        };
    };
    
    // Store the entity type
    missionNamespace setVariable ["RTSUI_lastEntityType", _entityType];
    
    // Define allowed panels for each entity type
    private _allowedPanels = switch (_entityType) do {
        case "MAN": { RTSUI_unitInfoPanels };
        case "VEHICLE": { RTSUI_vehicleInfoPanels };
        case "SQUAD": { RTSUI_squadInfoPanels };
        case "MIXED": { RTSUI_defaultInfoPanels };
        default { [] };
    };
    
    // Create array to track panels that should be shown
    private _panelsToShow = [];
    private _processedPanelTypes = [];
    
    // Determine which panels to show based on entity type
    {
        private _ctrl = _x;
        private _infoType = _ctrl getVariable ["infoType", ""];
        private _scriptPath = _ctrl getVariable ["scriptPath", ""];
        
        // Only process if this panel type is in our allowed list
        if (_infoType in _allowedPanels && !(_infoType in _processedPanelTypes) && !isNull _ctrl) then {
            _processedPanelTypes pushBack _infoType;
            
            if (_scriptPath != "") then {
                // Execute the panel update script
                [_ctrl, _unit] call compile preprocessFileLineNumbers _scriptPath;
                _ctrl ctrlShow true; // Make sure it's visible
                _panelsToShow pushBack _ctrl;
            };
        };
    } forEach RTSUI_infoControls;
    
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
        
        // Set new position
        _ctrl ctrlSetPosition [
            _pos select 0,
            safezoneY + safezoneH - 0.29 + (_visibleIndex * 0.035),
            _pos select 2,
            _pos select 3
        ];
        _ctrl ctrlCommit 0;
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