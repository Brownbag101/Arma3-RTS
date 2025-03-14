// scripts/training/paratrooperTraining.sqf
// Paratrooper Training Module for Unit Management System

// =====================================================================
// CONFIGURATION VALUES - EDIT THESE AS NEEDED
// =====================================================================

// Cost in training points
PARATROOPER_TRAINING_COST = 30;

// Training duration in seconds (set to 0 for instant)
PARATROOPER_TRAINING_DURATION = 60;  // 60 seconds for testing, could be longer in production

// Skill improvements
PARATROOPER_TRAINING_SKILLS = [
    ["aimingAccuracy", 0.4],   // Improve aiming accuracy to 0.4
    ["aimingSpeed", 0.4],      // Improve aiming speed to 0.4
    ["spotDistance", 0.5],     // Improve spotting distance to 0.5
    ["courage", 0.6],          // Improve courage to 0.6
    ["reloadSpeed", 0.4]       // Improve reload speed to 0.4
];

// =====================================================================
// MAIN FUNCTIONS
// =====================================================================

// Function to check if a unit is eligible for paratrooper training
fnc_canReceiveParatrooperTraining = {
    params ["_unit"];
    
    // Make sure unit exists and is alive
    if (isNull _unit || !alive _unit) exitWith { 
        diag_log format ["Paratrooper Training Error: Unit is null or dead"];
        false 
    };
    
    // Check if unit already has paratrooper training
    private _unitData = [_unit] call fnc_getUnitData;
    if (isNil "_unitData") exitWith { 
        diag_log "Paratrooper Training Error: Unit data not found";
        false 
    };
    
    private _training = _unitData select 2;
    if ("paratrooper" in _training) exitWith {
        diag_log format ["Paratrooper Training: Unit %1 already has paratrooper training", name _unit];
        false
    };
    
    // Check if unit has basic training first
    if !("basic" in _training) exitWith {
        diag_log format ["Paratrooper Training: Unit %1 needs basic training first", name _unit];
        hint format ["%1 needs to complete basic training before paratrooper training.", name _unit];
        false
    };
    
    // Check if enough training points are available
    private _trainingPoints = ["training"] call fnc_getResourceAmount;
    if (_trainingPoints < PARATROOPER_TRAINING_COST) exitWith {
        diag_log format ["Paratrooper Training: Not enough training points. Need %1, have %2", PARATROOPER_TRAINING_COST, _trainingPoints];
        false
    };
    
    // Check if research requirements are met
    private _researchMet = true;
    
    // If MISSION_completedResearch is defined (from research system)
    if (!isNil "MISSION_completedResearch") then {
        if !("paratrooper_doctrine" in MISSION_completedResearch) then {
            _researchMet = false;
            diag_log "Paratrooper Training: Research requirement 'paratrooper_doctrine' not met";
        };
    } else {
        // If no research system, require it to be explicitly unlocked
        _researchMet = false;
        diag_log "Paratrooper Training: Research system not found";
    };
    
    if (!_researchMet) exitWith {
        hint "Paratrooper training requires research in Paratrooper Doctrine.";
        false
    };
    
    // Unit is eligible
    true
};

// Function to start paratrooper training for a unit
fnc_startParatrooperTraining = {
    params ["_unit"];
    
    // Check eligibility
    if !([_unit] call fnc_canReceiveParatrooperTraining) exitWith {
        hint "Unit is not eligible for paratrooper training.";
        false
    };
    
    // Deduct training points
    ["training", -PARATROOPER_TRAINING_COST] call fnc_modifyResource;
    
    // If training is instant, apply effects immediately
    if (PARATROOPER_TRAINING_DURATION <= 0) then {
        [_unit] call fnc_completeParatrooperTraining;
    } else {
        // Otherwise, start training process
        hint format ["%1 has been sent for paratrooper training. Training will complete in %2 seconds.", name _unit, PARATROOPER_TRAINING_DURATION];
        
        // Track training status
        _unit setVariable ["paratrooperTrainingInProgress", true, true];
        
        // Schedule completion
        [_unit] spawn {
            params ["_unit"];
            
            // Wait for training to complete
            sleep PARATROOPER_TRAINING_DURATION;
            
            // Check if unit is still alive
            if (alive _unit) then {
                // Complete training
                [_unit] call fnc_completeParatrooperTraining;
            } else {
                // Unit died during training
                hint format ["%1 died during paratrooper training.", name _unit];
            };
        };
    };
    
    true
};

// Function to complete paratrooper training and apply effects
fnc_completeParatrooperTraining = {
    params ["_unit"];
    
    // Remove in-progress status
    _unit setVariable ["paratrooperTrainingInProgress", nil, true];
    
    // Apply skill improvements
    {
        _x params ["_skill", "_value"];
        _unit setSkill [_skill, _value];
    } forEach PARATROOPER_TRAINING_SKILLS;
    
    // Mark unit as a paratrooper
    _unit setVariable ["isParatrooper", true, true];
    
    // Update unit data
    private _unitData = [_unit] call fnc_getUnitData;
    private _training = _unitData select 2;
    _training pushBack "paratrooper";
    _unitData set [2, _training];
    [_unit, _unitData] call fnc_updateUnitData;
    
    // Add unique abilities or equipment if needed
    // For example, could give paratroopers better parachute handling
    
    // Provide feedback
    hint format ["%1 has completed paratrooper training. Airborne capabilities improved!", name _unit];
    
    // Log training completion
    diag_log format ["Paratrooper Training: %1 completed paratrooper training", name _unit];
    
    true
};

// Optional: Function to check training progress
fnc_checkParatrooperTrainingProgress = {
    params ["_unit"];
    
    if (isNull _unit) exitWith { false };
    
    private _inProgress = _unit getVariable ["paratrooperTrainingInProgress", false];
    _inProgress
};

// Return true to indicate the script loaded successfully
true