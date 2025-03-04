// Core Variables
RTSUI_controls = [];
RTSUI_selectedUnit = objNull;
RTSUI_lastSelectionType = ""; // Added variable to track selection type

// Core Functions
fnc_createBaseUI = {
    params ["_display"];
    
    // Clear any existing controls
    {
        ctrlDelete _x;
    } forEach RTSUI_controls;
    RTSUI_controls = [];
    
    // Create base panel - for unit info
    private _basePanel = _display ctrlCreate ["RscText", -1];
    _basePanel ctrlSetPosition [
        safezoneX,
        safezoneY + safezoneH - 0.3,
        0.6,
        0.3
    ];
    _basePanel ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _basePanel ctrlCommit 0;
    RTSUI_controls pushBack _basePanel;

    // Create command panel - for action buttons
    private _commandPanel = _display ctrlCreate ["RscText", 9501]; // Assign specific ID for reference
    _commandPanel ctrlSetPosition [
        safezoneX + 0.63,
        safezoneY + safezoneH - 0.3,
        0.9,
        0.3
    ];
    _commandPanel ctrlSetBackgroundColor [0, 0, 0, 0.5];
    _commandPanel ctrlCommit 0;
    RTSUI_controls pushBack _commandPanel;

    // Create abilities panel (for special abilities)
    private _abilitiesPanel = _display ctrlCreate ["RscText", -1];
    _abilitiesPanel ctrlSetPosition [
        safezoneX + safezoneW - 0.3,  // Position from right side
        safezoneY + safezoneH - 0.3,   // Same Y as other panels
        0.3,                           // Width
        0.3                            // Height
    ];
    _abilitiesPanel ctrlSetBackgroundColor [0, 0, 0, 0.5];
    _abilitiesPanel ctrlCommit 0;
    RTSUI_controls pushBack _abilitiesPanel;

    // Create abilities header
    private _abilitiesHeader = _display ctrlCreate ["RscText", -1];
    _abilitiesHeader ctrlSetPosition [
        safezoneX + safezoneW - 0.3,
        safezoneY + safezoneH - 0.3,
        0.3,
        0.03
    ];
    _abilitiesHeader ctrlSetBackgroundColor [0.2, 0.2, 0.2, 0.8];
    _abilitiesHeader ctrlSetText "  Special Abilities";
    _abilitiesHeader ctrlSetTextColor [1, 1, 1, 1];
    _abilitiesHeader ctrlCommit 0;
    RTSUI_controls pushBack _abilitiesHeader;
    
    // Create info panels using the modular system
    [_display] call fnc_createInfoPanels;

    // Initialize modular button system - create action buttons based on selection
    private _selections = curatorSelected select 0;
    [_display, _selections] call fnc_createActionButtons;

    // Create ability icons last
    [_display] call fnc_createAbilityIcons;
};

// Main Loop - replace this section in rtsUI.sqf
[] spawn {
    waitUntil {!isNull findDisplay 312};
    
    // Load all modular systems
    [] execVM "scripts\actions\registry.sqf";
    [] execVM "scripts\ui\buttonManager.sqf";
    [] execVM "scripts\ui\infoPanelManager.sqf";
    
    // Wait for all systems to be loaded
    waitUntil {!isNil "RTSUI_actionDatabase"};
    waitUntil {!isNil "fnc_createActionButtons"};
    waitUntil {!isNil "fnc_createInfoPanels"};
    
    // Check if critical arrays are properly initialized
    if (isNil "RTSUI_infoControls") then { 
        systemChat "CRITICAL: RTSUI_infoControls was nil, initializing";
        RTSUI_infoControls = []; 
    };
    
    if (isNil "RTSUI_infoPanelTypes") then { 
        systemChat "CRITICAL: RTSUI_infoPanelTypes was nil!";
    };
    
    // Create the base UI
    [findDisplay 312] call fnc_createBaseUI;
    
    // Explicitly ensure info panels are created
    systemChat "Explicitly creating info panels...";
    [findDisplay 312] call fnc_createInfoPanels;
    systemChat format ["Info controls after creation: %1", count RTSUI_infoControls];
    
    // Selection monitoring to trigger UI updates
    [] spawn {
        private ["_lastSelections", "_lastEntityType"];
        _lastSelections = [];
        _lastEntityType = "";
        
        while {!isNull findDisplay 312} do {
            private _selections = curatorSelected select 0;
            
            // Check if selection has changed
            if !(_selections isEqualTo _lastSelections) then {
                systemChat "Selection changed - processing...";
                
                // First, force all panels to reset completely
                {
                    _x ctrlShow false;
                    _x ctrlSetText "";
                } forEach RTSUI_infoControls;
                
                // Record previous type for transition handling
                _lastEntityType = RTSUI_lastSelectionType;
                _lastSelections = _selections;
                
                // Update UI based on selection
                if (count _selections > 0) then {
                    systemChat format ["Processing %1 selections", count _selections];
                    if (count _selections == 1) then {
                        // Single unit or vehicle selection
                        private _unit = _selections select 0;
                        RTSUI_selectedUnit = _unit;
                        RTSUI_lastSelectionType = "SINGLE";
                        
                        // Explicitly reset any forced entity type
                        missionNamespace setVariable ["RTSUI_lastEntityType", ""];
                        
                        // Force panel clear and update
                        call fnc_clearInfoPanels;
                        [_unit] call fnc_updateInfoPanels;
                    } else {
                        // Multiple units selection - check if all are infantry
                        private _allInfantry = true;
                        {
                            if !(_x isKindOf "CAManBase") then {
                                _allInfantry = false;
                            };
                        } forEach _selections;
                        
                        private _firstUnit = _selections select 0;
                        RTSUI_selectedUnit = _firstUnit;
                        
                        if (_allInfantry) then {
                            // It's definitely a squad
                            RTSUI_lastSelectionType = "SQUAD";
                            missionNamespace setVariable ["RTSUI_lastEntityType", "SQUAD"];
                            
                            // Force clean panel update
                            call fnc_clearInfoPanels;
                            [_firstUnit] call fnc_updateInfoPanels;
                        } else {
                            // Mixed selection
                            RTSUI_lastSelectionType = "MIXED";
                            missionNamespace setVariable ["RTSUI_lastEntityType", "MIXED"];
                            
                            call fnc_clearInfoPanels;
                            [_firstUnit] call fnc_updateInfoPanels;
                        };
                    };
                    
                    // Update ability icons after panel update
                    [findDisplay 312] call fnc_createAbilityIcons;
                } else {
                    // Nothing selected
                    RTSUI_selectedUnit = objNull;
                    RTSUI_lastSelectionType = "";
                    missionNamespace setVariable ["RTSUI_lastEntityType", ""];
                    call fnc_clearInfoPanels;
                    [objNull] call fnc_updateInfoPanels;
                    [findDisplay 312] call fnc_createAbilityIcons;
                };
                
                // Update action buttons based on new selection
                call fnc_onSelectionChanged;
            };
            
            // Update button states continuously
            [_selections] call fnc_updateActionButtons;
            
            sleep 0.1;
        };
    };
    
    // Real-time status update monitoring
    [] spawn {
        private ["_lastHealthState", "_lastFatigueState", "_lastAmmoState", "_lastFuelState"];
        _lastHealthState = -1;
        _lastFatigueState = -1;
        _lastAmmoState = -1;
        _lastFuelState = -1;
        
        while {!isNull findDisplay 312} do {
            // Only update if we have a valid selection
            if (!isNull RTSUI_selectedUnit) then {
                // Check if the entity type should be updated
                private _entity = RTSUI_selectedUnit;
                private _currentPanels = [];
                
                // Determine which panels need real-time updates based on entity type
                private _entityType = missionNamespace getVariable ["RTSUI_lastEntityType", ""];
                
                // If no explicit entity type, determine from selection type
                if (_entityType == "") then {
                    if (RTSUI_lastSelectionType == "SQUAD") then {
                        _entityType = "SQUAD";
                    } else {
                        _entityType = [[RTSUI_selectedUnit]] call fnc_getSelectionType;
                    };
                };
                
                switch (_entityType) do {
                    case "MAN": {
                        // Update health, fatigue, ammo for infantry
                        private _health = 1 - damage _entity;
                        private _fatigue = getFatigue _entity;
                        private _ammo = if (currentWeapon _entity != "") then {_entity ammo (currentWeapon _entity)} else {0};
                        
                        // Only update if values have changed
                        if (abs(_health - _lastHealthState) > 0.01) then {
                            _lastHealthState = _health;
                            [_entity, "health"] call fnc_updateSpecificPanel;
                        };
                        
                        if (abs(_fatigue - _lastFatigueState) > 0.01) then {
                            _lastFatigueState = _fatigue;
                            [_entity, "fatigue"] call fnc_updateSpecificPanel;
                        };
                        
                        if (_ammo != _lastAmmoState) then {
                            _lastAmmoState = _ammo;
                            [_entity, "ammo"] call fnc_updateSpecificPanel;
                        };
                    };
                    
                    case "VEHICLE": {
                        // Update health, fuel, ammo for vehicles
                        private _health = 1 - damage _entity;
                        private _fuel = fuel _entity;
                        private _ammo = if (currentWeapon _entity != "") then {_entity ammo (currentWeapon _entity)} else {0};
                        
                        // Make sure name is always shown
                        [_entity, "vehicleType"] call fnc_updateSpecificPanel;
                        
                        // Only update if values have changed
                        if (abs(_health - _lastHealthState) > 0.01) then {
                            _lastHealthState = _health;
                            [_entity, "vehicleHealth"] call fnc_updateSpecificPanel;
                        };
                        
                        if (abs(_fuel - _lastFuelState) > 0.01) then {
                            _lastFuelState = _fuel;
                            [_entity, "vehicleFuel"] call fnc_updateSpecificPanel;
                        };
                        
                        if (_ammo != _lastAmmoState) then {
                            _lastAmmoState = _ammo;
                            [_entity, "vehicleAmmo"] call fnc_updateSpecificPanel;
                        };
                        
                        // Always update cargo and weapon info to reflect any changes
                        [_entity, "vehicleCargoInfo"] call fnc_updateSpecificPanel;
                        [_entity, "vehicleWeapon"] call fnc_updateSpecificPanel;
                    };
                    
                    case "SQUAD": {
                        // For squads, continuously update group status
                        [_entity, "groupStatus"] call fnc_updateSpecificPanel;
                        [_entity, "squadTask"] call fnc_updateSpecificPanel;
                    };
                };
            };
            
            sleep 0.25; // Update 4 times per second
        };
    };
    
    waitUntil {isNull findDisplay 312};
    {
        ctrlDelete _x;
    } forEach RTSUI_controls;
    RTSUI_controls = [];
    
    sleep 0.1;
};