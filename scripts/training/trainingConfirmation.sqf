// scripts/training/trainingConfirmation.sqf
// Training Confirmation Dialog - Template for all training types

// =====================================================================
// GLOBAL VARIABLES FOR TRACKING DIALOG STATE
// =====================================================================

// Track dialog state
if (isNil "TRAINING_DIALOG_OPEN") then {
    TRAINING_DIALOG_OPEN = false;
};

// Currently displayed training type
if (isNil "TRAINING_CURRENT_TYPE") then {
    TRAINING_CURRENT_TYPE = "";
};

// Unit being trained
if (isNil "TRAINING_CURRENT_UNIT") then {
    TRAINING_CURRENT_UNIT = objNull;
};

// Training descriptions - customize these for each training type
TRAINING_DESCRIPTIONS = [
    ["basic", "Basic military training covering weapons handling, physical fitness, and field tactics. All recruits should undergo this training."],
    ["paratrooper", "Elite airborne training preparing soldiers to deploy via parachute. Includes jump training, aircraft procedures, and behind-enemy-lines tactics."],
    ["commando", "Intensive special forces training focusing on stealth, survival, sabotage, and close-quarters combat. Only the best soldiers can complete this course."],
    ["officer", "Command training covering leadership, tactical planning, and battlefield management. Graduates will be promoted to higher rank."],
    ["special", "Advanced specialized training unlocking unique battlefield abilities. Requires exceptional soldiers with previous training experience."]
];

// =====================================================================
// DIALOG CREATION FUNCTIONS
// =====================================================================

// Function to open training confirmation dialog
fnc_openTrainingConfirmationDialog = {
    params [
        ["_unit", objNull, [objNull]],
        ["_trainingType", "", [""]],
        ["_cost", 0, [0]]
    ];
    
    // Validate parameters
    if (isNull _unit) exitWith {
        hint "No unit selected for training.";
        false
    };
    
    if (_trainingType == "") exitWith {
        hint "No training type specified.";
        false
    };
    
    // Check if dialog is already open
    if (TRAINING_DIALOG_OPEN) then {
        call fnc_closeTrainingConfirmationDialog;
    };
    
    // Store current training details
    TRAINING_DIALOG_OPEN = true;
    TRAINING_CURRENT_TYPE = _trainingType;
    TRAINING_CURRENT_UNIT = _unit;
    
    // Create dialog
    private _display = findDisplay 312; // Zeus display
    
    if (isNull _display) exitWith {
        hint "Cannot create dialog - Zeus interface not active.";
        TRAINING_DIALOG_OPEN = false;
        false
    };
    
    // Create dialog container
    private _dialogContainer = _display ctrlCreate ["RscText", 5000];
    _dialogContainer ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.3 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.4 * safezoneH
    ];
    _dialogContainer ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _dialogContainer ctrlCommit 0;
    
    // Create title bar
    private _titleBar = _display ctrlCreate ["RscText", 5001];
    _titleBar ctrlSetPosition [
        0.3 * safezoneW + safezoneX,
        0.3 * safezoneH + safezoneY,
        0.4 * safezoneW,
        0.05 * safezoneH
    ];
    _titleBar ctrlSetBackgroundColor [0.2, 0.2, 0.3, 1];
    
    // Format training name for display (capitalize first letter)
    private _trainingName = _trainingType;
    _trainingName = toUpper (_trainingName select [0, 1]) + (_trainingName select [1]);
    
    _titleBar ctrlSetText format ["%1 Training Confirmation", _trainingName];
    _titleBar ctrlCommit 0;
    
    // Create unit info
    private _unitInfo = _display ctrlCreate ["RscStructuredText", 5002];
    _unitInfo ctrlSetPosition [
        0.31 * safezoneW + safezoneX,
        0.36 * safezoneH + safezoneY,
        0.38 * safezoneW,
        0.06 * safezoneH
    ];
    
    // Get unit details
    private _unitRank = [_unit] call fnc_getRankDisplay;
    private _unitName = name _unit;
    private _unitClass = getText (configFile >> "CfgVehicles" >> typeOf _unit >> "displayName");
    
    _unitInfo ctrlSetStructuredText parseText format [
        "<t size='1.2' align='center'>%1 %2</t><br/><t align='center'>%3</t>",
        _unitRank, _unitName, _unitClass
    ];
    _unitInfo ctrlCommit 0;
    
    // Create training description
    private _description = "";
    {
        if (_x select 0 == _trainingType) exitWith {
            _description = _x select 1;
        };
    } forEach TRAINING_DESCRIPTIONS;
    
    private _descriptionText = _display ctrlCreate ["RscStructuredText", 5003];
    _descriptionText ctrlSetPosition [
        0.31 * safezoneW + safezoneX,
        0.43 * safezoneH + safezoneY,
        0.38 * safezoneW,
        0.1 * safezoneH
    ];
    _descriptionText ctrlSetStructuredText parseText format [
        "<t align='center'>%1</t>",
        _description
    ];
    _descriptionText ctrlCommit 0;
    
    // Create cost information
    private _availablePoints = ["training"] call fnc_getResourceAmount;
    private _costColor = if (_availablePoints >= _cost) then {"#90EE90"} else {"#FF6347"}; // Green or red
    
    private _costInfo = _display ctrlCreate ["RscStructuredText", 5004];
    _costInfo ctrlSetPosition [
        0.31 * safezoneW + safezoneX,
        0.54 * safezoneH + safezoneY,
        0.38 * safezoneW,
        0.05 * safezoneH
    ];
    _costInfo ctrlSetStructuredText parseText format [
        "<t align='center'>Cost: <t color='%1'>%2 Training Points</t> (Available: %3)</t>",
        _costColor, _cost, floor _availablePoints
    ];
    _costInfo ctrlCommit 0;
    
    // Create duration information (if training has duration)
    private _durationVariable = format ["%1_TRAINING_DURATION", toUpper _trainingType];
    private _duration = missionNamespace getVariable [_durationVariable, 0];
    
    if (_duration > 0) then {
        private _durationInfo = _display ctrlCreate ["RscStructuredText", 5005];
        _durationInfo ctrlSetPosition [
            0.31 * safezoneW + safezoneX,
            0.59 * safezoneH + safezoneY,
            0.38 * safezoneW,
            0.04 * safezoneH
        ];
        _durationInfo ctrlSetStructuredText parseText format [
            "<t align='center'>Duration: %1 seconds</t>",
            _duration
        ];
        _durationInfo ctrlCommit 0;
    };
    
    // Create buttons
    private _confirmButton = _display ctrlCreate ["RscButton", 5006];
    _confirmButton ctrlSetPosition [
        0.35 * safezoneW + safezoneX,
        0.64 * safezoneH + safezoneY,
        0.12 * safezoneW,
        0.05 * safezoneH
    ];
    _confirmButton ctrlSetText "Begin Training";
    _confirmButton ctrlSetBackgroundColor [0.2, 0.5, 0.2, 1]; // Green
    
    // Set variables for the confirm button
    _confirmButton setVariable ["trainingType", _trainingType];
    _confirmButton setVariable ["trainingCost", _cost];
    _confirmButton setVariable ["trainingUnit", _unit];
    
    // Only enable if enough points
    _confirmButton ctrlEnable (_availablePoints >= _cost);
    
    // Add click handler
    _confirmButton ctrlAddEventHandler ["ButtonClick", {
        params ["_ctrl"];
        
        private _trainingType = _ctrl getVariable "trainingType";
        private _unit = _ctrl getVariable "trainingUnit";
        
        // Close dialog
        call fnc_closeTrainingConfirmationDialog;
        
        // Try to call specific training function
        private _fnc = missionNamespace getVariable [format ["fnc_start%1Training", _trainingType select [0, 1] + toUpper (_trainingType select [1])], {}];
        [_unit] call _fnc;
    }];
    _confirmButton ctrlCommit 0;
    
    // Create cancel button
    private _cancelButton = _display ctrlCreate ["RscButton", 5007];
    _cancelButton ctrlSetPosition [
        0.53 * safezoneW + safezoneX,
        0.64 * safezoneH + safezoneY,
        0.12 * safezoneW,
        0.05 * safezoneH
    ];
    _cancelButton ctrlSetText "Cancel";
    _cancelButton ctrlSetBackgroundColor [0.5, 0.2, 0.2, 1]; // Red
    _cancelButton ctrlAddEventHandler ["ButtonClick", {
        call fnc_closeTrainingConfirmationDialog;
    }];
    _cancelButton ctrlCommit 0;
    
    true
};

// Function to close training confirmation dialog
fnc_closeTrainingConfirmationDialog = {
    private _display = findDisplay 312;
    
    // Delete all dialog controls
    for "_i" from 5000 to 5007 do {
        private _ctrl = _display displayCtrl _i;
        if (!isNull _ctrl) then {
            ctrlDelete _ctrl;
        };
    };
    
    // Reset dialog state
    TRAINING_DIALOG_OPEN = false;
    TRAINING_CURRENT_TYPE = "";
    TRAINING_CURRENT_UNIT = objNull;
    
    true
};

// Function to check if training is possible
fnc_canStartTraining = {
    params [
        ["_unit", objNull, [objNull]],
        ["_trainingType", "", [""]],
        ["_cost", 0, [0]]
    ];
    
    // Check if unit exists and is alive
    if (isNull _unit || !alive _unit) exitWith { false };
    
    // Check if unit already has this training
    private _unitData = [_unit] call fnc_getUnitData;
    if (isNil "_unitData") exitWith { false };
    
    private _training = _unitData select 2;
    if (_trainingType in _training) exitWith { false };
    
    // Check if enough training points are available
    private _trainingPoints = ["training"] call fnc_getResourceAmount;
    if (_trainingPoints < _cost) exitWith { false };
    
    // Check if research requirements are met
    private _researchMet = true;
    
    {
        if (_x select 0 == _trainingType) exitWith {
            private _requiredResearch = _x select 1;
            
            // If MISSION_completedResearch is defined (from research system)
            if (!isNil "MISSION_completedResearch") then {
                {
                    if !(_x in MISSION_completedResearch) then {
                        _researchMet = false;
                    };
                } forEach _requiredResearch;
            };
        };
    } forEach UNIT_TRAINING_REQUIREMENTS;
    
    if (!_researchMet) exitWith { false };
    
    // All checks passed
    true
};