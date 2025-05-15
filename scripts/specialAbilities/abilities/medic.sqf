// scripts/specialAbilities/abilities/medic.sqf
// Healing special ability for medics to treat wounded friendly units

// Initialize global variables
if (isNil "MEDIC_active") then { MEDIC_active = false; };
if (isNil "MEDIC_healer") then { MEDIC_healer = objNull; };
if (isNil "MEDIC_target") then { MEDIC_target = objNull; };
if (isNil "MEDIC_keyHandler") then { MEDIC_keyHandler = -1; };
if (isNil "MEDIC_drawHandler") then { MEDIC_drawHandler = -1; };
if (isNil "MEDIC_progressHandler") then { MEDIC_progressHandler = -1; };
if (isNil "MEDIC_inProgress") then { MEDIC_inProgress = false; };

// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE BEHAVIOR ===
MEDIC_healingTime = 8;                // Time in seconds to heal
MEDIC_maxHealAmount = 0.8;            // Maximum healing (80% fully healed)
MEDIC_cooldownTime = 60;              // Cooldown time in seconds
MEDIC_healingRange = 5;               // Range from which healing can be performed

// Function to reset state
fnc_resetMedicState = {
    MEDIC_active = false;
    MEDIC_target = objNull;
    
    // Remove handlers
    if (MEDIC_keyHandler != -1) then {
        (findDisplay 312) displayRemoveEventHandler ["KeyDown", MEDIC_keyHandler];
        MEDIC_keyHandler = -1;
    };
    
    if (MEDIC_drawHandler != -1) then {
        removeMissionEventHandler ["Draw3D", MEDIC_drawHandler];
        MEDIC_drawHandler = -1;
    };
    
    if (MEDIC_progressHandler != -1) then {
        removeMissionEventHandler ["EachFrame", MEDIC_progressHandler];
        MEDIC_progressHandler = -1;
    };
    
    // Delete any progress controls
    if (!isNil "MEDIC_progressControls") then {
        {
            ctrlDelete _x;
        } forEach MEDIC_progressControls;
        MEDIC_progressControls = [];
    };
};

// Function to create progress display
fnc_createHealingProgress = {
    private _display = findDisplay 312;
    private _controls = [];
    
    // Create background
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [
        safezoneX + 0.35 * safezoneW,
        safezoneY + 0.8 * safezoneH,
        0.3 * safezoneW,
        0.05 * safezoneH
    ];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _background ctrlCommit 0;
    _controls pushBack _background;
    
    // Create progress bar
    private _progress = _display ctrlCreate ["RscProgress", -1];
    _progress ctrlSetPosition [
        safezoneX + 0.36 * safezoneW,
        safezoneY + 0.825 * safezoneH,
        0.28 * safezoneW,
        0.02 * safezoneH
    ];
    _progress ctrlSetTextColor [0.2, 0.8, 0.2, 1]; // Green
    _progress ctrlCommit 0;
    _controls pushBack _progress;
    
    // Create text
    private _text = _display ctrlCreate ["RscText", -1];
    _text ctrlSetPosition [
        safezoneX + 0.36 * safezoneW,
        safezoneY + 0.805 * safezoneH,
        0.28 * safezoneW,
        0.02 * safezoneH
    ];
    _text ctrlSetText "Healing...";
    _text ctrlSetTextColor [1, 1, 1, 1];
    _text ctrlCommit 0;
    _controls pushBack _text;
    
    MEDIC_progressControls = _controls;
    
    // Update progress handler
    MEDIC_progressHandler = addMissionEventHandler ["EachFrame", {
        if (!MEDIC_inProgress) exitWith {};
        
        private _controls = MEDIC_progressControls;
        if (!isNil "_controls" && count _controls > 0) then {
            private _progress = _controls select 1;
            if (!isNull _progress) then {
                _progress progressSetPosition (MEDIC_healer getVariable ["medicHealProgress", 0]);
            };
        };
    }];
};

// Function to execute healing
fnc_executeHealing = {
    MEDIC_inProgress = true;
    
    private _healer = MEDIC_healer;
    private _patient = MEDIC_target;
    
    // Create progress display
    call fnc_createHealingProgress;
    
    // Disable AI for healer
    _healer disableAI "MOVE";
    _healer disableAI "TARGET";
    _healer disableAI "AUTOTARGET";
    _healer disableAI "FSM";
    
    // Move to patient
    _healer doMove (getPos _patient);
    
    [_healer, _patient] spawn {
        params ["_healer", "_patient"];
        
        // Wait until healer reaches patient
        waitUntil {
            sleep 0.5;
            _healer distance _patient < MEDIC_healingRange || !alive _healer || !alive _patient
        };
        
        // Exit if either unit died
        if (!alive _healer || !alive _patient) exitWith {
            MEDIC_inProgress = false;
            call fnc_resetMedicState;
            systemChat "Healing interrupted.";
        };
        
        // Face patient
        _healer lookAt _patient;
        _healer doWatch _patient;
        
        // Start healing animation
        [_healer, "AinvPknlMstpSnonWnonDnon_medic4"] remoteExec ["switchMove", 0];
        [_patient, "AinjPfllMstpSnonWrflDnon_carried_Up"] remoteExec ["switchMove", 0];
        
        // Calculate initial damage
        private _initialDamage = damage _patient;
        private _targetDamage = _initialDamage - (1 - MEDIC_maxHealAmount);
        _targetDamage = _targetDamage max 0;
        
        private _startTime = time;
        private _duration = MEDIC_healingTime;
        
        // Healing process
        while {time < _startTime + _duration && alive _healer && alive _patient} do {
            private _elapsed = time - _startTime;
            private _progress = _elapsed / _duration;
            
            // Update damage based on progress
            private _currentDamage = linearConversion [0, 1, _progress, _initialDamage, _targetDamage, true];
            _patient setDamage _currentDamage;
            
            // Update progress variable
            _healer setVariable ["medicHealProgress", _progress];
            
            sleep 0.1;
        };
        
        // Complete healing
        if (alive _healer && alive _patient) then {
            _patient setDamage _targetDamage;
            
            // Reset animations
            [_healer, ""] remoteExec ["switchMove", 0];
            [_patient, ""] remoteExec ["switchMove", 0];
            
            // Set cooldown
            _healer setVariable ["ABILITY_medic_cooldown", time + MEDIC_cooldownTime, true];
            
            systemChat format ["%1 has healed %2.", name _healer, name _patient];
            hint parseText format [
                "<t size='1.2' color='#66ff66'>Healing Complete</t><br/><br/>" +
                "<t color='#90EE90'>%1</t> treated successfully.<br/>" +
                "<t color='#87CEEB'>Health restored to %2%3</t>",
                name _patient, round(MEDIC_maxHealAmount * 100), "%"
            ];
        };
        
        // Re-enable AI
        _healer enableAI "MOVE";
        _healer enableAI "TARGET";
        _healer enableAI "AUTOTARGET";
        _healer enableAI "FSM";
        
        MEDIC_inProgress = false;
        call fnc_resetMedicState;
    };
};

// Main function - called when ability is activated
params ["_unit", ["_target", objNull]];

// Set up state
MEDIC_healer = _unit;
MEDIC_target = _target;

// Check if target is valid and friendly
if (isNull _target || !alive _target) exitWith {
    systemChat "Invalid or dead target.";
    call fnc_resetMedicState;
};

if (side _unit != side _target) exitWith {
    systemChat "Cannot heal enemy units.";
    call fnc_resetMedicState;
};

if (damage _target < 0.01) exitWith {
    systemChat format ["%1 is already healthy.", name _target];
    call fnc_resetMedicState;
};

// Check if medic is already treating someone
if (MEDIC_inProgress) exitWith {
    systemChat "Already treating a patient.";
};

// Check cooldown
private _cooldown = _unit getVariable ["ABILITY_medic_cooldown", 0];
if (time < _cooldown) exitWith {
    private _remaining = _cooldown - time;
    systemChat format ["Healing ability on cooldown. %1 seconds remaining.", round _remaining];
};

// Execute healing
systemChat format ["%1 beginning to heal %2...", name _unit, name _target];
call fnc_executeHealing;