// Set Altitude Control Function
// Adjusts the flying height of selected aircraft

// === GAMEPLAY VARIABLES - ADJUST ALTITUDE PRESETS HERE ===
AIR_OP_ALTITUDE_PRESETS = [
    ["Very Low", 100, "Nap of the earth flying - increased concealment but vulnerable to ground fire"],
    ["Low", 200, "Low altitude - good balance between concealment and maneuverability"],
    ["Medium", 500, "Standard cruising altitude - balanced performance"],
    ["High", 1000, "High altitude - safer from ground fire but more visible to radar"],
    ["Very High", 2000, "Maximum operational altitude - safest from ground fire"]
];

// Function to force close any open dialog
AIR_OP_fnc_forceCloseDialog = {
    disableSerialization;
    private _display = findDisplay -1;
    if (!isNull _display) then {
        _display closeDisplay 1;
    };
    
    // Also check for other potential dialog IDs that might be open
    {
        private _d = findDisplay _x;
        if (!isNull _d) then {
            _d closeDisplay 1;
        };
    } forEach [312000, -1390, 46];
    
    // Return to Zeus if needed
    private _zeusDisplay = findDisplay 312;
    if (!isNull _zeusDisplay) then {
        ctrlActivate (_zeusDisplay displayCtrl 15717);
    };
};

AIR_OP_fnc_setAltitude = {
    // Use the currently selected aircraft or the one passed as parameter
    params [["_aircraft", AIR_OP_selectedAircraft]];
    
    if (isNull _aircraft) exitWith {
        systemChat "No aircraft selected for altitude adjustment";
        diag_log "AIR_OPS ALTITUDE: No aircraft selected";
        false
    };
    
    // Force close any existing dialogs first
    
    
    // Create dialog for altitude selection using an alternative approach
    // Instead of calling createDialog directly, which might cause issues in Zeus
    // we'll use the findDisplay command first to make sure we don't have conflicts
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
        diag_log "AIR_OPS ALTITUDE: Failed to create dialog";
        systemChat "Could not create altitude adjustment dialog";
        false
    };
    
    // Create background
    private _background = _display ctrlCreate ["RscText", 1000];
    _background ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.3 * safezoneH + safezoneY, 0.4 * safezoneW, 0.4 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", 1001];
    _title ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.3 * safezoneH + safezoneY, 0.4 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _title ctrlSetText "Set Aircraft Altitude";
    _title ctrlCommit 0;
    
    // Create aircraft info
    private _aircraftType = getText (configFile >> "CfgVehicles" >> typeOf _aircraft >> "displayName");
    private _info = _display ctrlCreate ["RscText", 1002];
    _info ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.35 * safezoneH + safezoneY, 0.4 * safezoneW, 0.05 * safezoneH];
    _info ctrlSetText format ["Aircraft: %1", _aircraftType];
    _info ctrlCommit 0;
    
    // Create altitude list
    private _list = _display ctrlCreate ["RscListBox", 1003];
    _list ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.41 * safezoneH + safezoneY, 0.36 * safezoneW, 0.2 * safezoneH];
    _list ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _list ctrlCommit 0;
    
    // Fill altitude presets
    {
        _x params ["_name", "_altitude", "_description"];
        private _index = _list lbAdd format ["%1 (%2m)", _name, _altitude];
        _list lbSetData [_index, str _altitude];
        _list lbSetTooltip [_index, _description];
    } forEach AIR_OP_ALTITUDE_PRESETS;
    
    // Create custom altitude input
    private _customLabel = _display ctrlCreate ["RscText", 1004];
    _customLabel ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.62 * safezoneH + safezoneY, 0.15 * safezoneW, 0.04 * safezoneH];
    _customLabel ctrlSetText "Custom Altitude:";
    _customLabel ctrlCommit 0;
    
    private _customInput = _display ctrlCreate ["RscEdit", 1005];
    _customInput ctrlSetPosition [0.48 * safezoneW + safezoneX, 0.62 * safezoneH + safezoneY, 0.2 * safezoneW, 0.04 * safezoneH];
    _customInput ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _customInput ctrlSetText "500"; // Default value
    _customInput ctrlCommit 0;
    
    // Create description text
    private _description = _display ctrlCreate ["RscStructuredText", 1006];
    _description ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.52 * safezoneH + safezoneY, 0.36 * safezoneW, 0.09 * safezoneH];
    _description ctrlSetStructuredText parseText "Select a preset altitude or enter a custom value in meters.";
    _description ctrlCommit 0;
    
    // Handle list selection - update description
    _list ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        
        private _display = ctrlParent _control;
        private _description = _display displayCtrl 1006;
        
        private _preset = AIR_OP_ALTITUDE_PRESETS select _selectedIndex;
        _description ctrlSetStructuredText parseText format ["<t size='0.9'>%1</t>", _preset select 2];
        
        // Update custom input to match selection
        private _customInput = _display displayCtrl 1005;
        _customInput ctrlSetText str (_preset select 1);
    }];
    
    // Create buttons
    private _confirmBtn = _display ctrlCreate ["RscButton", 1007];
    _confirmBtn ctrlSetPosition [0.48 * safezoneW + safezoneX, 0.67 * safezoneH + safezoneY, 0.2 * safezoneW, 0.05 * safezoneH];
    _confirmBtn ctrlSetText "Confirm";
    _confirmBtn ctrlSetBackgroundColor [0.2, 0.6, 0.2, 1];
    _confirmBtn ctrlCommit 0;
    
    private _cancelBtn = _display ctrlCreate ["RscButton", 1008];
    _cancelBtn ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.67 * safezoneH + safezoneY, 0.15 * safezoneW, 0.05 * safezoneH];
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
        
        // Get altitude from input field
        private _customInput = _display displayCtrl 1005;
        private _altitudeStr = ctrlText _customInput;
        private _altitude = parseNumber _altitudeStr;
        
        // Validate altitude
        if (_altitude < 50) then { _altitude = 50; }; // Minimum altitude
        if (_altitude > 5000) then { _altitude = 5000; }; // Maximum altitude
        
        // Apply altitude
        _aircraft flyInHeight _altitude;
        
        // Give feedback
        systemChat format ["%1 altitude set to %2m", getText (configFile >> "CfgVehicles" >> typeOf _aircraft >> "displayName"), _altitude];
        
        // Update waypoints if needed - FIXED WAYPOINT CODE
        private _driver = driver _aircraft;
        if (!isNull _driver) then {
            private _group = group _driver;
            if (!isNull _group) then {
                // Safer waypoint handling - guard against unexpected data types
                private _allWaypoints = waypoints _group;
                
                if (_allWaypoints isEqualType []) then {
                    {
                        if (_x isEqualType []) then {
                            private _wpPos = waypointPosition _x;
                            if (count _wpPos >= 3) then {
                                _wpPos set [2, _altitude];
                                _x setWaypointPosition [_wpPos, 0];
                            };
                        };
                    } forEach _allWaypoints;
                } else {
                    // Alternative waypoint iteration approach
                    for "_i" from 0 to (count waypoints _group - 1) do {
                        private _wp = [_group, _i];
                        private _wpPos = waypointPosition _wp;
                        if (count _wpPos >= 3) then {
                            _wpPos set [2, _altitude];
                            _wp setWaypointPosition [_wpPos, 0];
                        };
                    };
                };
            };
        };
        
        [] call AIR_OP_fnc_forceCloseDialog;
    }];
    
    _cancelBtn ctrlAddEventHandler ["ButtonClick", {
        [] call AIR_OP_fnc_forceCloseDialog;
    }];
    
    // Select first item by default
    if (lbSize _list > 0) then {
        _list lbSetCurSel 2; // Medium altitude by default
    };
    
    true
};

// Test function for altitude adjustment
AIR_OP_fnc_testSetAltitude = {
    private _deployedAircraft = [] call AIR_OP_fnc_getDeployedAircraft;
    
    if (count _deployedAircraft > 0) then {
        [_deployedAircraft select 0] call AIR_OP_fnc_setAltitude;
    } else {
        systemChat "No deployed aircraft found for altitude test";
    };
};