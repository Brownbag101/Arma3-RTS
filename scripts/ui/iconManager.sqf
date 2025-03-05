// Command icon controls array
RTSUI_commandIcons = [];

// Icon definitions
RTSUI_iconDefs = [
    [
        "moveOrder",                  // Icon ID
        "\icons\MoveOrderIcon.svg",   // Icon path
        {true},                      // Condition for showing (always true for move)
        {
            params ["_unit"];
            hint "Move order clicked!";
            // Move order logic here
        }
    ]
];

// Create command icons
fnc_createCommandIcons = {
    private _display = findDisplay 312;
    if (isNull _display) exitWith {};
    
    // Clear existing icons
    {
        ctrlDelete _x;
    } forEach RTSUI_commandIcons;
    RTSUI_commandIcons = [];
    
    // Create new icons
    {
        _x params ["_id", "_path", "_condition", "_handler"];
        
        private _iconSize = 0.04 * safezoneH;
        private _spacing = 0.005 * safezoneW;
        private _startX = safezoneX + 0.38;
        private _startY = safezoneY + safezoneH - 0.15;
        
        private _ctrl = _display ctrlCreate ["RscPictureKeepAspect", -1];
        _ctrl ctrlSetPosition [
            _startX + (_forEachIndex * (_iconSize + _spacing)),
            _startY,
            _iconSize,
            _iconSize
        ];
        _ctrl ctrlSetText _path;
        _ctrl ctrlSetTextColor [1, 1, 1, 0.9];
        
        // Add click handler
        _ctrl ctrlAddEventHandler ["MouseButtonDown", {
            params ["_ctrl", "_button"];
            if (_button == 0) then {
                private _unit = RTSUI_selectedUnit;
                if (!isNull _unit) then {
                    private _index = _ctrl getVariable ["iconIndex", 0];
                    private _handler = (RTSUI_iconDefs select _index) select 3;
                    [_unit] call _handler;
                };
            };
        }];
        
        _ctrl setVariable ["iconIndex", _forEachIndex];
        _ctrl setVariable ["iconId", _id];
        
        _ctrl ctrlCommit 0;
        RTSUI_commandIcons pushBack _ctrl;
        
    } forEach RTSUI_iconDefs;
};

// Update icon visibility
fnc_updateCommandIcons = {
    {
        private _ctrl = _x;
        private _index = _ctrl getVariable ["iconIndex", 0];
        private _condition = (RTSUI_iconDefs select _index) select 2;
        
        _ctrl ctrlShow (!isNull RTSUI_selectedUnit && {call _condition});
        _ctrl ctrlEnable (!isNull RTSUI_selectedUnit && {call _condition});
    } forEach RTSUI_commandIcons;
};