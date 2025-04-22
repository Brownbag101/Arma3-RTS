// Set Combat Mode Control Function
// Handles changing aircraft combat behavior on demand

// === GAMEPLAY VARIABLES - COMBAT MODE OPTIONS ===
AIR_OP_COMBAT_MODES = [
    ["BLUE", "Weapons Hold", [0.2, 0.2, 0.8, 1], "Hold fire unless directly fired upon"],
    ["GREEN", "Weapons Free", [0.2, 0.8, 0.2, 1], "Return fire only"],
    ["YELLOW", "Fire At Will", [0.8, 0.8, 0.2, 1], "Engage detected targets when convenient"],
    ["RED", "Engage At Will", [0.8, 0.2, 0.2, 1], "Actively seek and engage all targets"]
];

// Function to set aircraft combat mode
AIR_OP_fnc_setCombatMode = {
    // Get selected aircraft from UI
    private _aircraft = AIR_OP_selectedAircraft;
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected";
        diag_log "AIR_OPS COMBAT: No aircraft selected";
        false
    };
    
    // Check if aircraft is on RTB - don't change combat mode
    if (_aircraft getVariable ["AIR_OP_RTB", false]) exitWith {
        systemChat "Cannot change combat mode while aircraft is returning to base";
        diag_log "AIR_OPS COMBAT: Aircraft is RTB, cannot change mode";
        false
    };
    
    // Create dialog for mode selection
    disableSerialization;
    createDialog "RscDisplayEmpty";
    
    private _display = findDisplay -1;
    if (isNull _display) exitWith {
        systemChat "Could not create dialog";
        diag_log "AIR_OPS COMBAT: Failed to create dialog";
        false
    };
    
    // Create background
    private _background = _display ctrlCreate ["RscText", 5000];
    _background ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.3 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.4 * safezoneH
    ];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", 5001];
    _title ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.3 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.05 * safezoneH
    ];
    _title ctrlSetText "Set Combat Mode";
    _title ctrlSetTextColor [1, 1, 1, 1];
    _title ctrlSetBackgroundColor [0.2, 0.2, 0.4, 1];
    _title ctrlCommit 0;
    
    // Get aircraft display name
    private _aircraftName = getText (configFile >> "CfgVehicles" >> typeOf _aircraft >> "displayName");
    
    // Create subtitle with aircraft name
    private _subtitle = _display ctrlCreate ["RscText", 5002];
    _subtitle ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.35 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.03 * safezoneH
    ];
    _subtitle ctrlSetText format ["Aircraft: %1", _aircraftName];
    _subtitle ctrlSetTextColor [1, 1, 1, 1];
    _subtitle ctrlCommit 0;
    
    // Create buttons for each combat mode
    private _buttonWidth = 0.35 * safezoneW;
    private _buttonHeight = 0.04 * safezoneH;
    private _buttonSpacing = 0.01 * safezoneH;
    private _startY = 0.4 * safezoneH + safezoneY;
    
    {
        _x params ["_mode", "_displayName", "_color", "_description"];
        
        private _buttonY = _startY + (_forEachIndex * (_buttonHeight + _buttonSpacing));
        
        // Create button
        private _button = _display ctrlCreate ["RscButton", 5100 + _forEachIndex];
        _button ctrlSetPosition [
            0.325 * safezoneW + safezoneX,
            _buttonY,
            _buttonWidth,
            _buttonHeight
        ];
        _button ctrlSetText _displayName;
        _button ctrlSetBackgroundColor _color;
        _button ctrlSetTooltip _description;
        
        // Set event handler
        _button ctrlSetEventHandler ["ButtonClick", format [
            "[%1, '%2', '%3'] call AIR_OP_fnc_applyCombatMode; closeDialog 0;",
            _aircraft,
            _mode,
            _displayName
        ]];
        
        _button ctrlCommit 0;
        
    } forEach AIR_OP_COMBAT_MODES;
    
    // Create close button
    private _closeBtn = _display ctrlCreate ["RscButton", 5999];
    _closeBtn ctrlSetPosition [
        0.325 * safezoneW + safezoneX,
        0.62 * safezoneH + safezoneY,
        _buttonWidth,
        _buttonHeight
    ];
    _closeBtn ctrlSetText "Close";
    _closeBtn ctrlSetBackgroundColor [0.4, 0.4, 0.4, 1];
    _closeBtn ctrlSetEventHandler ["ButtonClick", "closeDialog 0;"];
    _closeBtn ctrlCommit 0;
    
    true
};

// Function to apply the selected combat mode
AIR_OP_fnc_applyCombatMode = {
    params ["_aircraft", "_mode", "_displayName"];
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected";
        false
    };
    
    // Apply to driver's group
    private _driver = driver _aircraft;
    if (isNull _driver) exitWith {
        systemChat "No pilot found in aircraft";
        false
    };
    
    private _group = group _driver;
    if (isNull _group) exitWith {
        systemChat "No valid group for pilot";
        false
    };
    
    // Apply combat mode
    _group setCombatMode _mode;
    
    // Apply corresponding behavior
    switch (_mode) do {
        case "BLUE": {
            _group setBehaviour "CARELESS";
            
            // Disable target AI but leave movement AI
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    _x disableAI "TARGET";
                    _x disableAI "AUTOTARGET";
                };
            } forEach crew _aircraft;
        };
        case "GREEN": {
            _group setBehaviour "AWARE";
            
            // Enable AI for targeting but set restrictive behavior
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    _x enableAI "TARGET";
                    _x enableAI "AUTOTARGET";
                };
            } forEach crew _aircraft;
        };
        case "YELLOW": {
            _group setBehaviour "COMBAT";
            
            // Enable AI fully
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    _x enableAI "TARGET";
                    _x enableAI "AUTOTARGET";
                    _x enableAI "WEAPONAIM";
                };
            } forEach crew _aircraft;
        };
        case "RED": {
            _group setBehaviour "COMBAT";
            
            // Fully enable combat AI
            if (!isNil "AIR_OP_fnc_enableCombatAI") then {
                [_aircraft] call AIR_OP_fnc_enableCombatAI;
            } else {
                // Fallback if function not available
                {
                    if (_x getVariable ["HANGAR_isPilot", false]) then {
                        _x enableAI "ALL";
                        _x enableAI "TARGET";
                        _x enableAI "AUTOTARGET";
                    };
                } forEach crew _aircraft;
            };
        };
    };
    
    // Update any active missions
    private _onMission = false;
    private _missionType = "";
    
    {
        _x params ["_id", "_missionAircraft", "_type"];
        if (_missionAircraft == _aircraft) exitWith {
            _onMission = true;
            _missionType = _type;
        };
    } forEach AIR_OP_activeMissions;
    
    if (_onMission) then {
        // For certain mission types and RED combat mode, re-initialize mission
        if (_mode == "RED" && (_missionType in ["cas", "airsup", "patrol"])) then {
            [_missionType, _aircraft, _targetIndex, _targetType] call AIR_OP_fnc_executeMission;
        };
    };
    
    systemChat format ["Combat Mode set to %1", _displayName];
    true
};