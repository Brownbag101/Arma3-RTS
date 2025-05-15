// scripts/ui/contextualMenu.sqf
// Contextual radial menu system for RTS mod
// Appears when Shift is held while hovering over objects in Zeus view

// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE MENU BEHAVIOR ===
CONTEXT_MENU_SIZE = 0.25;              // Menu size as fraction of screen height
CONTEXT_MENU_MAX_ITEMS = 8;            // Maximum items to show in the menu
CONTEXT_MENU_ICON_SIZE = 0.04;         // Icon size as fraction of screen height
CONTEXT_MENU_HOVER_SCALE = 1.2;        // How much icons scale when hovered
CONTEXT_MENU_FADE_TIME = 0.2;          // Fade in/out time in seconds
CONTEXT_MENU_BG_COLOR = [0, 0, 0, 0]; // Background color [r,g,b,a]
CONTEXT_MENU_HOLD_THRESHOLD = 0.1;     // How long to hold Shift before menu appears (seconds)
CONTEXT_MENU_USE_SPECIAL_ABILITIES = true; // Whether to include special abilities in the menu

// Internal state variables - Do not modify these
CONTEXT_MENU_ACTIVE = false;           // Whether the menu is currently displayed
CONTEXT_MENU_CONTROLS = [];            // Array of menu UI controls
CONTEXT_MENU_SHIFT_HELD = false;       // Whether shift is currently held
CONTEXT_MENU_SHIFT_HOLD_TIME = 0;      // How long shift has been held
CONTEXT_MENU_TARGET_OBJECT = objNull;  // Current target object under cursor
CONTEXT_MENU_TARGET_POS = [0,0,0];     // Current target position under cursor
CONTEXT_MENU_SELECTED_INDEX = -1;      // Currently highlighted menu item
CONTEXT_MENU_ACTIONS = [];             // Available actions for current context
CONTEXT_MENU_SCREEN_POS = [0.5, 0.5];  // Screen position of menu center
CONTEXT_MENU_KEY_HANDLER = -1;         // Handler ID for key events
CONTEXT_MENU_MOUSE_HANDLER = -1;       // Handler ID for mouse events
CONTEXT_MENU_DRAW_HANDLER = -1;        // Handler ID for 3D drawing
CONTEXT_MENU_TARGET_TYPE = "";         // Type of target ("OBJECT", "GROUND", etc.)

// === GAMEPLAY VARIABLES: Alternative Background Textures ===
// Uncomment one to change the background texture
CONTEXT_MENU_BACKGROUND_TEXTURE = "\a3\ui_f\data\IGUI\Cfg\Radar\radar_ca.paa"; // Default radar
// CONTEXT_MENU_BACKGROUND_TEXTURE = "\a3\ui_f\data\IGUI\RscIngameUI\RscHint\img_gradient_ca.paa"; // Gradient circle
// CONTEXT_MENU_BACKGROUND_TEXTURE = "\a3\ui_f\data\IGUI\Cfg\RadialMenu\icon_center_ca.paa"; // Radial menu center
// CONTEXT_MENU_BACKGROUND_TEXTURE = "\a3\ui_f\data\IGUI\Cfg\CommunicationMenu\instructor_ca.paa"; // Star-like pattern
// CONTEXT_MENU_BACKGROUND_TEXTURE = "\a3\ui_f\data\IGUI\Cfg\CommandBar\artillery_ca.paa"; // Artillery target
// CONTEXT_MENU_BACKGROUND_TEXTURE = "\a3\ui_f\data\GUI\Cfg\Cursors\hud_frame_ca.paa"; // HUD frame (military style)

// === GAMEPLAY VARIABLES: Color tinting for backgrounds ===
// Outer glow color (RGBA)
CONTEXT_MENU_GLOW_COLOR = [0.1, 0.1, 0.15, 0.6];
// Main background color (RGBA)
CONTEXT_MENU_MAIN_COLOR = [0.15, 0.15, 0.2, 0.9];
// Center highlight color (RGBA)
CONTEXT_MENU_CENTER_COLOR = [0.25, 0.25, 0.35, 0.5];

// Function to initialize the contextual menu system
fnc_initContextualMenu = {
    // Check if already initialized
    if (!isNil "CONTEXT_MENU_INITIALIZED" && {CONTEXT_MENU_INITIALIZED}) exitWith {
        systemChat "Contextual menu system already initialized.";
    };
    
    // Hook into Zeus interface
    [] spawn {
        waitUntil {!isNull findDisplay 312};
        call fnc_addContextMenuHandlers;
        systemChat "Contextual menu system initialized. Hold Shift while hovering over objects.";
    };
    
    // Mark as initialized
    CONTEXT_MENU_INITIALIZED = true;
};

// Function to add event handlers to Zeus interface
fnc_addContextMenuHandlers = {
    private _display = findDisplay 312;
    
    // Exit if display is not available
    if (isNull _display) exitWith {
        systemChat "Cannot initialize contextual menu - Zeus interface not active.";
    };
    
    // Add key down handler for Shift
    CONTEXT_MENU_KEY_HANDLER = _display displayAddEventHandler ["KeyDown", {
        params ["_display", "_key", "_shift", "_ctrl", "_alt"];
        
        // Check for Shift key (42 = left shift, 54 = right shift)
        if (_key in [42, 54] && !CONTEXT_MENU_SHIFT_HELD) then {
            CONTEXT_MENU_SHIFT_HELD = true;
            CONTEXT_MENU_SHIFT_HOLD_TIME = time;
            
            // If menu is not active, start checking for activation
            if (!CONTEXT_MENU_ACTIVE) then {
                [] spawn fnc_checkMenuActivation;
            };
        };
        
        false // Allow other handlers to process the key
    }];
    
    // Add key up handler to detect Shift release
    _display displayAddEventHandler ["KeyUp", {
        params ["_display", "_key", "_shift", "_ctrl", "_alt"];
        
        // Check for Shift key release
        if (_key in [42, 54] && CONTEXT_MENU_SHIFT_HELD) then {
            CONTEXT_MENU_SHIFT_HELD = false;
            
            // Close menu if it's open
            if (CONTEXT_MENU_ACTIVE) then {
                call fnc_closeContextMenu;
            };
        };
        
        false // Allow other handlers to process the key
    }];
    
    // Add mouse handler for menu interaction
    CONTEXT_MENU_MOUSE_HANDLER = _display displayAddEventHandler ["MouseMoving", {
        params ["_display", "_x", "_y"];
        
        // Only process if menu is active
        if (CONTEXT_MENU_ACTIVE) then {
            // Update mouse position
            CONTEXT_MENU_SCREEN_POS = [_x, _y];
            
            // Check which menu item is being hovered
            call fnc_updateMenuHighlight;
        };
    }];
    
    // Add mouse button handler for selection
    _display displayAddEventHandler ["MouseButtonDown", {
        params ["_display", "_button", "_x", "_y", "_shift", "_ctrl", "_alt"];
        
        // Check for left click while menu is active
        if (CONTEXT_MENU_ACTIVE && _button == 0) then {
            // Execute selected action if any
            if (CONTEXT_MENU_SELECTED_INDEX >= 0) then {
                [CONTEXT_MENU_SELECTED_INDEX] call fnc_executeMenuAction;
            };
            
            // Close menu
            call fnc_closeContextMenu;
            
            true // Consume the event
        } else {
            false // Allow other handlers to process the event
        };
    }];
    
    // Add handler for display close to clean up
    _display displayAddEventHandler ["Unload", {
        call fnc_cleanupContextMenu;
    }];
    
    systemChat "Contextual menu handlers added to Zeus interface.";
};

// Function to check if the menu should be activated
fnc_checkMenuActivation = {
    // While shift is held, check conditions
    while {CONTEXT_MENU_SHIFT_HELD && !CONTEXT_MENU_ACTIVE} do {
        // Wait for threshold time to pass
        if (time - CONTEXT_MENU_SHIFT_HOLD_TIME >= CONTEXT_MENU_HOLD_THRESHOLD) then {
            // Check if there's a valid target under cursor
            private _validTarget = call fnc_getTargetUnderCursor;
            
            if (_validTarget) then {
                // Check if there are actions available for this target
                private _actions = call fnc_getAvailableActions;
                
                if (count _actions > 0) then {
                    // Activate menu
                    CONTEXT_MENU_ACTIONS = _actions;
                    call fnc_openContextMenu;
                    break;
                };
            };
        };
        
        // Check again in a small interval
        sleep 0.05;
    };
};

// Function to get the target under the cursor
fnc_getTargetUnderCursor = {
    // Use curatorMouseOver to get what's under the cursor
    private _cursorData = curatorMouseOver;
    
    // Store the target type
    CONTEXT_MENU_TARGET_TYPE = _cursorData select 0;
    
    // Store cursor position for menu placement
    CONTEXT_MENU_SCREEN_POS = getMousePosition;
    
    // Process different target types
    switch (CONTEXT_MENU_TARGET_TYPE) do {
        case "OBJECT": {
            // Store target object
            CONTEXT_MENU_TARGET_OBJECT = _cursorData select 1;
            CONTEXT_MENU_TARGET_POS = getPos CONTEXT_MENU_TARGET_OBJECT;
            
            // Return true if it's a valid object
            !isNull CONTEXT_MENU_TARGET_OBJECT
        };
        case "GROUP": {
            // Store leader as target
            private _group = _cursorData select 1;
            CONTEXT_MENU_TARGET_OBJECT = leader _group;
            CONTEXT_MENU_TARGET_POS = getPos CONTEXT_MENU_TARGET_OBJECT;
            
            // Return true if it's a valid group
            !isNull _group
        };
        case "LOCATION": {
            // Store location center as target position
            private _location = _cursorData select 1;
            CONTEXT_MENU_TARGET_OBJECT = objNull;
            CONTEXT_MENU_TARGET_POS = locationPosition _location;
            
            // Return true for valid location
            true
        };
        case "GROUND": {
            // Store ground position
            CONTEXT_MENU_TARGET_OBJECT = objNull;
            CONTEXT_MENU_TARGET_POS = ASLToAGL (_cursorData select 1);
            
            // Return true for valid ground position
            true
        };
        default {
            // If nothing is under cursor, create a "EMPTY" type and use screenToWorld to get position
            CONTEXT_MENU_TARGET_TYPE = "EMPTY";
            CONTEXT_MENU_TARGET_OBJECT = objNull;
            CONTEXT_MENU_TARGET_POS = screenToWorld getMousePosition;
            
            // Always return true - we always have valid cursor coordinates
            true
        };
    };
};

// Function to get available actions for current context
fnc_getAvailableActions = {
    private _actions = [];
    private _selectedUnits = curatorSelected select 0;
    
    // No actions if no units selected
    if (count _selectedUnits == 0) exitWith {
        []
    };
    
    // Get selection type
    private _selectionType = [_selectedUnits] call fnc_getSelectionType;
    
    // Get target info
    private _targetObject = CONTEXT_MENU_TARGET_OBJECT;
    private _targetPos = CONTEXT_MENU_TARGET_POS;
    private _targetType = CONTEXT_MENU_TARGET_TYPE;
    
    // Check for special abilities if enabled
    if (CONTEXT_MENU_USE_SPECIAL_ABILITIES) then {
        // Only check special abilities for single unit selections
        if (count _selectedUnits == 1) then {
            private _unit = _selectedUnits select 0;
            
            // Check if the unit has any special abilities
            if (!isNil "fnc_getUnitAbilities") then {
                private _abilities = [_unit] call fnc_getUnitAbilities;
                
                // Add available abilities to actions
                {
                    private _abilityId = _x;
                    private _abilityInfo = [_abilityId] call fnc_getAbilityInfo;
                    
                    if (count _abilityInfo > 0) then {
                        _abilityInfo params ["_id", "_iconPath", "_displayName", "_tooltip", "_scriptPath"];
                        
                        // Check if the ability is on cooldown
                        private _cooldownInfo = [_unit, _abilityId] call fnc_getAbilityCooldown;
                        private _onCooldown = (_cooldownInfo select 0) > 0;
                        
                        // Add to actions if not on cooldown
                        if (!_onCooldown) then {
                            _actions pushBack [
                                _displayName,            // Action name
                                _iconPath,               // Icon path
                                _tooltip,                // Tooltip
                                "ability",               // Action type
                                [_unit, _scriptPath],    // Parameters
                                true                     // Enabled
                            ];
                        };
                    };
                } forEach _abilities;
            };
        };
    };
    
    // Add standard actions based on target type
    switch (_targetType) do {
        case "OBJECT": {
            // Get object info
			private _isVehicle = _targetObject isKindOf "LandVehicle" || _targetObject isKindOf "Air" || _targetObject isKindOf "Ship";
			private _isMan = _targetObject isKindOf "CAManBase";
			private _isDead = !alive _targetObject;
			private _isEnemy = false;
			// Check if target and selected unit have different sides
			if (count _selectedUnits > 0) then {
				private _selectedUnit = _selectedUnits select 0;
				if (!isNull _selectedUnit && !isNull _targetObject) then {
					_isEnemy = (side group _selectedUnit) != (side group _targetObject) && (side group _targetObject) != civilian;
				};
			};
			private _isStorage = _targetObject isKindOf "ReammoBox_F" || _targetObject isKindOf "ThingX";
            
            // Add actions for each type
            if (_isVehicle) then {
                // Actions for vehicles
                if (!_isDead) then {
                    // Live vehicle actions
                    _actions pushBack [
                        "Get In",
                        "\a3\ui_f\data\IGUI\Cfg\Actions\getindriver_ca.paa",
                        "Enter vehicle",
                        "command",
                        [_selectedUnits, _targetObject, "getin"],
                        true
                    ];
                    
                    if (_selectionType == "VEHICLE") then {
                        // If selected unit is a vehicle
                        _actions pushBack [
                            "Tow",
                            "a3\3den\data\cfgwaypoints\hook_ca.paa",
                            "Tow this vehicle",
                            "command",
                            [_selectedUnits select 0, _targetObject, "tow"],
                            true
                        ];
                    };
                } else {
                    // Dead vehicle actions
                    _actions pushBack [
                        "Salvage",
                        "\a3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa",
                        "Salvage parts from destroyed vehicle",
                        "command",
                        [_selectedUnits, _targetObject, "salvage"],
                        true
                    ];
                };
            };
            
            if (_isMan) then {
                // Actions for infantry
                if (!_isDead) then {
                    // Live infantry actions
                    if (_isEnemy) then {
                        // Enemy infantry
                        _actions pushBack [
                            "Capture",
                            "\a3\ui_f\data\IGUI\Cfg\Actions\handcuff_ca.paa",
                            "Attempt to capture enemy unit",
                            "command",
                            [_selectedUnits, _targetObject, "capture"],
                            true
                        ];
                        
                        // Add aimed shot if it's in our abilities
                        if (count _selectedUnits == 1 && {[_selectedUnits select 0, "aimedshot"] call fnc_hasAbility}) then {
                            _actions pushBack [
                                "Aimed Shot",
                                "\a3\ui_f\data\IGUI\Cfg\WeaponIcons\srifle_ca.paa",
                                "Take a precise shot at this target",
                                "command",
                                [_selectedUnits select 0, _targetObject, "aimedshot"],
                                true
                            ];
                        };
                    } else {
                        // Friendly infantry
                        _actions pushBack [
                            "Heal",
                            "\a3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa",
                            "Heal unit",
                            "command",
                            [_selectedUnits, _targetObject, "heal"],
                            true
                        ];
                    };
                } else {
                    // Dead infantry
                    _actions pushBack [
                        "Loot",
                        "\a3\ui_f\data\IGUI\Cfg\Actions\gear_ca.paa",
                        "Search body for items",
                        "command",
                        [_selectedUnits, _targetObject, "loot"],
                        true
                    ];
                    
                    _actions pushBack [
                        "Identify",
                        "\a3\ui_f\data\IGUI\Cfg\Actions\talk_ca.paa",
                        "Identify dead soldier",
                        "command",
                        [_selectedUnits, _targetObject, "identify"],
                        true
                    ];
                };
            };
            
            if (_isStorage) then {
                // Actions for storage boxes/crates
                _actions pushBack [
                    "Open",
                    "\a3\ui_f\data\IGUI\Cfg\Actions\gear_ca.paa",
                    "Open storage container",
                    "command",
                    [_selectedUnits, _targetObject, "open"],
                    true
                ];
                
                if (_selectionType == "VEHICLE") then {
                    _actions pushBack [
                        "Load Cargo",
                        "\a3\ui_f\data\IGUI\Cfg\Actions\loadVehicle_ca.paa",
                        "Load into vehicle",
                        "command",
                        [_selectedUnits select 0, _targetObject, "load"],
                        true
                    ];
                };
            };
        };
        
        case "GROUND": {
    // Actions for ground or empty space
    // Basic movement
    _actions pushBack [
        "Move Here",
        "a3\ui_f\data\IGUI\Cfg\Actions\ico_ON_ca.paa",
        "Move to this position",
        "command",
        [_selectedUnits, _targetPos, "move"],
        true
    ];
    
    // Waypoint options (if squad or leader)
    if (_selectionType == "SQUAD" || {count _selectedUnits == 1 && (_selectedUnits select 0) == leader group (_selectedUnits select 0)}) then {
        // Add various formation waypoints
        _actions pushBack [
            "Move (Line Formation)",
            "a3\ui_f_curator\data\rsccommon\rscattributeformation\line_ca.paa",
            "Move to position in line formation",
            "command",
            [_selectedUnits, _targetPos, "moveLine"],
            true
        ];
        
        _actions pushBack [
            "Move (Column Formation)",
            "a3\3den\data\attributes\formation\stag_column_ca.paa",
            "Move to position in column formation",
            "command",
            [_selectedUnits, _targetPos, "moveColumn"],
            true
        ];
        
        _actions pushBack [
            "Move (Wedge Formation)",
            "a3\ui_f_curator\data\rsccommon\rscattributeformation\wedge_ca.paa",
            "Move to position in wedge formation",
            "command",
            [_selectedUnits, _targetPos, "moveWedge"],
            true
        ];
        
        // Mark position option
        _actions pushBack [
            "Mark Position",
            "a3\ui_f\data\IGUI\Cfg\Actions\ico_cpt_activate_ca.paa",
            "Mark this position for the squad",
            "command",
            [_selectedUnits, _targetPos, "mark"],
            true
        ];
    }; 
    
    // Add ability to place a time bomb if available
    if (count _selectedUnits == 1 && {[_selectedUnits select 0, "timebomb"] call fnc_hasAbility}) then {
        _actions pushBack [
            "Place Bomb",
            "\a3\ui_f\data\IGUI\Cfg\SimpleTasks\types\destroy_ca.paa",
            "Place a timed explosive device",
            "command",
            [_selectedUnits select 0, _targetPos, "timebomb"],
            true
        ];
    };
    
    // Add SMG Burst if available
    if (count _selectedUnits == 1 && {[_selectedUnits select 0, "smgburst"] call fnc_hasAbility}) then {
        _actions pushBack [
            "SMG Burst",
            "\a3\ui_f\data\IGUI\Cfg\WeaponIcons\mg_ca.paa",
            "Fire SMG burst at position",
            "command",
            [_selectedUnits select 0, _targetPos, "smgburst"],
            true
        ];
    };
    
    // Add scouting ability if available
    if (count _selectedUnits == 1 && {[_selectedUnits select 0, "scout"] call fnc_hasAbility}) then {
        _actions pushBack [
            "Scout Area",
            "\a3\ui_f\data\IGUI\Cfg\simpleTasks\types\scout_ca.paa",
            "Scout this area for enemy units",
            "command",
            [_selectedUnits select 0, _targetPos, "scout"],
            true
        ];
    };
    
    // Vehicle specific commands for ground
    if (_selectionType == "VEHICLE") then {
        _actions pushBack [
            "Move Vehicle",
            "a3\ui_f\data\IGUI\Cfg\Actions\getindriver_ca.paa",
            "Move vehicle to this position",
            "command",
            [_selectedUnits, _targetPos, "moveVehicle"],
            true
        ];
        
        // If it's a transport vehicle, add disembark option
        private _vehicle = _selectedUnits select 0;
        if (_vehicle emptyPositions "cargo" > 0 || count (crew _vehicle) > 1) then {
            _actions pushBack [
                "Disembark Here",
                "a3\ui_f\data\IGUI\Cfg\Actions\getoutstandy_ca.paa",
                "Move vehicle here and order all units to disembark",
                "command",
                [_selectedUnits, _targetPos, "disembark"],
                true
            ];
        };
    };
};

case "EMPTY": {
    // EXACT SAME CODE as the GROUND case - just duplicate it!
    // Basic movement
    _actions pushBack [
        "Move Here",
        "a3\ui_f\data\IGUI\Cfg\Actions\ico_ON_ca.paa",
        "Move to this position",
        "command",
        [_selectedUnits, _targetPos, "move"],
        true
    ];
    
    // Waypoint options (if squad or leader)
    if (_selectionType == "SQUAD" || {count _selectedUnits == 1 && (_selectedUnits select 0) == leader group (_selectedUnits select 0)}) then {
        // Add various formation waypoints
        _actions pushBack [
            "Move (Line Formation)",
            "a3\ui_f_curator\data\rsccommon\rscattributeformation\line_ca.paa",
            "Move to position in line formation",
            "command",
            [_selectedUnits, _targetPos, "moveLine"],
            true
        ];
        
        _actions pushBack [
            "Move (Column Formation)",
            "a3\3den\data\attributes\formation\stag_column_ca.paa",
            "Move to position in column formation",
            "command",
            [_selectedUnits, _targetPos, "moveColumn"],
            true
        ];
        
        _actions pushBack [
            "Move (Wedge Formation)",
            "a3\ui_f_curator\data\rsccommon\rscattributeformation\wedge_ca.paa",
            "Move to position in wedge formation",
            "command",
            [_selectedUnits, _targetPos, "moveWedge"],
            true
        ];
        
        // Mark position option
        _actions pushBack [
            "Mark Position",
            "a3\ui_f\data\IGUI\Cfg\Actions\ico_cpt_activate_ca.paa",
            "Mark this position for the squad",
            "command",
            [_selectedUnits, _targetPos, "mark"],
            true
        ];
    }; 
    
    // Add ability to place a time bomb if available
    if (count _selectedUnits == 1 && {[_selectedUnits select 0, "timebomb"] call fnc_hasAbility}) then {
        _actions pushBack [
            "Place Bomb",
            "\a3\ui_f\data\IGUI\Cfg\SimpleTasks\types\destroy_ca.paa",
            "Place a timed explosive device",
            "command",
            [_selectedUnits select 0, _targetPos, "timebomb"],
            true
        ];
    };
    
    // Add SMG Burst if available
    if (count _selectedUnits == 1 && {[_selectedUnits select 0, "smgburst"] call fnc_hasAbility}) then {
        _actions pushBack [
            "SMG Burst",
            "\a3\ui_f\data\IGUI\Cfg\WeaponIcons\mg_ca.paa",
            "Fire SMG burst at position",
            "command",
            [_selectedUnits select 0, _targetPos, "smgburst"],
            true
        ];
    };
    
    // Add scouting ability if available
    if (count _selectedUnits == 1 && {[_selectedUnits select 0, "scout"] call fnc_hasAbility}) then {
        _actions pushBack [
            "Scout Area",
            "\a3\ui_f\data\IGUI\Cfg\simpleTasks\types\scout_ca.paa",
            "Scout this area for enemy units",
            "command",
            [_selectedUnits select 0, _targetPos, "scout"],
            true
        ];
    };
    
    // Vehicle specific commands for ground
    if (_selectionType == "VEHICLE") then {
        _actions pushBack [
            "Move Vehicle",
            "a3\ui_f\data\IGUI\Cfg\Actions\getindriver_ca.paa",
            "Move vehicle to this position",
            "command",
            [_selectedUnits, _targetPos, "moveVehicle"],
            true
        ];
        
        // If it's a transport vehicle, add disembark option
        private _vehicle = _selectedUnits select 0;
        if (_vehicle emptyPositions "cargo" > 0 || count (crew _vehicle) > 1) then {
            _actions pushBack [
                "Disembark Here",
                "a3\ui_f\data\IGUI\Cfg\Actions\getoutstandy_ca.paa",
                "Move vehicle here and order all units to disembark",
                "command",
                [_selectedUnits, _targetPos, "disembark"],
                true
            ];
        };
    };
};
        
        default {};
    };
    
    // Limit the number of actions to avoid cluttering the menu
    private _maxItems = CONTEXT_MENU_MAX_ITEMS min (count _actions);
    _actions resize _maxItems;
    
    _actions
};

// Function to open the context menu
fnc_openContextMenu = {
    // Create menu UI
    call fnc_createContextMenuUI;
    
    // Set menu as active
    CONTEXT_MENU_ACTIVE = true;
    
    // Add Draw3D handler for additional visual elements
    if (CONTEXT_MENU_DRAW_HANDLER == -1) then {
        CONTEXT_MENU_DRAW_HANDLER = addMissionEventHandler ["Draw3D", {
            // Only draw if menu is active
            if (CONTEXT_MENU_ACTIVE) then {
                // Draw line to target
                if (CONTEXT_MENU_TARGET_TYPE == "OBJECT" && !isNull CONTEXT_MENU_TARGET_OBJECT) then {
                    private _startPos = getPosASL (curatorSelected select 0 select 0);
                    private _endPos = getPosASL CONTEXT_MENU_TARGET_OBJECT;
                    
                    drawLine3D [
                        ASLToAGL _startPos,
                        ASLToAGL _endPos,
                        [0.5, 0.5, 1, 0.7]
                    ];
                    
                    // Draw indicator at target
                    drawIcon3D [
                        "\a3\ui_f\data\IGUI\Cfg\Cursors\selectOver_ca.paa",
                        [1, 1, 1, 0.7],
                        ASLToAGL _endPos,
                        1.5,
                        1.5,
                        0
                    ];
                };
                
                // Draw indicator at ground position
                if (CONTEXT_MENU_TARGET_TYPE == "GROUND") then {
                    private _startPos = getPosASL (curatorSelected select 0 select 0);
                    private _endPos = AGLToASL CONTEXT_MENU_TARGET_POS;
                    
                    drawLine3D [
                        ASLToAGL _startPos,
                        ASLToAGL _endPos,
                        [0.5, 0.5, 1, 0.7]
                    ];
                    
                    drawIcon3D [
                        "\a3\ui_f\data\IGUI\Cfg\Cursors\selectOver_ca.paa",
                        [1, 1, 1, 0.7],
                        ASLToAGL _endPos,
                        1.5,
                        1.5,
                        0
                    ];
                };
            };
        }];
    };
};

// Function to create the menu UI elements - WITH IMPROVED BUTTON CREATION
fnc_createContextMenuUI = {
    private _display = findDisplay 312;
    
    // Exit if display is not available
    if (isNull _display) exitWith {
        systemChat "Cannot create contextual menu - Zeus interface not active.";
    };
    
    // Clear existing controls
    call fnc_clearContextMenuUI;
    
    // Calculate menu dimensions
    private _menuSize = CONTEXT_MENU_SIZE * safezoneH;
    private _menuItems = count CONTEXT_MENU_ACTIONS;
    private _iconSize = CONTEXT_MENU_ICON_SIZE * safezoneH;
    
    // Get texture from variable or use default
    private _backgroundTexture = "\a3\ui_f\data\IGUI\Cfg\Radar\radar_ca.paa"; // Default
    if (!isNil "CONTEXT_MENU_BACKGROUND_TEXTURE") then {
        _backgroundTexture = CONTEXT_MENU_BACKGROUND_TEXTURE;
    };
    
    // Get color values with fallbacks
    private _glowColor = [0.1, 0.1, 0.15, 0.6]; // Default
    if (!isNil "CONTEXT_MENU_GLOW_COLOR") then {
        _glowColor = CONTEXT_MENU_GLOW_COLOR;
    };
    
    private _mainColor = [0.15, 0.15, 0.2, 0.9]; // Default
    if (!isNil "CONTEXT_MENU_MAIN_COLOR") then {
        _mainColor = CONTEXT_MENU_MAIN_COLOR;
    };
    
    private _centerColor = [0.25, 0.25, 0.35, 0.5]; // Default
    if (!isNil "CONTEXT_MENU_CENTER_COLOR") then {
        _centerColor = CONTEXT_MENU_CENTER_COLOR;
    };
    
    // Set animation time to 0 for instant appearance
    private _animTime = 0;
    
    // Create outer glow/shadow layer
    private _glowLayer = _display ctrlCreate ["RscPicture", -1];
    _glowLayer ctrlSetPosition [
        (CONTEXT_MENU_SCREEN_POS select 0) - (_menuSize / 2) * 1.1,
        (CONTEXT_MENU_SCREEN_POS select 1) - (_menuSize / 2) * 1.1,
        _menuSize * 1.1,
        _menuSize * 1.1
    ];
    _glowLayer ctrlSetText _backgroundTexture;
    _glowLayer ctrlSetTextColor _glowColor;
    _glowLayer ctrlCommit _animTime;
    CONTEXT_MENU_CONTROLS pushBack _glowLayer;
    
    // Create main circular background
    private _background = _display ctrlCreate ["RscPicture", -1];
    _background ctrlSetPosition [
        (CONTEXT_MENU_SCREEN_POS select 0) - (_menuSize / 2),
        (CONTEXT_MENU_SCREEN_POS select 1) - (_menuSize / 2),
        _menuSize,
        _menuSize
    ];
    _background ctrlSetText _backgroundTexture;
    _background ctrlSetTextColor _mainColor;
    _background ctrlCommit _animTime;
    CONTEXT_MENU_CONTROLS pushBack _background;
    
    // Create center highlight
    private _centerHighlight = _display ctrlCreate ["RscPicture", -1];
    _centerHighlight ctrlSetPosition [
        (CONTEXT_MENU_SCREEN_POS select 0) - (_menuSize / 6),
        (CONTEXT_MENU_SCREEN_POS select 1) - (_menuSize / 6),
        _menuSize * 0.33,
        _menuSize * 0.33
    ];
    _centerHighlight ctrlSetText _backgroundTexture;
    _centerHighlight ctrlSetTextColor _centerColor;
    _centerHighlight ctrlCommit _animTime;
    CONTEXT_MENU_CONTROLS pushBack _centerHighlight;
    
    // First create all controls without committing positions
    private _icons = [];
    
    // Define fixed positions for up to 8 icons (standard maximum)
    private _positions = [
        [0, -1],    // Top
        [0.7, -0.7], // Top right
        [1, 0],     // Right
        [0.7, 0.7],  // Bottom right
        [0, 1],     // Bottom
        [-0.7, 0.7], // Bottom left
        [-1, 0],    // Left
        [-0.7, -0.7] // Top left
    ];
    
    // If we have fewer than 8 icons, use a subset of positions
    if (_menuItems <= 4) then {
        _positions = [
            [0, -1],    // Top
            [1, 0],     // Right
            [0, 1],     // Bottom
            [-1, 0]     // Left
        ];
    };
    
    // Position each icon and button - NOW COMBINED INTO A SINGLE ELEMENT
    for "_i" from 0 to (_menuItems - 1) do {
        private _action = CONTEXT_MENU_ACTIONS select _i;
        _action params ["_name", "_iconPath", "_tooltip", "_type", "_params", "_enabled"];
        
        // Calculate position
        private _posIndex = _i mod (count _positions);
        private _pos = _positions select _posIndex;
        
        private _xFactor = _pos select 0;
        private _yFactor = _pos select 1;
        
        private _radius = _menuSize * 0.35;
        private _xOffset = _xFactor * _radius;
        private _yOffset = _yFactor * _radius;
        
        // MAJOR CHANGE: Use RscActivePicture instead of separate button and picture
        private _icon = _display ctrlCreate ["RscActivePicture", -1];
        _icon setVariable ["actionIndex", _i];
        _icon setVariable ["isIcon", true];
        _icon ctrlSetText _iconPath;
        _icon ctrlSetTextColor [1, 1, 1, 0.9]; // Slightly dimmed by default
        _icon ctrlSetBackgroundColor [0, 0, 0, 0]; // Completely transparent background
        _icon ctrlSetTooltip format ["%1: %2", _name, _tooltip];
        
        // Position the icon
        _icon ctrlSetPosition [
            (CONTEXT_MENU_SCREEN_POS select 0) + _xOffset - (_iconSize / 2),
            (CONTEXT_MENU_SCREEN_POS select 1) + _yOffset - (_iconSize / 2),
            _iconSize,
            _iconSize
        ];
        
        // Add click handler directly to the active picture
        _icon ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _index = _ctrl getVariable "actionIndex";
            [_index] call fnc_executeMenuAction;
            call fnc_closeContextMenu;
        }];
        
        // Add hover handlers
        _icon ctrlAddEventHandler ["MouseEnter", {
            params ["_ctrl"];
            private _index = _ctrl getVariable "actionIndex";
            CONTEXT_MENU_SELECTED_INDEX = _index;
            
            // Apply hover effect directly
            private _hoverSize = CONTEXT_MENU_ICON_SIZE * CONTEXT_MENU_HOVER_SCALE * safezoneH;
            private _pos = ctrlPosition _ctrl;
            private _centerX = (_pos select 0) + (_pos select 2) / 2;
            private _centerY = (_pos select 1) + (_pos select 3) / 2;
            
            _ctrl ctrlSetPosition [
                _centerX - _hoverSize / 2,
                _centerY - _hoverSize / 2,
                _hoverSize,
                _hoverSize
            ];
            _ctrl ctrlSetTextColor [1, 1, 1, 1]; // Full brightness
            _ctrl ctrlCommit 0.1;
        }];
        
        _icon ctrlAddEventHandler ["MouseExit", {
            params ["_ctrl"];
            CONTEXT_MENU_SELECTED_INDEX = -1;
            
            // Revert hover effect directly
            private _normalSize = CONTEXT_MENU_ICON_SIZE * safezoneH;
            private _pos = ctrlPosition _ctrl;
            private _centerX = (_pos select 0) + (_pos select 2) / 2;
            private _centerY = (_pos select 1) + (_pos select 3) / 2;
            
            _ctrl ctrlSetPosition [
                _centerX - _normalSize / 2,
                _centerY - _normalSize / 2,
                _normalSize,
                _normalSize
            ];
            _ctrl ctrlSetTextColor [1, 1, 1, 0.9]; // Slightly dimmed
            _ctrl ctrlCommit 0.1;
        }];
        
        _icon ctrlCommit _animTime;
        _icons pushBack _icon;
        CONTEXT_MENU_CONTROLS pushBack _icon;
    };
    
    // Create title text
    private _title = _display ctrlCreate ["RscText", -1];
    _title ctrlSetPosition [
        (CONTEXT_MENU_SCREEN_POS select 0) - (_menuSize / 4),
        (CONTEXT_MENU_SCREEN_POS select 1) - (_menuSize / 2) - (_iconSize / 2),
        _menuSize / 2,
        _iconSize / 2
    ];
    
    // Set title based on target type
    private _titleText = switch (CONTEXT_MENU_TARGET_TYPE) do {
        case "OBJECT": {
            if (!isNull CONTEXT_MENU_TARGET_OBJECT) then {
                getText (configFile >> "CfgVehicles" >> typeOf CONTEXT_MENU_TARGET_OBJECT >> "displayName")
            } else { "Target" };
        };
        case "GROUND": { "Ground" };
        case "GROUP": { "Group" };
        case "LOCATION": { "Location" };
        default { "Actions" };
    };
    
    _title ctrlSetText _titleText;
    _title ctrlSetTextColor [1, 1, 1, 1];
    _title ctrlCommit _animTime;
    CONTEXT_MENU_CONTROLS pushBack _title;
};

// Updated function for menu highlight - NOT NEEDED ANYMORE as we handle hover directly
fnc_updateMenuHighlight = {
    // This function is now empty as hover effects are handled directly in the control event handlers
    // Only leaving it empty to maintain compatibility with existing code that might call it
};

// Function to update highlighted menu item
fnc_updateMenuHighlight = {
    // Only process if menu is active
    if (!CONTEXT_MENU_ACTIVE) exitWith {};
    
    // Iterate through all controls
    {
        // Skip if not an icon
        if (!(_x getVariable ["isIcon", false])) then { continue };
        
        private _index = _x getVariable ["actionIndex", -1];
        
        if (_index == CONTEXT_MENU_SELECTED_INDEX) then {
            // Highlight this item - just make it bigger and brighter
            private _iconSize = CONTEXT_MENU_ICON_SIZE * CONTEXT_MENU_HOVER_SCALE * safezoneH;
            private _pos = ctrlPosition _x;
            private _centerX = (_pos select 0) + (_pos select 2) / 2;
            private _centerY = (_pos select 1) + (_pos select 3) / 2;
            
            _x ctrlSetPosition [
                _centerX - _iconSize / 2,
                _centerY - _iconSize / 2,
                _iconSize,
                _iconSize
            ];
            _x ctrlSetTextColor [1, 1, 1, 1]; // Full brightness
            _x ctrlCommit 0.1; // Quick animation
        } else {
            // Reset this item
            private _iconSize = CONTEXT_MENU_ICON_SIZE * safezoneH;
            private _pos = ctrlPosition _x;
            private _centerX = (_pos select 0) + (_pos select 2) / 2;
            private _centerY = (_pos select 1) + (_pos select 3) / 2;
            
            _x ctrlSetPosition [
                _centerX - _iconSize / 2,
                _centerY - _iconSize / 2,
                _iconSize,
                _iconSize
            ];
            _x ctrlSetTextColor [1, 1, 1, 0.8]; // Slightly dimmed
            _x ctrlCommit 0.1;
        };
    } forEach CONTEXT_MENU_CONTROLS;
};

// Function to execute a menu action
fnc_executeMenuAction = {
    params ["_index"];
    
    // Exit if index is invalid
    if (_index < 0 || _index >= count CONTEXT_MENU_ACTIONS) exitWith {
        systemChat "Invalid action index.";
    };
    
    // Get action data
    private _action = CONTEXT_MENU_ACTIONS select _index;
    _action params ["_name", "_iconPath", "_tooltip", "_type", "_params", "_enabled"];
    
    // Exit if action is disabled
    if (!_enabled) exitWith {
        systemChat format ["Action %1 is not available at this time.", _name];
    };
    
    // Execute based on action type
    switch (_type) do {
        case "ability": {
            // Execute ability script
            _params params ["_unit", "_scriptPath"];
            
            systemChat format ["Executing %1 ability.", _name];
            [_unit] execVM _scriptPath;
        };
        
        case "command": {
            // Process command action
            _params params ["_units", "_target", "_command"];
            
            switch (_command) do {
                case "move": {
                    // Move units to position
                    {
                        _x doMove _target;
                    } forEach _units;
                    
                    systemChat format ["Moving %1 units to position.", count _units];
                };
                
                case "getin": {
                    // Order units to get in vehicle
                    {
                        [_x] orderGetIn true;
                        _x assignAsCargo _target;
                    } forEach _units;
                    
                    systemChat format ["Ordering %1 units to enter vehicle.", count _units];
                };
                
                case "tow": {
                    // Execute tow script
                    if (count _units > 0) then {
                        [_units select 0, []] execVM "scripts\towSystem.sqf";
                        systemChat "Towing vehicle.";
                    };
                };
                
                case "load": {
                    // Execute cargo loading script
                    if (count _units > 0) then {
                        [_units select 0, [], "load"] execVM "scripts\cargoSystem.sqf";
                        systemChat "Loading cargo into vehicle.";
                    };
                };
                
                case "loot": {
                    // Move unit to the body and open inventory
                    if (count _units > 0) then {
                        private _unit = _units select 0;
                        _unit doMove (getPos _target);
                        
                        // Wait until unit reaches the body
                        [_unit, _target] spawn {
                            params ["_unit", "_body"];
                            
                            // Wait for unit to get close
                            waitUntil {sleep 0.5; _unit distance _body < 3 || !alive _unit};
                            
                            // Exit if unit died
                            if (!alive _unit) exitWith {};
                            
                            // Play animation 
                            _unit playMove "AinvPknlMstpSnonWnonDnon_medic4";
                            sleep 1;
                            
                            // Open inventory with BIS_fnc_arsenal
                            ["Open", [true, _body, _unit]] call BIS_fnc_arsenal;
                            
                            systemChat format ["%1 is looting the body.", name _unit];
                        };
                    };
                };
                
                case "identify": {
                    // Move unit to the body and identify
                    if (count _units > 0) then {
                        private _unit = _units select 0;
                        _unit doMove (getPos _target);
                        
                        // Wait until unit reaches the body
                        [_unit, _target] spawn {
                            params ["_unit", "_body"];
                            
                            // Wait for unit to get close
                            waitUntil {sleep 0.5; _unit distance _body < 3 || !alive _unit};
                            
                            // Exit if unit died
                            if (!alive _unit) exitWith {};
                            
                            // Play animation and show message
                            _unit playMove "AinvPknlMstpSnonWnonDnon_medic4";
                            sleep 3;
                            
                            // Generate identification message
                            private _ranks = ["Private", "Corporal", "Sergeant", "Lieutenant", "Captain"];
                            private _surnames = ["Smith", "Johnson", "Miller", "Williams", "Jones", "Brown", "Davis", "Wilson"];
                            private _rank = selectRandom _ranks;
                            private _name = selectRandom _surnames;
                            
                            systemChat format ["%1 identified the body as %2 %3.", name _unit, _rank, _name];
                        };
                    };
                };
                
                case "capture": {
                    // Check if unit has capture ability, otherwise use basic capture
                    if (count _units > 0) then {
                        private _unit = _units select 0;
                        
                        if ([_unit, "capture"] call fnc_hasAbility) then {
                            // Use capture ability
                            [_unit] execVM "scripts\specialAbilities\abilities\capture.sqf";
                        } else {
                            // Basic capture behavior
                            _unit doMove (getPos _target);
                            
                            // Wait until unit reaches the target
                            [_unit, _target] spawn {
                                params ["_unit", "_target"];
                                
                                // Wait for unit to get close
                                waitUntil {sleep 0.5; _unit distance _target < 3 || !alive _unit || !alive _target};
                                
                                // Exit if unit or target died
                                if (!alive _unit || !alive _target) exitWith {};
                                
                                // Make target surrender
                                _target setCaptive true;
                                _target setUnitPos "UP";
                                [_target, _target] call BIS_fnc_surrender;
                                
                                systemChat format ["%1 has captured %2.", name _unit, name _target];
                            };
                        };
                    };
                };
                
                case "heal": {
                    // Move unit to the target and heal
                    if (count _units > 0) then {
                        private _unit = _units select 0;
                        _unit doMove (getPos _target);
                        
                        // Wait until unit reaches the target
                        [_unit, _target] spawn {
                            params ["_unit", "_target"];
                            
                            // Wait for unit to get close
                            waitUntil {sleep 0.5; _unit distance _target < 3 || !alive _unit || !alive _target};
                            
                            // Exit if unit or target died
                            if (!alive _unit || !alive _target) exitWith {};
                            
                            // Play animation and heal
                            _unit playMove "AinvPknlMstpSnonWnonDnon_medic4";
                            sleep 3;
                            
                            // Heal target
                            _target setDamage 0;
                            
                            systemChat format ["%1 has healed %2.", name _unit, name _target];
                        };
                    };
                };
                
                case "open": {
                    // Move unit to the container and open
                    if (count _units > 0) then {
                        private _unit = _units select 0;
                        _unit doMove (getPos _target);
                        
                        // Wait until unit reaches the container
                        [_unit, _target] spawn {
                            params ["_unit", "_target"];
                            
                            // Wait for unit to get close
                            waitUntil {sleep 0.5; _unit distance _target < 3 || !alive _unit || isNull _target};
                            
                            // Exit if unit died or container is gone
                            if (!alive _unit || isNull _target) exitWith {};
                            
                            // Play animation and open
                            _unit playMove "AinvPknlMstpSnonWnonDnon_medic4";
                            sleep 1;
                            
                            // Create sound effect
                            playSound3D ["a3\sounds_f\characters\movements\pivot\concrete_pivot_3.wss", _target];
                            
                            // Generate item message
                            private _items = ["ammunition", "medical supplies", "documents", "equipment", "rations"];
                            private _foundItems = selectRandom _items;
                            
                            systemChat format ["%1 found %2 in the container.", name _unit, _foundItems];
                        };
                    };
                };
                
                case "aimedshot": {
                    // Execute aimed shot ability
                    if (count _units > 0) then {
                        [_units select 0] execVM "scripts\specialAbilities\abilities\aimedShot.sqf";
                    };
                };
                
                case "timebomb": {
                    // Execute time bomb ability
                    if (count _units > 0) then {
                        [_units select 0] execVM "scripts\specialAbilities\abilities\timeBomb.sqf";
                    };
                };
                
                case "mark": {
                    // Mark position on map
                    if (count _units > 0) then {
                        private _unit = leader group (_units select 0);
                        private _markerName = format ["mark_%1_%2", name _unit, floor random 10000];
                        
                        // Create marker
                        private _marker = createMarker [_markerName, _target];
                        _marker setMarkerType "hd_dot";
                        _marker setMarkerColor "ColorBlue";
                        _marker setMarkerText format ["%1's Mark", name _unit];
                        
                        systemChat format ["%1 marked position on map.", name _unit];
                        
                        // Delete marker after some time
                        [_markerName] spawn {
                            params ["_name"];
                            sleep 300; // 5 minutes
                            deleteMarker _name;
                        };
                    };
                };
                
                // NEW FORMATION MOVEMENT COMMANDS
                case "moveLine": {
                    if (count _units > 1) then {
                        // Set formation
                        _units select 0 setFormation "LINE";
                        
                        // Move units
                        {
                            _x doMove _target;
                        } forEach _units;
                        
                        systemChat format ["Moving %1 units in line formation.", count _units];
                    } else {
                        // Just move single unit
                        _units select 0 doMove _target;
                        systemChat "Moving unit to position.";
                    };
                };
                
                case "moveColumn": {
                    if (count _units > 1) then {
                        // Set formation
                        _units select 0 setFormation "COLUMN";
                        
                        // Move units
                        {
                            _x doMove _target;
                        } forEach _units;
                        
                        systemChat format ["Moving %1 units in column formation.", count _units];
                    } else {
                        // Just move single unit
                        _units select 0 doMove _target;
                        systemChat "Moving unit to position.";
                    };
                };
                
                case "moveWedge": {
                    if (count _units > 1) then {
                        // Set formation
                        _units select 0 setFormation "WEDGE";
                        
                        // Move units
                        {
                            _x doMove _target;
                        } forEach _units;
                        
                        systemChat format ["Moving %1 units in wedge formation.", count _units];
                    } else {
                        // Just move single unit
                        _units select 0 doMove _target;
                        systemChat "Moving unit to position.";
                    };
                };
                
                case "moveVehicle": {
                    // Move vehicle to position
                    private _vehicle = _units select 0;
                    _vehicle doMove _target;
                    systemChat format ["Moving %1 to position.", getText (configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName")];
                };
                
                case "disembark": {
                    // Move vehicle to position and then disembark
                    private _vehicle = _units select 0;
                    
                    // Execute the move and disembark
                    [_vehicle, _target] spawn {
                        params ["_veh", "_pos"];
                        
                        // Get all units in vehicle
                        private _crew = crew _veh;
                        
                        // Move to position
                        _veh doMove _pos;
                        systemChat format ["Moving %1 to disembark position.", getText (configFile >> "CfgVehicles" >> typeOf _veh >> "displayName")];
                        
                        // Wait until vehicle reaches position or stops
                        waitUntil {sleep 0.5; _veh distance _pos < 15 || speed _veh < 0.1};
                        
                        // Order everyone out
                        {
                            unassignVehicle _x;
                            [_x] orderGetIn false;
                            _x action ["GetOut", _veh];
                        } forEach _crew;
                        
                        systemChat "All units disembarking.";
                    };
                };
                
                case "scout": {
                    // Execute scouting ability script
                    if (count _units > 0) then {
                        [_units select 0] execVM "scripts\specialAbilities\abilities\scouting.sqf";
                    };
                };
                
                case "smgburst": {
                    // Execute SMG burst ability
                    if (count _units > 0) then {
                        [_units select 0] execVM "scripts\specialAbilities\abilities\smgBurst.sqf";
                    };
                };
                
                case "salvage": {
                    // Move unit to the vehicle to salvage parts
                    if (count _units > 0) then {
                        private _unit = _units select 0;
                        _unit doMove (getPos _target);
                        
                        // Wait until unit reaches the vehicle
                        [_unit, _target] spawn {
                            params ["_unit", "_vehicle"];
                            
                            // Wait for unit to get close
                            waitUntil {sleep 0.5; _unit distance _vehicle < 5 || !alive _unit};
                            
                            // Exit if unit died
                            if (!alive _unit) exitWith {};
                            
                            // Play animation
                            _unit playMove "AinvPknlMstpSnonWnonDnon_medic4";
                            sleep 3;
                            
                            // Generate salvage message
                            private _items = ["engine parts", "metal scraps", "electrical components", "fuel", "ammunition"];
                            private _salvageItems = selectRandom _items;
                            
                            systemChat format ["%1 salvaged %2 from the destroyed vehicle.", name _unit, _salvageItems];
                            
                            // Small chance to add resources to the economy system
                            if (random 1 > 0.6) then {
                                if (!isNil "RTS_fnc_modifyResource") then {
                                    private _resources = ["iron", "steel", "aluminum", "fuel", "rubber"];
                                    private _resource = selectRandom _resources;
                                    private _amount = 5 + floor(random 15);
                                    
                                    [_resource, _amount] call RTS_fnc_modifyResource;
                                    systemChat format ["Added %1 %2 to inventory.", _amount, _resource];
                                };
                            };
                        };
                    };
                };
                
                default {
                    systemChat format ["Command %1 not implemented yet.", _command];
                };
            };
        };
        
        default {
            systemChat format ["Action type %1 not implemented yet.", _type];
        };
    };
};

// Function to close the context menu
fnc_closeContextMenu = {
    // Clear UI
    call fnc_clearContextMenuUI;
    
    // Set as inactive
    CONTEXT_MENU_ACTIVE = false;
    
    // Reset selection
    CONTEXT_MENU_SELECTED_INDEX = -1;
};

// Function to clear context menu UI
fnc_clearContextMenuUI = {
    // Delete all controls
    {
        ctrlDelete _x;
    } forEach CONTEXT_MENU_CONTROLS;
    
    // Reset controls array
    CONTEXT_MENU_CONTROLS = [];
};

// Function to clean up context menu resources
fnc_cleanupContextMenu = {
    // Clear UI
    call fnc_clearContextMenuUI;
    
    // Reset state
    CONTEXT_MENU_ACTIVE = false;
    CONTEXT_MENU_SHIFT_HELD = false;
    CONTEXT_MENU_SELECTED_INDEX = -1;
    
    // Remove draw handler
    if (CONTEXT_MENU_DRAW_HANDLER != -1) then {
        removeMissionEventHandler ["Draw3D", CONTEXT_MENU_DRAW_HANDLER];
        CONTEXT_MENU_DRAW_HANDLER = -1;
    };
};

// Function to check if unit has a specific ability
// Wrapper around existing ability system if available
fnc_hasAbility = {
    params ["_unit", "_abilityId"];
    
    // Use existing ability system if available
    if (!isNil "fnc_getUnitAbilities") then {
        private _abilities = [_unit] call fnc_getUnitAbilities;
        (_abilityId in _abilities)
    } else {
        // Fallback to checking variable directly
        private _abilities = _unit getVariable ["RTSUI_unlockedAbilities", []];
        (_abilityId in _abilities)
    }
};

// Initialize the contextual menu system
call fnc_initContextualMenu;