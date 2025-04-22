// Set Speed Control Function
// Handles changing aircraft speed on demand

// === GAMEPLAY VARIABLES - SPEED OPTIONS ===
AIR_OP_SPEED_OPTIONS = [
    ["LIMITED", "Cruise Speed", [0.2, 0.6, 0.9, 1], "Efficient fuel usage, extended loiter time"],
    ["NORMAL", "Combat Speed", [0.3, 0.7, 0.3, 1], "Standard operational speed"],
    ["FULL", "Maximum Speed", [0.9, 0.3, 0.3, 1], "High fuel consumption, improved evasion"]
];

// Function to set aircraft speed
AIR_OP_fnc_setSpeed = {
    // Get selected aircraft from UI
    private _aircraft = AIR_OP_selectedAircraft;
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected";
        diag_log "AIR_OPS SPEED: No aircraft selected";
        false
    };
    
    // Create dialog for speed selection
    disableSerialization;
    createDialog "RscDisplayEmpty";
    
    private _display = findDisplay -1;
    if (isNull _display) exitWith {
        systemChat "Could not create dialog";
        diag_log "AIR_OPS SPEED: Failed to create dialog";
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
    _title ctrlSetText "Set Aircraft Speed";
    _title ctrlSetTextColor [1, 1, 1, 1];
    _title ctrlSetBackgroundColor [0.2, 0.4, 0.3, 1];
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
    
    // Get current speed
    private _speed = speed _aircraft;
    
    // Show current speed
    private _currentSpeedText = _display ctrlCreate ["RscText", 5003];
    _currentSpeedText ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.38 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.03 * safezoneH
    ];
    _currentSpeedText ctrlSetText format ["Current speed: %1 km/h", round _speed];
    _currentSpeedText ctrlSetTextColor [0.8, 1, 0.8, 1];
    _currentSpeedText ctrlCommit 0;
    
    // Create info about fuel consumption
    private _fuelInfo = _display ctrlCreate ["RscText", 5004];
    _fuelInfo ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.41 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.03 * safezoneH
    ];
    _fuelInfo ctrlSetText "Note: Higher speeds increase fuel consumption";
    _fuelInfo ctrlSetTextColor [1, 0.8, 0.6, 1];
    _fuelInfo ctrlCommit 0;
    
    // Create buttons for each speed option
    private _buttonWidth = 0.35 * safezoneW;
    private _buttonHeight = 0.07 * safezoneH;
    private _buttonSpacing = 0.01 * safezoneH;
    private _startY = 0.45 * safezoneH + safezoneY;
    
    {
        _x params ["_speedMode", "_displayName", "_color", "_description"];
        
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
        
        // Add speed estimate based on aircraft type
        private _speedEstimate = "";
        private _maxSpeed = getNumber (configFile >> "CfgVehicles" >> typeOf _aircraft >> "maxSpeed");
        
        if (_maxSpeed == 0) then {
            // If not found in config, use default estimates
            switch (_speedMode) do {
                case "LIMITED": { _speedEstimate = "~250 km/h"; };
                case "NORMAL": { _speedEstimate = "~350 km/h"; };
                case "FULL": { _speedEstimate = "~450 km/h"; };
            };
        } else {
            // Calculate based on config max speed
            private _speedMult = switch (_speedMode) do {
                case "LIMITED": { 0.6 };
                case "NORMAL": { 0.8 };
                case "FULL": { 1.0 };
                default { 0.7 };
            };
            
            _speedEstimate = format ["~%1 km/h", round (_maxSpeed * _speedMult)];
        };
        
        // Add info about fuel consumption
        private _fuelUse = switch (_speedMode) do {
            case "LIMITED": { "Low Fuel Use"; };
            case "NORMAL": { "Medium Fuel Use"; };
            case "FULL": { "High Fuel Use"; };
            default { ""; };
        };
        
        private _buttonText = format ["%1\n%2\n%3", _displayName, _speedEstimate, _fuelUse];
        _button ctrlSetText _buttonText;
        _button ctrlSetTooltip _description;
        
        // Set event handler
        _button ctrlSetEventHandler ["ButtonClick", format [
            "[%1, '%2', '%3'] call AIR_OP_fnc_applySpeed; closeDialog 0;",
            _aircraft,
            _speedMode,
            _displayName
        ]];
        
        _button ctrlCommit 0;
        
    } forEach AIR_OP_SPEED_OPTIONS;
    
    // Create close button
    private _closeBtn = _display ctrlCreate ["RscButton", 5999];
    _closeBtn ctrlSetPosition [
        0.325 * safezoneW + safezoneX,
        0.69 * safezoneH + safezoneY,
        _buttonWidth,
        0.04 * safezoneH
    ];
    _closeBtn ctrlSetText "Close";
    _closeBtn ctrlSetBackgroundColor [0.4, 0.4, 0.4, 1];
    _closeBtn ctrlSetEventHandler ["ButtonClick", "closeDialog 0;"];
    _closeBtn ctrlCommit 0;
    
    true
};

// Function to apply the selected speed
AIR_OP_fnc_applySpeed = {
    params ["_aircraft", "_speedMode", "_displayName"];
    
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
    
    // Apply speed to group
    _group setSpeedMode _speedMode;
    
    // Update all waypoints with the new speed
    {
        _x setWaypointSpeed _speedMode;
    } forEach waypoints _group;
    
    // Store speed setting on the aircraft
    _aircraft setVariable ["AIR_OP_speedMode", _speedMode, true];
    
    // Apply immediate speed change
    switch (_speedMode) do {
        case "LIMITED": {
            // Apply cruise speed settings
            _aircraft limitSpeed 250; // Limit top speed for better fuel economy
            
            // Update pilot behavior
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    _x setSkill ["spotDistance", 0.8]; // Better observation when slower
                    _x setSkill ["spotTime", 0.7];
                };
            } forEach crew _aircraft;
            
            // Enable fuel saving
            [_aircraft] spawn {
                params ["_aircraft"];
                
                // Only continue if aircraft exists and speed mode hasn't changed
                while {!isNull _aircraft && alive _aircraft && (_aircraft getVariable ["AIR_OP_speedMode", ""]) == "LIMITED"} do {
                    // Reduce fuel consumption
                    private _currentFuel = fuel _aircraft;
                    private _newFuel = _currentFuel + 0.001; // Small boost to compensate for lower speed
                    _aircraft setFuel (_newFuel min 1);
                    
                    sleep 10;
                };
            };
        };
        
        case "NORMAL": {
            // Standard combat speed
            _aircraft limitSpeed -1; // No artificial limit
            
            // Balanced pilot settings
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    _x setSkill ["spotDistance", 0.7];
                    _x setSkill ["spotTime", 0.7];
                };
            } forEach crew _aircraft;
        };
        
        case "FULL": {
            // Maximum speed
            _aircraft limitSpeed -1; // No speed limit
            
            // Adjust pilot skills
            {
                if (_x getVariable ["HANGAR_isPilot", false]) then {
                    _x setSkill ["spotDistance", 0.6]; // Harder to spot targets at high speed
                    _x setSkill ["spotTime", 0.5];
                };
            } forEach crew _aircraft;
            
            // Increased fuel consumption
            [_aircraft] spawn {
                params ["_aircraft"];
                
                // Only continue if aircraft exists and speed mode hasn't changed
                while {!isNull _aircraft && alive _aircraft && (_aircraft getVariable ["AIR_OP_speedMode", ""]) == "FULL"} do {
                    // Increase fuel consumption
                    private _currentFuel = fuel _aircraft;
                    private _newFuel = _currentFuel - 0.002; // Extra consumption at max speed
                    _aircraft setFuel (_newFuel max 0);
                    
                    sleep 10;
                };
            };
        };
    };
    
    systemChat format ["Speed set to %1", _displayName];
    true
};