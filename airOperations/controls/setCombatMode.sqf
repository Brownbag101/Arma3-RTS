// Set Combat Mode Control Function
// Adjusts the combat behavior of selected aircraft

// === GAMEPLAY VARIABLES - ADJUST COMBAT MODE PRESETS HERE ===
AIR_OP_COMBAT_PRESETS = [
    ["BLUE", "Never fire - aircraft will not engage any targets", "\a3\ui_f\data\igui\cfg\commandbar\holdfire_ca.paa"],
    ["GREEN", "Hold fire, defend only - aircraft will only fire when fired upon", "\a3\ui_f\data\igui\cfg\commandbar\holdfire_ca.paa"],
    ["WHITE", "Hold fire, engage at will - aircraft will engage spotted targets but won't actively hunt", "\a3\ui_f\data\igui\cfg\commandbar\attack_ca.paa"],
    ["YELLOW", "Fire at will - aircraft will actively engage spotted enemies", "\a3\ui_f\data\igui\cfg\commandbar\attack_ca.paa"],
    ["RED", "Fire at will, engage at will - maximum aggression", "\a3\ui_f\data\igui\cfg\commandbar\attack_ca.paa"]
];

AIR_OP_fnc_setCombatMode = {
    // Use the currently selected aircraft or the one passed as parameter
    params [["_aircraft", AIR_OP_selectedAircraft]];
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected for combat mode adjustment";
        diag_log "AIR_OPS COMBAT: No aircraft selected";
        false
    };
    
    
    
    // Create dialog for combat mode selection - Zeus compatible approach
    disableSerialization;
    private _display = findDisplay 312; // Zeus display
    
    // If we're in Zeus, create the dialog as a child of Zeus display
    if (!isNull _display) then {
        _display createDisplay "RscDisplayEmpty";
        _display = findDisplay -1;
    } else {
        // Outside Zeus, create dialog normally
        createDialog "RscDisplayEmpty";
        _display = findDisplay -1;
    };
    
    if (isNull _display) exitWith {
        diag_log "AIR_OPS COMBAT: Failed to create dialog";
        systemChat "Could not create combat mode dialog";
        false
    };
    
    // Create background
    private _background = _display ctrlCreate ["RscText", 1000];
    _background ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.35 * safezoneH + safezoneY, 0.4 * safezoneW, 0.4 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", 1001];
    _title ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.35 * safezoneH + safezoneY, 0.4 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _title ctrlSetText "Set Combat Mode";
    _title ctrlCommit 0;
    
    // Create aircraft info
    private _aircraftType = getText (configFile >> "CfgVehicles" >> typeOf _aircraft >> "displayName");
    private _info = _display ctrlCreate ["RscText", 1002];
    _info ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.4 * safezoneH + safezoneY, 0.4 * safezoneW, 0.05 * safezoneH];
    _info ctrlSetText format ["Aircraft: %1", _aircraftType];
    _info ctrlCommit 0;
    
    // Show current mode
    private _driver = driver _aircraft;
    private _currentMode = "UNKNOWN";
    
    if (!isNull _driver) then {
        private _group = group _driver;
        if (!isNull _group) then {
            _currentMode = combatMode _group;
        };
    };
    
    private _currentInfo = _display ctrlCreate ["RscText", 1003];
    _currentInfo ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.45 * safezoneH + safezoneY, 0.4 * safezoneW, 0.05 * safezoneH];
    _currentInfo ctrlSetText format ["Current Mode: %1", _currentMode];
    _currentInfo ctrlCommit 0;
    
    // Create mode list
    private _list = _display ctrlCreate ["RscListBox", 1004];
    _list ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.5 * safezoneH + safezoneY, 0.36 * safezoneW, 0.18 * safezoneH];
    _list ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _list ctrlCommit 0;
    
    // Fill combat mode presets
    {
        _x params ["_name", "_description", "_icon"];
        private _index = _list lbAdd _name;
        _list lbSetData [_index, _name];
        _list lbSetTooltip [_index, _description];
        
        // Set color based on aggression level
        switch (_name) do {
            case "BLUE": { _list lbSetColor [_index, [0.5, 0.5, 1, 1]]; };
            case "GREEN": { _list lbSetColor [_index, [0.5, 1, 0.5, 1]]; };
            case "WHITE": { _list lbSetColor [_index, [1, 1, 1, 1]]; };
            case "YELLOW": { _list lbSetColor [_index, [1, 1, 0.5, 1]]; };
            case "RED": { _list lbSetColor [_index, [1, 0.5, 0.5, 1]]; };
        };
        
        // Set the same index as current mode
        if (_name == _currentMode) then {
            _list lbSetCurSel _index;
        };
    } forEach AIR_OP_COMBAT_PRESETS;
    
    // Create description text
    private _description = _display ctrlCreate ["RscStructuredText", 1005];
    _description ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.69 * safezoneH + safezoneY, 0.36 * safezoneW, 0.09 * safezoneH];
    _description ctrlSetStructuredText parseText "Select a combat mode for the aircraft.";
    _description ctrlCommit 0;
    
    // Handle list selection - update description
    _list ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        
        private _display = ctrlParent _control;
        private _description = _display displayCtrl 1005;
        
        private _preset = AIR_OP_COMBAT_PRESETS select _selectedIndex;
        _description ctrlSetStructuredText parseText format ["<t size='0.9'>%1</t>", _preset select 1];
    }];
    
    // Create buttons
    private _confirmBtn = _display ctrlCreate ["RscButton", 1006];
    _confirmBtn ctrlSetPosition [0.48 * safezoneW + safezoneX, 0.69 * safezoneH + safezoneY, 0.2 * safezoneW, 0.05 * safezoneH];
    _confirmBtn ctrlSetText "Confirm";
    _confirmBtn ctrlSetBackgroundColor [0.2, 0.6, 0.2, 1];
    _confirmBtn ctrlCommit 0;
    
    private _cancelBtn = _display ctrlCreate ["RscButton", 1007];
    _cancelBtn ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.69 * safezoneH + safezoneY, 0.15 * safezoneW, 0.05 * safezoneH];
    _cancelBtn ctrlSetText "Cancel";
    _cancelBtn ctrlSetBackgroundColor [0.6, 0.2, 0.2, 1];
    _cancelBtn ctrlCommit 0;
    
    // Add handlers
    _confirmBtn ctrlAddEventHandler ["ButtonClick", {
        params ["_control"];
        private _display = ctrlParent _control;
        
        // Get the selected aircraft
        private _aircraft = AIR_OP_selectedAircraft;
        
        if (isNull _aircraft) exitWith {
            systemChat "No aircraft selected";
            [] call AIR_OP_fnc_forceCloseDialog;
        };
        
        // Get combat mode from selection
        private _list = _display displayCtrl 1004;
        private _selectedIndex = lbCurSel _list;
        
        if (_selectedIndex == -1) exitWith {
            systemChat "No combat mode selected";
            [] call AIR_OP_fnc_forceCloseDialog;
        };
        
        private _combatMode = _list lbData _selectedIndex;
        
        // Get aircraft group
        private _driver = driver _aircraft;
        if (isNull _driver) exitWith {
            systemChat "Aircraft has no pilot";
            [] call AIR_OP_fnc_forceCloseDialog;
        };
        
        private _group = group _driver;
        if (isNull _group) exitWith {
            systemChat "Pilot has no group";
            [] call AIR_OP_fnc_forceCloseDialog;
        };
        
        // Apply combat mode to group
        _group setCombatMode _combatMode;
        
        // Set behavior based on combat mode
        switch (_combatMode) do {
            case "BLUE": { _group setBehaviour "CARELESS"; };
            case "GREEN": { _group setBehaviour "SAFE"; };
            case "WHITE": { _group setBehaviour "AWARE"; };
            case "YELLOW": { _group setBehaviour "AWARE"; };
            case "RED": { _group setBehaviour "COMBAT"; };
        };
        
        // Update all waypoints - safer approach
        if (waypoints _group isEqualType []) then {
            {
                if (_x isEqualType []) then {
                    _x setWaypointCombatMode _combatMode;
                };
            } forEach waypoints _group;
        } else {
            // Alternative waypoint iteration approach
            for "_i" from 0 to (count waypoints _group - 1) do {
                private _wp = [_group, _i];
                _wp setWaypointCombatMode _combatMode;
            };
        };
        
        // Give feedback
        systemChat format ["%1 combat mode set to %2", getText (configFile >> "CfgVehicles" >> typeOf _aircraft >> "displayName"), _combatMode];
        
        [] call AIR_OP_fnc_forceCloseDialog;
    }];
    
    _cancelBtn ctrlAddEventHandler ["ButtonClick", {
        [] call AIR_OP_fnc_forceCloseDialog;
    }];
    
    // Select current combat mode or YELLOW by default
    if (lbCurSel _list == -1) then {
        private _defaultIndex = 3; // YELLOW
        {
            if (_x select 0 == _currentMode) exitWith {
                _defaultIndex = _forEachIndex;
            };
        } forEach AIR_OP_COMBAT_PRESETS;
        
        _list lbSetCurSel _defaultIndex;
    };
    
    true
};

// Test function for combat mode adjustment
AIR_OP_fnc_testSetCombatMode = {
    private _deployedAircraft = [] call AIR_OP_fnc_getDeployedAircraft;
    
    if (count _deployedAircraft > 0) then {
        [_deployedAircraft select 0] call AIR_OP_fnc_setCombatMode;
    } else {
        systemChat "No deployed aircraft found for combat mode test";
    };
};