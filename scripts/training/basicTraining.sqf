// scripts/training/basicTraining.sqf
// Basic Training Module for Unit Management System

// =====================================================================
// CONFIGURATION VALUES - EDIT THESE AS NEEDED
// =====================================================================

// Cost in training points
BASIC_TRAINING_COST = 10;

// Training duration in seconds (set to 0 for instant)
BASIC_TRAINING_DURATION = 30;  // 30 seconds for testing, could be longer in production

// Skill improvements
BASIC_TRAINING_SKILLS = [
    ["aimingAccuracy", 0.3],   // Improve aiming accuracy to 0.3
    ["aimingSpeed", 0.3],      // Improve aiming speed to 0.3
    ["spotDistance", 0.4],     // Improve spotting distance to 0.4
    ["courage", 0.4],          // Improve courage to 0.4
    ["reloadSpeed", 0.3]       // Improve reload speed to 0.3
];

// =====================================================================
// MAIN FUNCTIONS
// =====================================================================

// Function to check if a unit is eligible for basic training
fnc_canReceiveBasicTraining = {
    params ["_unit"];
    
    // Make sure unit exists and is alive
    if (isNull _unit || !alive _unit) exitWith { 
        diag_log format ["Basic Training Error: Unit is null or dead"];
        false 
    };
    
    // Check if unit already has basic training
    private _unitData = [_unit] call fnc_getUnitData;
    if (isNil "_unitData") exitWith { 
        diag_log "Basic Training Error: Unit data not found";
        false 
    };
    
    private _training = _unitData select 2;
    if ("basic" in _training) exitWith {
        diag_log format ["Basic Training: Unit %1 already has basic training", name _unit];
        false
    };
    
    // Check if enough training points are available
    private _trainingPoints = ["training"] call fnc_getResourceAmount;
    if (_trainingPoints < BASIC_TRAINING_COST) exitWith {
        diag_log format ["Basic Training: Not enough training points. Need %1, have %2", BASIC_TRAINING_COST, _trainingPoints];
        false
    };
    
    // Unit is eligible
    true
};

// Function to start basic training for a unit
fnc_startBasicTraining = {
    params ["_unit"];
    
    // Check eligibility
    if !([_unit] call fnc_canReceiveBasicTraining) exitWith {
        hint "Unit is not eligible for basic training.";
        false
    };
    
    // Deduct training points
    ["training", -BASIC_TRAINING_COST] call fnc_modifyResource;
    
    // If training is instant, apply effects immediately
    if (BASIC_TRAINING_DURATION <= 0) then {
        [_unit] call fnc_completeBasicTraining;
    } else {
        // Otherwise, start training process
        hint format ["%1 has been sent for basic training. Training will complete in %2 seconds.", name _unit, BASIC_TRAINING_DURATION];
        
        // Track training status
        _unit setVariable ["basicTrainingInProgress", true, true];
        
        // Schedule completion
        [_unit] spawn {
            params ["_unit"];
            
            // Wait for training to complete
            sleep BASIC_TRAINING_DURATION;
            
            // Check if unit is still alive
            if (alive _unit) then {
                // Complete training
                [_unit] call fnc_completeBasicTraining;
            } else {
                // Unit died during training
                hint format ["%1 died during basic training.", name _unit];
            };
        };
    };
    
    true
};

// Function to complete basic training and apply effects
fnc_completeBasicTraining = {
    params ["_unit"];
    
    // Remove in-progress status
    _unit setVariable ["basicTrainingInProgress", nil, true];
    
    // Apply skill improvements
    {
        _x params ["_skill", "_value"];
        _unit setSkill [_skill, _value];
    } forEach BASIC_TRAINING_SKILLS;
    
    // Update unit data
    private _unitData = [_unit] call fnc_getUnitData;
    private _training = _unitData select 2;
    _training pushBack "basic";
    _unitData set [2, _training];
    [_unit, _unitData] call fnc_updateUnitData;
    
    // Provide feedback
    hint format ["%1 has completed basic training. Combat effectiveness improved!", name _unit];
    
    // Log training completion
    diag_log format ["Basic Training: %1 completed basic training", name _unit];
    
    true
};

// Optional: Function to check training progress
fnc_checkBasicTrainingProgress = {
    params ["_unit"];
    
    if (isNull _unit) exitWith { false };
    
    private _inProgress = _unit getVariable ["basicTrainingInProgress", false];
    _inProgress
};

// Return true to indicate the script loaded successfully
true