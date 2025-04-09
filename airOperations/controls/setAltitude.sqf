// Set Altitude Control Function
// Handles changing aircraft altitude on demand

// === GAMEPLAY VARIABLES - ALTITUDE OPTIONS ===
AIR_OP_ALTITUDE_OPTIONS = [
    [100, "Very Low (100m)", "Improved ground attack accuracy, higher risk"],
    [300, "Low (300m)", "Standard combat altitude, balanced risk"],
    [500, "Medium (500m)", "Standard patrol altitude, reduced ground fire risk"],
    [800, "High (800m)", "Limited attack capability, minimal ground fire risk"],
    [1200, "Very High (1200m)", "Reconnaissance altitude, near immunity to ground fire"]
];

// Function to set aircraft altitude
AIR_OP_fnc_setAltitude = {
    // Get selected aircraft from UI
    private _aircraft = AIR_OP_selectedAircraft;
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected";
        diag_log "AIR_OPS ALTITUDE: No aircraft selected";
        false
    };
    
    // Create dialog for altitude selection
    disableSerialization;
    createDialog "RscDisplayEmpty";
    
    private _display = findDisplay -1;
    if (isNull _display) exitWith {
        systemChat "Could not create dialog";
        diag_log "AIR_OPS ALTITUDE: Failed to create dialog";
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
    _title ctrlSetText "Set Flight Altitude";
    _title ctrlSetTextColor [1, 1, 1, 1];
    _title ctrlSetBackgroundColor [0.2, 0.3, 0.5, 1];
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
    
    // Get current altitude
    private _currentAlt = ((getPosASL _aircraft) select 2) - ((getTerrainHeightASL (getPos _aircraft)) max 0);
    
    // Show current altitude
    private _currentAltText = _display ctrlCreate ["RscText", 5003];
    _currentAltText ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.38 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.03 * safezoneH
    ];
    _currentAltText ctrlSetText format ["Current altitude: %1m", round _currentAlt];
    _currentAltText ctrlSetTextColor [0.8, 0.8, 1, 1];
    _currentAltText ctrlCommit 0;
    
    // Create buttons for each altitude option
    private _buttonWidth = 0.35 * safezoneW;
    private _buttonHeight = 0.04 * safezoneH;
    private _buttonSpacing = 0.01 * safezoneH;
    private _startY = 0.42 * safezoneH + safezoneY;
    
    {
        _x params ["_altitude", "_displayName", "_description"];
        
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
        
        // Highlight current altitude range
        if (_currentAlt > (_altitude - 100) && _currentAlt < (_altitude + 100)) then {
            _button ctrlSetBackgroundColor [0.3, 0.5, 0.8, 1];
        } else {
            _button ctrlSetBackgroundColor [0.2, 0.2, 0.3, 1];
        };
        
        _button ctrlSetTooltip _description;
        
        // Set event handler
        _button ctrlSetEventHandler ["ButtonClick", format [
            "[%1, %2, '%3'] call AIR_OP_fnc_applyAltitude; closeDialog 0;",
            _aircraft,
            _altitude,
            _displayName
        ]];
        
        _button ctrlCommit 0;
        
    } forEach AIR_OP_ALTITUDE_OPTIONS;
    
    // Create custom altitude input
    private _customLabel = _display ctrlCreate ["RscText", 5200];
    _customLabel ctrlSetPosition [
        0.325 * safezoneW + safezoneX,
        0.65 * safezoneH + safezoneY,
        0.1 * safezoneW,
        0.03 * safezoneH
    ];
    _customLabel ctrlSetText "Custom:";
    _customLabel ctrlSetTextColor [1, 1, 1, 1];
    _customLabel ctrlCommit 0;
    
    private _customInput = _display ctrlCreate ["RscEdit", 5201];
    _customInput ctrlSetPosition [
        0.425 * safezoneW + safezoneX,
        0.65 * safezoneH + safezoneY,
        0.1 * safezoneW,
        0.03 * safezoneH
    ];
    _customInput ctrlSetText format ["%1", round _currentAlt];
    _customInput ctrlSetTextColor [1, 1, 1, 1];
    _customInput ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _customInput ctrlCommit 0;
    
    private _customButton = _display ctrlCreate ["RscButton", 5202];
    _customButton ctrlSetPosition [
        0.53 * safezoneW + safezoneX,
        0.65 * safezoneH + safezoneY,
        0.145 * safezoneW,
        0.03 * safezoneH
    ];
    _customButton ctrlSetText "Apply Custom";
    _customButton ctrlSetBackgroundColor [0.3, 0.3, 0.5, 1];
    _customButton ctrlSetEventHandler ["ButtonClick", format [
        "private _alt = parseNumber ctrlText 5201; if (_alt > 0) then { [%1, _alt, 'Custom ' + str _alt + 'm'] call AIR_OP_fnc_applyAltitude; }; closeDialog 0;",
        _aircraft
    ]];
    _customButton ctrlCommit 0;
    
    // Create close button
    private _closeBtn = _display ctrlCreate ["RscButton", 5999];
    _closeBtn ctrlSetPosition [
        0.325 * safezoneW + safezoneX,
        0.69 * safezoneH + safezoneY,
        _buttonWidth,
        _buttonHeight
    ];
    _closeBtn ctrlSetText "Close";
    _closeBtn ctrlSetBackgroundColor [0.4, 0.4, 0.4, 1];
    _closeBtn ctrlSetEventHandler ["ButtonClick", "closeDialog 0;"];
    _closeBtn ctrlCommit 0;
    
    true
};

// Function to apply the selected altitude
AIR_OP_fnc_applyAltitude = {
    params ["_aircraft", "_altitude", "_displayName"];
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected";
        false
    };
    
    // Get driver and group
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
    
    // Apply altitude setting
    _aircraft flyInHeight _altitude;
    
    // Update waypoints to maintain altitude
    {
        _x setWaypointStatements ["true", format ["vehicle this flyInHeight %1", _altitude]];
    } forEach waypoints _group;
    
    // Store altitude setting on the aircraft
    _aircraft setVariable ["AIR_OP_setAltitude", _altitude, true];
    
    // Apply immediate change in altitude with movement command
    private _pos = getPosASL _aircraft;
    _pos set [2, _altitude + (getTerrainHeightASL _pos)];
    _aircraft doMove _pos;
    
    // Monitor altitude to ensure it's maintained
    [_aircraft, _altitude] spawn {
        params ["_aircraft", "_targetAlt"];
        
        if (isNull _aircraft) exitWith {};
        
        for "_i" from 1 to 10 do {
            if (isNull _aircraft || !alive _aircraft) exitWith {};
            
            // Force altitude setting
            _aircraft flyInHeight _targetAlt;
            
            // Get current altitude
            private _currentAlt = ((getPosASL _aircraft) select 2) - ((getTerrainHeightASL (getPos _aircraft)) max 0);
            
            // If off by more than 50m, apply correction
            if (abs(_currentAlt - _targetAlt) > 50) then {
                private _pos = getPosASL _aircraft;
                _pos set [2, _targetAlt + (getTerrainHeightASL _pos)];
                _aircraft doMove _pos;
            };
            
            sleep 5;
        };
    };
    
    systemChat format ["Altitude set to %1", _displayName];
    true
};