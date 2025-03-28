// SMG Burst Ability - IMPROVED VERSION
// Allows a unit to empty their submachine gun at a target in slow motion for dramatic effect

// Initialize global variables
if (isNil "SMGBURST_active") then { SMGBURST_active = false; };
if (isNil "SMGBURST_shootingUnit") then { SMGBURST_shootingUnit = objNull; };
if (isNil "SMGBURST_target") then { SMGBURST_target = objNull; };
if (isNil "SMGBURST_targetPos") then { SMGBURST_targetPos = []; };
if (isNil "SMGBURST_timeScale") then { SMGBURST_timeScale = 0.3; }; // Slow-mo factor - adjustable
if (isNil "SMGBURST_keyHandler") then { SMGBURST_keyHandler = -1; };
if (isNil "SMGBURST_timeHandler") then { SMGBURST_timeHandler = -1; };
if (isNil "SMGBURST_drawHandler") then { SMGBURST_drawHandler = -1; };
if (isNil "SMGBURST_shotHandler") then { SMGBURST_shotHandler = -1; };
if (isNil "SMGBURST_currentPos") then { SMGBURST_currentPos = [0,0,0]; };
if (isNil "SMGBURST_controls") then { SMGBURST_controls = []; };
if (isNil "SMGBURST_burstInProgress") then { SMGBURST_burstInProgress = false; };
if (isNil "SMGBURST_activeTracers") then { SMGBURST_activeTracers = []; };

// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE BEHAVIOR ===
SMGBURST_maxDistance = 150;       // Maximum range for SMG burst
SMGBURST_burstDuration = 3;       // How long the burst lasts in seconds
SMGBURST_shotsPerSecond = 12;     // Rate of fire during burst
SMGBURST_acuracyRange = 2;        // How many meters the shots can deviate from target center
SMGBURST_baseHitChance = 50;      // Base chance (%) for each bullet to hit the target
SMGBURST_aimTime = 1;             // Time in seconds the unit takes to aim before firing

// Function to reset SMG burst state
fnc_resetSMGBurstState = {
    // Don't print message if burst is in progress to avoid spam
    if (!SMGBURST_burstInProgress) then {
        systemChat "Resetting SMG Burst state...";
    };
    
    SMGBURST_active = false;
    SMGBURST_target = objNull;
    SMGBURST_targetPos = [];
    
    // Remove handlers
    if (SMGBURST_keyHandler != -1) then {
        (findDisplay 312) displayRemoveEventHandler ["KeyDown", SMGBURST_keyHandler];
        SMGBURST_keyHandler = -1;
    };
    
    if (SMGBURST_timeHandler != -1) then {
        removeMissionEventHandler ["EachFrame", SMGBURST_timeHandler];
        SMGBURST_timeHandler = -1;
    };
    
    if (SMGBURST_shotHandler != -1) then {
        removeMissionEventHandler ["EachFrame", SMGBURST_shotHandler];
        SMGBURST_shotHandler = -1;
    };
    
    if (SMGBURST_drawHandler != -1) then {
        removeMissionEventHandler ["Draw3D", SMGBURST_drawHandler];
        SMGBURST_drawHandler = -1;
    };
    
    // Reset time only if not in burst
    if (!SMGBURST_burstInProgress) then {
        setAccTime 1;
    };
    
    // Clean up UI
    {
        ctrlDelete _x;
    } forEach SMGBURST_controls;
    SMGBURST_controls = [];
    
    if (!SMGBURST_burstInProgress) then {
        systemChat "SMG Burst state reset complete";
    };
};


// Create UI for SMG Burst
fnc_createSMGBurstUI = {
    private _display = findDisplay 312;
    
    // Create overlay
    private _overlay = _display ctrlCreate ["RscText", -1];
    _overlay ctrlSetPosition [safezoneX, safezoneY, safezoneW, safezoneH];
    _overlay ctrlSetBackgroundColor [0, 0.1, 0.2, 0.3];
    _overlay ctrlCommit 0;
    SMGBURST_controls pushBack _overlay;
    
    // Create info text
    private _infoText = _display ctrlCreate ["RscStructuredText", -1];
    _infoText ctrlSetPosition [safezoneX + (safezoneW * 0.3), safezoneY + (safezoneH * 0.1), safezoneW * 0.4, safezoneH * 0.1];
    _infoText ctrlSetStructuredText parseText "<t align='center' size='1.2'>SMG BURST ACTIVE<br/>SPACE to mark target | ENTER to confirm | BACKSPACE to cancel</t>";
    _infoText ctrlCommit 0;
    SMGBURST_controls pushBack _infoText;
    
    // Create target info display with background
    private _targetInfoBG = _display ctrlCreate ["RscText", -1];
    _targetInfoBG ctrlSetPosition [safezoneX + (safezoneW * 0.4), safezoneY + (safezoneH * 0.2), safezoneW * 0.2, safezoneH * 0.15];
    _targetInfoBG ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _targetInfoBG ctrlCommit 0;
    SMGBURST_controls pushBack _targetInfoBG;
    
    private _targetInfo = _display ctrlCreate ["RscStructuredText", -1];
    _targetInfo ctrlSetPosition [safezoneX + (safezoneW * 0.4), safezoneY + (safezoneH * 0.2), safezoneW * 0.2, safezoneH * 0.15];
    _targetInfo ctrlSetBackgroundColor [0, 0, 0, 0];
    _targetInfo ctrlSetStructuredText parseText "";
    _targetInfo ctrlCommit 0;
    SMGBURST_controls pushBack _targetInfo;
    
    uiNamespace setVariable ["SMGBURST_targetInfo", _targetInfo];
    
    // Create confirm button
    private _confirmBtn = _display ctrlCreate ["RscButton", -1];
    _confirmBtn ctrlSetPosition [
        safezoneX + (safezoneW * 0.45),
        safezoneY + (safezoneH * 0.36),
        safezoneW * 0.1,
        safezoneH * 0.04
    ];
    _confirmBtn ctrlSetText "OPEN FIRE";
    _confirmBtn ctrlSetBackgroundColor [0.7, 0.2, 0.2, 0.8];
    _confirmBtn ctrlShow false;
    _confirmBtn ctrlAddEventHandler ["ButtonClick", {
        if (!isNull SMGBURST_target || count SMGBURST_targetPos > 0) then {
            [] call fnc_executeSMGBurst;
        };
    }];
    _confirmBtn ctrlCommit 0;
    SMGBURST_controls pushBack _confirmBtn;
    
    uiNamespace setVariable ["SMGBURST_confirmBtn", _confirmBtn];
};

// Update target info
fnc_updateTargetInfo = {
    params ["_target", ["_targetPos", []]];
    
    // Exit if no target info control
    private _targetInfo = uiNamespace getVariable ["SMGBURST_targetInfo", controlNull];
    if (isNull _targetInfo) exitWith {};
    
    private _unit = SMGBURST_shootingUnit;
    if (isNull _unit) exitWith {};
    
    private _pos = if (count _targetPos > 0) then {_targetPos} else {if (!isNull _target) then {getPos _target} else {[0,0,0]}};
    if (_pos isEqualTo [0,0,0]) exitWith {};
    
    private _distance = _pos distance _unit;
    
    // Calculate hit chance based on distance and conditions
    private _hitChance = SMGBURST_baseHitChance;
    
    // Distance modifier
    private _distanceModifier = switch true do {
        case (_distance < 50): { 1.2 };
        case (_distance < 100): { 1.0 };
        case (_distance < 150): { 0.8 };
        default { 0.6 };
    };
    
    // Stance modifier
    private _stanceModifier = switch (stance _unit) do {
        case "PRONE": { 1.2 };
        case "CROUCH": { 1.1 };
        default { 0.9 };
    };
    
    // Calculate final hit chance
    private _finalHitChance = (_hitChance * _distanceModifier * _stanceModifier) min 95;
    
    // Generate text for info panel
    private _text = if (!isNull _target) then {
        format [
            "<t size='1.1'>Target: %1</t><br/>" +
            "<t color='#ADD8E6'>Distance: %2m</t><br/>" +
            "<t color='#90EE90'>Hit Chance: %3%4</t><br/>" +
            "<t size='0.8' color='#A0A0A0'>Modifiers: Distance %.1f | Stance %.1f</t>",
            if (_target isKindOf "CAManBase") then {name _target} else {typeOf _target},
            round _distance,
            round _finalHitChance,
            "%",
            _distanceModifier,
            _stanceModifier
        ];
    } else {
        format [
            "<t size='1.1'>Target: Position</t><br/>" +
            "<t color='#ADD8E6'>Distance: %1m</t><br/>" +
            "<t color='#90EE90'>Hit Chance: %2%3</t><br/>" +
            "<t size='0.8' color='#A0A0A0'>Modifiers: Distance %.1f | Stance %.1f</t>",
            round _distance,
            round _finalHitChance,
            "%",
            _distanceModifier,
            _stanceModifier
        ];
    };
    
    _targetInfo ctrlSetStructuredText parseText _text;
};

// Execute the SMG Burst - ERROR-FREE VERSION
fnc_executeSMGBurst = {
    private _unit = SMGBURST_shootingUnit;
    private _target = SMGBURST_target;
    private _targetPos = SMGBURST_targetPos;
    
    // Check for valid unit
    if (isNull _unit) exitWith {
        systemChat "No valid unit for SMG Burst!";
        SMGBURST_burstInProgress = false;
        setAccTime 1;
    };
    
    // Reset UI state but keep slow-mo active
    SMGBURST_burstInProgress = true;
    [] call fnc_resetSMGBurstState;
    
    // Exit if no valid target
    if (isNull _target && count _targetPos == 0) exitWith {
        systemChat "No valid target for SMG Burst!";
        SMGBURST_burstInProgress = false;
        setAccTime 1;
    };
    
    // Determine if we have an object target or just a position
    private _hasObjectTarget = !isNull _target;
    private _finalTargetPos = if (_hasObjectTarget) then {getPosATL _target} else {_targetPos};
    
    systemChat "Preparing for SMG Burst...";
    
    // Prepare unit for burst fire - IMPORTANT AIMING SETUP
    _unit disableAI "AUTOTARGET";
    _unit disableAI "FSM";
    _unit disableAI "MOVE";
    _unit disableAI "TARGET";
    
    _unit setUnitPos "UP";
    
    // Turn to face target
    _unit setDir ([_unit, _finalTargetPos] call BIS_fnc_dirTo);
    
    // Target object if available, otherwise watch position
    if (_hasObjectTarget) then {
        _unit doTarget _target;
        _unit lookAt _target;
    } else {
        _unit doWatch _finalTargetPos;
        _unit lookAt _finalTargetPos;
    };
    
    // Ensure primary weapon is selected and properly held
    _unit selectWeapon (primaryWeapon _unit);
    _unit setCombatMode "RED";
    
    // Force weapon ready - IMPROVED WEAPON HANDLING
    _unit action ["WeaponOnBack", _unit];
    sleep 0.1;
    _unit action ["SwitchWeapon", _unit, _unit, 0];
    
    // Check for weapon and ammo
    private _weapon = currentWeapon _unit;
    if (_weapon == "") exitWith {
        systemChat "No weapon available for SMG Burst!";
        
        // Reset unit state
        _unit enableAI "AUTOTARGET";
        _unit enableAI "FSM";
        _unit enableAI "MOVE";
        _unit doTarget objNull;
        _unit doWatch objNull;
        
        SMGBURST_burstInProgress = false;
        setAccTime 1;
    };
    
    private _ammo = _unit ammo _weapon;
    if (_ammo == 0) exitWith {
        systemChat "No ammunition for SMG Burst!";
        
        // Reset unit state
        _unit enableAI "AUTOTARGET";
        _unit enableAI "FSM";
        _unit enableAI "MOVE";
        _unit doTarget objNull;
        _unit doWatch objNull;
        
        SMGBURST_burstInProgress = false;
        setAccTime 1;
    };
    
    // Create slow-mo effect
    setAccTime SMGBURST_timeScale;
    
    // Add visual effects that will persist during the burst
    private _drawHandler = addMissionEventHandler ["Draw3D", {
        // Get references to needed variables
        private _burstActive = missionNamespace getVariable ["SMGBURST_burstInProgress", false];
        if (!_burstActive) exitWith {
            removeMissionEventHandler ["Draw3D", _thisEventHandler];
        };
        
        private _unit = missionNamespace getVariable ["SMGBURST_shootingUnit", objNull];
        if (isNull _unit) exitWith {
            removeMissionEventHandler ["Draw3D", _thisEventHandler];
        };
        
        private _target = missionNamespace getVariable ["SMGBURST_target", objNull];
        private _targetPos = missionNamespace getVariable ["SMGBURST_targetPos", []];
        
        // Get current target position (may move if it's an object)
        private _currentTargetPos = [0,0,0];
        
        if (!isNull _target) then {
            _currentTargetPos = getPosATL _target;
        } else {
            if (count _targetPos > 0) then {
                _currentTargetPos = _targetPos;
            };
        };
        
        // Don't draw anything if we don't have a valid position
        if (_currentTargetPos isEqualTo [0,0,0]) exitWith {};
        
        // Get weapon muzzle position for bullet traces
        private _muzzlePos = [0,0,0];
        private _weaponPos = _unit selectionPosition "weapon";
        
        if (_weaponPos isEqualTo [0,0,0]) then {
            // Fallback to neck position if weapon position is unavailable
            _muzzlePos = _unit modelToWorldVisual (_unit selectionPosition "neck");
        } else {
            _muzzlePos = _unit modelToWorldVisual _weaponPos;
        };
        
        // Skip drawing if position is invalid
        if (_muzzlePos isEqualTo [0,0,0]) exitWith {};
        
        // Draw target indicator
        drawIcon3D [
            "\a3\ui_f\data\IGUI\Cfg\Cursors\icon_radar_ca.paa",
            [1,0,0,1],
            ASLToAGL (AGLToASL _currentTargetPos),
            1.5,
            1.5,
            0,
            "",
            2,
            0.05,
            "PuristaMedium"
        ];
        
        // Draw spread circle to indicate accuracy area
        private _iterations = 12; // reduced to avoid excessive processing
        private _spreadRadius = missionNamespace getVariable ["SMGBURST_acuracyRange", 2];
        
        for "_i" from 0 to _iterations - 1 do {
            private _angle = _i * (360/_iterations);
            private _nextAngle = ((_i + 1) % _iterations) * (360/_iterations);
            
            private _x1 = (_spreadRadius * sin _angle);
            private _y1 = (_spreadRadius * cos _angle);
            private _x2 = (_spreadRadius * sin _nextAngle);
            private _y2 = (_spreadRadius * cos _nextAngle);
            
            private _pos1 = [
                (_currentTargetPos select 0) + _x1,
                (_currentTargetPos select 1) + _y1,
                (_currentTargetPos select 2)
            ];
            
            private _pos2 = [
                (_currentTargetPos select 0) + _x2,
                (_currentTargetPos select 1) + _y2,
                (_currentTargetPos select 2)
            ];
            
            drawLine3D [
                ASLToAGL (AGLToASL _pos1),
                ASLToAGL (AGLToASL _pos2),
                [1,0,0,0.7]
            ];
        };
        
        // Retrieve any active tracer lines to draw
        private _tracers = missionNamespace getVariable ["SMGBURST_activeTracers", []];
        {
            _x params ["_from", "_to", "_age", "_maxAge"];
            
            // Ensure we have valid positions
            if (!(_from isEqualTo [0,0,0]) && !(_to isEqualTo [0,0,0])) then {
                // Fade tracer based on age
                private _alpha = linearConversion [0, _maxAge, _age, 0.8, 0, true];
                private _color = [1, 0.5, 0, _alpha]; // Orange tracer that fades out
                
                // Draw the tracer line
                drawLine3D [
                    ASLToAGL (AGLToASL _from),
                    ASLToAGL (AGLToASL _to),
                    _color
                ];
            };
        } forEach _tracers;
    }];
    
    // Initialize tracers array
    SMGBURST_activeTracers = [];
    
    // Give the unit time to properly aim before firing
    systemChat "Unit is taking aim...";
    sleep SMGBURST_aimTime;
    
    if (!alive _unit) exitWith {
        systemChat "Unit died before firing!";
        SMGBURST_burstInProgress = false;
        setAccTime 1;
        removeMissionEventHandler ["Draw3D", _drawHandler];
    };
    
    // Execute the burst fire with improved aiming and continuous fire
    [_unit, _target, _finalTargetPos, _ammo, _drawHandler] spawn {
        params ["_unit", "_target", "_targetPos", "_ammo", "_drawHandler"];
        
        // Calculate rounds to fire (either all ammo or limited by burst duration)
        private _roundsToFire = _ammo min (SMGBURST_burstDuration * SMGBURST_shotsPerSecond);
        private _delayBetweenShots = 1 / SMGBURST_shotsPerSecond;
        
        systemChat format ["Beginning SMG Burst with %1 rounds!", _roundsToFire];
        
        // Try to set weapon to full auto mode if available
        private _weapon = currentWeapon _unit;
        if (_weapon != "") then {
            private _config = configFile >> "CfgWeapons" >> _weapon;
            if (isClass _config) then {
                private _modes = getArray (_config >> "modes");
                {
                    if (toLower _x in ["fullauto", "auto"]) exitWith {
                        _unit selectWeaponTurret [_weapon, [], _x];
                    };
                } forEach _modes;
            };
        };
        
        // Activate tracers array for visual effects
        SMGBURST_activeTracers = [];
        
        // Fire all rounds in the burst
        for "_i" from 1 to _roundsToFire do {
            // Exit if unit is dead
            if (!alive _unit) exitWith {
                SMGBURST_burstInProgress = false;
                setAccTime 1;
            };
            
            // Get current target position (may move if it's an object)
            private _currentTargetPos = if (!isNull _target) then {
                getPosATL _target
            } else {
                _targetPos
            };
            
            // Ensure unit keeps aiming at target throughout the burst
            if (!isNull _target && alive _target) then {
                _unit doTarget _target;
                _unit lookAt _target;
            } else {
                _unit doWatch _currentTargetPos;
                _unit lookAt _currentTargetPos;
            };
            
            // Add some randomness to shot trajectory
            private _spread = SMGBURST_acuracyRange;
            private _randomPos = [
                (_currentTargetPos select 0) + (random (_spread * 2) - _spread),
                (_currentTargetPos select 1) + (random (_spread * 2) - _spread),
                (_currentTargetPos select 2) + (random (_spread / 2) - (_spread / 4))
            ];
            
            // Face target and fire weapon
            _unit setDir ([_unit, _currentTargetPos] call BIS_fnc_dirTo);
            _unit forceWeaponFire [currentWeapon _unit, "Single"];
            
            // Add tracer effect
            private _muzzlePos = _unit modelToWorldVisual (_unit selectionPosition "weapon");
            if (_muzzlePos isEqualTo [0,0,0]) then {
                _muzzlePos = _unit modelToWorldVisual (_unit selectionPosition "neck");
            };
            
            if (!(_muzzlePos isEqualTo [0,0,0]) && !(_randomPos isEqualTo [0,0,0])) then {
                private _tracer = [_muzzlePos, _randomPos, 0, 0.5]; // [from, to, current age, max age]
                SMGBURST_activeTracers pushBack _tracer;
            };
            
            // Update tracer ages and remove old ones
            SMGBURST_activeTracers = SMGBURST_activeTracers apply {
                _x set [2, (_x select 2) + _delayBetweenShots]; // Increase age
                _x
            };
            
            // Remove tracers that have exceeded their max age
            SMGBURST_activeTracers = SMGBURST_activeTracers select {
                (_x select 2) < (_x select 3)
            };
            
            // Calculate if shot hits target
            if (!isNull _target && alive _target) then {
                private _distance = _unit distance _target;
                
                // Base hit chance that decreases with distance
                private _baseHitChance = SMGBURST_baseHitChance;
                private _distanceFactor = linearConversion [0, SMGBURST_maxDistance, _distance, 1, 0.5, true];
                private _stanceFactor = switch (stance _unit) do {
                    case "PRONE": { 1.2 };
                    case "CROUCH": { 1.1 };
                    default { 0.9 };
                };
                
                private _hitChance = _baseHitChance * _distanceFactor * _stanceFactor;
                
                // Apply damage if hit successful
                if (random 100 < _hitChance) then {
                    // Calculate damage (less with distance)
                    private _damageAmount = linearConversion [0, SMGBURST_maxDistance, _distance, 0.1, 0.05, true];
                    
                    // Apply damage
                    _target setDamage ((damage _target) + _damageAmount);
                    
                    // Create blood effect at the hit position
                    private _bloodEffect = "#particlesource" createVehicleLocal (getPos _target);
                    _bloodEffect setParticleClass "BulletImpactBlood";
                    _bloodEffect setPos _randomPos;
                    _bloodEffect setDropInterval 0.01;
                    
                    // Delete effect after a moment
                    [_bloodEffect] spawn {
                        params ["_effect"];
                        sleep 0.2;
                        deleteVehicle _effect;
                    };
                } else {
                    // Miss effect near the target
                    private _impactPos = _randomPos;
                    
                    // Create impact effect
                    private _impactEffect = "#particlesource" createVehicleLocal _impactPos;
                    _impactEffect setParticleClass "ImpactDust";
                    _impactEffect setPos _impactPos;
                    _impactEffect setDropInterval 0.01;
                    
                    // Delete effect after a moment
                    [_impactEffect] spawn {
                        params ["_effect"];
                        sleep 0.2;
                        deleteVehicle _effect;
                    };
                };
            };
            
            // Wait for next shot
            sleep _delayBetweenShots;
        };
        
        // Let tracers fade out
        sleep 0.5;
        
        // Reset accTime
        SMGBURST_burstInProgress = false;
        setAccTime 1;
        
        // Remove draw handler
        removeMissionEventHandler ["Draw3D", _drawHandler];
        
        // Reset unit state
        _unit enableAI "AUTOTARGET";
        _unit enableAI "FSM";
        _unit enableAI "MOVE";
        _unit doTarget objNull;
        _unit doWatch objNull;
        
        // Clear tracers
        SMGBURST_activeTracers = [];
        
        systemChat "SMG Burst complete!";
    };
};

// Main ability activation
params ["_unit"];

systemChat format ["%1 is preparing for an SMG Burst!", name _unit];
[] call fnc_resetSMGBurstState;

SMGBURST_active = true;
SMGBURST_shootingUnit = _unit;

// Set up Draw3D handler for target visualization
SMGBURST_drawHandler = addMissionEventHandler ["Draw3D", {
    if (!SMGBURST_active) exitWith {};
    
    SMGBURST_currentPos = screenToWorld getMousePosition;
    
    // If we have a selected target or position, draw indicators
    if (!isNull SMGBURST_target || count SMGBURST_targetPos > 0) then {
        private _targetPos = if (!isNull SMGBURST_target) then {
            getPosATL SMGBURST_target
        } else {
            SMGBURST_targetPos
        };
        
        // Draw targeting indicator
        drawIcon3D [
            "\a3\ui_f\data\IGUI\Cfg\Cursors\icon_radar_ca.paa",
            [1,0,0,1],
            ASLToAGL (AGLToASL _targetPos),
            2,
            2,
            0,
            "",
            2,
            0.05,
            "PuristaMedium"
        ];
        
        // Draw spread circle to indicate accuracy area
        private _iterations = 12; // reduced for better performance
        private _spreadRadius = SMGBURST_acuracyRange;
        
        for "_i" from 0 to _iterations - 1 do {
            private _angle = _i * (360/_iterations);
            private _nextAngle = ((_i + 1) % _iterations) * (360/_iterations);
            
            private _x1 = (_spreadRadius * sin _angle);
            private _y1 = (_spreadRadius * cos _angle);
            private _x2 = (_spreadRadius * sin _nextAngle);
            private _y2 = (_spreadRadius * cos _nextAngle);
            
            private _pos1 = [
                (_targetPos select 0) + _x1,
                (_targetPos select 1) + _y1,
                (_targetPos select 2)
            ];
            
            private _pos2 = [
                (_targetPos select 0) + _x2,
                (_targetPos select 1) + _y2,
                (_targetPos select 2)
            ];
            
            drawLine3D [
                ASLToAGL (AGLToASL _pos1),
                ASLToAGL (AGLToASL _pos2),
                [1,0,0,0.7]
            ];
        };
    } else {
        // Draw cursor for selection
        private _color = [1,1,1,0.7];
        
        drawIcon3D [
            "\a3\ui_f\data\IGUI\Cfg\Cursors\hc_move_ca.paa",
            _color,
            ASLToAGL (AGLToASL SMGBURST_currentPos),
            1,
            1,
            0,
            "",
            2,
            0.05,
            "PuristaMedium"
        ];
    };
    
    // Get unit and make sure it exists
    private _unit = SMGBURST_shootingUnit;
    if (isNull _unit) exitWith {};
    
    // Draw line from shooter to target
    private _unitPos = getPosASL _unit;
    private _targetPos = if (!isNull SMGBURST_target) then {
        AGLToASL (getPosATL SMGBURST_target)
    } else {
        if (count SMGBURST_targetPos > 0) then {
            AGLToASL SMGBURST_targetPos
        } else {
            AGLToASL SMGBURST_currentPos
        };
    };
    
    drawLine3D [
        ASLToAGL _unitPos,
        ASLToAGL _targetPos,
        [0.8,0.8,1,0.5]
    ];
    
    // Draw distance text
    private _distance = (_unitPos distance _targetPos);
    private _color = if (_distance <= SMGBURST_maxDistance) then {
        [0,1,0,1] // Green if in range
    } else {
        [1,0,0,1] // Red if out of range
    };
    
    private _midPoint = _unitPos vectorAdd ((_targetPos vectorDiff _unitPos) vectorMultiply 0.5);
    
    drawIcon3D [
        "",
        _color,
        ASLToAGL _midPoint,
        0,
        0,
        0,
        format ["%1m", round _distance],
        2,
        0.05,
        "PuristaMedium"
    ];
}];

// Set up time handler for slow motion
SMGBURST_timeHandler = addMissionEventHandler ["EachFrame", {
    if (SMGBURST_active) then {
        setAccTime SMGBURST_timeScale;
    };
}];

// Create UI
call fnc_createSMGBurstUI;

// Add key handler
private _display = findDisplay 312;
if (!isNull _display) then {
    SMGBURST_keyHandler = _display displayAddEventHandler ["KeyDown", {
        params ["_displayOrControl", "_key", "_shift", "_ctrl", "_alt"];
        
        if (SMGBURST_active) then {
            // Space key - Mark target
            if (_key == 57) then {
                systemChat "Space pressed - Selecting target";
                
                // Get object under cursor
                private _cursorData = curatorMouseOver;
                
                if (_cursorData select 0 == "OBJECT") then {
                    private _target = _cursorData select 1;
                    
                    // Ensure target is valid
                    if (!isNull _target) then {
                        private _distance = _target distance SMGBURST_shootingUnit;
                        
                        // Check range
                        if (_distance > SMGBURST_maxDistance) then {
                            systemChat format ["Target too far! Maximum range is %1m", SMGBURST_maxDistance];
                            hint parseText format [
                                "<t size='1.2' color='#ff6666'>Target Too Far</t><br/><br/>Maximum range is %1m<br/>Current distance: %2m",
                                SMGBURST_maxDistance, round _distance
                            ];
                        } else {
                            SMGBURST_target = _target;
                            SMGBURST_targetPos = []; // Clear position target
                            
                            systemChat format ["Target selected: %1 at distance %2m", 
                                if (_target isKindOf "CAManBase") then {name _target} else {typeOf _target}, 
                                round _distance
                            ];
                            
                            // Update target info
                            [_target] call fnc_updateTargetInfo;
                            
                            // Show confirm button
                            private _confirmBtn = uiNamespace getVariable ["SMGBURST_confirmBtn", controlNull];
                            if (!isNull _confirmBtn) then {
                                _confirmBtn ctrlShow true;
                            };
                        };
                    };
                } else {
                    // No object selected, use position
                    private _pos = screenToWorld getMousePosition;
                    private _distance = _pos distance SMGBURST_shootingUnit;
                    
                    // Check range
                    if (_distance > SMGBURST_maxDistance) then {
                        systemChat format ["Position too far! Maximum range is %1m", SMGBURST_maxDistance];
                        hint parseText format [
                            "<t size='1.2' color='#ff6666'>Position Too Far</t><br/><br/>Maximum range is %1m<br/>Current distance: %2m",
                            SMGBURST_maxDistance, round _distance
                        ];
                    } else {
                        SMGBURST_target = objNull; // Clear object target
                        SMGBURST_targetPos = _pos;
                        
                        systemChat format ["Position marked at distance %1m", round _distance];
                        
                        // Update target info
                        [objNull, _pos] call fnc_updateTargetInfo;
                        
                        // Show confirm button
                        private _confirmBtn = uiNamespace getVariable ["SMGBURST_confirmBtn", controlNull];
                        if (!isNull _confirmBtn) then {
                            _confirmBtn ctrlShow true;
                        };
                    };
                };
                
                true
            };
            
            // Enter key - Confirm
            if (_key == 28) then {
                if (!isNull SMGBURST_target || count SMGBURST_targetPos > 0) then {
                    [] call fnc_executeSMGBurst;
                    true
                };
            };
            
            // Backspace key - Cancel
            if (_key == 14) then {
                [] call fnc_resetSMGBurstState;
                systemChat "SMG Burst cancelled";
                true
            };
        };
        
        false
    }];
};

systemChat "SMG Burst ability activated - SPACE to select target | ENTER to confirm | BACKSPACE to cancel";