// scripts/economy/economyUI.sqf
// UI for displaying economy system resources

// Controls array to keep track of all UI elements
RTS_economyControls = [];

// Function to create the resource display UI
RTS_fnc_createResourceUI = {
    // Only create UI if it doesn't exist
    if (count RTS_economyControls > 0) exitWith {};
    
    // Create display layer for UI
    if (isNil "RTS_economyLayer") then {
        RTS_economyLayer = "RTS_Economy" call BIS_fnc_rscLayer;
    };
    
    // Wait until resources are defined
    if (isNil "RTS_resources") exitWith {
        systemChat "Economy resources not yet initialized. Retrying...";
        [] spawn {
            sleep 1;
            [] call RTS_fnc_createResourceUI;
        };
    };
    
    // Show the layer
    RTS_economyLayer cutRsc ["RscTitleDisplayEmpty", "PLAIN", -1, false];
    private _display = uiNamespace getVariable "RscTitleDisplayEmpty";
    
    // Background for top resource bar - MAKE IT WIDER TO FIT ALL RESOURCES
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [
        safezoneX,
        safezoneY,
        safezoneW,
        0.04 * safezoneH
    ];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _background ctrlCommit 0;
    RTS_economyControls pushBack _background;
    
    // === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE THE LAYOUT ===
    // Create resource indicators with improved layout for many resources
    private _resourceCount = count RTS_resources;
    private _spacing = 0.005 * safezoneW;       // Reduced spacing between resources
    private _textWidth = 0.09 * safezoneW;      // Reduced width of each resource display
    private _textHeight = 0.035 * safezoneH;
    private _startX = safezoneX + (safezoneW - (_resourceCount * (_textWidth + _spacing))) / 2;
    
    // Debug message to show layout calculations
    diag_log format ["Resource UI Layout: %1 resources, each %2 wide with %3 spacing, starting at %4",
        _resourceCount, _textWidth, _spacing, _startX];
    
    // Create a resource indicator for each resource in the economy
    {
        _x params ["_type", "_amount"];
        
        // Find tooltip for this resource
        private _tooltip = "";
        private _displayName = "";
        
        {
            _x params ["_iconType", "_iconPath", "_iconTooltip"];
            if (_iconType == _type) exitWith {
                _tooltip = _iconTooltip;
                
                // Format display name properly (capitalize first letter)
                _displayName = _iconType select [0, 1];
                _displayName = toUpper _displayName;
                _displayName = _displayName + (_iconType select [1]);
            };
        } forEach RTS_resourceIcons;
        
        // If no display name was found, create a default one
        if (_displayName == "") then {
            _displayName = _type select [0, 1];
            _displayName = toUpper _displayName;
            _displayName = _displayName + (_type select [1]);
        };
        
        // Create text control
        private _textCtrl = _display ctrlCreate ["RscStructuredText", -1];
        _textCtrl ctrlSetPosition [
            _startX + (_forEachIndex * (_textWidth + _spacing)),
            safezoneY + 0.005 * safezoneH,
            _textWidth,
            _textHeight
        ];
        
        // Get income rate for this resource
        private _income = [_type] call RTS_fnc_getResourceIncome;
        
        // Create more compact display format
        _textCtrl ctrlSetStructuredText parseText format [
            "<t size='0.8'>%1: %2</t><br/><t size='0.7' color='#8cff9b'>+%3/min</t>",
            _displayName,
            floor _amount,
            _income
        ];
        _textCtrl ctrlSetTooltip _tooltip;
        
        // Store resource type in control variable for updates
        _textCtrl setVariable ["resourceType", _type];
        
        _textCtrl ctrlCommit 0;
        RTS_economyControls pushBack _textCtrl;
        
        // Debug info
        diag_log format ["Created resource display for %1: %2", _type, _displayName];
        
    } forEach RTS_resources;
};

// Update the RTS_fnc_updateResourceUI function to handle more resources
RTS_fnc_updateResourceUI = {
    // If UI doesn't exist, create it
    if (count RTS_economyControls == 0) then {
        [] call RTS_fnc_createResourceUI;
    };
    
    // Update each resource text control
    {
        if (ctrlClassName _x == "RscStructuredText") then {
            private _resourceType = _x getVariable ["resourceType", ""];
            if (_resourceType != "") then {
                private _amount = [_resourceType] call RTS_fnc_getResource;
                private _income = [_resourceType] call RTS_fnc_getResourceIncome;
                
                // Get display name
                private _displayName = "";
                {
                    _x params ["_iconType", "_iconPath", "_iconTooltip"];
                    if (_iconType == _resourceType) exitWith {
                        // Format display name properly (capitalize first letter)
                        _displayName = _resourceType select [0, 1];
                        _displayName = toUpper _displayName;
                        _displayName = _displayName + (_resourceType select [1]);
                    };
                } forEach RTS_resourceIcons;
                
                // If still no display name, create a default
                if (_displayName == "") then {
                    _displayName = _resourceType select [0, 1];
                    _displayName = toUpper _displayName;
                    _displayName = _displayName + (_resourceType select [1]);
                };
                
                // Update the display with current values
                _x ctrlSetStructuredText parseText format [
                    "<t size='0.8'>%1: %2</t><br/><t size='0.7' color='#8cff9b'>+%3/min</t>",
                    _displayName,
                    floor _amount,
                    _income
                ];
            };
        };
    } forEach RTS_economyControls;
};

// Function to update the resource display UI
RTS_fnc_updateResourceUI = {
    // If UI doesn't exist, create it
    if (count RTS_economyControls == 0) then {
        [] call RTS_fnc_createResourceUI;
    };
    
    // Update each resource text control
    {
        if (ctrlClassName _x == "RscStructuredText") then {
            private _resourceType = _x getVariable ["resourceType", ""];
            if (_resourceType != "") then {
                private _amount = [_resourceType] call RTS_fnc_getResource;
                private _income = [_resourceType] call RTS_fnc_getResourceIncome;
                
                // Get display name
                private _displayName = "";
                {
                    _x params ["_iconType", "_iconPath", "_iconTooltip"];
                    if (_iconType == _resourceType) exitWith {
                        // Format display name properly (capitalize first letter)
                        _displayName = _resourceType select [0, 1];
                        _displayName = toUpper _displayName;
                        _displayName = _displayName + (_resourceType select [1]);
                    };
                } forEach RTS_resourceIcons;
                
                // If still no display name, create a default
                if (_displayName == "") then {
                    _displayName = _resourceType select [0, 1];
                    _displayName = toUpper _displayName;
                    _displayName = _displayName + (_resourceType select [1]);
                };
                
                // Update the display with current values
                _x ctrlSetStructuredText parseText format [
                    "<t size='0.8'>%1: %2</t><br/><t size='0.7' color='#8cff9b'>+%3/min</t>",
                    _displayName,
                    floor _amount,
                    _income
                ];
            };
        };
    } forEach RTS_economyControls;
};

// Function to destroy the resource display UI
RTS_fnc_destroyResourceUI = {
    {
        ctrlDelete _x;
    } forEach RTS_economyControls;
    
    RTS_economyControls = [];
    
    // Hide the layer
    RTS_economyLayer cutText ["", "PLAIN"];
};

// Initialize UI when script is executed
[] call RTS_fnc_createResourceUI;

// Update UI every second
[] spawn {
    while {true} do {
        [] call RTS_fnc_updateResourceUI;
        sleep 1;
    };
};