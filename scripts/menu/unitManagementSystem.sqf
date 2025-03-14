// scripts/menu/unitManagementSystem.sqf
// Unit Management System for WW2 RTS - Manage individual units and training

// =====================================================================
// CONFIGURATION VALUES - EDIT THESE AS NEEDED
// =====================================================================

// Training points cost for different training types
UNIT_TRAINING_COSTS = [
    ["basic", 10],        // Basic training
    ["paratrooper", 30],  // Paratrooper training
    ["commando", 50],     // Commando training
    ["officer", 40],      // Officer training
    ["special", 60]       // Special abilities training
];

// Required research IDs for each training type to be available
UNIT_TRAINING_REQUIREMENTS = [
    ["basic", []],                             // No requirements
    ["paratrooper", ["paratrooper_doctrine"]], // Requires paratrooper doctrine
    ["commando", ["commando_training"]],       // Requires commando training research
    ["officer", ["officer_academy"]],          // Requires officer academy
    ["special", ["special_operations"]]        // Requires special operations research
];

// =====================================================================
// GLOBAL VARIABLES - DO NOT EDIT BELOW THIS LINE
// =====================================================================

// Initialize unit data storage if not already defined
if (isNil "UNIT_DATA") then {
    UNIT_DATA = [];
};

// Track UI state
if (isNil "UNIT_MANAGEMENT_OPEN") then {
    UNIT_MANAGEMENT_OPEN = false;
};

// Selected unit
if (isNil "UNIT_SELECTED") then {
    UNIT_SELECTED = objNull;
};

// Function to check if a unit has data stored
fnc_unitHasData = {
    params ["_unit"];
    
    private _index = UNIT_DATA findIf {(_x select 0) == _unit};
    (_index != -1)
};

// Function to get unit data - creates data if it doesn't exist
fnc_getUnitData = {
    params ["_unit"];
    
    private _index = UNIT_DATA findIf {(_x select 0) == _unit};
    
    if (_index == -1) then {
        // Create new data entry for unit
        private _newData = [
            _unit,                // The unit object
            0,                    // Kills
            [],                   // Completed training
            [],                   // Special abilities
            time,                 // Creation time
            [],                   // Medals/awards
            []                    // Missions completed
        ];
        
        UNIT_DATA pushBack _newData;
        _newData
    } else {
        // Return existing data
        UNIT_DATA select _index
    };
};

// Function to update unit data
fnc_updateUnitData = {
    params ["_unit", "_dataArray"];
    
    private _index = UNIT_DATA findIf {(_x select 0) == _unit};
    
    if (_index != -1) then {
        UNIT_DATA set [_index, _dataArray];
        true
    } else {
        UNIT_DATA pushBack _dataArray;
        true
    };
};

// Function to get current rank as a string
fnc_getRankDisplay = {
    params ["_unit"];
    
    private _rankID = rankId _unit;
    private _rankName = "";
    
    switch (_rankID) do {
        case 0: { _rankName = "Private"; };
        case 1: { _rankName = "Corporal"; };
        case 2: { _rankName = "Sergeant"; };
        case 3: { _rankName = "Lieutenant"; };
        case 4: { _rankName = "Captain"; };
        case 5: { _rankName = "Major"; };
        case 6: { _rankName = "Colonel"; };
        default { _rankName = "Unknown"; };
    };
    
    _rankName
};

// Function to open the Unit Management UI
fnc_openUnitManagementUI = {
    if (dialog) then {closeDialog 0};
    createDialog "RscDisplayEmpty";
    
    private _display = findDisplay -1;
    
    if (isNull _display) exitWith {
        diag_log "Failed to create Unit Management UI";
        systemChat "Error: Could not create unit management interface";
        false
    };
    
    // Set flag
    UNIT_MANAGEMENT_OPEN = true;
    
    // Create background
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.7 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", -1];
    _title ctrlSetPosition [0.2 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.6 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetText "UNIT MANAGEMENT";
    _title ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _title ctrlCommit 0;
    
    // Create training points display
    private _trainingPointsText = _display ctrlCreate ["RscText", 1001];
    _trainingPointsText ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.21 * safezoneH + safezoneY, 0.56 * safezoneW, 0.04 * safezoneH];
    _trainingPointsText ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
    _trainingPointsText ctrlCommit 0;
    
    // Create unit list header
    private _unitListHeader = _display ctrlCreate ["RscText", -1];
    _unitListHeader ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.26 * safezoneH + safezoneY, 0.25 * safezoneW, 0.04 * safezoneH];
    _unitListHeader ctrlSetText "AVAILABLE UNITS";
    _unitListHeader ctrlSetBackgroundColor [0.3, 0.3, 0.3, 1];
    _unitListHeader ctrlCommit 0;
    
    // Create unit detail header
    private _unitDetailHeader = _display ctrlCreate ["RscText", -1];
    _unitDetailHeader ctrlSetPosition [0.48 * safezoneW + safezoneX, 0.26 * safezoneH + safezoneY, 0.3 * safezoneW, 0.04 * safezoneH];
    _unitDetailHeader ctrlSetText "UNIT DETAILS";
    _unitDetailHeader ctrlSetBackgroundColor [0.3, 0.3, 0.3, 1];
    _unitDetailHeader ctrlCommit 0;
    
    // Create unit list box
    private _unitListBox = _display ctrlCreate ["RscListBox", 1200];
    _unitListBox ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.25 * safezoneW, 0.45 * safezoneH];
    _unitListBox ctrlCommit 0;
    
    // Create unit details panel
    private _unitDetailsPanel = _display ctrlCreate ["RscStructuredText", 1300];
    _unitDetailsPanel ctrlSetPosition [0.48 * safezoneW + safezoneX, 0.31 * safezoneH + safezoneY, 0.3 * safezoneW, 0.25 * safezoneH];
    _unitDetailsPanel ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.7];
    _unitDetailsPanel ctrlCommit 0;
    
    // Create training header
    private _trainingHeader = _display ctrlCreate ["RscText", -1];
    _trainingHeader ctrlSetPosition [0.48 * safezoneW + safezoneX, 0.57 * safezoneH + safezoneY, 0.3 * safezoneW, 0.04 * safezoneH];
    _trainingHeader ctrlSetText "TRAINING OPTIONS";
    _trainingHeader ctrlSetBackgroundColor [0.3, 0.3, 0.3, 1];
    _trainingHeader ctrlCommit 0;
    
    // Create training buttons - Use Y position that continues from the training header
    private _buttonHeight = 0.04 * safezoneH;
    private _buttonSpacing = 0.005 * safezoneH;
    private _startY = 0.62 * safezoneH + safezoneY;
    
    // Basic Training Button
    private _basicTrainingBtn = _display ctrlCreate ["RscButton", 1401];
    _basicTrainingBtn ctrlSetPosition [0.48 * safezoneW + safezoneX, _startY, 0.3 * safezoneW, _buttonHeight];
    _basicTrainingBtn ctrlSetText "Basic Training (10 points)";
    _basicTrainingBtn ctrlSetBackgroundColor [0.2, 0.2, 0.3, 1];
    _basicTrainingBtn ctrlSetEventHandler ["ButtonClick", "['basic'] call fnc_openTrainingConfirmation"];
    _basicTrainingBtn ctrlCommit 0;
    
    // Paratrooper Training Button
    private _paraTrainingBtn = _display ctrlCreate ["RscButton", 1402];
    _paraTrainingBtn ctrlSetPosition [0.48 * safezoneW + safezoneX, _startY + (_buttonHeight + _buttonSpacing), 0.3 * safezoneW, _buttonHeight];
    _paraTrainingBtn ctrlSetText "Paratrooper Training (30 points)";
    _paraTrainingBtn ctrlSetBackgroundColor [0.2, 0.2, 0.3, 1];
    _paraTrainingBtn ctrlSetEventHandler ["ButtonClick", "['paratrooper'] call fnc_openTrainingConfirmation"];
    _paraTrainingBtn ctrlCommit 0;
    
    // Commando Training Button
    private _commandoTrainingBtn = _display ctrlCreate ["RscButton", 1403];
    _commandoTrainingBtn ctrlSetPosition [0.48 * safezoneW + safezoneX, _startY + 2 * (_buttonHeight + _buttonSpacing), 0.3 * safezoneW, _buttonHeight];
    _commandoTrainingBtn ctrlSetText "Commando Training (50 points)";
    _commandoTrainingBtn ctrlSetBackgroundColor [0.2, 0.2, 0.3, 1];
    _commandoTrainingBtn ctrlSetEventHandler ["ButtonClick", "['commando'] call fnc_openTrainingConfirmation"];
    _commandoTrainingBtn ctrlCommit 0;
    
    // Officer Training Button
    private _officerTrainingBtn = _display ctrlCreate ["RscButton", 1404];
    _officerTrainingBtn ctrlSetPosition [0.48 * safezoneW + safezoneX, _startY + 3 * (_buttonHeight + _buttonSpacing), 0.3 * safezoneW, _buttonHeight];
    _officerTrainingBtn ctrlSetText "Officer Training (40 points)";
    _officerTrainingBtn ctrlSetBackgroundColor [0.2, 0.2, 0.3, 1];
    _officerTrainingBtn ctrlSetEventHandler ["ButtonClick", "['officer'] call fnc_openTrainingConfirmation"];
    _officerTrainingBtn ctrlCommit 0;
    
    // Special Abilities Button
    private _specialTrainingBtn = _display ctrlCreate ["RscButton", 1405];
    _specialTrainingBtn ctrlSetPosition [0.48 * safezoneW + safezoneX, _startY + 4 * (_buttonHeight + _buttonSpacing), 0.3 * safezoneW, _buttonHeight];
    _specialTrainingBtn ctrlSetText "Special Abilities Training (60 points)";
    _specialTrainingBtn ctrlSetBackgroundColor [0.2, 0.2, 0.3, 1];
    _specialTrainingBtn ctrlSetEventHandler ["ButtonClick", "['special'] call fnc_openTrainingConfirmation"];
    _specialTrainingBtn ctrlCommit 0;
    
    // Create close button
    private _closeButton = _display ctrlCreate ["RscButton", 1500];
    _closeButton ctrlSetPosition [0.7 * safezoneW + safezoneX, 0.8 * safezoneH + safezoneY, 0.08 * safezoneW, 0.04 * safezoneH];
    _closeButton ctrlSetText "Close";
    _closeButton ctrlSetEventHandler ["ButtonClick", "closeDialog 0"];
    _closeButton ctrlCommit 0;
    
    // Add event handlers for the unit list
    _unitListBox ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        [_control, _selectedIndex] call fnc_selectUnit;
    }];
    
    // Add handler for dialog closure
    _display displayAddEventHandler ["Unload", {
        UNIT_MANAGEMENT_OPEN = false;
        UNIT_SELECTED = objNull;
    }];
    
    // Populate the unit list
    call fnc_populateUnitList;
    
    // Start UI update loop
    [] spawn {
        while {UNIT_MANAGEMENT_OPEN && !isNull findDisplay -1} do {
            call fnc_updateUnitManagementUI;
            sleep 0.5;
        };
    };
};

// Function to populate the unit list
fnc_populateUnitList = {
    private _display = findDisplay -1;
    private _unitListBox = _display displayCtrl 1200;
    
    // Clear current list
    lbClear _unitListBox;
    
    // Get all friendly units
    private _friendlyUnits = allUnits select {side _x == side player};
    
    // Add each unit to the list
    {
        private _unit = _x;
        private _unitName = name _unit;
        private _unitRank = [_unit] call fnc_getRankDisplay;
        private _unitType = getText (configFile >> "CfgVehicles" >> typeOf _unit >> "displayName");
        
        // Get unit data (creates it if it doesn't exist)
        private _unitData = [_unit] call fnc_getUnitData;
        private _kills = _unitData select 1;
        
        private _index = _unitListBox lbAdd format ["%1 %2 (%3)", _unitRank, _unitName, _unitType];
        _unitListBox lbSetData [_index, netId _unit];
        
        // Set tooltip with additional info
        _unitListBox lbSetTooltip [_index, format ["Kills: %1", _kills]];
        
        // Add rank icon if we had icons for ranks
        //_unitListBox lbSetPicture [_index, _rankIcon];
        
    } forEach _friendlyUnits;
    
    // Sort alphabetically
    lbSort _unitListBox;
    
    // Select the currently selected unit if it's still in the list
    if (!isNull UNIT_SELECTED) then {
        for "_i" from 0 to (lbSize _unitListBox - 1) do {
            if ((_unitListBox lbData _i) == (netId UNIT_SELECTED)) exitWith {
                _unitListBox lbSetCurSel _i;
            };
        };
    } else {
        // Otherwise select the first unit
        if (lbSize _unitListBox > 0) then {
            _unitListBox lbSetCurSel 0;
        };
    };
};

// Function to select a unit from the list
fnc_selectUnit = {
    params ["_control", "_selectedIndex"];
    
    if (_selectedIndex < 0) exitWith {};
    
    // Get the selected unit from the netId stored in the list
    private _unitNetId = _control lbData _selectedIndex;
    private _unit = objectFromNetId _unitNetId;
    
    if (isNull _unit) exitWith {
        systemChat "Error: Selected unit not found.";
    };
    
    // Update selected unit
    UNIT_SELECTED = _unit;
    
    // Update the unit details display
    [_unit] call fnc_updateUnitDetailsPanel;
    
    // Update training button states
    [_unit] call fnc_updateTrainingButtons;
};

// Function to update unit details panel
fnc_updateUnitDetailsPanel = {
    params ["_unit"];
    
    private _display = findDisplay -1;
    private _unitDetailsPanel = _display displayCtrl 1300;
    
    if (isNull _unit) exitWith {
        _unitDetailsPanel ctrlSetStructuredText parseText "No unit selected.";
    };
    
    // Get unit data
    private _unitData = [_unit] call fnc_getUnitData;
    _unitData params ["", "_kills", "_training", "_abilities", "_creationTime", "_medals", "_missions"];
    
    // Calculate service time
    private _serviceTime = time - _creationTime;
    private _serviceDays = floor (_serviceTime / 86400); // Convert to days
    private _serviceHours = floor ((_serviceTime % 86400) / 3600); // Convert to hours
    
    // Format training list
    private _trainingText = "";
    if (count _training > 0) then {
        {
            // Capitalize first letter of training type
            private _trainingType = _x;
            private _firstLetter = toUpper (_trainingType select [0, 1]);
            private _restLetters = _trainingType select [1];
            private _formattedType = _firstLetter + _restLetters;
            
            if (_trainingText != "") then { _trainingText = _trainingText + ", "; };
            _trainingText = _trainingText + _formattedType;
        } forEach _training;
    } else {
        _trainingText = "None";
    };
    
    // Format abilities list
    private _abilitiesText = "";
    if (count _abilities > 0) then {
        {
            if (_abilitiesText != "") then { _abilitiesText = _abilitiesText + ", "; };
            _abilitiesText = _abilitiesText + _x;
        } forEach _abilities;
    } else {
        _abilitiesText = "None";
    };
    
    // Check for special abilities unlocked via the ability system
    private _specialAbilities = _unit getVariable ["RTSUI_unlockedAbilities", []];
    if (count _specialAbilities > 0) then {
        if (_abilitiesText == "None") then {
            _abilitiesText = "";
        } else {
            _abilitiesText = _abilitiesText + ", ";
        };
        
        {
            if (_forEachIndex > 0) then { _abilitiesText = _abilitiesText + ", "; };
            _abilitiesText = _abilitiesText + _x;
        } forEach _specialAbilities;
    };
    
    // Format details string
    private _detailsString = format [
        "<t size='1.2' align='center'>%1 %2</t><br/><br/>" +
        "<t>Rank: %3</t><br/>" +
        "<t>Class: %4</t><br/>" +
        "<t>Kills: %5</t><br/>" +
        "<t>Service Time: %6d %7h</t><br/><br/>" +
        "<t>Training: %8</t><br/>" +
        "<t>Abilities: %9</t>",
        [_unit] call fnc_getRankDisplay,
        name _unit,
        [_unit] call fnc_getRankDisplay,
        getText (configFile >> "CfgVehicles" >> typeOf _unit >> "displayName"),
        _kills,
        _serviceDays,
        _serviceHours,
        _trainingText,
        _abilitiesText
    ];
    
    _unitDetailsPanel ctrlSetStructuredText parseText _detailsString;
};

// Function to update training buttons based on available research
fnc_updateTrainingButtons = {
    params ["_unit"];
    
    private _display = findDisplay -1;
    
    // Get unit's current training
    private _unitData = [_unit] call fnc_getUnitData;
    private _unitTraining = _unitData select 2;
    
    // Check each training button
    {
        _x params ["_trainingType", "_requiredResearch"];
        private _buttonIndex = switch (_trainingType) do {
            case "basic": { 1401 };
            case "paratrooper": { 1402 };
            case "commando": { 1403 };
            case "officer": { 1404 };
            case "special": { 1405 };
            default { -1 };
        };
        
        if (_buttonIndex != -1) then {
            private _button = _display displayCtrl _buttonIndex;
            
            // Check if unit already has this training
            private _hasTraining = _trainingType in _unitTraining;
            
            // Check if research requirements are met
            private _researchMet = true;
            
            // If MISSION_completedResearch is defined (from research system)
            if (!isNil "MISSION_completedResearch") then {
                {
                    if !(_x in MISSION_completedResearch) then {
                        _researchMet = false;
                    };
                } forEach _requiredResearch;
            } else {
                // If no research system, only require basic training to be unlocked by default
                if (_trainingType != "basic") then {
                    _researchMet = false;
                };
            };
            
            // Check if we have enough training points
            private _trainingPointCost = 0;
            {
                if (_x select 0 == _trainingType) exitWith {
                    _trainingPointCost = _x select 1;
                };
            } forEach UNIT_TRAINING_COSTS;
            
            private _trainingPoints = ["training"] call fnc_getResourceAmount;
            private _enoughPoints = _trainingPoints >= _trainingPointCost;
            
            // Update button state
            if (_hasTraining) then {
                _button ctrlSetText format ["%1 Training (Completed)", toUpper (_trainingType select [0, 1]) + (_trainingType select [1])];
                _button ctrlEnable false;
                _button ctrlSetBackgroundColor [0.3, 0.5, 0.3, 1]; // Green for completed
            } else {
                if (_researchMet && _enoughPoints) then {
                    _button ctrlEnable true;
                    _button ctrlSetBackgroundColor [0.2, 0.2, 0.3, 1]; // Normal color
                } else {
                    _button ctrlEnable false;
                    if (!_researchMet) then {
                        _button ctrlSetText format ["%1 Training (Research Required)", toUpper (_trainingType select [0, 1]) + (_trainingType select [1])];
                        _button ctrlSetBackgroundColor [0.5, 0.3, 0.3, 1]; // Red for unavailable
                    } else {
                        _button ctrlSetText format ["%1 Training (%2 points - Not Enough)", toUpper (_trainingType select [0, 1]) + (_trainingType select [1]), _trainingPointCost];
                        _button ctrlSetBackgroundColor [0.5, 0.5, 0.3, 1]; // Yellow for not enough points
                    };
                };
            };
        };
    } forEach UNIT_TRAINING_REQUIREMENTS;
};

// Function to update training points display
fnc_updateTrainingPointsDisplay = {
    private _display = findDisplay -1;
    private _trainingPointsText = _display displayCtrl 1001;
    
    private _trainingPoints = ["training"] call fnc_getResourceAmount;
    
    _trainingPointsText ctrlSetText format ["Training Points: %1", floor _trainingPoints];
};

// Function to update the entire unit management UI
fnc_updateUnitManagementUI = {
    // Update training points display
    call fnc_updateTrainingPointsDisplay;
    
    // Check if selected unit is still valid
    if (!isNull UNIT_SELECTED && {!alive UNIT_SELECTED}) then {
        UNIT_SELECTED = objNull;
        
        // Update unit list to select a new unit
        call fnc_populateUnitList;
    };
    
    // Update unit details if a unit is selected
    if (!isNull UNIT_SELECTED) then {
        [UNIT_SELECTED] call fnc_updateUnitDetailsPanel;
        [UNIT_SELECTED] call fnc_updateTrainingButtons;
    };
};

// Function to get resource amount (integrates with economy system)
fnc_getResourceAmount = {
    params ["_resourceName"];
    
    private _amount = 0;
    
    // Try to use RTS_fnc_getResource if available
    if (!isNil "RTS_fnc_getResource") then {
        _amount = [_resourceName] call RTS_fnc_getResource;
    } else {
        // Fallback to checking RTS_resources directly
        if (!isNil "RTS_resources") then {
            {
                _x params ["_name", "_value"];
                if (_name == _resourceName) exitWith {
                    _amount = _value;
                };
            } forEach RTS_resources;
        };
    };
    
    _amount
};

// Function to modify resource amount (integrates with economy system)
fnc_modifyResource = {
    params ["_resourceName", "_amount"];
    
    private _success = false;
    
    // Try to use RTS_fnc_modifyResource if available
    if (!isNil "RTS_fnc_modifyResource") then {
        _success = [_resourceName, _amount] call RTS_fnc_modifyResource;
    } else {
        // Fallback to modifying RTS_resources directly
        if (!isNil "RTS_resources") then {
            {
                _x params ["_name", "_value"];
                if (_name == _resourceName) exitWith {
                    RTS_resources set [_forEachIndex, [_name, _value + _amount]];
                    _success = true;
                };
            } forEach RTS_resources;
        };
    };
    
    _success
};

// Function to open training confirmation dialog
fnc_openTrainingConfirmation = {
    params ["_trainingType"];
    
    if (isNull UNIT_SELECTED) exitWith {
        hint "No unit selected for training.";
    };
    
    // Get training cost
    private _trainingCost = 0;
    {
        if (_x select 0 == _trainingType) exitWith {
            _trainingCost = _x select 1;
        };
    } forEach UNIT_TRAINING_COSTS;
    
    // Call the actual confirmation dialog function
    [UNIT_SELECTED, _trainingType, _trainingCost] call fnc_openTrainingConfirmationDialog;
};

// Function to show confirmation dialog
fnc_showConfirmationDialog = {
    params ["_message", "_trainingType", "_cost"];
    
    private _display = findDisplay -1;
    
    // Create dialog background
    private _dialogBg = _display ctrlCreate ["RscText", 2000];
    _dialogBg ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.35 * safezoneH + safezoneY, 0.4 * safezoneW, 0.3 * safezoneH];
    _dialogBg ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _dialogBg ctrlCommit 0;
    
    // Create dialog title
    private _dialogTitle = _display ctrlCreate ["RscText", 2001];
    _dialogTitle ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.35 * safezoneH + safezoneY, 0.4 * safezoneW, 0.05 * safezoneH];
    _dialogTitle ctrlSetText "Confirm Training";
    _dialogTitle ctrlSetBackgroundColor [0.3, 0.3, 0.3, 1];
    _dialogTitle ctrlCommit 0;
    
    // Create message text
    private _messageText = _display ctrlCreate ["RscStructuredText", 2002];
    _messageText ctrlSetPosition [0.31 * safezoneW + safezoneX, 0.41 * safezoneH + safezoneY, 0.38 * safezoneW, 0.15 * safezoneH];
    _messageText ctrlSetStructuredText parseText format ["<t align='center'>%1</t>", _message];
    _messageText ctrlCommit 0;
    
    // Create confirm button
    private _confirmBtn = _display ctrlCreate ["RscButton", 2003];
    _confirmBtn ctrlSetPosition [0.35 * safezoneW + safezoneX, 0.57 * safezoneH + safezoneY, 0.1 * safezoneW, 0.05 * safezoneH];
    _confirmBtn ctrlSetText "Confirm";
    _confirmBtn ctrlSetBackgroundColor [0.2, 0.5, 0.2, 1];
    _confirmBtn setVariable ["trainingType", _trainingType];
    _confirmBtn setVariable ["cost", _cost];
    _confirmBtn ctrlSetEventHandler ["ButtonClick", "
        params ['_ctrl'];
        private _trainingType = _ctrl getVariable 'trainingType';
        private _cost = _ctrl getVariable 'cost';
        [_trainingType, _cost] call fnc_startTraining;
        call fnc_closeConfirmationDialog;
    "];
    _confirmBtn ctrlCommit 0;
    
    // Create cancel button
    private _cancelBtn = _display ctrlCreate ["RscButton", 2004];
    _cancelBtn ctrlSetPosition [0.55 * safezoneW + safezoneX, 0.57 * safezoneH + safezoneY, 0.1 * safezoneW, 0.05 * safezoneH];
    _cancelBtn ctrlSetText "Cancel";
    _cancelBtn ctrlSetBackgroundColor [0.5, 0.2, 0.2, 1];
    _cancelBtn ctrlSetEventHandler ["ButtonClick", "call fnc_closeConfirmationDialog"];
    _cancelBtn ctrlCommit 0;
};

// Function to close confirmation dialog
fnc_closeConfirmationDialog = {
    private _display = findDisplay -1;
    
    for "_i" from 2000 to 2004 do {
        ctrlDelete (_display displayCtrl _i);
    };
};

// Function to start training
fnc_startTraining = {
    params ["_trainingType", "_cost"];
    
    if (isNull UNIT_SELECTED) exitWith {
        hint "No unit selected for training.";
        false
    };
    
    // Check if unit already has this training
    private _unitData = [UNIT_SELECTED] call fnc_getUnitData;
    private _training = _unitData select 2;
    
    if (_trainingType in _training) exitWith {
        hint format ["%1 already has %2 training.", name UNIT_SELECTED, _trainingType];
        false
    };
    
    // Check if we have enough training points
    private _trainingPoints = ["training"] call fnc_getResourceAmount;
    
    if (_trainingPoints < _cost) exitWith {
        hint format ["Not enough training points. Need %1, have %2.", _cost, floor _trainingPoints];
        false
    };
    
    // Deduct training points
    ["training", -_cost] call fnc_modifyResource;
    
    // Add training to unit data
    _training pushBack _trainingType;
    _unitData set [2, _training];
    
    // Special handling for each training type
    switch (_trainingType) do {
        case "basic": {
            // Basic training improves skills
            UNIT_SELECTED setSkill ["aimingAccuracy", 0.3];
            UNIT_SELECTED setSkill ["aimingSpeed", 0.3];
            UNIT_SELECTED setSkill ["spotDistance", 0.4];
        };
        case "paratrooper": {
            // Paratroopers get better with parachutes
            UNIT_SELECTED setVariable ["isParatrooper", true, true];
            
            // Can add more effects later
        };
        case "commando": {
            // Commandos are better at stealth and combat
            UNIT_SELECTED setSkill ["aimingAccuracy", 0.6];
            UNIT_SELECTED setSkill ["spotDistance", 0.6];
            UNIT_SELECTED setSkill ["courage", 0.8];
            
            // Can add more effects later
        };
        case "officer": {
            // Promote unit to next rank if possible
            private _currentRank = rankId UNIT_SELECTED;
            if (_currentRank < 6) then { // 6 is highest rank (Colonel)
                private _newRank = (_currentRank + 1) min 6;
                
                // Get rank name
                private _rankName = "PRIVATE";
                switch (_newRank) do {
                    case 1: { _rankName = "CORPORAL"; };
                    case 2: { _rankName = "SERGEANT"; };
                    case 3: { _rankName = "LIEUTENANT"; };
                    case 4: { _rankName = "CAPTAIN"; };
                    case 5: { _rankName = "MAJOR"; };
                    case 6: { _rankName = "COLONEL"; };
                };
                
                UNIT_SELECTED setRank _rankName;
            };
        };
        case "special": {
            // Add ability to use special abilities
            // This would integrate with the special abilities system
            // For now, just a placeholder
            _unitData set [3, (_unitData select 3) + ["specialTraining"]];
            
            // If special abilities system exists, try to unlock an ability
            if (!isNil "fnc_unlockAbility") then {
                [UNIT_SELECTED, "scout"] call fnc_unlockAbility;
            };
        };
    };
    
    // Update unit data
    [UNIT_SELECTED, _unitData] call fnc_updateUnitData;
    
    // Show success message
    private _trainingName = _trainingType select [0, 1] + toUpper (_trainingType select [1]) + " Training";
    hint format ["%1 has been sent for %2. New skills acquired!", name UNIT_SELECTED, _trainingName];
    
    // Force UI update
    [UNIT_SELECTED] call fnc_updateUnitDetailsPanel;
    [UNIT_SELECTED] call fnc_updateTrainingButtons;
    call fnc_updateTrainingPointsDisplay;
    
    true
};

// Register with menu system
if (!isNil "RTS_menuButtons") then {
    // Check if intelligence button exists
    private _intelligenceIndex = RTS_menuButtons findIf {(_x select 0) == "intelligence"};
    
    if (_intelligenceIndex != -1) then {
        // Update intelligence button to open unit management
        private _currentButton = RTS_menuButtons select _intelligenceIndex;
        
        // Create new button data with same icon and tooltip but new function
        RTS_menuButtons set [_intelligenceIndex, [
            "intelligence",
            _currentButton select 1,
            "Personnel Management",
            "Manage and train your units"
        ]];
        
        systemChat "Unit Management System integrated with Intelligence button.";
    } else {
        systemChat "Warning: Intelligence button not found in menu system.";
    };
};