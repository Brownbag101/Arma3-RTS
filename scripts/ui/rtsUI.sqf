if (isNil "RTSUI_abilityIcons") then { 
    RTSUI_abilityIcons = []; 
};

// Time acceleration settings array: [id, display name, acceleration value, icon]
// GAMEPLAY VARIABLES - Modify these values to change acceleration factors
RTSUI_timeAccelerationSettings = [
    ["slow_mo", "Slow Mo", 0.25, "\a3\ui_f\data\gui\rsc\rscdisplaymain\hover_left_ca.paa"],
    ["normal", "Normal", 1, "\a3\ui_f\data\igui\cfg\actions\obsolete\ui_action_watch_ca.paa"],
    ["fast", "2X Speed", 2, "\a3\ui_f\data\gui\rsc\rscdisplaymain\hover_right_ca.paa"],
    ["very_fast", "4X Speed", 4, "\a3\ui_f\data\gui\rsc\rscdisplaymain\menu_logo_ca.paa"]
];

// Current acceleration setting (default: normal)
RTSUI_currentAccelerationSetting = "normal";

// Core Variables
RTSUI_controls = [];
RTSUI_selectedUnit = objNull;
RTSUI_lastSelectionType = ""; // Added variable to track selection type

// Time acceleration control array
RTSUI_timeAccelControls = [];

// Function to create time acceleration panel
fnc_createTimeAccelerationPanel = {
    params ["_display"];
    
    // Panel dimensions and position
    private _panelWidth = 0.58;
    private _panelHeight = 0.025;
    private _buttonWidth = _panelWidth / 4;
    private _buttonHeight = 0.02 * safezoneH;
    private _panelX = safezoneX + 0.01;
    private _panelY = (safezoneY + safezoneH - 0.3) - _panelHeight - 0.005; // Just above info panel
    
    // Create background panel
    private _panel = _display ctrlCreate ["RscText", -1];
    _panel ctrlSetPosition [
        _panelX,
        _panelY,
        _panelWidth,
        _panelHeight
    ];
    _panel ctrlSetBackgroundColor [0, 0, 0, 0.5];
    _panel ctrlCommit 0;
    RTSUI_controls pushBack _panel;
    
    // Create time acceleration buttons
    {
        _x params ["_id", "_name", "_value", "_icon"];
        
        private _index = _forEachIndex;
        private _buttonX = _panelX + (_index * _buttonWidth);
        
        // Create button background
        private _btnBg = _display ctrlCreate ["RscText", -1];
        _btnBg ctrlSetPosition [
            _buttonX,
            _panelY + 0.0025,
            _buttonWidth - 0.002,
            _buttonHeight
        ];
        
        // Set background color based on current selection
        if (_id == RTSUI_currentAccelerationSetting) then {
            _btnBg ctrlSetBackgroundColor [0.3, 0.3, 0.5, 0.9];
        } else {
            _btnBg ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
        };
        
        _btnBg ctrlCommit 0;
        _btnBg setVariable ["timeAccelId", _id];
        RTSUI_controls pushBack _btnBg;
        
        // Add to time acceleration controls for updating
        RTSUI_timeAccelControls pushBack _btnBg;
        
        // Create icon
        private _btnIcon = _display ctrlCreate ["RscPicture", -1];
        _btnIcon ctrlSetPosition [
            _buttonX + 0.002,
            _panelY + 0.0025,
            _buttonHeight,
            _buttonHeight
        ];
        _btnIcon ctrlSetText _icon;
        _btnIcon ctrlCommit 0;
        RTSUI_controls pushBack _btnIcon;
        
        // Create text label
        private _btnText = _display ctrlCreate ["RscText", -1];
        _btnText ctrlSetPosition [
            _buttonX + _buttonHeight + 0.002,
            _panelY + 0.0025,
            _buttonWidth - _buttonHeight - 0.004,
            _buttonHeight
        ];
        _btnText ctrlSetText _name;
        _btnText ctrlSetTextColor [1, 1, 1, 0.9];
        _btnText ctrlCommit 0;
        RTSUI_controls pushBack _btnText;
        
        // Create actual button (invisible but clickable)
        private _btn = _display ctrlCreate ["RscButton", -1];
        _btn ctrlSetPosition [
            _buttonX,
            _panelY + 0.0025,
            _buttonWidth - 0.002,
            _buttonHeight
        ];
        _btn ctrlSetText "";
        _btn ctrlSetBackgroundColor [0, 0, 0, 0.01]; // Almost transparent
        _btn ctrlSetTooltip format ["Set game speed to %1", _name];
        
        // Store settings
        _btn setVariable ["timeAccelId", _id];
        _btn setVariable ["timeAccelValue", _value];
        _btn setVariable ["timeAccelName", _name];
        _btn setVariable ["timeAccelButton", _btnBg];
        
        // Add hover effects
        _btn ctrlAddEventHandler ["MouseEnter", {
            params ["_ctrl"];
            private _bg = _ctrl getVariable "timeAccelButton";
            private _id = _ctrl getVariable "timeAccelId";
            
            if (_id != RTSUI_currentAccelerationSetting) then {
                _bg ctrlSetBackgroundColor [0.2, 0.2, 0.3, 0.8];
            };
        }];
        
        _btn ctrlAddEventHandler ["MouseExit", {
            params ["_ctrl"];
            private _bg = _ctrl getVariable "timeAccelButton";
            private _id = _ctrl getVariable "timeAccelId";
            
            if (_id != RTSUI_currentAccelerationSetting) then {
                _bg ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
            };
        }];
        
        // Add click handler
        _btn ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _id = _ctrl getVariable "timeAccelId";
            private _value = _ctrl getVariable "timeAccelValue";
            private _name = _ctrl getVariable "timeAccelName";
            
            [_id, _value, _name] call fnc_setTimeAcceleration;
        }];
        
        _btn ctrlCommit 0;
        RTSUI_controls pushBack _btn;
        
    } forEach RTSUI_timeAccelerationSettings;
};

// Function to set time acceleration
fnc_setTimeAcceleration = {
    params ["_id", "_value", "_name"];
    
    // Set accTime
    setAccTime _value;
    
    // Update current setting
    RTSUI_currentAccelerationSetting = _id;
    
    // Update visual state
    [] call fnc_updateTimeAccelerationButtons;
    
    // Provide feedback
    systemChat format ["Game speed set to %1", _name];
};

// Function to update time acceleration button visuals
fnc_updateTimeAccelerationButtons = {
    if (isNil "RTSUI_timeAccelControls") exitWith {};
    
    {
        private _id = _x getVariable ["timeAccelId", ""];
        
        if (_id == RTSUI_currentAccelerationSetting) then {
            _x ctrlSetBackgroundColor [0.3, 0.3, 0.5, 0.9];
        } else {
            _x ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
        };
    } forEach RTSUI_timeAccelControls;
};

// Function to reset time acceleration when Zeus interface is closed
fnc_resetTimeAcceleration = {
    // Reset to normal speed
    setAccTime 1;
    RTSUI_currentAccelerationSetting = "normal";
    
    // Clear controls array
    if (!isNil "RTSUI_timeAccelControls") then {
        RTSUI_timeAccelControls = [];
    };
};

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
    
    // Create time acceleration panel
    [_display] call fnc_createTimeAccelerationPanel;
    
    // Create info panels using the modular system
    [_display] call fnc_createInfoPanels;

    // Initialize modular button system - create action buttons based on selection
    private _selections = curatorSelected select 0;
    [_display, _selections] call fnc_createActionButtons;

    // Create ability icons last
    [_display] call fnc_createAbilityIcons;
};

// Function to simulate backspace key press
fnc_simulateBackspaceKey = {
    // Check if Zeus interface is open
    if (isNull findDisplay 312) exitWith {
        systemChat "Cannot simulate key press - Zeus interface not open";
    };
    
    // Backspace key code is 14
    private _keyCode = 14;
    
    // Get Zeus display
    private _display = findDisplay 312;
    
    // Create simulated key down event
    private _handled = [_display, _keyCode, false, false, false] call {
        params ["_displayOrControl", "_key", "_shift", "_ctrl", "_alt"];
        
        // Manually trigger any key handlers on the display
        private _handlers = _displayOrControl getVariable ["keyHandlers", []];
        private _result = false;
        
        {
            private _res = [_displayOrControl, _key, _shift, _ctrl, _alt] call _x;
            if (_res) then { _result = true; };
        } forEach _handlers;
        
        // If we're using the current RTS system, also try to trigger FIREATP_keyHandler or AIMEDSHOT_keyHandler
        if (!isNil "FIREATP_keyHandler" && FIREATP_keyHandler != -1) then {
            private _eh = _displayOrControl displayCtrl FIREATP_keyHandler;
            if (!isNull _eh) then {
                [_displayOrControl, _key, _shift, _ctrl, _alt] call _eh;
            };
        };
        
        if (!isNil "AIMEDSHOT_keyHandler" && AIMEDSHOT_keyHandler != -1) then {
            private _eh = _displayOrControl displayCtrl AIMEDSHOT_keyHandler;
            if (!isNull _eh) then {
                [_displayOrControl, _key, _shift, _ctrl, _alt] call _eh;
            };
        };
        
        // Manually trigger resetFireAtPositionState or resetAimedShotState if active
        if (!isNil "FIREATP_active" && {FIREATP_active}) then {
            if (!isNil "fnc_resetFireAtPositionState") then {
                [] call fnc_resetFireAtPositionState;
                systemChat "Cancelled Fire At Position mode";
            };
        };
        
        if (!isNil "AIMEDSHOT_active" && {AIMEDSHOT_active}) then {
            if (!isNil "fnc_resetAimedShotState") then {
                [] call fnc_resetAimedShotState;
                systemChat "Cancelled Aimed Shot mode";
            };
        };
        
        _result
    };
    
    diag_log format ["Simulated backspace key press, handled: %1", _handled];
    systemChat "Simulated backspace key press";
};

// Main initialization function - can be called repeatedly
fnc_initializeRTSUI = {
    // Create the base UI
    [findDisplay 312] call fnc_createBaseUI;
    
    // Explicitly ensure info panels are created
    [findDisplay 312] call fnc_createInfoPanels;
    
    // Selection monitoring to trigger UI updates
    [] spawn {
        private ["_lastSelections", "_lastEntityType"];
        _lastSelections = [];
        _lastEntityType = "";
        
        // Keep running until Zeus interface is closed
        while {!isNull findDisplay 312} do {
            private _selections = curatorSelected select 0;
            
            // Check if selection has changed
            if !(_selections isEqualTo _lastSelections) then {
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
        // Status monitoring code (similar to before)
        // This will be terminated when Zeus closes
        private ["_lastHealthState", "_lastFatigueState", "_lastAmmoState", "_lastFuelState", "_lastCombatMode", "_lastStance"];
        _lastHealthState = -1;
        _lastFatigueState = -1;
        _lastAmmoState = -1;
        _lastFuelState = -1;
        _lastCombatMode = "";
        _lastStance = "";
        
        while {!isNull findDisplay 312} do {
            // Only update if we have a valid selection
            if (!isNull RTSUI_selectedUnit) then {
                // Existing status update code...
                // Check entity type and update panels
            };
            
            sleep 0.25; // Update 4 times per second
        };
    };
};

// Cleanup function
fnc_cleanupRTSUI = {
    {
        ctrlDelete _x;
    } forEach RTSUI_controls;
    RTSUI_controls = [];
    
    // Reset time acceleration when Zeus interface is closed
    [] call fnc_resetTimeAcceleration;
};

// Main Zeus monitoring loop - persistent throughout mission
[] spawn {
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
        RTSUI_infoControls = []; 
    };

    // Continuous monitoring loop - stays alive throughout mission
    while {true} do {
        // Wait for Zeus to open
        waitUntil {!isNull findDisplay 312};
        systemChat "Zeus interface detected - initializing RTS UI";
        
        // Initialize UI
        call fnc_initializeRTSUI;
        
        // Wait for Zeus to close
        waitUntil {isNull findDisplay 312};
        systemChat "Zeus interface closed - cleaning up UI";
        
        // Clean up UI
        call fnc_cleanupRTSUI;
        
        // Small delay to prevent excessive CPU usage
        sleep 0.5;
    };
};
    
