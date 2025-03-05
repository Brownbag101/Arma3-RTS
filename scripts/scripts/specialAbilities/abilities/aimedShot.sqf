// Initialize global variables
if (isNil "AIMEDSHOT_active") then { AIMEDSHOT_active = false; };
if (isNil "AIMEDSHOT_targets") then { AIMEDSHOT_targets = []; };
if (isNil "AIMEDSHOT_markerCount") then { AIMEDSHOT_markerCount = 0; };
if (isNil "AIMEDSHOT_shootingUnit") then { AIMEDSHOT_shootingUnit = objNull; };
if (isNil "AIMEDSHOT_timeScale") then { AIMEDSHOT_timeScale = 0.1; };
if (isNil "AIMEDSHOT_keyHandler") then { AIMEDSHOT_keyHandler = -1; };
if (isNil "AIMEDSHOT_timeHandler") then { AIMEDSHOT_timeHandler = -1; };
if (isNil "AIMEDSHOT_shotHandler") then { AIMEDSHOT_shotHandler = -1; };
if (isNil "AIMEDSHOT_drawHandler") then { AIMEDSHOT_drawHandler = -1; };
if (isNil "AIMEDSHOT_currentPos") then { AIMEDSHOT_currentPos = [0,0,0]; };
if (isNil "AIMEDSHOT_selectedPos") then { AIMEDSHOT_selectedPos = []; };

// Function to ensure proper activation state
fnc_resetAimedShotState = {
    systemChat "Resetting aimed shot state...";
    
    AIMEDSHOT_active = false;
    AIMEDSHOT_targets = [];
    AIMEDSHOT_markerCount = 0;
    AIMEDSHOT_selectedPos = [];
    
    // Remove handlers
    if (AIMEDSHOT_keyHandler != -1) then {
        (findDisplay 312) displayRemoveEventHandler ["KeyDown", AIMEDSHOT_keyHandler];
        AIMEDSHOT_keyHandler = -1;
    };
    
    if (AIMEDSHOT_timeHandler != -1) then {
        removeMissionEventHandler ["EachFrame", AIMEDSHOT_timeHandler];
        AIMEDSHOT_timeHandler = -1;
    };
    
    if (AIMEDSHOT_shotHandler != -1) then {
        removeMissionEventHandler ["EachFrame", AIMEDSHOT_shotHandler];
        AIMEDSHOT_shotHandler = -1;
    };
    
    if (AIMEDSHOT_drawHandler != -1) then {
        removeMissionEventHandler ["Draw3D", AIMEDSHOT_drawHandler];
        AIMEDSHOT_drawHandler = -1;
    };
    
    // Reset time
    setAccTime 1;
    
    [] call fnc_cleanupAimedShotUI;
    
    systemChat "State reset complete";
};

// Create target marker
fnc_createTargetMarker = {
    params ["_pos", ["_target", objNull]];
    
    private _markerName = format ["aimedshot_target_%1", AIMEDSHOT_markerCount];
    private _marker = createMarker [_markerName, _pos];
    _marker setMarkerType "mil_destroy";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerSize [1, 1];
    
    private _distance = _pos distance AIMEDSHOT_shootingUnit;
    private _hitChance = 75; // Default hit chance, could be calculated based on distance/conditions
    
    _marker setMarkerText format ["%1%2", round _hitChance, "%"];
    
    AIMEDSHOT_targets = [[_markerName, _target, _pos, _hitChance]];
    AIMEDSHOT_markerCount = AIMEDSHOT_markerCount + 1;
    
    private _targetInfo = uiNamespace getVariable ["AIMEDSHOT_targetInfo", controlNull];
    if (!isNull _targetInfo) then {
        // Calculate more detailed hit chance based on distance and conditions
    private _baseHitChance = _hitChance;
    private _distanceModifier = switch true do {
        case (_distance < 100): { 1.0 };
        case (_distance < 200): { 0.9 };
        case (_distance < 300): { 0.8 };
        case (_distance < 400): { 0.7 };
        default { 0.6 };
    };
    
    private _stanceModifier = switch (stance AIMEDSHOT_shootingUnit) do {
        case "PRONE": { 1.1 };
        case "CROUCH": { 1.0 };
        default { 0.9 };
    };
    
    private _finalHitChance = (_baseHitChance * _distanceModifier * _stanceModifier) min 95;
    
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
};

// UI Creation function
fnc_createAimedShotUI = {
    private _display = findDisplay 312;
    private _controls = [];
    
    // Create overlay
    private _overlay = _display ctrlCreate ["RscText", -1];
    _overlay ctrlSetPosition [safezoneX, safezoneY, safezoneW, safezoneH];
    _overlay ctrlSetBackgroundColor [0, 0.1, 0.2, 0.3];
    _overlay ctrlCommit 0;
    _controls pushBack _overlay;
    
    // Create info text
    private _infoText = _display ctrlCreate ["RscStructuredText", -1];
    _infoText ctrlSetPosition [safezoneX + (safezoneW * 0.3), safezoneY + (safezoneH * 0.1), safezoneW * 0.4, safezoneH * 0.1];
    _infoText ctrlSetStructuredText parseText "<t align='center' size='1.2'>AIMED SHOT ACTIVE<br/>SPACE to mark target | ENTER to confirm | BACKSPACE to cancel</t>";
    _infoText ctrlCommit 0;
    _controls pushBack _infoText;
    
    // Create target info display with background
    private _targetInfoBG = _display ctrlCreate ["RscText", -1];
    _targetInfoBG ctrlSetPosition [safezoneX + (safezoneW * 0.4), safezoneY + (safezoneH * 0.2), safezoneW * 0.2, safezoneH * 0.15];
    _targetInfoBG ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _targetInfoBG ctrlCommit 0;
    _controls pushBack _targetInfoBG;
    
    private _targetInfo = _display ctrlCreate ["RscStructuredText", -1];
    _targetInfo ctrlSetPosition [safezoneX + (safezoneW * 0.4), safezoneY + (safezoneH * 0.2), safezoneW * 0.2, safezoneH * 0.15];
    _targetInfo ctrlSetBackgroundColor [0, 0, 0, 0];
    _targetInfo ctrlSetStructuredText parseText "";
    _targetInfo ctrlCommit 0;
    _controls pushBack _targetInfo;
    
    systemChat "Created target info control";
    
    // Create confirm button
    private _confirmBtn = _display ctrlCreate ["RscButton", -1];
    _confirmBtn ctrlSetPosition [safezoneX + (safezoneW * 0.45), safezoneY + (safezoneH * 0.36), safezoneW * 0.1, safezoneH * 0.04];
    _confirmBtn ctrlSetText "CONFIRM SHOT";
    _confirmBtn ctrlSetBackgroundColor [0.2, 0.6, 0.2, 0.8];
    _confirmBtn ctrlAddEventHandler ["ButtonClick", {
        if (count AIMEDSHOT_targets > 0) then {
            private _confirmBtn = uiNamespace getVariable ["AIMEDSHOT_confirmBtn", controlNull];
            if (!isNull _confirmBtn) then {
                _confirmBtn ctrlShow false;
            };
            [] call fnc_executeAimedShot;
        };
    }];
    _confirmBtn ctrlCommit 0;
    _controls pushBack _confirmBtn;
    
    // Store controls in UI namespace
    uiNamespace setVariable ["AIMEDSHOT_controls", _controls];
    uiNamespace setVariable ["AIMEDSHOT_targetInfo", _targetInfo];
    uiNamespace setVariable ["AIMEDSHOT_confirmBtn", _confirmBtn];
};

// Cleanup UI function
fnc_cleanupAimedShotUI = {
    {
        ctrlDelete _x;
    } forEach (uiNamespace getVariable ["AIMEDSHOT_controls", []]);
    
    {
        _x params ["_markerName"];
        if (markerType _markerName != "") then {
            deleteMarker _markerName;
        };
    } forEach AIMEDSHOT_targets;
    
    uiNamespace setVariable ["AIMEDSHOT_controls", []];
    uiNamespace setVariable ["AIMEDSHOT_targetInfo", controlNull];
    uiNamespace setVariable ["AIMEDSHOT_confirmBtn", controlNull];
};

// Execute the aimed shot
fnc_executeAimedShot = {
    if (count AIMEDSHOT_targets > 0) then {
        private _target = AIMEDSHOT_targets select 0;
        _target params ["_markerName", "_target", "_pos", "_hitChance"];
        
        if (isNull _target) exitWith {
            systemChat "No valid target selected";
            [] call fnc_resetAimedShotState;
        };
        
        systemChat "Moving into position...";
        
        private _originalPos = unitPos AIMEDSHOT_shootingUnit;
        private _startTime = time;
        private _phase = 0;
        private _isAimed = false;
        
        // Prepare unit for shot
        AIMEDSHOT_shootingUnit disableAI "AUTOTARGET";
        AIMEDSHOT_shootingUnit disableAI "FSM";
        AIMEDSHOT_shootingUnit disableAI "MOVE";
        AIMEDSHOT_shootingUnit disableAI "TARGET";
        
        AIMEDSHOT_shootingUnit setUnitPos "UP";
        
        // Force immediate facing regardless of target type
        private _targetPos = if (isNull _target) then { _pos } else { getPosATL _target };
        AIMEDSHOT_shootingUnit setDir ([AIMEDSHOT_shootingUnit, _targetPos] call BIS_fnc_dirTo);
        AIMEDSHOT_shootingUnit doWatch _targetPos;
        
        // Set targeting based on target type
        if (!isNull _target) then {
            AIMEDSHOT_shootingUnit doTarget _target;
        } else {
            AIMEDSHOT_shootingUnit doWatch _targetPos;
        };
        
        AIMEDSHOT_shootingUnit selectWeapon (primaryWeapon AIMEDSHOT_shootingUnit);
        AIMEDSHOT_shootingUnit setCombatMode "RED";
        
        // Force weapon ready stance
        AIMEDSHOT_shootingUnit action ["WeaponOnBack", AIMEDSHOT_shootingUnit];
        AIMEDSHOT_shootingUnit action ["SwitchWeapon", AIMEDSHOT_shootingUnit, AIMEDSHOT_shootingUnit, 0];
        
        private _weapon = currentWeapon AIMEDSHOT_shootingUnit;
        if (_weapon == "") exitWith {
            systemChat "No weapon available";
            [] call fnc_resetAimedShotState;
        };
        
        private _ammo = AIMEDSHOT_shootingUnit ammo _weapon;
        if (_ammo == 0) exitWith {
            systemChat "No ammunition!";
            [] call fnc_resetAimedShotState;
        };
        
        // Create new shoot button
        private _display = findDisplay 312;
        private _shootBtn = _display ctrlCreate ["RscButton", -1];
        _shootBtn ctrlSetPosition [safezoneX + (safezoneW * 0.45), safezoneY + (safezoneH * 0.36), safezoneW * 0.1, safezoneH * 0.04];
        _shootBtn ctrlSetText "TAKE SHOT";
        _shootBtn ctrlSetBackgroundColor [0.7, 0.2, 0.2, 0.8];
        _shootBtn ctrlShow false;  // Hide initially until aimed
        _shootBtn ctrlCommit 0;
        
        AIMEDSHOT_shotHandler = addMissionEventHandler ["EachFrame", {
            params ["_thisEventHandler"];
            private _elapsed = time - (_thisArgs select 0);
            private _phase = _thisArgs select 1;
            private _target = _thisArgs select 2;
            private _hitChance = _thisArgs select 3;
            private _originalPos = _thisArgs select 4;
            private _shootBtn = _thisArgs select 5;
            private _isAimed = _thisArgs select 6;
            
            switch (_phase) do {
                case 0: {
                    // Aiming phase
                    if (_elapsed > 1.0 && !_isAimed) then {
                        systemChat "Ready to take shot!";
                        _shootBtn ctrlShow true;
                        _thisArgs set [6, true];  // Set aimed flag
                        
                        // Add click handler for shoot button
                        _shootBtn ctrlAddEventHandler ["ButtonClick", {
                            params ["_ctrl"];
                            _ctrl ctrlShow false;
                            
                            // Take the shot
                            private _target = (_this select 0) getVariable ["target", objNull];
                            private _hitChance = (_this select 0) getVariable ["hitChance", 75];
                            
                            AIMEDSHOT_shootingUnit forceWeaponFire [currentWeapon AIMEDSHOT_shootingUnit, "Single"];
                            
                            if (random 100 < _hitChance) then {
                                _target setDamage ((damage _target) + 0.8);
                                systemChat format ["Hit on %1!", if (_target isKindOf "CAManBase") then {name _target} else {typeOf _target}];
                            } else {
                                systemChat "Shot missed!";
                            };
                            
                            // Immediate cleanup
                            AIMEDSHOT_active = false;
                            AIMEDSHOT_shootingUnit enableAI "AUTOTARGET";
                            AIMEDSHOT_shootingUnit enableAI "FSM";
                            AIMEDSHOT_shootingUnit enableAI "MOVE";
                            AIMEDSHOT_shootingUnit doTarget objNull;
                            AIMEDSHOT_shootingUnit doWatch objNull;
                            
                            [] call fnc_resetAimedShotState;
                            systemChat "Ability complete";
                        }];
                        
                        // Store variables needed for the button click
                        _shootBtn setVariable ["target", _target];
                        _shootBtn setVariable ["hitChance", _hitChance];
                        _shootBtn setVariable ["phase", _thisArgs select 1];
                        
                        _thisArgs set [1, 1];  // Move to hold phase
                    };
                };
                case 1: {
                    // Hold aim and wait for player shot
                    AIMEDSHOT_shootingUnit doTarget _target;
                    
                    // Check if phase was changed by button click
                    if (_shootBtn getVariable ["phase", 1] == 2) then {
                        _thisArgs set [1, 2];  // Move to cleanup
                    };
                };
                case 2: {
                    if (_elapsed > (_thisArgs select 7)) then {
                        // Reset unit
                        AIMEDSHOT_shootingUnit enableAI "AUTOTARGET";
                        AIMEDSHOT_shootingUnit enableAI "FSM";
                        AIMEDSHOT_shootingUnit enableAI "MOVE";
                        
                        AIMEDSHOT_shootingUnit doTarget objNull;
                        AIMEDSHOT_shootingUnit doWatch objNull;
                        AIMEDSHOT_shootingUnit setUnitPos _originalPos;
                        
                        ctrlDelete _shootBtn;
                        [] call fnc_resetAimedShotState;
                        
                        systemChat "Ability complete";
                        
                        removeMissionEventHandler ["EachFrame", _thisEventHandler];
                    };
                };
            };
        }, [_startTime, _phase, _target, _hitChance, _originalPos, _shootBtn, _isAimed, time + 0.5]];
    };
};

// Main ability activation
params ["_unit"];

systemChat format ["Attempting to activate ability for unit: %1", name _unit];
[] call fnc_resetAimedShotState;

AIMEDSHOT_active = true;
AIMEDSHOT_shootingUnit = _unit;

// Set up Draw3D handler for crosshair
AIMEDSHOT_drawHandler = addMissionEventHandler ["Draw3D", {
    if (AIMEDSHOT_active) then {
        AIMEDSHOT_currentPos = screenToWorld getMousePosition;
        
        // If we have a selected position, draw the crosshair there
        if (count AIMEDSHOT_selectedPos > 0) then {
            private _pos = AIMEDSHOT_selectedPos;
            
            // Draw main targeting reticle
            drawIcon3D [
                "\a3\ui_f\data\IGUI\Cfg\Targeting\targetingM_ca.paa",
                [1,1,1,1],    // White
                ASLToAGL (AGLToASL _pos),
                2,
                2,
                45,
                "",
                2,
                0.05,
                "PuristaMedium"
            ];
            
            // Draw cross marker
            drawIcon3D [
                "\a3\ui_f\data\Map\MarkerBrushes\cross_ca.paa",
                [1,0,0,1],    // Red
                ASLToAGL (AGLToASL _pos vectorAdd [0,0,0.1]),
                1,
                1,
                0,
                "",
                2,
                0.05,
                "PuristaMedium"
            ];
        };
        
        // Optional: Draw distance line from shooter to target
        if (count AIMEDSHOT_targets == 0) then {
            private _shooterPos = getPosASL AIMEDSHOT_shootingUnit;
            private _targetPos = AGLToASL AIMEDSHOT_currentPos;
            if (!isNil "_shooterPos" && !isNil "_targetPos") then {
                drawLine3D [
                    ASLToAGL _shooterPos,
                    ASLToAGL _targetPos,
                    [0.8,0.8,1,0.5]
                ];
            };
        };
    };
}];

// Set up time handler
AIMEDSHOT_timeHandler = addMissionEventHandler ["EachFrame", {
    if (AIMEDSHOT_active) then {
        setAccTime AIMEDSHOT_timeScale;
    };
}];

[] call fnc_createAimedShotUI;

// Add key handler
private _display = findDisplay 312;
AIMEDSHOT_keyHandler = _display displayAddEventHandler ["KeyDown", {
    params ["_displayOrControl", "_key", "_shift", "_ctrl", "_alt"];
    
    if (AIMEDSHOT_active) then {
        // Space key - Mark target
        if (_key == 57) then {
            systemChat "Space pressed - Marking target position";
            
            if (count AIMEDSHOT_targets == 0) then {
                private _cursorData = curatorMouseOver;
                private _target = objNull;
                private _pos = AIMEDSHOT_currentPos;
                AIMEDSHOT_selectedPos = _pos;  // Store the selected position
                
                if (_cursorData select 0 == "OBJECT") then {
                    _target = _cursorData select 1;
                    _pos = getPos _target;
                };
                
                [_pos, _target] call fnc_createTargetMarker;
            };
            true
        };
        
        // Enter key - Confirm shot
        if (_key == 28) then {
            if (count AIMEDSHOT_targets > 0) then {
                private _confirmBtn = uiNamespace getVariable ["AIMEDSHOT_confirmBtn", controlNull];
                if (!isNull _confirmBtn) then {
                    _confirmBtn ctrlShow false;
                };
                [] call fnc_executeAimedShot;
            };
            true
        };
        
        // Backspace key - Cancel
        if (_key == 14) then {
            [] call fnc_resetAimedShotState;
            systemChat "Aimed Shot cancelled";
            true
        };
    };
    false
}];

systemChat "Aimed Shot activated - SPACE to mark target | ENTER to confirm | BACKSPACE to cancel";