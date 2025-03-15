// scripts/training/basicTraining.sqf
// Enhanced Basic Training Module with shooting exercises

// =====================================================================
// CONFIGURATION VALUES - EDIT THESE AS NEEDED
// =====================================================================

// Cost in training points
BASIC_TRAINING_COST = 10;

// Training duration in seconds (set to 0 for instant)
BASIC_TRAINING_DURATION = 30;  // 30 seconds for testing, could be longer in production

// Skill improvements (increments added to existing skills)
BASIC_TRAINING_SKILLS = [
    ["aimingAccuracy", 0.1],   // Improve aiming accuracy by 0.1
    ["aimingSpeed", 0.1],      // Improve aiming speed by 0.1
    ["spotDistance", 0.1],     // Improve spotting distance by 0.1
    ["courage", 0.1],          // Improve courage by 0.1
    ["reloadSpeed", 0.1]       // Improve reload speed by 0.1
];

// SHOOTING EXERCISE PARAMETERS - EDIT THESE AS NEEDED
BASIC_TRAINING_SHOTS_PER_TARGET = 5;    // Number of shots at each target
BASIC_TRAINING_TARGETS_TO_ENGAGE = 3;    // Number of targets to engage during training
BASIC_TRAINING_DELAY_BETWEEN_TARGETS = 2; // Seconds between target changes

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
    
    // Check if we have required markers
    private _trainingStart = markerPos "training_start";
    if (_trainingStart isEqualTo [0,0,0]) then {
        hint "Error: training_start marker not found!";
        diag_log "Basic Training Error: training_start marker is missing";
    };
    
    // Check for firing positions
    private _hasAnyFiringPos = false;
    private _firingPosList = [];
    for "_i" from 1 to 6 do {
        private _markerName = format ["fire_pos_%1", _i];
        private _pos = markerPos _markerName;
        if !(_pos isEqualTo [0,0,0]) then {
            _hasAnyFiringPos = true;
            _firingPosList pushBack _markerName;
        };
    };
    
    if (!_hasAnyFiringPos) then {
        hint "Error: No firing position markers (fire_pos_1, fire_pos_2, etc.) found!";
        diag_log "Basic Training Error: No firing position markers found";
    } else {
        diag_log format ["Found %1 firing position markers: %2", count _firingPosList, _firingPosList];
    };
    
    // Check for target objects by variable name
    private _hasAnyTargets = false;
    private _targetList = [];
    for "_i" from 1 to 6 do {
        private _targetName = format ["target_%1", _i];
        private _targetObj = missionNamespace getVariable [_targetName, objNull];
        
        if (!isNull _targetObj) then {
            _hasAnyTargets = true;
            _targetList pushBack _targetName;
        };
    };
    
    if (!_hasAnyTargets) then {
        hint "Error: No target objects (target_1, target_2, etc.) found as variable names!";
        diag_log "Basic Training Error: No target objects found with variable names target_1 through target_6";
    } else {
        diag_log format ["Found %1 target objects with variable names: %2", count _targetList, _targetList];
    };
    
    // Store original group and position for later
    _unit setVariable ["basicTraining_originalGroup", group _unit, true];
    _unit setVariable ["basicTraining_originalPos", getPos _unit, true];
    _unit setVariable ["basicTraining_isLeader", (leader group _unit) == _unit, true];
    
    // Deduct training points
    ["training", -BASIC_TRAINING_COST] call fnc_modifyResource;
    
    // Track training status
    _unit setVariable ["basicTrainingInProgress", true, true];
    
    // If training is instant, apply effects immediately
    if (BASIC_TRAINING_DURATION <= 0) then {
        [_unit] call fnc_completeBasicTraining;
    } else {
        // Start training process
        hint format ["%1 has been ordered to basic training.", name _unit];
        
        // Start the training process in a separate thread
        [_unit] spawn fnc_conductBasicTraining;
    };
    
    true
};

// Function to conduct actual basic training exercise
fnc_conductBasicTraining = {
    params ["_unit"];
    
    // Add global timeout of 10 minutes for entire process
    private _globalTimeout = 600; // 10 minutes
    private _globalStartTime = time;
    
    // Create a temporary training group
    private _trainingGroup = createGroup (side _unit);
    [_unit] joinSilent _trainingGroup;
    
    // Ensure unit is not in a vehicle
    if (vehicle _unit != _unit) then {
        _unit action ["Eject", vehicle _unit];
        sleep 1;
    };
    
    // Disable AI temporarily
    _unit disableAI "AUTOCOMBAT";
    _unit disableAI "AUTOTARGET";
    _unit setBehaviour "CARELESS";
    
    // Explicitly make unit non-editable for Zeus
    {
        _x removeCuratorEditableObjects [[_unit], false];
    } forEach allCurators;
    
    // Find training start position
    private _trainingStart = markerPos "training_start";
    if (_trainingStart isEqualTo [0,0,0]) then {
        // Fallback if marker doesn't exist
        diag_log "Basic Training Error: training_start marker not found";
        _trainingStart = getPos _unit;
    };
    
    // Give feedback that unit is heading to training
    hint format ["%1 is heading to the training grounds.", name _unit];
    
    // Make unit RUN to the training start position
    _unit setUnitPos "UP";
    _unit forceSpeed -1; // Force maximum speed
    _unit doMove _trainingStart;
    
    // Wait until unit reaches training start or timeout
    private _startTime = time;
    private _moveTimeout = 120; // 2 minutes to reach training area
    private _reachedStart = false;
    
    while {time < _startTime + _moveTimeout} do {
        // Check if unit is still alive
        if (!alive _unit) exitWith {};
        
        // Check if unit has reached the start position
        if (_unit distance _trainingStart < 3) exitWith {
            _reachedStart = true;
        };
        sleep 1;
    };
    
    // Check if unit is still alive
    if (!alive _unit) exitWith {
        diag_log format ["Basic Training: %1 died during movement to training area", name _unit];
        [_unit] call fnc_completeBasicTraining;
    };
    
    // If unit didn't reach start position, move them there
    if (!_reachedStart) then {
        diag_log format ["Basic Training: %1 did not reach training start position in time, teleporting", name _unit];
        _unit setPos _trainingStart;
    };
    
    // DEBUG: Indicate unit has reached training start
    hint format ["%1 has reached training start, preparing firing position...", name _unit];
    diag_log format ["Unit %1 has reached training start", name _unit];
    
    // Prepare array of firing positions
    private _firingPositions = [];
    for "_i" from 1 to 6 do {
        private _markerName = format ["fire_pos_%1", _i];
        private _posMarker = markerPos _markerName;
        if !(_posMarker isEqualTo [0,0,0]) then {
            _firingPositions pushBack _posMarker;
            diag_log format ["Found firing position %1 at %2", _markerName, _posMarker];
        };
    };
    
    diag_log format ["Total firing positions found: %1", count _firingPositions];
    
    // Prepare array of targets - using objects with variable names instead of markers
    private _targets = [];
    for "_i" from 1 to 6 do {
        private _targetName = format ["target_%1", _i];
        private _targetObj = missionNamespace getVariable [_targetName, objNull];
        
        if (!isNull _targetObj) then {
            private _targetPos = getPos _targetObj;
            _targets pushBack _targetPos;
            diag_log format ["Found target object %1 at position %2", _targetName, _targetPos];
        } else {
            diag_log format ["Target object %1 not found or is null", _targetName];
        };
    };
    
    diag_log format ["Total targets found: %1", count _targets];
    
    // Check if we have valid positions and targets
    if (count _firingPositions == 0) then {
        diag_log "Basic Training Error: No valid firing positions found. Completing training early.";
        hint "ERROR: No firing positions found. Training cannot proceed with shooting exercises.";
        sleep 3;
        [_unit] call fnc_completeBasicTraining;
    } else {
        if (count _targets == 0) then {
            diag_log "Basic Training Error: No valid targets found. Completing training early.";
            hint "ERROR: No targets found. Training cannot proceed with shooting exercises.";
            sleep 3;
            [_unit] call fnc_completeBasicTraining;
        } else {
            // Unit has reached training start, now teleport to firing position
            _unit allowDamage false; // Prevent damage during teleport
            
            // Pick a random firing position
            private _selectedPos = selectRandom _firingPositions;
            diag_log format ["Selected firing position: %1", _selectedPos];
            
            // Move to firing position
            _unit setPos _selectedPos;
            hint format ["%1 has arrived at the training range and is starting exercises.", name _unit];
            sleep 1;
            
            // Make unit face target_4 initially (if it exists, otherwise face first target)
            private _initialTarget = [0,0,0];
            private _target4Obj = missionNamespace getVariable ["target_4", objNull];
            
            if (!isNull _target4Obj) then {
                _initialTarget = getPos _target4Obj;
                diag_log format ["Using target_4 object for initial facing at %1", _initialTarget];
            };
            
            if (_initialTarget isEqualTo [0,0,0] && count _targets > 0) then {
                _initialTarget = _targets select 0;
                diag_log format ["Target_4 not found, using first available target at %1", _initialTarget];
            };
            
            if !(_initialTarget isEqualTo [0,0,0]) then {
                _unit doWatch _initialTarget;
                diag_log format ["Unit watching initial target at %1", _initialTarget];
                sleep 1;
            };
            
            // Ensure unit has a weapon and full ammunition
            if (primaryWeapon _unit == "") then {
                // Give a basic rifle if unit has none
                _unit addWeapon "arifle_MXC_F";
                _unit addMagazines ["30Rnd_65x39_caseless_mag", 5];
                diag_log "Added basic weapon to unit";
            } else {
                diag_log format ["Unit using existing weapon: %1", primaryWeapon _unit];
            };
            
            // Set full ammo for primary weapon
            _unit setAmmo [primaryWeapon _unit, 30]; // Set to full magazine capacity
            diag_log "Set unit's weapon to full ammunition";
            sleep 1;
            
            // Now start the actual training timer
            private _trainingStartTime = time;
            private _trainingEndTime = _trainingStartTime + BASIC_TRAINING_DURATION;
            diag_log format ["Training started at %1, will end at %2", _trainingStartTime, _trainingEndTime];
            
            // Conduct shooting exercise
            private _targetsToEngage = (BASIC_TRAINING_TARGETS_TO_ENGAGE min count _targets) max 1;
            diag_log format ["Will engage %1 targets", _targetsToEngage];
            
            for "_i" from 1 to _targetsToEngage do {
                // Check if training time is up
                if (time >= _trainingEndTime) exitWith {
                    diag_log format ["Basic Training: Training duration completed for %1", name _unit];
                };
                
                // Select random target
                private _targetPos = selectRandom _targets;
                diag_log format ["Selected target %1 for engagement %2", _targetPos, _i];
                
                // Create temporary target object if desired
                private _targetObj = "Sign_Arrow_Large_F" createVehicle _targetPos;
                _targetObj setPosASL (AGLtoASL _targetPos);
                diag_log "Created target object";
                
                // Watch and shoot at target
                _unit doWatch _targetPos;
                diag_log "Unit watching target";
                sleep 1;
                
                // Fire multiple shots at each target
                for "_j" from 1 to BASIC_TRAINING_SHOTS_PER_TARGET do {
                    // Check time again
                    if (time >= _trainingEndTime) exitWith {};
                    
                    // Set ammo to ensure we can fire
                    _unit setAmmo [primaryWeapon _unit, 30];
                    
                    _unit fire (primaryWeapon _unit);
                    diag_log format ["Unit fired shot %1 at target", _j];
                    sleep (0.5 + random 1);
                };
                
                // Clean up target
                deleteVehicle _targetObj;
                diag_log "Deleted target object";
                
                // Delay between targets if we still have time
                if (_i < _targetsToEngage && time < _trainingEndTime) then {
                    diag_log format ["Waiting %1 seconds before next target", BASIC_TRAINING_DELAY_BETWEEN_TARGETS];
                    sleep BASIC_TRAINING_DELAY_BETWEEN_TARGETS;
                };
            };
            
            // Wait until training time is complete
            private _remainingTime = _trainingEndTime - time;
            if (_remainingTime > 0) then {
                hint format ["%1 is completing training exercises. %2 seconds remaining.", name _unit, round _remainingTime];
                diag_log format ["Waiting %1 seconds to complete training time", _remainingTime];
                sleep _remainingTime;
            };
            
            // Re-enable damage
            _unit allowDamage true;
            diag_log "Re-enabling damage for unit";
            
            // Training complete!
            hint format ["%1 has completed the training exercises!", name _unit];
            diag_log "Training exercises completed successfully";
        };
    };
    
    diag_log "Calling fnc_completeBasicTraining to finalize training";
    // Complete the training regardless of how we got here
    [_unit] call fnc_completeBasicTraining;
};

// Function to complete basic training and apply effects
fnc_completeBasicTraining = {
    params ["_unit"];
    
    diag_log format ["Completing basic training for unit %1", name _unit];
    
    // Make sure unit is still alive
    if (isNull _unit || !alive _unit) exitWith {
        diag_log "Basic Training Error: Unit is null or dead during completion";
        false
    };
    
    // Enable damage again
    _unit allowDamage true;
    
    // Re-enable AI
    _unit enableAI "AUTOCOMBAT";
    _unit enableAI "AUTOTARGET";
    _unit setBehaviour "AWARE";
    
    // Remove in-progress status
    _unit setVariable ["basicTrainingInProgress", nil, true];
    
    // Apply skill improvements - add to existing skills
    {
        _x params ["_skill", "_value"];
        private _currentSkill = _unit skill _skill;
        private _newSkill = (_currentSkill + _value) min 1; // Cap at 1.0 maximum
        _unit setSkill [_skill, _newSkill];
        diag_log format ["Improved skill %1 from %2 to %3", _skill, _currentSkill, _newSkill];
    } forEach BASIC_TRAINING_SKILLS;
    
    // Update unit data
    private _unitData = [_unit] call fnc_getUnitData;
    private _training = _unitData select 2;
    _training pushBack "basic";
    _unitData set [2, _training];
    [_unit, _unitData] call fnc_updateUnitData;
    diag_log "Updated unit data to include basic training";
    
    // Get original group and leadership status
    private _originalGroup = _unit getVariable ["basicTraining_originalGroup", grpNull];
    private _wasLeader = _unit getVariable ["basicTraining_isLeader", false];
    
    // Return to original group if it exists
    if (!isNull _originalGroup) then {
        // Move back to group
        [_unit] joinSilent _originalGroup;
        diag_log format ["Unit rejoined original group %1", _originalGroup];
        
        // Take leadership if unit was leader before
        if (_wasLeader) then {
            _originalGroup selectLeader _unit;
            diag_log "Unit resumed leadership of group";
        } else {
            // Or take leadership if highest rank
            private _highestRankID = -1;
            private _highestRankUnit = objNull;
            
            {
                private _rankID = rankId _x;
                if (_rankID > _highestRankID) then {
                    _highestRankID = _rankID;
                    _highestRankUnit = _x;
                };
            } forEach units _originalGroup;
            
            if (_highestRankUnit == _unit) then {
                _originalGroup selectLeader _unit;
                diag_log "Unit assumed leadership as highest ranking member";
            };
        };
    } else {
        diag_log "Original group was null, unit remains in training group";
    };
    
    // Make unit available for Zeus editing again
    {
        _x addCuratorEditableObjects [[_unit], true];
    } forEach allCurators;
    diag_log "Made unit editable in Zeus again";
    
    // Clear variables
    _unit setVariable ["basicTraining_originalGroup", nil];
    _unit setVariable ["basicTraining_originalPos", nil];
    _unit setVariable ["basicTraining_isLeader", nil];
    
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
diag_log "Basic training script loaded successfully";
true