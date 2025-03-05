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
    
    // Background for top resource bar
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
    
    // Create resource indicators using text only
    private _resourceCount = count RTS_resources;
    private _spacing = 0.01 * safezoneW;
    private _textWidth = 0.13 * safezoneW;
    private _textHeight = 0.035 * safezoneH;
    private _startX = safezoneX + (safezoneW - (_resourceCount * (_textWidth + _spacing))) / 2;
    
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
        
        _textCtrl ctrlSetStructuredText parseText format [
            "<t size='0.9'>%1: %2</t><br/><t size='0.8' color='#8cff9b'>+%3/min</t>",
            _displayName,
            floor _amount,
            _income
        ];
        _textCtrl ctrlSetTooltip _tooltip;
        
        // Store resource type in control variable for updates
        _textCtrl setVariable ["resourceType", _type];
        
        _textCtrl ctrlCommit 0;
        RTS_economyControls pushBack _textCtrl;
        
    } forEach RTS_resources;
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
                
                _x ctrlSetStructuredText parseText format [
                    "<t size='0.9'>%1: %2</t><br/><t size='0.8' color='#8cff9b'>+%3/min</t>",
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