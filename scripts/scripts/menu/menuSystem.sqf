// scripts/menu/menuSystem.sqf
// Main menu buttons for RTS systems

// Controls array to track the menu buttons
RTS_menuControls = [];

// Menu definitions with icons and tooltips
RTS_menuButtons = [
    ["command", "\a3\ui_f\data\gui\cfg\hints\commanding_ca.paa", "Command Center", "Access unit and squad commands"],
    ["intelligence", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\map_ca.paa", "Intelligence", "View strategic intelligence and enemy information"],
    ["research", "\a3\ui_f\data\gui\rsc\rscdisplaymain\gradient_ca.paa", "Research", "Research new technologies and equipment"],
    ["construction", "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\icon_toolbox_buildings_ca.paa", "Construction", "Construct buildings and defenses"],
    ["training", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\face_ca.paa", "Training", "Train and upgrade units"]
];

// Function to create the menu buttons
RTS_fnc_createMenuButtons = {
    // Clear existing controls
    call RTS_fnc_destroyMenuButtons;
    
    // Use the actual Zeus display instead of creating a new layer
    private _display = findDisplay 312;
    if (isNull _display) then {
        systemChat "Zeus display not found! Cannot create menu buttons.";
        return;
    };
    
    // Button dimensions and spacing
    private _buttonSize = 0.05 * safezoneH; // Make buttons larger
    private _buttonMargin = 0.01 * safezoneH;
    private _startY = safezoneY + 0.2 * safezoneH;
    private _startX = safezoneX + 0.01 * safezoneW;
    
    // Create menu background
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [
        _startX,
        _startY,
        _buttonSize + 0.02 * safezoneW,
        (count RTS_menuButtons * (_buttonSize + _buttonMargin)) + _buttonMargin
    ];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.7]; // More visible background
    _background ctrlCommit 0;
    RTS_menuControls pushBack _background;
    
    // Create each button
    {
        _x params ["_id", "_icon", "_name", "_tooltip"];
        
        // Create button background
        private _btnBg = _display ctrlCreate ["RscText", -1];
        _btnBg ctrlSetPosition [
            _startX + 0.01 * safezoneW,
            _startY + _buttonMargin + (_forEachIndex * (_buttonSize + _buttonMargin)),
            _buttonSize,
            _buttonSize
        ];
        _btnBg ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.9];
        _btnBg ctrlCommit 0;
        RTS_menuControls pushBack _btnBg;
        
        // Create icon separately
        private _btnIcon = _display ctrlCreate ["RscPicture", -1];
        _btnIcon ctrlSetPosition [
            _startX + 0.01 * safezoneW,
            _startY + _buttonMargin + (_forEachIndex * (_buttonSize + _buttonMargin)),
            _buttonSize,
            _buttonSize
        ];
        _btnIcon ctrlSetText _icon;
        _btnIcon ctrlCommit 0;
        RTS_menuControls pushBack _btnIcon;
        
        // Create actual button (invisible but clickable)
        private _btn = _display ctrlCreate ["RscButton", -1];
        _btn ctrlSetPosition [
            _startX + 0.01 * safezoneW,
            _startY + _buttonMargin + (_forEachIndex * (_buttonSize + _buttonMargin)),
            _buttonSize,
            _buttonSize
        ];
        _btn ctrlSetText "";
        _btn ctrlSetBackgroundColor [0, 0, 0, 0.01]; // Almost transparent but not completely
        _btn ctrlSetTooltip format ["%1: %2", _name, _tooltip];
        
        // Store button data
        _btn setVariable ["buttonId", _id];
        _btn setVariable ["buttonName", _name];
        _btn setVariable ["buttonBg", _btnBg];
        
        // Add hover effects
        _btn ctrlAddEventHandler ["MouseEnter", {
            params ["_ctrl"];
            private _bg = _ctrl getVariable "buttonBg";
            _bg ctrlSetBackgroundColor [0.3, 0.3, 0.3, 0.9];
        }];
        
        _btn ctrlAddEventHandler ["MouseExit", {
            params ["_ctrl"];
            private _bg = _ctrl getVariable "buttonBg";
            _bg ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.9];
        }];
        
        // Add click handler
        _btn ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _id = _ctrl getVariable "buttonId";
            private _name = _ctrl getVariable "buttonName";
            
            // Clear feedback to show button is working
            systemChat format ["CLICKED: Opening %1 panel", _name];
            hint format ["%1 panel opened", _name];
            
            // Here you would call your existing functions based on the button ID
            switch (_id) do {
                case "command": {
                    // Call your command system
                    // Example: [] call RTS_fnc_openCommandPanel;
                };
                case "intelligence": {
                    // Call your intelligence system
                    // Example: [] call RTS_fnc_openIntelligencePanel;
                };
                case "research": {
                    // Call your research system
                    // Example: [] call RTS_fnc_openResearchPanel;
                };
                case "construction": {
                    // Call your construction system
                    // Example: [] call RTS_fnc_openConstructionPanel;
                };
                case "training": {
                    // Call your training system
                    // Example: [] call RTS_fnc_openTrainingPanel;
                };
            };
        }];
        
        _btn ctrlCommit 0;
        RTS_menuControls pushBack _btn;
    } forEach RTS_menuButtons;
    
    systemChat "Menu buttons created - hover for tooltips, click to activate";
};

// Function to destroy menu buttons
RTS_fnc_destroyMenuButtons = {
    {
        ctrlDelete _x;
    } forEach RTS_menuControls;
    
    RTS_menuControls = [];
};

// Initialize menu system
[] spawn {
    RTS_menuControls = []; // Ensure it's initialized
    
    waitUntil {!isNil "RTS_resources"}; // Wait for economy system to be initialized
    waitUntil {!isNil "RTS_resourceIcons"}; // Wait for economy resources to be fully defined
    waitUntil {count RTS_resources > 0}; // Make sure resources are populated
    sleep 3; // Give a longer delay to ensure economy UI is fully set up
    
    // Check for Zeus interface and wait until it's available
    [] spawn {
        while {true} do {
            if (!isNull findDisplay 312) then {
                systemChat "Zeus interface detected - creating menu buttons";
                [] call RTS_fnc_createMenuButtons;
                
                // Add handler for Zeus interface closing
                (findDisplay 312) displayAddEventHandler ["Unload", {
                    RTS_menuControls = [];
                    systemChat "Zeus interface closed - menu buttons removed";
                }];
                
                // Break the loop once buttons are created
                breakOut "zeusCheck";
            };
            sleep 1;
        };
    };
};