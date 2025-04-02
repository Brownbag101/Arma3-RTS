// Set Speed Control Function
// Adjusts the flying speed of selected aircraft

// === GAMEPLAY VARIABLES - ADJUST SPEED PRESETS HERE ===
AIR_OP_SPEED_PRESETS = [
    ["LIMITED", "Economical cruise speed - maximizes fuel efficiency"],
    ["NORMAL", "Standard cruising speed - balanced performance"],
    ["FULL", "Maximum speed - rapid response but higher fuel consumption"]
];

AIR_OP_fnc_setSpeed = {
    // Use the currently selected aircraft or the one passed as parameter
    params [["_aircraft", AIR_OP_selectedAircraft]];
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected for speed adjustment";
        diag_log "AIR_OPS SPEED: No aircraft selected";
        false
    };
    
    
    
    // Create dialog for speed selection - Zeus compatible approach
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
        diag_log "AIR_OPS SPEED: Failed to create dialog";
        systemChat "Could not create speed adjustment dialog";
        false
    };
    
    // Create background
    private _background = _display ctrlCreate ["RscText", 1000];
    _background ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.35 * safezoneH + safezoneY, 0.4 * safezoneW, 0.3 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", 1001];
    _title ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.35 * safezoneH + safezoneY, 0.4 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _title ctrlSetText "Set Aircraft Speed";
    _title ctrlCommit 0;
    
    // Create aircraft info
    private _aircraftType = getText (configFile >> "CfgVehicles" >> typeOf _aircraft >> "displayName");
    private _info = _display ctrlCreate ["RscText", 1002];
    _info ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.4 * safezoneH + safezoneY, 0.4 * safezoneW, 0.05 * safezoneH];
    _info ctrlSetText format ["Aircraft: %1", _aircraftType];
    _info ctrlCommit 0;
    
    // Create speed list
    private _list = _display ctrlCreate ["RscListBox", 1003];
    _list ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.46 * safezoneH + safezoneY, 0.36 * safezoneW, 0.12 * safezoneH];
    _list ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _list ctrlCommit 0;
    
    // Fill speed presets
    {
        _x params ["_name", "_description"];
        private _index = _list lbAdd _name;
        _list lbSetData [_index, _name];
        _list lbSetTooltip [_index, _description];
    } forEach AIR_OP_SPEED_PRESETS;
    
    // Create description text
    private _description = _display ctrlCreate ["RscStructuredText", 1004];
    _description ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.59 * safezoneH + safezoneY, 0.36 * safezoneW, 0.09 * safezoneH];
    _description ctrlSetStructuredText parseText "Select a speed setting for the aircraft.";
    _description ctrlCommit 0;
    
    // Handle list selection - update description
    _list ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        
        private _display = ctrlParent _control;
        private _description = _display displayCtrl 1004;
        
        private _preset = AIR_OP_SPEED_PRESETS select _selectedIndex;
        _description ctrlSetStructuredText parseText format ["<t size='0.9'>%1</t>", _preset select 1];
    }];
    
    // Create buttons
    private _confirmBtn = _display ctrlCreate ["RscButton", 1005];
    _confirmBtn ctrlSetPosition [0.48 * safezoneW + safezoneX, 0.59 * safezoneH + safezoneY, 0.2 * safezoneW, 0.05 * safezoneH];
    _confirmBtn ctrlSetText "Confirm";
    _confirmBtn ctrlSetBackgroundColor [0.2, 0.6, 0.2, 1];
    _confirmBtn ctrlCommit 0;
    
    private _cancelBtn = _display ctrlCreate ["RscButton", 1006];
    _cancelBtn ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.59 * safezoneH + safezoneY, 0.15 * safezoneW, 0.05 * safezoneH];
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
        
        // Get speed from selection
        private _list = _display displayCtrl 1003;
        private _selectedIndex = lbCurSel _list;
        
        if (_selectedIndex == -1) exitWith {
            systemChat "No speed setting selected";
            [] call AIR_OP_fnc_forceCloseDialog;
        };
        
        private _speedSetting = _list lbData _selectedIndex;
        
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
        
        // Apply speed setting to group
        _group setSpeedMode _speedSetting;
        
        // Update all waypoints - safer approach
        if (waypoints _group isEqualType []) then {
            {
                if (_x isEqualType []) then {
                    _x setWaypointSpeed _speedSetting;
                };
            } forEach waypoints _group;
        } else {
            // Alternative waypoint iteration approach
            for "_i" from 0 to (count waypoints _group - 1) do {
                private _wp = [_group, _i];
                _wp setWaypointSpeed _speedSetting;
            };
        };
        
        // Give feedback
        systemChat format ["%1 speed set to %2", getText (configFile >> "CfgVehicles" >> typeOf _aircraft >> "displayName"), _speedSetting];
        
        [] call AIR_OP_fnc_forceCloseDialog;
    }];
    
    _cancelBtn ctrlAddEventHandler ["ButtonClick", {
        [] call AIR_OP_fnc_forceCloseDialog;
    }];
    
    // Select Normal speed by default
    _list lbSetCurSel 1;
    
    true
};

// Test function for speed adjustment
AIR_OP_fnc_testSetSpeed = {
    private _deployedAircraft = [] call AIR_OP_fnc_getDeployedAircraft;
    
    if (count _deployedAircraft > 0) then {
        [_deployedAircraft select 0] call AIR_OP_fnc_setSpeed;
    } else {
        systemChat "No deployed aircraft found for speed test";
    };
};