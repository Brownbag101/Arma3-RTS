// Virtual Hangar System - User Interface
// Handles creation and management of the Virtual Hangar UI

// Initialize variables
HANGAR_selectedAircraftIndex = -1;
HANGAR_selectedPilotIndex = -1;
HANGAR_selectedDeployPosIndex = -1;
HANGAR_assigningPilot = false;
HANGAR_uiControls = [];

// Create a force close function at the global level
HANGAR_fnc_forceCloseAllUI = {
    // Force deletion of all custom UI elements
    disableSerialization;
    
    // Log what we're doing
    diag_log "UI: Force closing all hangar UI elements";
    
    // Get Zeus display
    private _zeusDisplay = findDisplay 312;
    
    if (isNull _zeusDisplay) exitWith {
        diag_log "UI: No Zeus display found to clean UI";
        false
    };
    
    // Control IDs to look for and delete
    private _controlIDs = [9820, 9821, 9822, 9823, 9830, 9831, 9832, 9833, 9840, 9841, 9842, 9843];
    
    // Loop through all controls and delete those that match
    {
        private _control = _zeusDisplay displayCtrl _x;
        if (!isNull _control) then {
            ctrlDelete _control;
            diag_log format ["UI: Deleted control %1", _x];
        };
    } forEach _controlIDs;
    
    // Force reset UI flags
    HANGAR_assigningPilot = false;
    HANGAR_selectedPilotIndex = -1;
    HANGAR_selectedDeployPosIndex = -1;
    
    // Clean up controls array
    HANGAR_uiControls = HANGAR_uiControls - [objNull];
    
    true
};

// Function to open the Virtual Hangar UI
HANGAR_fnc_openUI = {
    // Clean up any stray view models from previous sessions
    private _cleaned = [] call HANGAR_fnc_cleanupViewModels;
    if (_cleaned > 0) then {
        systemChat format ["Cleaned up %1 stray aircraft models", _cleaned];
    };
    
    // Store original camera position if needed
    if (isNull curatorCamera) exitWith {
        systemChat "Zeus camera not active";
        diag_log "UI: Cannot open - Zeus camera not active";
    };
    
    // Store current camera position
    HANGAR_originalCamPos = getPosASL curatorCamera;
    HANGAR_originalCamDir = vectorDir curatorCamera;
    
    diag_log format ["UI: Stored original camera position: %1, dir: %2", HANGAR_originalCamPos, HANGAR_originalCamDir];
    
    // Make sure any UI panels are closed first
    call HANGAR_fnc_forceCloseAllUI;
    
    // Move camera to view the hangar area
    [] call fnc_focusCameraOnAirfield;
    
    // Clear any viewed aircraft properly
    call HANGAR_fnc_clearAllViewedAircraft;
    
    // Get the Zeus display
    HANGAR_display = findDisplay 312;
    
    // Initialize UI elements
    call HANGAR_fnc_createCustomUI;
    
    // Select the first category
    if (count HANGAR_aircraftTypes > 0) then {
        HANGAR_selectedCategory = HANGAR_aircraftTypes select 0 select 0;
        call HANGAR_fnc_updateAircraftList;
    };
    
    systemChat "Virtual Hangar opened";
    diag_log "UI: Virtual Hangar UI opened";
};

// Function to close the UI
HANGAR_fnc_closeUI = {
    // Make sure all UI panels are closed first
    call HANGAR_fnc_forceCloseAllUI;
    
    // Clear viewed aircraft properly
    call HANGAR_fnc_clearAllViewedAircraft;
    
    // Restore original camera position
    if (!isNil "HANGAR_originalCamPos") then {
        curatorCamera setPosASL HANGAR_originalCamPos;
        curatorCamera setVectorDir HANGAR_originalCamDir;
        
        // Clear the stored positions
        HANGAR_originalCamPos = nil;
        HANGAR_originalCamDir = nil;
        
        diag_log "UI: Restored original camera position";
    };
    
    // Clean up controls
    {
        ctrlDelete _x;
    } forEach HANGAR_uiControls;
    
    HANGAR_uiControls = [];
    
    systemChat "Virtual Hangar closed";
    diag_log "UI: Virtual Hangar UI closed";
};

// Function to create the main UI elements
HANGAR_fnc_createCustomUI = {
    if (isNull HANGAR_display) exitWith {
        diag_log "UI: Cannot create - display is null";
    };
    
    // Clear any existing controls
    {
        ctrlDelete _x;
    } forEach HANGAR_uiControls;
    HANGAR_uiControls = [];
    
    // Create background with better opacity
    private _background = HANGAR_display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [
        safezoneX,
        safezoneY,
        safezoneW,
        safezoneH
    ];
    _background ctrlSetBackgroundColor [0, 0, 0, 0]; // Less dark background
    _background ctrlCommit 0;
    HANGAR_uiControls pushBack _background;
    
    // Title at the top
    private _title = HANGAR_display ctrlCreate ["RscStructuredText", -1];
    _title ctrlSetPosition [
        safezoneX + (safezoneW * 0.3),
        safezoneY + (safezoneH * 0.05),
        safezoneW * 0.4,
        safezoneH * 0.05
    ];
    _title ctrlSetStructuredText parseText "<t size='1.5' align='center'>RAF Virtual Hangar</t>";
    _title ctrlSetBackgroundColor [0.1, 0.1, 0.3, 0.7];
    _title ctrlCommit 0;
    HANGAR_uiControls pushBack _title;
    
    // Create category buttons (fixed layout)
    private _numCategories = count HANGAR_aircraftTypes;
    private _buttonWidth = (safezoneW * 0.7) / _numCategories;
    private _buttonHeight = safezoneH * 0.05;
    private _startX = safezoneX + (safezoneW * 0.15); // Center the buttons
    private _startY = safezoneY + (safezoneH * 0.12);
    
    for "_i" from 0 to (_numCategories - 1) do {
        private _categoryData = HANGAR_aircraftTypes select _i;
        private _categoryName = _categoryData select 0;
        
        // Create button directly
        private _button = HANGAR_display ctrlCreate ["RscButton", 9810 + _i];
        _button ctrlSetPosition [
            _startX + (_i * _buttonWidth),
            _startY,
            _buttonWidth - (safezoneW * 0.01),
            _buttonHeight
        ];
        _button ctrlSetText _categoryName;
        _button ctrlSetBackgroundColor [0.2, 0.2, 0.4, 0.8];
        _button ctrlSetTextColor [1, 1, 1, 1];
        _button ctrlCommit 0;
        
        // Set tooltip
        _button ctrlSetTooltip format ["View %1 aircraft", _categoryName];
        
        // Add click handler
        _button ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _categoryIndex = (ctrlIDC _ctrl) - 9810;
            private _categoryName = (HANGAR_aircraftTypes select _categoryIndex) select 0;
            
            // Update category selection
            HANGAR_selectedCategory = _categoryName;
            
            // Update aircraft list
            call HANGAR_fnc_updateAircraftList;
            
            // Update category button colors
            call HANGAR_fnc_updateCategoryButtons;
        }];
        
        HANGAR_uiControls pushBack _button;
    };
    
    // Create aircraft list (left panel)
    private _aircraftList = HANGAR_display ctrlCreate ["RscListbox", 9802];
    _aircraftList ctrlSetPosition [
        safezoneX + (safezoneW * 0.1),
        safezoneY + (safezoneH * 0.2),
        safezoneW * 0.25,
        safezoneH * 0.6
    ];
    _aircraftList ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _aircraftList ctrlCommit 0;
    HANGAR_uiControls pushBack _aircraftList;
    
    // Create info panel (right panel)
    private _infoPanel = HANGAR_display ctrlCreate ["RscStructuredText", 9803];
    _infoPanel ctrlSetPosition [
        safezoneX + (safezoneW * 0.65),
        safezoneY + (safezoneH * 0.2),
        safezoneW * 0.25,
        safezoneH * 0.6
    ];
    _infoPanel ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _infoPanel ctrlCommit 0;
    HANGAR_uiControls pushBack _infoPanel;
    
    // === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE BUTTON POSITIONS AND SIZES ===
    // Create action buttons (bottom)
    private _buttonY = safezoneY + (safezoneH * 0.85);
    private _buttonH = safezoneH * 0.06;
    private _buttonW = safezoneW * 0.15;
    private _spacing = safezoneW * 0.01;
    private _numButtons = 6; // Including Close button
    private _totalWidth = (_buttonW * _numButtons) + (_spacing * (_numButtons - 1));
    private _startButtonX = safezoneX + ((safezoneW - _totalWidth) / 2); // Center buttons
    
    // Assign Pilot Button
    private _assignPilotBtn = HANGAR_display ctrlCreate ["RscButton", 9804];
    _assignPilotBtn ctrlSetPosition [
        _startButtonX,
        _buttonY,
        _buttonW,
        _buttonH
    ];
    _assignPilotBtn ctrlSetText "Assign Pilot";
    _assignPilotBtn ctrlSetBackgroundColor [0.2, 0.2, 0.4, 0.8];
    _assignPilotBtn ctrlSetTooltip "Assign a pilot to this aircraft";
    _assignPilotBtn ctrlCommit 0;
    HANGAR_uiControls pushBack _assignPilotBtn;
    
    // Refuel Button
    private _refuelBtn = HANGAR_display ctrlCreate ["RscButton", 9805];
    _refuelBtn ctrlSetPosition [
        _startButtonX + _buttonW + _spacing,
        _buttonY,
        _buttonW,
        _buttonH
    ];
    _refuelBtn ctrlSetText "Refuel";
    _refuelBtn ctrlSetBackgroundColor [0.2, 0.4, 0.2, 0.8];
    _refuelBtn ctrlSetTooltip "Refuel the aircraft using fuel resources";
    _refuelBtn ctrlCommit 0;
    HANGAR_uiControls pushBack _refuelBtn;
    
    // Rearm Button
    private _rearmBtn = HANGAR_display ctrlCreate ["RscButton", 9806];
    _rearmBtn ctrlSetPosition [
        _startButtonX + ((_buttonW + _spacing) * 2),
        _buttonY,
        _buttonW,
        _buttonH
    ];
    _rearmBtn ctrlSetText "Rearm";
    _rearmBtn ctrlSetBackgroundColor [0.4, 0.2, 0.2, 0.8];
    _rearmBtn ctrlSetTooltip "Rearm the aircraft using ammo resources";
    _rearmBtn ctrlCommit 0;
    HANGAR_uiControls pushBack _rearmBtn;
    
    // Deploy Button
    private _deployBtn = HANGAR_display ctrlCreate ["RscButton", 9807];
    _deployBtn ctrlSetPosition [
        _startButtonX + ((_buttonW + _spacing) * 3),
        _buttonY,
        _buttonW,
        _buttonH
    ];
    _deployBtn ctrlSetText "Deploy";
    _deployBtn ctrlSetBackgroundColor [0.4, 0.4, 0.2, 0.8];
    _deployBtn ctrlSetTooltip "Deploy the aircraft to a position on the airfield";
    _deployBtn ctrlCommit 0;
    HANGAR_uiControls pushBack _deployBtn;
    
    // Repair Button
    private _repairBtn = HANGAR_display ctrlCreate ["RscButton", 9808];
    _repairBtn ctrlSetPosition [
        _startButtonX + ((_buttonW + _spacing) * 4),
        _buttonY,
        _buttonW,
        _buttonH
    ];
    _repairBtn ctrlSetText "Repair";
    _repairBtn ctrlSetBackgroundColor [0.2, 0.2, 0.4, 0.8];
    _repairBtn ctrlSetTooltip "Repair the aircraft using materials";
    _repairBtn ctrlCommit 0;
    HANGAR_uiControls pushBack _repairBtn;
    
    // Close button (now a standard button at the bottom)
    private _closeBtn = HANGAR_display ctrlCreate ["RscButton", 9809];
    _closeBtn ctrlSetPosition [
        _startButtonX + ((_buttonW + _spacing) * 5),
        _buttonY,
        _buttonW,
        _buttonH
    ];
    _closeBtn ctrlSetText "Close";
    _closeBtn ctrlSetBackgroundColor [0.5, 0, 0, 0.8];
    _closeBtn ctrlSetTooltip "Close Virtual Hangar";
    _closeBtn ctrlAddEventHandler ["ButtonClick", {
        call HANGAR_fnc_closeUI;
    }];
    _closeBtn ctrlCommit 0;
    HANGAR_uiControls pushBack _closeBtn;
    
    // Create sample aircraft if none exist
    if (count HANGAR_storedAircraft == 0) then {
        call HANGAR_fnc_addSampleAircraft;
    };
    
    // Initialize action buttons
    call HANGAR_fnc_initializeActionButtons;
    
    // Update category button highlighting
    call HANGAR_fnc_updateCategoryButtons;
    
    // Update aircraft list
    call HANGAR_fnc_updateAircraftList;
    
    diag_log "UI: Custom UI created";
};

// Function to update category button highlighting
HANGAR_fnc_updateCategoryButtons = {
    for "_i" from 0 to ((count HANGAR_aircraftTypes) - 1) do {
        private _ctrl = HANGAR_display displayCtrl (9810 + _i);
        private _categoryName = (HANGAR_aircraftTypes select _i) select 0;
        
        if (_categoryName == HANGAR_selectedCategory) then {
            _ctrl ctrlSetBackgroundColor [0.4, 0.4, 0.6, 0.9];
            _ctrl ctrlSetTextColor [1, 1, 1, 1];
        } else {
            _ctrl ctrlSetBackgroundColor [0.2, 0.2, 0.2, 0.8];
            _ctrl ctrlSetTextColor [0.8, 0.8, 0.8, 1];
        };
    };
};

// Function to update aircraft list based on selected category
HANGAR_fnc_updateAircraftList = {
    // Get the list control
    private _listbox = HANGAR_display displayCtrl 9802;
    
    // Clear list
    lbClear _listbox;
    
    // Find aircraft of the selected category
    private _categoryAircraft = [];
    
    // Log the current state for debugging
    diag_log format ["UI: Updating aircraft list. Category: %1, Total stored: %2", HANGAR_selectedCategory, count HANGAR_storedAircraft];
    
    // Process stored aircraft
    {
        _x params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed"];
        
        // Find category for this aircraft type
        private _category = "";
        {
            _x params ["_catName", "_aircraftList"];
            
            {
                if (_x select 0 == _type) exitWith {
                    _category = _catName;
                };
            } forEach _aircraftList;
            
            if (_category != "") exitWith {};
        } forEach HANGAR_aircraftTypes;
        
        // If category matches, add to filtered list
        if (_category == HANGAR_selectedCategory) then {
            _categoryAircraft pushBack [_forEachIndex, _displayName, _isDeployed];
            diag_log format ["UI: Adding aircraft to list: %1 (index: %2, deployed: %3)", _displayName, _forEachIndex, _isDeployed];
        };
    } forEach HANGAR_storedAircraft;
    
    // Add aircraft to list
    {
        _x params ["_index", "_displayName", "_isDeployed"];
        private _prefix = if (_isDeployed) then {"[DEPLOYED] "} else {""};
        private _idx = _listbox lbAdd (_prefix + _displayName);
        _listbox lbSetData [_idx, str _index];
        
        // Make deployed aircraft green
        if (_isDeployed) then {
            _listbox lbSetColor [_idx, [0.5, 1, 0.5, 1]];
        };
    } forEach _categoryAircraft;
    
    // If no aircraft found, add a message
    if (count _categoryAircraft == 0) then {
        _listbox lbAdd "No aircraft in hangar";
        _listbox lbSetData [0, "-1"];
    };
    
    // Add event handler for selection
    _listbox ctrlRemoveAllEventHandlers "LBSelChanged";
    _listbox ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        
        private _data = _control lbData _selectedIndex;
        private _aircraftIndex = parseNumber _data;
        
        // Only proceed if valid index
        if (_aircraftIndex >= 0) then {
            // Update selected aircraft
            HANGAR_selectedAircraftIndex = _aircraftIndex;
            
            // View the aircraft
            [_aircraftIndex] call HANGAR_fnc_viewAircraft;
            
            // Update aircraft info
            call HANGAR_fnc_updateAircraftInfo;
            
            // Update button states
            call HANGAR_fnc_updateActionButtonStates;
        };
    }];
    
    // Reset selection
    HANGAR_selectedAircraftIndex = -1;
    call HANGAR_fnc_clearAllViewedAircraft;
    call HANGAR_fnc_updateAircraftInfo;
    call HANGAR_fnc_updateActionButtonStates;
};

// Function to update aircraft info display
HANGAR_fnc_updateAircraftInfo = {
    private _infoBox = HANGAR_display displayCtrl 9803;
    
    if (HANGAR_selectedAircraftIndex < 0 || HANGAR_selectedAircraftIndex >= count HANGAR_storedAircraft) then {
        // No selection
        _infoBox ctrlSetStructuredText parseText "<t size='1.2' align='center'>No aircraft selected</t><br/><br/><t align='center'>Select an aircraft from the list to view its details.</t>";
    } else {
        // Get aircraft data
        private _record = HANGAR_storedAircraft select HANGAR_selectedAircraftIndex;
        _record params ["_type", "_displayName", "_fuel", "_damage", "_weaponsData", "_crew", "_customData", "_isDeployed", "_deployedInstance"];
        
        // Format weapons text
        private _weaponsText = "";
        {
            _x params ["_weapon", "_ammo", "_weaponName"];
            _weaponsText = _weaponsText + format ["<t size='0.9'>%1: %2 rounds</t><br/>", _weaponName, _ammo];
        } forEach _weaponsData;
        
        if (_weaponsText == "") then {
            _weaponsText = "<t size='0.9'>No weapons data available</t>";
        };
        
        // Format crew text
        private _crewText = "";
        private _requiredCrew = [_type] call HANGAR_fnc_getRequiredCrew;
        
        {
            _x params ["_pilotIndex", "_role", "_turretPath"];
            
            if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
                private _pilotData = HANGAR_pilotRoster select _pilotIndex;
                _pilotData params ["_name", "_rankIndex"];
                
                private _rank = [_rankIndex] call HANGAR_fnc_getPilotRankName;
                private _roleText = switch (_role) do {
                    case "driver": {"Pilot"};
                    case "gunner": {"Gunner"};
                    case "commander": {"Commander"};
                    case "turret": {format ["Turret %1", _turretPath]};
                    case "cargo": {"Crew"};
                    default {"Crew"};
                };
                
                _crewText = _crewText + format ["<t size='0.9'>%1: %2 %3</t><br/>", _roleText, _rank, _name];
            };
        } forEach _crew;
        
        if (_crewText == "") then {
            _crewText = "<t size='0.9'>No crew assigned</t>";
        };
        
        // Calculate crew status text/color
        private _crewStatusText = format ["%1/%2", count _crew, _requiredCrew];
        private _crewStatusColor = if (count _crew >= _requiredCrew) then {"#8cff9b"} else {"#ff8c8c"};
        
        // Deployment status text
        private _deployedText = "";
        if (_isDeployed) then {
            _deployedText = "<t color='#8cff9b' size='1.2'>AIRCRAFT DEPLOYED</t><br/>";
        };
        
        // Format full info with improved layout
        private _infoText = format [
            "<t size='1.5' align='center'>%1</t><br/><br/>" +
            "%11" +
            "<t size='1.2' color='#8888ff'>Status:</t><br/>" +
            "<t size='1.0'>Fuel: <t color='%4'>%2%3</t></t><br/>" +
            "<t size='1.0'>Damage: <t color='%6'>%5%3</t></t><br/>" +
            "<t size='1.0'>Crew: <t color='%8'>%7</t></t><br/><br/>" +
            "<t size='1.2' color='#8888ff'>Weapons:</t><br/>%9<br/>" +
            "<t size='1.2' color='#8888ff'>Crew:</t><br/>%10",
            _displayName,
            round(_fuel * 100),
            "%",
            if (_fuel < 0.3) then {"#ff8c8c"} else {"#8cff9b"},
            round(_damage * 100),
            if (_damage > 0.3) then {"#ff8c8c"} else {"#8cff9b"},
            _crewStatusText,
            _crewStatusColor,
            _weaponsText,
            _crewText,
            _deployedText
        ];
        
        _infoBox ctrlSetStructuredText parseText _infoText;
    };
};

// Function to update action button states
HANGAR_fnc_updateActionButtonStates = {
    // Get action button controls
    private _assignPilotBtn = HANGAR_display displayCtrl 9804;
    private _refuelBtn = HANGAR_display displayCtrl 9805;
    private _rearmBtn = HANGAR_display displayCtrl 9806;
    private _deployBtn = HANGAR_display displayCtrl 9807;
    private _repairBtn = HANGAR_display displayCtrl 9808;
    
    private _hasSelection = HANGAR_selectedAircraftIndex >= 0;
    
    // Enable/disable buttons based on selection
    _assignPilotBtn ctrlEnable _hasSelection;
    _refuelBtn ctrlEnable _hasSelection;
    _rearmBtn ctrlEnable _hasSelection;
    _deployBtn ctrlEnable _hasSelection;
    _repairBtn ctrlEnable _hasSelection;
    
    // Additional checks for deploy button
    if (_hasSelection) then {
        // Check if aircraft has required crew
        private _canDeploy = [HANGAR_selectedAircraftIndex] call HANGAR_fnc_isAircraftFullyCrewed;
        
        // Get deployment status
        private _record = HANGAR_storedAircraft select HANGAR_selectedAircraftIndex;
        private _isDeployed = _record select 7;
        
        // Can deploy if fully crewed or already deployed (to move it)
        _deployBtn ctrlEnable (_canDeploy || _isDeployed);
        
        // Update button text for deployed aircraft
        if (_isDeployed) then {
            _deployBtn ctrlSetText "Reposition";
            _deployBtn ctrlSetTooltip "Move the deployed aircraft to a new position";
        } else {
            _deployBtn ctrlSetText "Deploy";
            _deployBtn ctrlSetTooltip "Deploy the aircraft to a position on the airfield";
        };
    };
};

// Initialize action buttons
HANGAR_fnc_initializeActionButtons = {
    // Get action button controls
    private _assignPilotBtn = HANGAR_display displayCtrl 9804;
    private _refuelBtn = HANGAR_display displayCtrl 9805;
    private _rearmBtn = HANGAR_display displayCtrl 9806;
    private _deployBtn = HANGAR_display displayCtrl 9807;
    private _repairBtn = HANGAR_display displayCtrl 9808;
    
    // Clear existing event handlers to prevent duplicates
    _assignPilotBtn ctrlRemoveAllEventHandlers "ButtonClick";
    _refuelBtn ctrlRemoveAllEventHandlers "ButtonClick";
    _rearmBtn ctrlRemoveAllEventHandlers "ButtonClick";
    _deployBtn ctrlRemoveAllEventHandlers "ButtonClick";
    _repairBtn ctrlRemoveAllEventHandlers "ButtonClick";
    
    // Assign pilot button
    _assignPilotBtn ctrlAddEventHandler ["ButtonClick", {
        diag_log "UI: Assign Pilot button clicked";
        
        if (HANGAR_selectedAircraftIndex >= 0) then {
            call HANGAR_fnc_openPilotSelectionUI;
        } else {
            systemChat "You must select an aircraft first";
        };
    }];
    
    // Refuel button
    _refuelBtn ctrlAddEventHandler ["ButtonClick", {
        if (HANGAR_selectedAircraftIndex >= 0) then {
            [HANGAR_selectedAircraftIndex] call HANGAR_fnc_refuelAircraft;
            call HANGAR_fnc_updateAircraftInfo;
        } else {
            systemChat "You must select an aircraft first";
        };
    }];
    
    // Rearm button
    _rearmBtn ctrlAddEventHandler ["ButtonClick", {
        if (HANGAR_selectedAircraftIndex >= 0) then {
            [HANGAR_selectedAircraftIndex] call HANGAR_fnc_rearmAircraft;
            call HANGAR_fnc_updateAircraftInfo;
        } else {
            systemChat "You must select an aircraft first";
        };
    }];
    
    // Repair button
    _repairBtn ctrlAddEventHandler ["ButtonClick", {
        if (HANGAR_selectedAircraftIndex >= 0) then {
            [HANGAR_selectedAircraftIndex] call HANGAR_fnc_repairAircraft;
            call HANGAR_fnc_updateAircraftInfo;
        } else {
            systemChat "You must select an aircraft first";
        };
    }];
    
    // Deploy button
    _deployBtn ctrlAddEventHandler ["ButtonClick", {
        if (HANGAR_selectedAircraftIndex >= 0) then {
            // Get current record
            private _record = HANGAR_storedAircraft select HANGAR_selectedAircraftIndex;
            private _isDeployed = _record select 7;
            
            if (!_isDeployed) then {
                // Not yet deployed - check crew requirements first
                if ([HANGAR_selectedAircraftIndex] call HANGAR_fnc_isAircraftFullyCrewed) then {
                    call HANGAR_fnc_openDeployPositionUI;
                } else {
                    private _type = _record select 0;
                    private _required = [_type] call HANGAR_fnc_getRequiredCrew;
                    private _current = count (_record select 5);
                    
                    systemChat format ["Aircraft needs %1 crew members, but only has %2", _required, _current];
                };
            } else {
                // Already deployed - just move it
                call HANGAR_fnc_openDeployPositionUI;
            };
        } else {
            systemChat "You must select an aircraft first";
        };
    }];
    
    // Disable action buttons initially
    call HANGAR_fnc_updateActionButtonStates;
    
    diag_log "UI: Action buttons initialized";
};

// ===============================================================
// ENHANCED PILOT ASSIGNMENT UI
// ===============================================================
// Replace the pilot selection UI functions in hangarUI.sqf with these improved versions
// This enables multi-crew assignment and shows available positions

// Function to open pilot selection UI
HANGAR_fnc_openPilotSelectionUI = {
    if (isNull HANGAR_display) exitWith {
        systemChat "Display not found";
        diag_log "UI: Cannot open pilot selection - display not found";
    };
    
    // Ensure any previous pilots UIs are closed first
    call HANGAR_fnc_closePilotSelectionUI;
    
    // Log aircraft selection for debugging
    diag_log format ["UI: Opening pilot selection UI. Selected aircraft index: %1", HANGAR_selectedAircraftIndex];
    
    // Ensure we have a valid aircraft selected
    if (HANGAR_selectedAircraftIndex < 0 || HANGAR_selectedAircraftIndex >= count HANGAR_storedAircraft) exitWith {
        systemChat "No valid aircraft selected";
        diag_log "UI: Cannot open pilot UI: No valid aircraft selected";
    };
    
    // Double check for orphaned pilots in crew list
    private _record = HANGAR_storedAircraft select HANGAR_selectedAircraftIndex;
    private _aircraftName = _record select 1;
    private _crew = _record select 5;
    private _validatedCrew = [];
    
    // Verify each crew member still exists in the roster
    {
        _x params ["_pilotIndex", "_role", "_turretPath"];
        
        if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
            // Pilot exists, keep in crew
            _validatedCrew pushBack _x;
        } else {
            // Pilot no longer exists (was removed from roster)
            diag_log format ["HANGAR: Removing invalid pilot index %1 from %2's crew", _pilotIndex, _aircraftName];
            // Don't add to validated crew
        };
    } forEach _crew;
    
    // Update crew with validated list
    if (count _validatedCrew != count _crew) then {
        diag_log format ["HANGAR: Fixed crew list for %1: %2 entries removed", _aircraftName, (count _crew) - (count _validatedCrew)];
        _record set [5, _validatedCrew];
    };
    
    // Ensure we have some pilots to assign
    if (count HANGAR_pilotRoster == 0) then {
        // Add some sample pilots if none exist
        call HANGAR_fnc_addSamplePilots;
    };
    
    // Get aircraft data
    _record = HANGAR_storedAircraft select HANGAR_selectedAircraftIndex;
    private _aircraftType = _record select 0;
    _aircraftName = _record select 1;
    _crew = _record select 5;
    
    // Get required crew count
    private _requiredCrew = [_aircraftType] call HANGAR_fnc_getRequiredCrew;
    private _currentCrew = count _crew;
    
    // Get available crew positions
    private _availablePositions = [HANGAR_selectedAircraftIndex] call HANGAR_fnc_getAvailableCrewPositions;
    
    // Find aircraft category
    private _aircraftCategory = "";
    {
        _x params ["_category", "_aircraftList"];
        
        {
            _x params ["_className"];
            if (_className == _aircraftType) exitWith {
                _aircraftCategory = _category;
                diag_log format ["UI: Found category %1 for aircraft type %2", _category, _aircraftType];
            };
        } forEach _aircraftList;
        
        if (_aircraftCategory != "") exitWith {};
    } forEach HANGAR_aircraftTypes;
    
    // Create pilot selection overlay fresh each time
    private _overlay = HANGAR_display ctrlCreate ["RscText", 9820];
    _overlay ctrlSetPosition [
        safezoneX + (safezoneW * 0.3),
        safezoneY + (safezoneH * 0.2),
        safezoneW * 0.4,
        safezoneH * 0.6
    ];
    _overlay ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _overlay ctrlCommit 0;
    HANGAR_uiControls pushBack _overlay;
    
    // Title with aircraft info and crew requirements
    private _title = HANGAR_display ctrlCreate ["RscStructuredText", 9840, _overlay];
    _title ctrlSetPosition [
        0,
        0,
        safezoneW * 0.4,
        safezoneH * 0.08
    ];
    _title ctrlSetStructuredText parseText format [
        "<t align='center' size='1.2'>SELECT PILOT</t><br/>" +
        "<t align='center' size='1.0'>%1 - Crew: %2/%3</t>",
        _aircraftName,
        _currentCrew,
        _requiredCrew
    ];
    _title ctrlSetBackgroundColor [0.2, 0.2, 0.4, 0.8];
    _title ctrlCommit 0;
    
    // Position selection combo box - NEW
    private _posLabel = HANGAR_display ctrlCreate ["RscText", 9843, _overlay];
    _posLabel ctrlSetPosition [
        safezoneW * 0.02,
        safezoneH * 0.09,
        safezoneW * 0.1,
        safezoneH * 0.03
    ];
    _posLabel ctrlSetText "Position:";
    _posLabel ctrlCommit 0;
    
    private _posCombo = HANGAR_display ctrlCreate ["RscCombo", 9844, _overlay];
    _posCombo ctrlSetPosition [
        safezoneW * 0.13,
        safezoneH * 0.09,
        safezoneW * 0.25,
        safezoneH * 0.03
    ];
    _posCombo ctrlCommit 0;
    
    // Add available positions to combo
    {
        _x params ["_role", "_turretPath"];
        
        private _posName = switch (_role) do {
            case "driver": {"Pilot"};
            case "gunner": {"Gunner"};
            case "commander": {"Commander"};
            case "turret": {format ["Turret %1", _turretPath]};
            case "cargo": {"Crew"};
            default {"Unknown"};
        };
        
        private _idx = _posCombo lbAdd _posName;
        _posCombo lbSetData [_idx, format ["%1|%2", _role, _turretPath]];
    } forEach _availablePositions;
    
    // Default to first position if any are available
    if (count _availablePositions > 0) then {
        _posCombo lbSetCurSel 0;
    } else {
        // No positions left - show warning
        _posCombo lbAdd "No positions available";
        _posCombo lbSetCurSel 0;
        _posCombo ctrlEnable false;
    };
    
    // Existing crew list - NEW
    private _crewLabel = HANGAR_display ctrlCreate ["RscText", 9845, _overlay];
    _crewLabel ctrlSetPosition [
        safezoneW * 0.02,
        safezoneH * 0.13,
        safezoneW * 0.36,
        safezoneH * 0.03
    ];
    _crewLabel ctrlSetText "Current Crew:";
    _crewLabel ctrlCommit 0;
    
    private _crewList = HANGAR_display ctrlCreate ["RscListbox", 9846, _overlay];
    _crewList ctrlSetPosition [
        safezoneW * 0.02,
        safezoneH * 0.17,
        safezoneW * 0.36,
        safezoneH * 0.1
    ];
    _crewList ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.5];
    _crewList ctrlCommit 0;
    
    // Add current crew to list
    {
        _x params ["_pilotIndex", "_role", "_turretPath"];
        
        if (_pilotIndex >= 0 && _pilotIndex < count HANGAR_pilotRoster) then {
            private _pilotData = HANGAR_pilotRoster select _pilotIndex;
            _pilotData params ["_name", "_rankIndex"];
            
            private _rank = [_rankIndex] call HANGAR_fnc_getPilotRankName;
            private _roleText = switch (_role) do {
                case "driver": {"Pilot"};
                case "gunner": {"Gunner"};
                case "commander": {"Commander"};
                case "turret": {format ["Turret %1", _turretPath]};
                case "cargo": {"Crew"};
                default {"Unknown"};
            };
            
            private _idx = _crewList lbAdd format ["%1: %2 %3", _roleText, _rank, _name];
            _crewList lbSetData [_idx, str _pilotIndex];
        };
    } forEach _crew;
    
    if (count _crew == 0) then {
        _crewList lbAdd "No crew assigned";
    };
    
    // Pilot listbox
    private _pilotLabel = HANGAR_display ctrlCreate ["RscText", 9847, _overlay];
    _pilotLabel ctrlSetPosition [
        safezoneW * 0.02,
        safezoneH * 0.28,
        safezoneW * 0.36,
        safezoneH * 0.03
    ];
    _pilotLabel ctrlSetText "Available Pilots:";
    _pilotLabel ctrlCommit 0;
    
    private _listbox = HANGAR_display ctrlCreate ["RscListbox", 9821, _overlay];
    _listbox ctrlSetPosition [
        safezoneW * 0.02,
        safezoneH * 0.32,
        safezoneW * 0.36,
        safezoneH * 0.25
    ];
    _listbox ctrlSetBackgroundColor [0, 0, 0, 0.5];
    _listbox ctrlCommit 0;
    
    // Add pilots to list
    private _availablePilots = [];
    
    // Collect available pilots that match the aircraft specialization
    {
        private _pilotData = _x;
        _pilotData params ["_name", "_rankIndex", "_missions", "_kills", "_specialization", "_aircraft"];
        private _pilotIndex = _forEachIndex;
        private _isAvailable = true;
        
        // First check if pilot is not assigned to any aircraft
        if (!isNull _aircraft) then {
            _isAvailable = false;
            diag_log format ["UI: Pilot %1 already assigned to aircraft", _name];
        } else {
            // Even if aircraft is null, double check all aircraft records
            // to ensure pilot isn't in any crew lists
            {
                private _record = _x;
                if (count _record >= 6) then {
                    private _crew = _record select 5;
                    {
                        _x params ["_crewPilotIndex"];
                        if (_crewPilotIndex == _pilotIndex) exitWith {
                            _isAvailable = false;
                            diag_log format ["UI: Pilot %1 found in crew list of another aircraft", _name];
                        };
                    } forEach _crew;
                };
                // If already found as unavailable, no need to check more
                if (!_isAvailable) exitWith {};
            } forEach HANGAR_storedAircraft;
        };
        
        // Check specialization matches only if pilot is available
        if (_isAvailable && (_specialization == _aircraftCategory || _aircraftCategory == "")) then {
            _availablePilots pushBack _forEachIndex;
            diag_log format ["UI: Found available pilot: %1 with specialization %2", _name, _specialization];
        };
    } forEach HANGAR_pilotRoster;
    
    diag_log format ["UI: Found %1 available pilots for aircraft category %2", count _availablePilots, _aircraftCategory];
    
    if (count _availablePilots == 0) then {
        _listbox lbAdd "No available pilots with matching specialization";
        _listbox lbSetData [0, "-1"];
        
        // Add a helpful message if no pilots
        private _infoText = HANGAR_display ctrlCreate ["RscText", 9842, _overlay];
        _infoText ctrlSetPosition [
            safezoneW * 0.02,
            safezoneH * 0.58,
            safezoneW * 0.36,
            safezoneH * 0.05
        ];
        _infoText ctrlSetText format ["Need pilots specialized in %1", _aircraftCategory];
        _infoText ctrlSetTextColor [1, 0.7, 0.7, 1];
        _infoText ctrlCommit 0;
    } else {
        {
            private _pilotIndex = _x;
            private _pilotData = HANGAR_pilotRoster select _pilotIndex;
            _pilotData params ["_name", "_rankIndex", "_missions", "_kills", "_specialization"];
            
            private _rankName = [_rankIndex] call HANGAR_fnc_getPilotRankName;
            private _displayName = format ["%1 %2 - %3 missions, %4 kills - %5", _rankName, _name, _missions, _kills, _specialization];
            
            private _idx = _listbox lbAdd _displayName;
            _listbox lbSetData [_idx, str _pilotIndex];
            
            // Color based on specialization
            switch (_specialization) do {
                case "Fighters": {
                    _listbox lbSetColor [_idx, [0.7, 0.7, 1, 1]];
                };
                case "Bombers": {
                    _listbox lbSetColor [_idx, [1, 0.7, 0.7, 1]];
                };
                case "Transport": {
                    _listbox lbSetColor [_idx, [0.7, 1, 0.7, 1]];
                };
                case "Recon": {
                    _listbox lbSetColor [_idx, [1, 1, 0.7, 1]];
                };
            };
        } forEach _availablePilots;
    };
    
    // Set selection handler
    _listbox ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        
        if (_selectedIndex >= 0) then {
            private _data = _control lbData _selectedIndex;
            HANGAR_selectedPilotIndex = parseNumber _data;
            diag_log format ["UI: Selected pilot index: %1", HANGAR_selectedPilotIndex];
        };
    }];
    
    // Store the position combo reference for confirmation handler
    HANGAR_positionCombo = _posCombo;
    
    // Confirm button
    private _confirmBtn = HANGAR_display ctrlCreate ["RscButton", 9822, _overlay];
    _confirmBtn ctrlSetPosition [
        safezoneW * 0.06,
        safezoneH * 0.52,
        safezoneW * 0.12,
        safezoneH * 0.05
    ];
    _confirmBtn ctrlSetText "CONFIRM";
    _confirmBtn ctrlSetBackgroundColor [0.2, 0.4, 0.2, 0.8];
    _confirmBtn ctrlCommit 0;
    
    // Confirm button action
    _confirmBtn ctrlAddEventHandler ["ButtonClick", {
        if (HANGAR_selectedPilotIndex >= 0) then {
            // Double check aircraft index is valid
            if (HANGAR_selectedAircraftIndex >= 0 && HANGAR_selectedAircraftIndex < count HANGAR_storedAircraft) then {
                // Get selected position from combo
                private _posCombo = HANGAR_positionCombo;
                private _posIndex = lbCurSel _posCombo;
                private _posData = "";
                
                if (_posIndex >= 0) then {
                    _posData = _posCombo lbData _posIndex;
                };
                
                // Parse position data
                private _role = "driver"; // Default
                private _turretPath = [];
                
                if (_posData != "") then {
                    private _parts = _posData splitString "|";
                    if (count _parts >= 1) then {
                        _role = _parts select 0;
                    };
                    
                    if (count _parts >= 2) then {
                        private _pathStr = _parts select 1;
                        // Parse turret path from string representation
                        if (_pathStr != "[]") then {
                            _turretPath = [parseNumber (_pathStr select [1, (count _pathStr) - 2])];
                        };
                    };
                };
                
                // Log the assignment for debugging
                diag_log format ["UI: Confirming pilot assignment. Pilot: %1, Aircraft: %2, Role: %3, TurretPath: %4", 
                    HANGAR_selectedPilotIndex, HANGAR_selectedAircraftIndex, _role, _turretPath];
                
                // Assign pilot to aircraft with specific role
                [HANGAR_selectedPilotIndex, HANGAR_selectedAircraftIndex, _role, _turretPath] call HANGAR_fnc_assignPilotToStoredAircraft;
            } else {
                systemChat "Invalid aircraft selection";
                diag_log format ["UI: Invalid aircraft index: %1", HANGAR_selectedAircraftIndex];
            };
        } else {
            systemChat "No pilot selected";
        };
        
        // Close selection UI
        call HANGAR_fnc_closePilotSelectionUI;
        
        // Update aircraft info
        call HANGAR_fnc_updateAircraftInfo;
        call HANGAR_fnc_updateActionButtonStates;
    }];
    
    // Cancel button
    private _cancelBtn = HANGAR_display ctrlCreate ["RscButton", 9823, _overlay];
    _cancelBtn ctrlSetPosition [
        safezoneW * 0.22,
        safezoneH * 0.52,
        safezoneW * 0.12,
        safezoneH * 0.05
    ];
    _cancelBtn ctrlSetText "CANCEL";
    _cancelBtn ctrlSetBackgroundColor [0.4, 0.2, 0.2, 0.8];
    _cancelBtn ctrlCommit 0;
    
    // Cancel button action
    _cancelBtn ctrlAddEventHandler ["ButtonClick", {
        call HANGAR_fnc_closePilotSelectionUI;
    }];
    
    // Set flag
    HANGAR_assigningPilot = true;
    
    // Select first pilot by default
    if (lbSize _listbox > 0) then {
        _listbox lbSetCurSel 0;
    };
    
    diag_log "UI: Opened pilot selection UI";
};

// Enhanced function to close pilot selection UI
HANGAR_fnc_closePilotSelectionUI = {
    // Clean up position combo reference
    HANGAR_positionCombo = nil;
    
    // Log what we're attempting to close
    diag_log "UI: Attempting to close pilot selection UI - detailed cleanup";
    
    // Explicitly try to delete controls by ID
    private _display = findDisplay 312;
    if (!isNull _display) then {
        // Main overlay
        private _overlay = _display displayCtrl 9820;
        if (!isNull _overlay) then {
            ctrlDelete _overlay;
        };
        
        // Explicitly delete all child controls (even if parent is deleted, sometimes children remain)
        {
            private _ctrl = _display displayCtrl _x;
            if (!isNull _ctrl) then {
                ctrlDelete _ctrl;
                diag_log format ["UI: Explicitly deleted control ID: %1", _x];
            };
        } forEach [9821, 9822, 9823, 9840, 9841, 9842, 9843, 9844, 9845, 9846, 9847];
    };
    
    // Clean up from HANGAR_uiControls array too
    private _controlsToRemove = [];
    {
        // Check if control is part of pilot UI
        private _ctrl = _x;
        private _idc = ctrlIDC _ctrl;
        if (_idc >= 9820 && _idc <= 9850) then {
            ctrlDelete _ctrl;
            _controlsToRemove pushBack _ctrl;
        };
    } forEach HANGAR_uiControls;
    
    // Remove from array
    HANGAR_uiControls = HANGAR_uiControls - _controlsToRemove;
    
    // Reset flag
    HANGAR_assigningPilot = false;
    HANGAR_selectedPilotIndex = -1;
    
    diag_log "UI: Closed pilot selection UI - flags reset and controls deleted";
};

// Function to open deploy position selection UI
HANGAR_fnc_openDeployPositionUI = {
    // Ensure any previous deploy UIs are closed first
    call HANGAR_fnc_closeDeployPositionUI;
    
    // Create overlay from scratch
    private _overlay = HANGAR_display ctrlCreate ["RscText", 9830];
    _overlay ctrlSetPosition [
        safezoneX + (safezoneW * 0.3),
        safezoneY + (safezoneH * 0.2),
        safezoneW * 0.4,
        safezoneH * 0.6
    ];
    _overlay ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _overlay ctrlCommit 0;
    HANGAR_uiControls pushBack _overlay;
    
    // Title
    private _title = HANGAR_display ctrlCreate ["RscText", 9841, _overlay];
    _title ctrlSetPosition [
        0,
        0,
        safezoneW * 0.4,
        safezoneH * 0.05
    ];
    _title ctrlSetText "SELECT DEPLOY POSITION";
    _title ctrlSetTextColor [1, 1, 1, 1];
    _title ctrlSetBackgroundColor [0.4, 0.4, 0.2, 0.8];
    _title ctrlSetFont "PuristaBold";
    _title ctrlCommit 0;
    
    // Position listbox
    private _listbox = HANGAR_display ctrlCreate ["RscListbox", 9831, _overlay];
    _listbox ctrlSetPosition [
        safezoneW * 0.02,
        safezoneH * 0.08,
        safezoneW * 0.36,
        safezoneH * 0.42
    ];
    _listbox ctrlSetBackgroundColor [0, 0, 0, 0.5];
    _listbox ctrlCommit 0;
    
    // Add deploy positions to list - check if markers exist
    private _validPositions = 0;
    
    {
        private _positionName = _x;
        if (markerType _positionName != "") then {
            private _displayName = format ["Position %1", _forEachIndex + 1];
            
            private _idx = _listbox lbAdd _displayName;
            _listbox lbSetData [_idx, str _forEachIndex];
            _validPositions = _validPositions + 1;
        };
    } forEach HANGAR_deployPositions;
    
    // If no valid positions, add a message
    if (_validPositions == 0) then {
        _listbox lbAdd "No valid deploy positions defined";
        _listbox lbSetData [0, "-1"];
        systemChat "WARNING: No deploy position markers found. Add markers named hangar_deploy_1 through hangar_deploy_5.";
    };
    
    // Set selection handler
    _listbox ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        
        if (_selectedIndex >= 0) then {
            private _data = _control lbData _selectedIndex;
            HANGAR_selectedDeployPosIndex = parseNumber _data;
            diag_log format ["UI: Selected deploy position index: %1", HANGAR_selectedDeployPosIndex];
        };
    }];
    
    // Confirm button
    private _confirmBtn = HANGAR_display ctrlCreate ["RscButton", 9832, _overlay];
    _confirmBtn ctrlSetPosition [
        safezoneW * 0.06,
        safezoneH * 0.52,
        safezoneW * 0.12,
        safezoneH * 0.05
    ];
    _confirmBtn ctrlSetText "DEPLOY";
    _confirmBtn ctrlSetBackgroundColor [0.4, 0.4, 0.2, 0.8];
    _confirmBtn ctrlCommit 0;
    
    // Get current aircraft record to update button text if repositioning
    private _record = HANGAR_storedAircraft select HANGAR_selectedAircraftIndex;
    private _isDeployed = _record select 7;
    
    if (_isDeployed) then {
        _confirmBtn ctrlSetText "REPOSITION";
    } else {
        _confirmBtn ctrlSetText "DEPLOY";
    };
    
    // Confirm button action
    _confirmBtn ctrlAddEventHandler ["ButtonClick", {
        if (HANGAR_selectedDeployPosIndex >= 0) then {
            // Deploy aircraft
            [HANGAR_selectedAircraftIndex, HANGAR_selectedDeployPosIndex] call HANGAR_fnc_deployAircraft;
            
            // Close deploy position selection
            call HANGAR_fnc_closeDeployPositionUI;
            
            // Update UI
            call HANGAR_fnc_updateAircraftList;
            call HANGAR_fnc_updateAircraftInfo;
            call HANGAR_fnc_updateActionButtonStates;
        } else {
            systemChat "You must select a deploy position first";
        };
    }];
    
    // Cancel button
    private _cancelBtn = HANGAR_display ctrlCreate ["RscButton", 9833, _overlay];
    _cancelBtn ctrlSetPosition [
        safezoneW * 0.22,
        safezoneH * 0.52,
        safezoneW * 0.12,
        safezoneH * 0.05
    ];
    _cancelBtn ctrlSetText "CANCEL";
    _cancelBtn ctrlSetBackgroundColor [0.4, 0.2, 0.2, 0.8];
    _cancelBtn ctrlCommit 0;
    
    // Cancel button action
    _cancelBtn ctrlAddEventHandler ["ButtonClick", {
        call HANGAR_fnc_closeDeployPositionUI;
    }];
    
    // Select first position by default
    if (lbSize _listbox > 0) then {
        _listbox lbSetCurSel 0;
    };
    
    diag_log "UI: Opened deploy position UI";
};

// Function to close deploy position UI
HANGAR_fnc_closeDeployPositionUI = {
    // Call the global force close function
    call HANGAR_fnc_forceCloseAllUI;
    
    // Extra attempt to explicitly delete the overlay
    private _display = findDisplay 312; // Zeus display
    if (!isNull _display) then {
        private _overlay = _display displayCtrl 9830;
        if (!isNull _overlay) then {
            ctrlDelete _overlay;
            diag_log "UI: Deleted deploy position overlay specifically";
        };
    };
    
    HANGAR_selectedDeployPosIndex = -1;
    diag_log "UI: Closed deploy position UI";
};

// Register the Virtual Hangar function for the menu system
fnc_openVirtualHangarUI = {
    [] spawn {
        // Small delay to ensure Zeus is fully initialized
        sleep 0.1;
        call HANGAR_fnc_openUI;
    };
};