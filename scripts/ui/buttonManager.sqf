// Button Manager
// Handles creation and display of action buttons based on current selection

// Initialize arrays to store button controls
if (isNil "RTSUI_actionButtons") then { RTSUI_actionButtons = []; };
if (isNil "RTSUI_actionOverlays") then { RTSUI_actionOverlays = []; };

// Clear all action buttons
fnc_clearActionButtons = {
    {
        ctrlDelete _x;
    } forEach (RTSUI_actionButtons + RTSUI_actionOverlays);
    
    RTSUI_actionButtons = [];
    RTSUI_actionOverlays = [];
};

// Create buttons for given selection(s)
fnc_createActionButtons = {
    params ["_display", "_selections"];
    
    // Clear existing buttons
    call fnc_clearActionButtons;
    
    // Exit if no display or no selection
    if (isNull _display || count _selections == 0) exitWith {
        systemChat "No valid selection for buttons";
    };
    
    // Debug message
    systemChat format ["Creating buttons for %1 selections", count _selections];
    
    // Force squad type for multiple infantry units
    private _entityType = "";
    if (count _selections > 1) then {
        // Check if all selections are infantry
        private _allInfantry = true;
        {
            if !(_x isKindOf "CAManBase") then {
                _allInfantry = false;
            };
        } forEach _selections;
        
        if (_allInfantry) then {
            _entityType = "SQUAD";
            systemChat "Squad selection detected!";
        } else {
            _entityType = [_selections] call fnc_getSelectionType;
        };
    } else {
        _entityType = [_selections] call fnc_getSelectionType;
    };
    
    systemChat format ["Entity type: %1", _entityType];
    
    if (_entityType == "NONE") exitWith {
        systemChat "No valid entity type for selection";
    };
    
    // Store the primary selection for dynamic button updates
    private _primarySelection = _selections select 0;
    
    // Get applicable actions for this entity type
    private _actions = [_entityType] call fnc_getActionsForType;
    systemChat format ["Found %1 applicable actions", count _actions];
    
    if (count _actions == 0) exitWith {
        systemChat "No actions available for this entity type";
    };
    
    // Layout configuration
    private _buttonSize = 0.04 * safezoneH;
    private _spacing = 0.005 * safezoneW;
    private _buttonsPerColumn = 3; // Increased from 3 to 5 for better organization
    private _startX = safezoneX + 0.65;
    private _startY = safezoneY + safezoneH - 0.29;
    
    // Get all categories for actions
    private _categories = [];
    {
        private _actionId = _x;
        private _category = [_actionId] call fnc_getActionCategory;
        
        if !(_category in _categories) then {
            _categories pushBack _category;
        };
    } forEach _actions;
    
    systemChat format ["Action categories: %1", _categories];
    
    // Show the action panel
    private _panelCtrl = _display displayCtrl 9501; // Command panel ID
    if (!isNull _panelCtrl) then {
        _panelCtrl ctrlShow true;
    };
    
    // Create category headers
    private _catY = _startY;
    private _columnNum = 0;
    
    {
        private _category = _x;
        private _catActions = [];
        
        // Get actions for this category
        {
            private _actionId = _x;
            if ([_actionId] call fnc_getActionCategory == _category) then {
                _catActions pushBack _actionId;
            };
        } forEach _actions;
        
        if (count _catActions > 0) then {
            // Create category header
            private _header = _display ctrlCreate ["RscText", -1];
            _header ctrlSetPosition [
                _startX + (_columnNum * (_buttonSize * 2 + _spacing * 3)),
                _catY,
                _buttonSize * 2,
                _buttonSize * 0.4
            ];
            _header ctrlSetBackgroundColor [0.2, 0.2, 0.2, 0.8];
            _header ctrlSetText format ["  %1", _category];
            _header ctrlSetTextColor [1, 1, 1, 1];
            _header ctrlCommit 0;
            
            RTSUI_actionButtons pushBack _header;
            
            // Create buttons for this category
            private _btnY = _catY + (_buttonSize * 0.45);
            private _btnCount = 0;
            
            {
    private _actionId = _x;
    private _actionData = [_actionId] call fnc_getActionById;
    
    if (count _actionData > 0) then {
        _actionData params ["_id", "_name", "_iconPath", "_tooltip", "_scriptPath", "_types"];
        
        // For vehicle tow button, update the icon based on state
        if (_id == "vehicle_tow" && _entityType == "VEHICLE") then {
            if (!isNull (_primarySelection getVariable ["towing_vehicle", objNull])) then {
                _iconPath = "a3\3den\data\cfgwaypoints\unhook_ca.paa";
                _name = "Unhook";
                _tooltip = "Unhook towed vehicle";
            } else {
                _iconPath = "a3\3den\data\cfgwaypoints\hook_ca.paa";
                _name = "Hook";
                _tooltip = "Hook to nearby vehicle";
            };
        };
        
        // For hold/release button, update icon and text based on state
        if (_id == "vehicle_togglehold" && _entityType == "VEHICLE") then {
            if (_primarySelection getVariable ["RTS_onHold", false]) then {
                _iconPath = "ca\data\data\t_move2.paa";
                _name = "Release Vehicle";
                _tooltip = "Release vehicle from hold";
            } else {
                _iconPath = "a3\3den\data\cfgwaypoints\hold_ca.paa";
                _name = "Hold Position";
                _tooltip = "Hold vehicle in position";
            };
        };
        
        // Create icon with the appropriate path
        private _icon = _display ctrlCreate ["RscPictureKeepAspect", -1];
        _icon ctrlSetPosition [
            _startX + (_columnNum * (_buttonSize * 2 + _spacing * 3)),
            _btnY,
            _buttonSize,
            _buttonSize
        ];
        _icon ctrlSetText _iconPath;
        _icon ctrlSetTextColor [1, 1, 1, 1];
        _icon ctrlCommit 0;
        
        RTSUI_actionButtons pushBack _icon;
        
        // Create invisible button overlay for better click handling
        private _button = _display ctrlCreate ["RscButton", -1];
        _button ctrlSetPosition [
            _startX + (_columnNum * (_buttonSize * 2 + _spacing * 3)),
            _btnY,
            _buttonSize,
            _buttonSize
        ];
        _button ctrlSetText "";
        _button ctrlSetBackgroundColor [0, 0, 0, 0];
        _button ctrlSetTooltip _tooltip;
        
        // Add click handler
        _button ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _actionData = _ctrl getVariable "actionData";
            
            if (count _actionData > 0) then {
                _actionData params ["_id", "_name", "_iconPath", "_tooltip", "_scriptPath", "_types"];
                
                // For debugging
                systemChat format ["Executing action: %1", _name];
                
                // Get current selections
                private _selections = curatorSelected select 0;
                if (count _selections == 0) exitWith {
                    systemChat "No units selected for action!";
                };
                
                // Check if we should apply to squad or individual
                if (_types select 0 == "SQUAD") then {
                    // Squad action - pass the first unit and all selections
                    [_selections select 0, _selections] execVM _scriptPath;
                    systemChat format ["Squad action %1 called on %2 units", _name, count _selections];
                } else {
                    // Individual action - only apply to first unit
                    [_selections select 0, [_selections select 0]] execVM _scriptPath;
                    systemChat format ["Individual action %1 called on %2", _name, name (_selections select 0)];
                };
                
                // Special handling for toggle buttons that need icon updates
                if (_id == "vehicle_tow" || _id == "vehicle_togglehold") then {
                    // Give a small delay for the action to complete before refreshing
                    [] spawn {
                        sleep 0.5;
                        if (!isNull findDisplay 312) then {
                            private _currentSelections = curatorSelected select 0;
                            if (count _currentSelections > 0) then {
                                [findDisplay 312, _currentSelections] call fnc_createActionButtons;
                            };
                        };
                    };
                };
            };
        }];
                    
                    _button setVariable ["actionData", _actionData];
                    _button ctrlCommit 0;
                    
                    RTSUI_actionOverlays pushBack _button;
                    
                    // Move to next button position
                    _btnY = _btnY + _buttonSize + _spacing;
                    _btnCount = _btnCount + 1;
                    
                    // If we've reached max buttons in column, move to next column
                    if (_btnCount >= _buttonsPerColumn) then {
                        _btnY = _catY + (_buttonSize * 0.45);
                        _columnNum = _columnNum + 1;
                        _btnCount = 0;
                    };
                };
            } forEach _catActions;
            
            // Move to next column for next category if we haven't already
            if (_btnCount > 0) then {
                _columnNum = _columnNum + 1;
            };
        };
    } forEach _categories;
};

// Update button states (enabled/disabled) based on selection state
fnc_updateActionButtons = {
    params ["_selections"];
    
    {
        private _button = _x;
        private _actionData = _button getVariable ["actionData", []];
        
        if (count _actionData > 0) then {
            _actionData params ["_id", "_name", "_iconPath", "_tooltip", "_scriptPath", "_types"];
            
            // Custom logic for specific buttons
            private _enabled = true;
            
            // Example: disable launcher button if unit doesn't have launcher
            if (_id == "weapon_launcher" && count _selections == 1) then {
                private _unit = _selections select 0;
                if (_unit isKindOf "CAManBase") then {
                    _enabled = secondaryWeapon _unit != "";
                };
            };
            
            // Example: disable sidearm button if unit doesn't have handgun
            if (_id == "weapon_sidearm" && count _selections == 1) then {
                private _unit = _selections select 0;
                if (_unit isKindOf "CAManBase") then {
                    _enabled = handgunWeapon _unit != "";
                };
            };
            
            // Set button state
            _button ctrlEnable _enabled;
            
            // Find corresponding icon and set its alpha
            private _iconIndex = RTSUI_actionButtons findIf {
                ctrlPosition _x select 0 == ctrlPosition _button select 0 &&
                ctrlPosition _x select 1 == ctrlPosition _button select 1
            };
            
            if (_iconIndex != -1) then {
                private _icon = RTSUI_actionButtons select _iconIndex;
                _icon ctrlSetTextColor [1, 1, 1, if (_enabled) then {1} else {0.4}];
            };
        };
    } forEach RTSUI_actionOverlays;
};

// Selection change handler - called when selection changes
fnc_onSelectionChanged = {
    private _display = findDisplay 312;
    if (isNull _display) exitWith {};
    
    private _selections = curatorSelected select 0;
    systemChat format ["Selection changed: %1 units", count _selections];
    [_display, _selections] call fnc_createActionButtons;
};