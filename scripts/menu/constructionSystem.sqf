// scripts/menu/constructionSystem.sqf
// Construction System for WW2 RTS - Integrated with existing economy and research

// Initialize construction variables if not already defined
if (isNil "MISSION_constructionQueue") then {
    MISSION_constructionQueue = [];
};

if (isNil "MISSION_selectedFactory") then {
    MISSION_selectedFactory = 0;
};

if (isNil "MISSION_constructionUIOpen") then {
    MISSION_constructionUIOpen = false;
};

// Initialize construction resources if needed
if (isNil "MISSION_constructionResources") then {
    MISSION_constructionResources = [];
    // Copy from economy system if available
    if (!isNil "RTS_resources") then {
        {
            _x params ["_name", "_amount"];
            MISSION_constructionResources pushBack [_name, _amount];
        } forEach RTS_resources;
    };
};

// Initialize construction options if needed
if (isNil "MISSION_constructionOptions") then {
    MISSION_constructionOptions = [];
    // Format: [classname, displayName, category, quantity, resources, constructionTime]
    // Example: ["JMSSA_LeeEnfield_Rifle", "Lee-Enfield No.4", "Small Arms", 0, [["Iron", 50], ["Wood", 30]], 60]
    
    // Add some default construction options that don't require research
    MISSION_constructionOptions = [
        
    ];
};

// Number of factories
if (isNil "MISSION_factoryCount") then {
    MISSION_factoryCount = 5;
};

// Function to get a resource amount from the economy system
fnc_getResourceAmount = {
    params ["_resourceName"];
    
    // Get lowercase resource name for case-insensitive checking
    private _lowerResourceName = toLower _resourceName;
    private _amount = 0;
    
    // Try to use the existing economy resource functions first
    if (!isNil "RTS_fnc_getResource") then {
        _amount = [_resourceName] call RTS_fnc_getResource;
        if (!isNil "_amount") then {
            // Return successful result early
            _amount
        } else {
            // Reset to 0 if result was nil
            _amount = 0;
        };
    };
    
    // If amount is still 0, check RTS_resources directly
    if (_amount == 0) then {
        if (!isNil "RTS_resources") then {
            {
                _x params ["_resName", "_resAmount"];
                if (toLower _resName == _lowerResourceName) exitWith {
                    _amount = _resAmount;
                };
            } forEach RTS_resources;
        };
    };
    
    // Last fallback: check construction resources directly
    if (_amount == 0) then {
        if (!isNil "MISSION_constructionResources") then {
            {
                _x params ["_resName", "_resAmount"];
                if (toLower _resName == _lowerResourceName) exitWith {
                    _amount = _resAmount;
                };
            } forEach MISSION_constructionResources;
        };
    };
    
    // Log resource lookup for debugging
    diag_log format ["Resource lookup: %1 -> %2", _resourceName, _amount];
    
    // Return the amount (or 0 if not found)
    _amount
};

// Function to modify a resource amount
fnc_modifyResource = {
    params ["_resourceName", "_amount"];
    
    // Get lowercase resource name for case-insensitive checking
    private _lowerResourceName = toLower _resourceName;
    private _modified = false;
    
    // Try to use the existing economy resource functions first
    if (!isNil "RTS_fnc_modifyResource") then {
        diag_log format ["Using RTS_fnc_modifyResource to modify %1 by %2", _resourceName, _amount];
        _modified = [_resourceName, _amount] call RTS_fnc_modifyResource;
        if (_modified) exitWith {};
    };
    
    // Fallback: modify RTS_resources directly
    if (!_modified && !isNil "RTS_resources") then {
        {
            _x params ["_resName", "_resAmount"];
            if (toLower _resName == _lowerResourceName) exitWith {
                private _newAmount = _resAmount + _amount;
                
                // Ensure resource doesn't go below zero
                if (_newAmount < 0) then { _newAmount = 0; };
                
                RTS_resources set [_forEachIndex, [_resName, _newAmount]];
                diag_log format ["Modified %1 in RTS_resources: %2 -> %3", _resourceName, _resAmount, _newAmount];
                _modified = true;
            };
        } forEach RTS_resources;
    };
    
    // Last fallback: modify construction resources directly
    if (!_modified && !isNil "MISSION_constructionResources") then {
        {
            _x params ["_resName", "_resAmount"];
            if (toLower _resName == _lowerResourceName) exitWith {
                private _newAmount = _resAmount + _amount;
                
                // Ensure resource doesn't go below zero
                if (_newAmount < 0) then { _newAmount = 0; };
                
                MISSION_constructionResources set [_forEachIndex, [_resName, _newAmount]];
                diag_log format ["Modified %1 in MISSION_constructionResources: %2 -> %3", _resourceName, _resAmount, _newAmount];
                _modified = true;
            };
        } forEach MISSION_constructionResources;
    };
    
    // Resource not found in any system
    if (!_modified) then {
        diag_log format ["Warning: Resource %1 not found in any resource system", _resourceName];
    };
    
    _modified
};

// Function to open the Construction UI
fnc_openConstructionUI = {
    if (dialog) then {closeDialog 0};
    createDialog "RscDisplayEmpty";
    
    private _display = findDisplay -1;
    
    if (isNull _display) exitWith {
        diag_log "Failed to create Construction UI";
        systemChat "Error: Could not create construction interface";
        false
    };
    
    // Update MISSION_constructionResources from RTS_resources for synchronization
    if (!isNil "RTS_resources") then {
        // Clear old resources
        MISSION_constructionResources = [];
        // Copy fresh values
        {
            if (count _x >= 2) then {
                _x params ["_name", "_value"];
                MISSION_constructionResources pushBack [_name, _value];
            };
        } forEach RTS_resources;
    };
    
    // Set flag
    MISSION_constructionUIOpen = true;
    
    // Create background
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.7 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", -1];
    _title ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetText "Production Facilities";
    _title ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _title ctrlCommit 0;
    
    // Create resource display
    private _resourcesText = _display ctrlCreate ["RscText", 1700];
    _resourcesText ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.21 * safezoneH + safezoneY, 0.56 * safezoneW, 0.04 * safezoneH];
    _resourcesText ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
    _resourcesText ctrlCommit 0;
    
    // Create factory buttons
    for "_i" from 0 to (MISSION_factoryCount - 1) do {
        private _factoryButton = _display ctrlCreate ["RscButton", 1100 + _i];
        _factoryButton ctrlSetPosition [
            0.22 * safezoneW + safezoneX,
            (0.26 + (_i * 0.06)) * safezoneH + safezoneY,
            0.15 * safezoneW,
            0.05 * safezoneH
        ];
        _factoryButton ctrlSetText format ["Factory %1", _i + 1];
        _factoryButton ctrlSetEventHandler ["ButtonClick", format ["[%1] call fnc_selectFactory", _i]];
        _factoryButton ctrlCommit 0;
    };
    
    // Create category tabs
    private _categories = [];
    {
        private _category = _x select 2;
        if (!(_category in _categories) && _category != "") then {
            _categories pushBack _category;
        };
    } forEach MISSION_constructionOptions;
    
    for "_i" from 0 to ((count _categories) - 1) min 4 do {
        private _category = _categories select _i;
        private _tabButton = _display ctrlCreate ["RscButton", 1200 + _i];
        _tabButton ctrlSetPosition [
            (0.38 + (_i * 0.09)) * safezoneW + safezoneX,
            0.26 * safezoneH + safezoneY,
            0.09 * safezoneW,
            0.04 * safezoneH
        ];
        _tabButton ctrlSetText _category;
        _tabButton setVariable ["category", _category];
        _tabButton ctrlSetEventHandler ["ButtonClick", "params ['_ctrl']; [_ctrl getVariable 'category'] call fnc_switchConstructionTab"];
        _tabButton ctrlCommit 0;
    };
    
    // Create construction options list box
    private _optionsListBox = _display ctrlCreate ["RscListBox", 1300];
    _optionsListBox ctrlSetPosition [0.38 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.2 * safezoneW, 0.4 * safezoneH];
    _optionsListBox ctrlCommit 0;
    
    // Create construction queue list box
    private _queueListBox = _display ctrlCreate ["RscListBox", 1400];
    _queueListBox ctrlSetPosition [0.59 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.19 * safezoneW, 0.4 * safezoneH];
    _queueListBox ctrlCommit 0;
    
    // Create details panel
    private _detailsPanel = _display ctrlCreate ["RscStructuredText", 1500];
    _detailsPanel ctrlSetPosition [0.38 * safezoneW + safezoneX, 0.72 * safezoneH + safezoneY, 0.2 * safezoneW, 0.12 * safezoneH];
    _detailsPanel ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
    _detailsPanel ctrlCommit 0;
    
    // Create "Add to Queue" button
    private _addButton = _display ctrlCreate ["RscButton", 1600];
    _addButton ctrlSetPosition [0.59 * safezoneW + safezoneX, 0.72 * safezoneH + safezoneY, 0.19 * safezoneW, 0.05 * safezoneH];
    _addButton ctrlSetText "Add to Construction Queue";
    _addButton ctrlSetEventHandler ["ButtonClick", "[] call fnc_addToConstructionQueue"];
    _addButton ctrlCommit 0;
    
    // Create close button
    private _closeButton = _display ctrlCreate ["RscButton", 1700];
    _closeButton ctrlSetPosition [0.7 * safezoneW + safezoneX, 0.79 * safezoneH + safezoneY, 0.08 * safezoneW, 0.04 * safezoneH];
    _closeButton ctrlSetText "Close";
    _closeButton ctrlSetEventHandler ["ButtonClick", "closeDialog 0"];
    _closeButton ctrlCommit 0;
    
    // Add event handlers
    _optionsListBox ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        [_control, _selectedIndex] call fnc_updateDetailsPanel;
    }];
    
    // Add handler for dialog closure
    _display displayAddEventHandler ["Unload", {
        MISSION_constructionUIOpen = false;
    }];
    
    // Select default factory
    [MISSION_selectedFactory] call fnc_selectFactory;
    
    // Switch to first tab if available
    if (count _categories > 0) then {
        [_categories select 0] call fnc_switchConstructionTab;
    };
    
    // Debug resource info
    if (!isNil "RTS_resources") then {
        diag_log format ["RTS_resources: %1", RTS_resources];
    } else {
        diag_log "RTS_resources is nil";
    }; 
    
    // Start UI update loop
    [] spawn {
        while {MISSION_constructionUIOpen && !isNull findDisplay -1} do {
            call fnc_updateConstructionUI;
            sleep 0.5;
        };
    };
};

// Function to select a factory
fnc_selectFactory = {
    params ["_factoryIndex"];
    
    // Save selected factory
    MISSION_selectedFactory = _factoryIndex;
    
    private _display = findDisplay -1;
    
    // Update button visuals
    for "_i" from 0 to (MISSION_factoryCount - 1) do {
        private _factoryButton = _display displayCtrl (1100 + _i);
        if (!isNull _factoryButton) then {
            if (_i == _factoryIndex) then {
                _factoryButton ctrlSetBackgroundColor [0.3, 0.3, 0.8, 1];
            } else {
                _factoryButton ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
            };
        };
    };
    
    // Update queue display
    call fnc_updateQueueDisplay;
};

// Function to switch construction tab
fnc_switchConstructionTab = {
    params ["_category"];
    
    private _display = findDisplay -1;
    
    // Update tab button visuals
    for "_i" from 0 to 4 do {
        private _tabButton = _display displayCtrl (1200 + _i);
        if (!isNull _tabButton) then {
            if ((_tabButton getVariable ["category", ""]) == _category) then {
                _tabButton ctrlSetBackgroundColor [0.3, 0.3, 0.8, 1];
            } else {
                _tabButton ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
            };
        };
    };
    
    // Store current category
    _display setVariable ["currentCategory", _category];
    
    // Update options list
    [_category] call fnc_updateOptionsList;
};

// Function to update options list for a category
fnc_updateOptionsList = {
    params ["_category"];
    
    private _display = findDisplay -1;
    private _optionsListBox = _display displayCtrl 1300;
    
    if (isNull _optionsListBox) exitWith {
        diag_log "Error: Options list box control not found";
    };
    
    // Clear current list
    lbClear _optionsListBox;
    
    // Filter options by category
    private _categoryOptions = [];
    
    // Use for loop instead of select to be safer
    for "_i" from 0 to ((count MISSION_constructionOptions) - 1) do {
        private _option = MISSION_constructionOptions select _i;
        if (!isNil "_option" && {count _option >= 3}) then {
            if (_option select 2 == _category) then {
                _categoryOptions pushBack _option;
            };
        };
    };
    
    // Add each option to the list
    {
        private _className = _x select 0;
        private _displayName = _x select 1;
        private _quantity = _x select 3;
        
        if (isNil "_className") then { _className = "unknown"; };
        if (isNil "_displayName") then { _displayName = "Unknown Item"; };
        if (isNil "_quantity") then { _quantity = 0; };
        
        private _index = _optionsListBox lbAdd format ["%1 (Available: %2)", _displayName, _quantity];
        _optionsListBox lbSetData [_index, _className];
        
        // Set color based on availability
        if (_quantity > 0) then {
            _optionsListBox lbSetColor [_index, [1, 1, 1, 1]]; // White for available
        } else {
            _optionsListBox lbSetColor [_index, [0.5, 0.5, 0.5, 1]]; // Gray for unavailable
        };
    } forEach _categoryOptions;
    
    // Select first item by default
    if (lbSize _optionsListBox > 0) then {
        _optionsListBox lbSetCurSel 0;
    };
};

// Function to update queue display
fnc_updateQueueDisplay = {
    private _display = findDisplay -1;
    private _queueListBox = _display displayCtrl 1400;
    
    // Clear current list
    lbClear _queueListBox;
    
    // Get items in the queue for this factory
    private _factoryQueue = MISSION_constructionQueue select {(_x select 0) == MISSION_selectedFactory};
    
    // Add each item to the list
    {
        _x params ["", "_className", "_startTime", "_endTime"];
        
        // Find display name
        private _index = MISSION_constructionOptions findIf {(_x select 0) == _className};
        if (_index != -1) then {
            private _displayName = (MISSION_constructionOptions select _index) select 1;
            private _timeLeft = _endTime - time;
            
            private _lbIndex = _queueListBox lbAdd format ["%1 (%2s)", _displayName, floor _timeLeft];
            _queueListBox lbSetData [_lbIndex, _className];
            
            // Set color based on progress
            private _progress = 1 - (_timeLeft / (_endTime - _startTime));
            private _color = [
                0.5 + (_progress * 0.5),
                0.5 + (_progress * 0.5),
                0.2,
                1
            ];
            
            _queueListBox lbSetColor [_lbIndex, _color];
        };
    } forEach _factoryQueue;
};

// Function to update details panel
fnc_updateDetailsPanel = {
    params ["_control", "_selectedIndex"];
    
    if (_selectedIndex < 0) exitWith {};
    
    private _className = _control lbData _selectedIndex;
    private _display = ctrlParent _control;
    private _detailsPanel = _display displayCtrl 1500;
    private _addButton = _display displayCtrl 1600;
    
    if (isNull _detailsPanel || isNull _addButton) exitWith {
        systemChat "Error: Controls not found in updateDetailsPanel";
    };
    
    // Get item data
    private _itemIndex = MISSION_constructionOptions findIf {(_x select 0) == _className};
    if (_itemIndex == -1) exitWith {
        systemChat format ["Error: Item %1 not found in construction options", _className];
    };
    
    private _itemData = MISSION_constructionOptions select _itemIndex;
    _itemData params ["", "_displayName", "_category", "_quantity", "_resources", "_constructionTime"];
    
    // Format resources text
    private _resourcesText = "";
    private _canBuild = true;
    private _debugInfo = "";
    
    if (!isNil "_resources") then {
        {
            if (count _x >= 2) then {
                _x params ["_resourceName", "_amount"];
                private _available = [_resourceName] call fnc_getResourceAmount;
                
                // Debug information
                _debugInfo = _debugInfo + format ["%1: need %2, have %3 | ", _resourceName, _amount, _available];
                
                private _color = if (_available >= _amount) then {"#AAAAAA"} else {"#FF5555"};
                _resourcesText = _resourcesText + format ["<t color='%3'>%1: %2</t><br/>", _resourceName, _amount, _color];
                
                if (_available < _amount) then {
                    _canBuild = false;
                };
            };
        } forEach _resources;
    } else {
        _resourcesText = "<t color='#FF5555'>Resource data missing!</t><br/>";
        _canBuild = false;
        diag_log "Warning: Resources data is nil in updateDetailsPanel";
    };
    
    // Format details string
    private _detailsString = format [
        "<t size='1.1' align='center'>%1</t><br/><br/>" +
        "<t>Resources Required:</t><br/>" +
        "%2" +
        "<t>Construction Time: %3 min</t>",
        _displayName,
        _resourcesText,
        (_constructionTime / 60) toFixed 1
    ];
    
    _detailsPanel ctrlSetStructuredText parseText _detailsString;
    
    // Log debug information
    diag_log format ["Construction Resources: %1", _debugInfo];
    
    // Enable/disable add button based on resources and queue
    private _factoryBusy = false;
    {
        if ((_x select 0) == MISSION_selectedFactory) exitWith {
            _factoryBusy = true;
        };
    } forEach MISSION_constructionQueue;
    
    _addButton ctrlEnable (_canBuild && _quantity > 0 && !_factoryBusy);
    
    // Additional debug feedback
    if (!_canBuild) then {
        diag_log "Cannot build: insufficient resources";
    };
    if (_quantity <= 0) then {
        diag_log "Cannot build: no quantity available";
    };
    if (_factoryBusy) then {
        diag_log "Cannot build: factory busy";
    };
};

// Function to add item to construction queue
fnc_addToConstructionQueue = {
    private _display = findDisplay -1;
    private _optionsListBox = _display displayCtrl 1300;
    private _selectedIndex = lbCurSel _optionsListBox;
    
    if (_selectedIndex < 0) exitWith {
        hint "No item selected.";
    };
    
    // Get selected item
    private _className = _optionsListBox lbData _selectedIndex;
    private _itemIndex = MISSION_constructionOptions findIf {(_x select 0) == _className};
    
    if (_itemIndex == -1) exitWith {
        hint "Error: Item not found in construction options.";
    };
    
    private _itemData = MISSION_constructionOptions select _itemIndex;
    _itemData params ["", "_displayName", "", "_quantity", "_resources", "_constructionTime"];
    
    // Check if factory is available
    private _factoryBusy = false;
    {
        if ((_x select 0) == MISSION_selectedFactory) exitWith {
            _factoryBusy = true;
        };
    } forEach MISSION_constructionQueue;
    
    if (_factoryBusy) exitWith {
        hint format ["Factory %1 is already busy.", MISSION_selectedFactory + 1];
    };
    
    // Check if we have quantity available
    if (_quantity <= 0) exitWith {
        hint "No items available for construction.";
    };
    
    // Check if we have enough resources
    private _canBuild = true;
    private _missingResources = [];
    private _resourceDebug = [];
    
    {
        _x params ["_resourceName", "_amount"];
        private _available = [_resourceName] call fnc_getResourceAmount;
        
        _resourceDebug pushBack format ["%1 (need %2, have %3)", _resourceName, _amount, _available];
        
        if (_available < _amount) then {
            _canBuild = false;
            _missingResources pushBack format ["%1 (need %2, have %3)", _resourceName, _amount, _available];
        };
    } forEach _resources;
    
    // Debug log all resources checked
    diag_log format ["Resources checked: %1", _resourceDebug joinString ", "];
    
    if (!_canBuild) exitWith {
        hint format ["Not enough resources: %1", _missingResources joinString ", "];
        diag_log format ["Missing resources: %1", _missingResources];
    };
    
    // Deduct resources - all checks passed, proceed with construction
    {
        _x params ["_resourceName", "_amount"];
        [_resourceName, -_amount] call fnc_modifyResource;
        diag_log format ["Deducted %2 of %1", _resourceName, _amount];
    } forEach _resources;
    
    // Reduce quantity
    _itemData set [3, _quantity - 1];
    
    // Add to construction queue
    private _startTime = time;
    private _endTime = _startTime + _constructionTime;
    MISSION_constructionQueue pushBack [MISSION_selectedFactory, _className, _startTime, _endTime];
    
    // Update UI
    call fnc_updateQueueDisplay;
    call fnc_updateResourcesDisplay;
    [_display getVariable ["currentCategory", ""]] call fnc_updateOptionsList;
    
    hint format ["Started construction of %1 in Factory %2", _displayName, MISSION_selectedFactory + 1];
};

// Function to update resources display
fnc_updateResourcesDisplay = {
    private _display = findDisplay -1;
    if (isNull _display) exitWith {
        diag_log "Error: Display not found for resource update";
    };
    
    private _resourcesText = _display displayCtrl 1700;
    if (isNull _resourcesText) exitWith {
        diag_log "Error: Resource text control not found";
    };
    
    // Get resources to display - try to use existing resource system
    private _resourcesArray = [];
    
    // Try RTS economy system first
    if (!isNil "RTS_resources") then {
        {
            if (count _x >= 2) then {
                _x params ["_name", "_value"];
                _resourcesArray pushBack format ["%1: %2", _name, floor _value];
            };
        } forEach RTS_resources;
    } 
    
    // If no resource system found
    else {
        _resourcesArray = ["No resource system found"];
    };
    
    // Update text with safety check
    if (count _resourcesArray > 0) then {
        _resourcesText ctrlSetText (_resourcesArray joinString " | ");
    } else {
        _resourcesText ctrlSetText "Resources unavailable";
    };
};

// Function to update the whole construction UI
fnc_updateConstructionUI = {
    private _display = findDisplay -1;
    
    // Update resources display
    call fnc_updateResourcesDisplay;
    
    // Update queue display
    call fnc_updateQueueDisplay;
    
    // Update option list
    private _currentCategory = _display getVariable ["currentCategory", ""];
    if (_currentCategory != "") then {
        [_currentCategory] call fnc_updateOptionsList;
    };
    
    // Update details if something is selected
    private _optionsListBox = _display displayCtrl 1300;
    private _selectedIndex = lbCurSel _optionsListBox;
    
    if (_selectedIndex >= 0) then {
        [_optionsListBox, _selectedIndex] call fnc_updateDetailsPanel;
    };
};

// Function to process the construction queue
fnc_processConstructionQueue = {
    private _currentTime = time;
    private _completedItems = [];
    
    {
        _x params ["_factory", "_className", "_startTime", "_endTime"];
        
        if (_currentTime >= _endTime) then {
            _completedItems pushBack _x;
            
            // Add to available equipment
            private _itemIndex = MISSION_constructionOptions findIf {(_x select 0) == _className};
            if (_itemIndex != -1) then {
                private _itemData = MISSION_constructionOptions select _itemIndex;
                _itemData params ["", "_displayName", "_category"];
                
                // Check if item exists in available equipment
                private _equipmentIndex = -1;
                if (!isNil "MISSION_availableEquipment") then {
                    _equipmentIndex = MISSION_availableEquipment findIf {(_x select 0) == _className};
                } else {
                    // Initialize available equipment if it doesn't exist
                    MISSION_availableEquipment = [];
                };
                
                if (_equipmentIndex != -1) then {
                    // Update existing entry
                    private _count = (MISSION_availableEquipment select _equipmentIndex) select 3;
                    (MISSION_availableEquipment select _equipmentIndex) set [3, _count + 1];
                } else {
                    // Add new entry
                    MISSION_availableEquipment pushBack [_className, _displayName, _category, 1];
                };
                
                hint format ["Construction of %1 is complete! Item added to procurement.", _displayName];
            } else {
                hint format ["Construction complete but item %1 not found in options.", _className];
            };
        };
    } forEach MISSION_constructionQueue;
    
    // Remove completed items from the queue
    MISSION_constructionQueue = MISSION_constructionQueue - _completedItems;
};

// Start the construction background process
[] spawn {
    while {true} do {
        // Process construction queue
        call fnc_processConstructionQueue;
        
        sleep 1;
    };
};

// Integration with menu system
// This needs to be called when the construction button is clicked
if (!isNil "RTS_menuButtons") then {
    // Find construction button in the menu
    private _index = RTS_menuButtons findIf {(_x select 0) == "construction"};
    
    if (_index != -1) then {
        // Update button click handler in the switch statement
        // Note: This is already done in menuSystem.sqf integration
        systemChat "Construction system integrated with menu button.";
    } else {
        systemChat "Warning: Could not find construction button in RTS_menuButtons.";
    };
};

// Return true when script is loaded
true