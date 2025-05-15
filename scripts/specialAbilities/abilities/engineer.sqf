// scripts/specialAbilities/abilities/engineer.sqf
// Repair special ability for engineers to fix vehicles and structures

// Initialize global variables
if (isNil "ENGINEER_active") then { ENGINEER_active = false; };
if (isNil "ENGINEER_repairer") then { ENGINEER_repairer = objNull; };
if (isNil "ENGINEER_target") then { ENGINEER_target = objNull; };
if (isNil "ENGINEER_keyHandler") then { ENGINEER_keyHandler = -1; };
if (isNil "ENGINEER_drawHandler") then { ENGINEER_drawHandler = -1; };
if (isNil "ENGINEER_progressHandler") then { ENGINEER_progressHandler = -1; };
if (isNil "ENGINEER_inProgress") then { ENGINEER_inProgress = false; };

// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE BEHAVIOR ===
ENGINEER_repairTime = 12;             // Time in seconds to repair
ENGINEER_cooldownTime = 120;          // Cooldown time in seconds
ENGINEER_repairRange = 8;             // Range from which repair can be performed

// Function to reset state
fnc_resetEngineerState = {
    ENGINEER_active = false;
    ENGINEER_target = objNull;
    
    // Remove handlers
    if (ENGINEER_keyHandler != -1) then {
        (findDisplay 312) displayRemoveEventHandler ["KeyDown", ENGINEER_keyHandler];
        ENGINEER_keyHandler = -1;
    };
    
    if (ENGINEER_drawHandler != -1) then {
        removeMissionEventHandler ["Draw3D", ENGINEER_drawHandler];
        ENGINEER_drawHandler = -1;
    };
    
    if (ENGINEER_progressHandler != -1) then {
        removeMissionEventHandler ["EachFrame", ENGINEER_progressHandler];
        ENGINEER_progressHandler = -1;
    };
    
    // Delete any progress controls
    if (!isNil "ENGINEER_progressControls") then {
        {
            ctrlDelete _x;
        } forEach ENGINEER_progressControls;
        ENGINEER_progressControls = [];
    };
};

// Function to create progress display
fnc_createRepairProgress = {
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
    _progress ctrlSetTextColor [0.8, 0.4, 0.1, 1]; // Orange
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
    _text ctrlSetText "Repairing...";
    _text ctrlSetTextColor [1, 1, 1, 1];
    _text ctrlCommit 0;
    _controls pushBack _text;
    
    ENGINEER_progressControls = _controls;
    
    // Update progress handler
    ENGINEER_progressHandler = addMissionEventHandler ["EachFrame", {
        if (!ENGINEER_inProgress) exitWith {};
        
        private _controls = ENGINEER_progressControls;
        if (!isNil "_controls" && count _controls > 0) then {
            private _progress = _controls select 1;
            if (!isNull _progress) then {
                _progress progressSetPosition (ENGINEER_repairer getVariable ["engineerRepairProgress", 0]);
            };
        };
    }];
};

// Function to execute repairing
fnc_executeRepairing = {
    ENGINEER_inProgress = true;
    
    private _engineer = ENGINEER_repairer;
    private _target = ENGINEER_target;
    
    // Create progress display
    call fnc_createRepairProgress;
    
    // Disable AI for engineer
    _engineer disableAI "MOVE";
    _engineer disableAI "TARGET";
    _engineer disableAI "AUTOTARGET";
    _engineer disableAI "FSM";
    
    // Move to target
    _engineer doMove (getPos _target);
    
    [_engineer, _target] spawn {
        params ["_engineer", "_target"];
        
        // Wait until engineer reaches target
        waitUntil {
            sleep 0.5;
            _engineer distance _target < ENGINEER_repairRange || !alive _engineer || isNull _target
        };
        
        // Exit if engineer died or target is destroyed
        if (!alive _engineer || isNull _target) exitWith {
            ENGINEER_inProgress = false;
            call fnc_resetEngineerState;
            systemChat "Repair interrupted.";
        };
        
        // Face target
        _engineer lookAt _target;
        _engineer doWatch _target;
        
        // Start repair animation
        [_engineer, "AinvPknlMstpSnonWnonDnon_medic4"] remoteExec ["switchMove", 0];
        
        // Calculate initial damage
        private _initialDamage = damage _target;
        private _targetDamage = 0; // Fully repaired
        
        private _startTime = time;
        private _duration = ENGINEER_repairTime;
        
        // Repair process
        while {time < _startTime + _duration && alive _engineer && !isNull _target} do {
            private _elapsed = time - _startTime;
            private _progress = _elapsed / _duration;
            
            // Update damage based on progress
            private _currentDamage = linearConversion [0, 1, _progress, _initialDamage, _targetDamage, true];
            _target setDamage _currentDamage;
            
            // Update progress variable
            _engineer setVariable ["engineerRepairProgress", _progress];
            
            // Add visual effects every second
            if (_elapsed % 1 < 0.1) then {
                // Welding sparks effect
                private _effectPos = _engineer modelToWorld [0.3, 0.3, 0.3];
                private _effect = "#particlesource" createVehicleLocal _effectPos;
                _effect setParticleClass "FireSparks";
                _effect setDropInterval 0.05;
                
                // Delete effect after a moment
                [_effect] spawn {
                    params ["_effect"];
                    sleep 0.5;
                    deleteVehicle _effect;
                };
            };
            
            sleep 0.1;
        };
        
        // Complete repair
        if (alive _engineer && !isNull _target) then {
            _target setDamage 0;
            
            // Reset animation
            [_engineer, ""] remoteExec ["switchMove", 0];
            
            // Set cooldown
            _engineer setVariable ["ABILITY_engineer_cooldown", time + ENGINEER_cooldownTime, true];
            
            // Get vehicle/object name
            private _targetName = if (_target isKindOf "AllVehicles") then {
                getText (configFile >> "CfgVehicles" >> typeOf _target >> "displayName")
            } else {
                typeOf _target
            };
            
            systemChat format ["%1 has repaired %2.", name _engineer, _targetName];
            hint parseText format [
                "<t size='1.2' color='#66ff66'>Repair Complete</t><br/><br/>" +
                "<t color='#90EE90'>%1</t> fully repaired.<br/>" +
                "<t color='#87CEEB'>Ready for service!</t>",
                _targetName
            ];
            
            // Play completion sound effect
            playSound3D ["a3\sounds_f\characters\footsteps\concrete_walk_4.wss", _target];
        };
        
        // Re-enable AI
        _engineer enableAI "MOVE";
        _engineer enableAI "TARGET";
        _engineer enableAI "AUTOTARGET";
        _engineer enableAI "FSM";
        
        ENGINEER_inProgress = false;
        call fnc_resetEngineerState;
    };
};

// Main function - called when ability is activated
params ["_unit", ["_target", objNull]];

// Set up state
ENGINEER_repairer = _unit;
ENGINEER_target = _target;

// Check if target is valid
if (isNull _target) exitWith {
    systemChat "Invalid target.";
    call fnc_resetEngineerState;
};

// Check if target is a vehicle or structure
if (!(_target isKindOf "AllVehicles" || _target isKindOf "House")) exitWith {
    systemChat "Cannot repair this object.";
    call fnc_resetEngineerState;
};

// Check if target is already fully repaired
if (damage _target < 0.01) exitWith {
    systemChat format ["%1 is already repaired.", 
        if (_target isKindOf "AllVehicles") then {
            getText (configFile >> "CfgVehicles" >> typeOf _target >> "displayName")
        } else { 
            typeOf _target 
        }
    ];
    call fnc_resetEngineerState;
};

// Check if engineer is already repairing something
if (ENGINEER_inProgress) exitWith {
    systemChat "Already repairing something.";
};

// Check cooldown
private _cooldown = _unit getVariable ["ABILITY_engineer_cooldown", 0];
if (time < _cooldown) exitWith {
    private _remaining = _cooldown - time;
    systemChat format ["Repair ability on cooldown. %1 seconds remaining.", round _remaining];
};

// Execute repairing
private _targetName = if (_target isKindOf "AllVehicles") then {
    getText (configFile >> "CfgVehicles" >> typeOf _target >> "displayName")
} else {
    typeOf _target
};

systemChat format ["%1 beginning to repair %2...", name _unit, _targetName];
call fnc_executeRepairing;