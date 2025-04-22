// scripts/specialAbilities/abilities/fireAtPosition.sqf
// Initialize global variables if they don't exist
if (isNil "FIREATP_active") then { FIREATP_active = false; };
if (isNil "FIREATP_targets") then { FIREATP_targets = []; };
if (isNil "FIREATP_markerCount") then { FIREATP_markerCount = 0; };
if (isNil "FIREATP_shootingVehicle") then { FIREATP_shootingVehicle = objNull; };
if (isNil "FIREATP_timeScale") then { FIREATP_timeScale = 0.1; };
if (isNil "FIREATP_keyHandler") then { FIREATP_keyHandler = -1; };
if (isNil "FIREATP_timeHandler") then { FIREATP_timeHandler = -1; };
if (isNil "FIREATP_shotHandler") then { FIREATP_shotHandler = -1; };
if (isNil "FIREATP_drawHandler") then { FIREATP_drawHandler = -1; };
if (isNil "FIREATP_currentPos") then { FIREATP_currentPos = [0,0,0]; };
if (isNil "FIREATP_selectedPos") then { FIREATP_selectedPos = []; };
if (isNil "FIREATP_selectedAmmo") then { FIREATP_selectedAmmo = ""; };
if (isNil "FIREATP_roundCount") then { FIREATP_roundCount = 1; };

// Function to ensure proper activation state
fnc_resetFireAtPositionState = {
    systemChat "Resetting fire at position state...";
    
    FIREATP_active = false;
    FIREATP_targets = [];
    FIREATP_markerCount = 0;
    FIREATP_selectedPos = [];
    FIREATP_selectedAmmo = "";
    FIREATP_roundCount = 1;
    
    // Remove handlers
    if (FIREATP_keyHandler != -1) then {
        (findDisplay 312) displayRemoveEventHandler ["KeyDown", FIREATP_keyHandler];
        FIREATP_keyHandler = -1;
    };
    
    if (FIREATP_timeHandler != -1) then {
        removeMissionEventHandler ["EachFrame", FIREATP_timeHandler];
        FIREATP_timeHandler = -1;
    };
    
    if (FIREATP_shotHandler != -1) then {
        removeMissionEventHandler ["EachFrame", FIREATP_shotHandler];
        FIREATP_shotHandler = -1;
    };
    
    if (FIREATP_drawHandler != -1) then {
        removeMissionEventHandler ["Draw3D", FIREATP_drawHandler];
        FIREATP_drawHandler = -1;
    };
    
    // Reset time
    setAccTime 1;
    
    [] call fnc_cleanupFireAtPositionUI;
    
    systemChat "State reset complete";
};

// Create target marker
fnc_createTargetMarker = {
    params ["_pos", ["_target", objNull]];
    
    private _markerName = format ["fireatp_target_%1", FIREATP_markerCount];
    private _marker = createMarker [_markerName, _pos];
    _marker setMarkerType "mil_destroy";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerSize [1, 1];
    
    private _distance = _pos distance FIREATP_shootingVehicle;
    
    FIREATP_targets = [[_markerName, objNull, _pos]];
    FIREATP_markerCount = FIREATP_markerCount + 1;
    
    private _targetInfo = uiNamespace getVariable ["FIREATP_targetInfo", controlNull];
    if (!isNull _targetInfo) then {
        // Fix the structured text format
        private _text = format [
            "<t size='1.1'>Target: Position</t><br/>" +
            "<t color='#ADD8E6'>Distance: %1m</t><br/>" +
            "<t color='#90EE90'>Rounds: %2 x %3</t>",
            round _distance,
            FIREATP_roundCount,
            if (FIREATP_selectedAmmo != "") then {FIREATP_selectedAmmo} else {"Not Selected"}
        ];
        
        // Use try-catch to handle potential formatting errors
        try {
            _targetInfo ctrlSetStructuredText parseText _text;
        } catch {
            // Fallback to a simpler text format if error occurs
            _targetInfo ctrlSetStructuredText parseText format ["Target Position: %1m away", round _distance];
            systemChat "Warning: Error in structured text formatting";
        };
    };
};


// Completely redesigned UI with proper horizontal alignment
fnc_createFireAtPositionUI = {
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
    _infoText ctrlSetStructuredText parseText "<t align='center' size='1.2'>FIRE AT POSITION ACTIVE<br/>SPACE to mark target | ENTER to confirm | BACKSPACE to cancel</t>";
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
    
    // Create ammo selection group
    private _ammoBG = _display ctrlCreate ["RscText", -1];
    _ammoBG ctrlSetPosition [safezoneX + (safezoneW * 0.35), safezoneY + (safezoneH * 0.4), safezoneW * 0.3, safezoneH * 0.15];
    _ammoBG ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _ammoBG ctrlCommit 0;
    _controls pushBack _ammoBG;
    
    private _ammoTitle = _display ctrlCreate ["RscText", -1];
    _ammoTitle ctrlSetPosition [safezoneX + (safezoneW * 0.35), safezoneY + (safezoneH * 0.4), safezoneW * 0.3, safezoneH * 0.03];
    _ammoTitle ctrlSetText "SELECT AMMUNITION TYPE";
    _ammoTitle ctrlSetBackgroundColor [0.2, 0.2, 0.3, 0.8];
    _ammoTitle ctrlCommit 0;
    _controls pushBack _ammoTitle;
    
    // Get available ammunition types for this vehicle
    private _vehicle = FIREATP_shootingVehicle;
    private _currentWeapon = currentWeapon _vehicle;
    private _ammoTypes = [];
    
    // Get weapon info and muzzles
    private _allTurrets = allTurrets [_vehicle, true];
    {
        private _turretWeapons = _vehicle weaponsTurret _x;
        {
            private _weapon = _x;
            private _weaponName = getText (configFile >> "CfgWeapons" >> _weapon >> "displayName");
            
            // Get all muzzles for this weapon
            private _muzzles = getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
            if (count _muzzles == 0) then { _muzzles = [_weapon]; };
            
            {
                private _muzzle = _x;
                private _displayName = _weaponName;
                
                if (_muzzle != _weapon) then {
                    _displayName = getText (configFile >> "CfgWeapons" >> _weapon >> _muzzle >> "displayName");
                    if (_displayName == "") then {
                        _displayName = format ["%1 (%2)", _weaponName, _muzzle];
                    };
                };
                
                _ammoTypes pushBack [_weapon, _muzzle, _displayName];
            } forEach _muzzles;
        } forEach _turretWeapons;
    } forEach [[]] + _allTurrets;
    
    // Create buttons for ammunition types
    private _buttonCount = count _ammoTypes;
    private _buttonHeight = 0.03;
    private _buttonY = safezoneY + (safezoneH * 0.43);
    
    for "_i" from 0 to ((_buttonCount - 1) min 5) do {
        private _ammoData = _ammoTypes select _i;
        _ammoData params ["_weapon", "_muzzle", "_displayName"];
        
        private _ammoBtn = _display ctrlCreate ["RscButton", -1];
        _ammoBtn ctrlSetPosition [
            safezoneX + (safezoneW * 0.36),
            _buttonY + (_i * (_buttonHeight + 0.005)),
            safezoneW * 0.28,
            safezoneH * _buttonHeight
        ];
        _ammoBtn ctrlSetText _displayName;
        _ammoBtn ctrlSetBackgroundColor [0.2, 0.2, 0.2, 0.8];
        
        _ammoBtn ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _data = _ctrl getVariable "ammoData";
            _data params ["_weapon", "_muzzle", "_displayName"];
            
            // Set as selected ammo
            FIREATP_selectedAmmo = _muzzle;
            FIREATP_selectedWeapon = _weapon;
            
            // Update all button colors
            {
                if (_x getVariable ["isAmmoButton", false]) then {
                    _x ctrlSetBackgroundColor [0.2, 0.2, 0.2, 0.8];
                };
            } forEach (uiNamespace getVariable ["FIREATP_controls", []]);
            
            // Highlight this button
            _ctrl ctrlSetBackgroundColor [0.2, 0.5, 0.2, 0.8];
            
            // Update target info if target is selected
            if (count FIREATP_targets > 0) then {
                private _targetInfo = uiNamespace getVariable ["FIREATP_targetInfo", controlNull];
                if (!isNull _targetInfo) then {
                    private _target = FIREATP_targets select 0;
                    _target params ["_markerName", "_dummy", "_pos"];
                    private _distance = _pos distance FIREATP_shootingVehicle;
                    
                    private _text = format [
                        "<t size='1.1'>Target: Position</t><br/>" +
                        "<t color='#ADD8E6'>Distance: %1m</t><br/>" +
                        "<t color='#90EE90'>Rounds: %2 x %3</t>",
                        round _distance,
                        FIREATP_roundCount,
                        _displayName
                    ];
                    
                    _targetInfo ctrlSetStructuredText parseText _text;
                };
            };
        }];
        
        _ammoBtn setVariable ["ammoData", _ammoData];
        _ammoBtn setVariable ["isAmmoButton", true];
        _ammoBtn ctrlCommit 0;
        _controls pushBack _ammoBtn;
    };
    
    // Create round count selector
    private _roundLabel = _display ctrlCreate ["RscText", -1];
    _roundLabel ctrlSetPosition [
        safezoneX + (safezoneW * 0.35),
        safezoneY + (safezoneH * 0.57),
        safezoneW * 0.3,
        safezoneH * 0.03
    ];
    _roundLabel ctrlSetText "NUMBER OF ROUNDS:";
    _roundLabel ctrlSetBackgroundColor [0.2, 0.2, 0.3, 0.8];
    _roundLabel ctrlCommit 0;
    _controls pushBack _roundLabel;
    
    private _roundBG = _display ctrlCreate ["RscText", -1];
    _roundBG ctrlSetPosition [
        safezoneX + (safezoneW * 0.35),
        safezoneY + (safezoneH * 0.6),
        safezoneW * 0.3,
        safezoneH * 0.04
    ];
    _roundBG ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _roundBG ctrlCommit 0;
    _controls pushBack _roundBG;
    
    private _roundSlider = _display ctrlCreate ["RscSlider", -1];
    _roundSlider ctrlSetPosition [
        safezoneX + (safezoneW * 0.36),
        safezoneY + (safezoneH * 0.605),
        safezoneW * 0.22,
        safezoneH * 0.03
    ];
    _roundSlider sliderSetRange [1, 10];
    _roundSlider sliderSetPosition 1;
    _roundSlider ctrlCommit 0;
    _controls pushBack _roundSlider;
    
    private _roundText = _display ctrlCreate ["RscText", -1];
    _roundText ctrlSetPosition [
        safezoneX + (safezoneW * 0.585),
        safezoneY + (safezoneH * 0.605),
        safezoneW * 0.05,
        safezoneH * 0.03
    ];
    _roundText ctrlSetText "1";
    _roundText ctrlCommit 0;
    _controls pushBack _roundText;
    
    _roundSlider ctrlAddEventHandler ["SliderPosChanged", {
        params ["_control", "_newValue"];
        private _roundText = _control getVariable "roundText";
        private _roundCount = round _newValue;
        _roundText ctrlSetText str _roundCount;
        
        // Update global variable
        FIREATP_roundCount = _roundCount;
        
        // Update target info if target is selected
        if (count FIREATP_targets > 0) then {
            private _targetInfo = uiNamespace getVariable ["FIREATP_targetInfo", controlNull];
            if (!isNull _targetInfo) then {
                private _target = FIREATP_targets select 0;
                _target params ["_markerName", "_dummy", "_pos"];
                private _distance = _pos distance FIREATP_shootingVehicle;
                
                // Get ammo display name
                private _displayName = FIREATP_selectedAmmo;
                {
                    if (_x getVariable ["isAmmoButton", false]) then {
                        private _btnData = _x getVariable ["ammoData", []];
                        if (count _btnData > 0) then {
                            _btnData params ["_weapon", "_muzzle", "_ammoName"];
                            if (_muzzle == FIREATP_selectedAmmo) then {
                                _displayName = _ammoName;
                            };
                        };
                    };
                } forEach (uiNamespace getVariable ["FIREATP_controls", []]);
                
                private _text = format [
                    "<t size='1.1'>Target: Position</t><br/>" +
                    "<t color='#ADD8E6'>Distance: %1m</t><br/>" +
                    "<t color='#90EE90'>Rounds: %2 x %3</t>",
                    round _distance,
                    _roundCount,
                    _displayName
                ];
                
                _targetInfo ctrlSetStructuredText parseText _text;
            };
        };
    }];
    _roundSlider setVariable ["roundText", _roundText];
    
    // Create confirm button
    private _confirmBtn = _display ctrlCreate ["RscButton", -1];
    _confirmBtn ctrlSetPosition [safezoneX + (safezoneW * 0.45), safezoneY + (safezoneH * 0.66), safezoneW * 0.1, safezoneH * 0.04];
    _confirmBtn ctrlSetText "FIRE";
    _confirmBtn ctrlSetBackgroundColor [0.7, 0.2, 0.2, 0.8];
    _confirmBtn ctrlAddEventHandler ["ButtonClick", {
        if (count FIREATP_targets > 0 && FIREATP_selectedAmmo != "") then {
            private _confirmBtn = uiNamespace getVariable ["FIREATP_confirmBtn", controlNull];
            if (!isNull _confirmBtn) then {
                _confirmBtn ctrlShow false;
            };
            [] call fnc_executeFireAtPosition;
        } else {
            if (FIREATP_selectedAmmo == "") then {
                systemChat "Please select an ammunition type";
            } else {
                systemChat "Please select a target position";
            };
        };
    }];
    _confirmBtn ctrlCommit 0;
    _controls pushBack _confirmBtn;
    
    // Store controls in UI namespace
    uiNamespace setVariable ["FIREATP_controls", _controls];
    uiNamespace setVariable ["FIREATP_targetInfo", _targetInfo];
    uiNamespace setVariable ["FIREATP_confirmBtn", _confirmBtn];
};

// Cleanup UI function
fnc_cleanupFireAtPositionUI = {
    {
        ctrlDelete _x;
    } forEach (uiNamespace getVariable ["FIREATP_controls", []]);
    
    {
        _x params ["_markerName"];
        if (markerType _markerName != "") then {
            deleteMarker _markerName;
        };
    } forEach FIREATP_targets;
    
    uiNamespace setVariable ["FIREATP_controls", []];
    uiNamespace setVariable ["FIREATP_targetInfo", controlNull];
    uiNamespace setVariable ["FIREATP_confirmBtn", controlNull];
};

// Improved firing mechanism
fnc_executeFireAtPosition = {
    if (count FIREATP_targets > 0 && FIREATP_selectedAmmo != "") then {
        private _target = FIREATP_targets select 0;
        _target params ["_markerName", "_dummy", "_pos"];
        
        if (isNil "_pos") exitWith {
            systemChat "No valid target position selected";
            [] call fnc_resetFireAtPositionState;
        };
        
        private _vehicle = FIREATP_shootingVehicle;
        private _weapon = FIREATP_selectedWeapon;
        private _muzzle = FIREATP_selectedAmmo;
        private _roundCount = FIREATP_roundCount;
        
        // Save target position globally
        missionNamespace setVariable ["FIREATP_lastTargetPos", _pos];
        
        // Reset time to normal immediately
        setAccTime 1;
        
        // Clean up UI before starting the firing sequence
        [] call fnc_cleanupFireAtPositionUI;
        
        // Set up the firing sequence with a different approach
        [_vehicle, _weapon, _muzzle, _pos, _roundCount] spawn {
            params ["_vehicle", "_weapon", "_muzzle", "_pos", "_roundCount"];
            
            // Safety checks
            if (isNull _vehicle || !alive _vehicle) exitWith {
                systemChat "Vehicle no longer available";
            };
            
            // Constants
            private _aimDelay = 2.5;  // Time to aim
            private _shotInterval = 0.8;  // Time between shots
            
            // Make sure position is valid
            if (isNil "_pos") then {
                _pos = missionNamespace getVariable ["FIREATP_lastTargetPos", getPos _vehicle];
            };
            
            // Create target helper
            private _targetHelper = "Land_HelipadEmpty_F" createVehicle _pos;
            _targetHelper setPosATL _pos;
            
            // Get gunner
            private _gunner = gunner _vehicle;
            if (isNull _gunner) then {
                _gunner = driver _vehicle;
            };
            
            // Aim procedure
            systemChat "Aiming at target...";
            _vehicle doWatch _targetHelper;
            _gunner doWatch _targetHelper;
            
            // Force aim direction
            _vehicle setDir ([_vehicle, _pos] call BIS_fnc_dirTo);
            sleep _aimDelay;
            
            // Use a completely different method for firing - BIS_fnc_fire
            for "_i" from 1 to _roundCount do {
                if (!alive _vehicle) exitWith {
                    systemChat "Vehicle destroyed before completing fire mission";
                };
                
                // Select weapon
                _vehicle selectWeapon _muzzle;
                
                // Alternative firing method
                [_vehicle, _muzzle] call BIS_fnc_fire;
                
                // Debug info
                systemChat format ["Firing round %1 of %2 (weapon: %3, muzzle: %4)", 
                    _i, _roundCount, _weapon, _muzzle];
                
                // Wait between shots
                if (_i < _roundCount) then {
                    sleep _shotInterval;
                };
            };
            
            // Cleanup 
            deleteVehicle _targetHelper;
            systemChat "Fire mission complete";
        };
        
        // Reset state
        FIREATP_active = false;
    };
};

// Main ability activation
params ["_vehicle"];

if !(_vehicle isKindOf "Tank" || _vehicle isKindOf "Car" || _vehicle isKindOf "StaticWeapon") exitWith {
    systemChat "This ability can only be used with vehicles that have weapons";
    false
};

systemChat format ["Activating Fire at Position for: %1", getText (configFile >> "CfgVehicles" >> typeOf _vehicle >> "displayName")];
[] call fnc_resetFireAtPositionState;

FIREATP_active = true;
FIREATP_shootingVehicle = _vehicle;

// Set up Draw3D handler for crosshair
FIREATP_drawHandler = addMissionEventHandler ["Draw3D", {
    if (FIREATP_active) then {
        FIREATP_currentPos = screenToWorld getMousePosition;
        
        // If we have a selected position, draw the crosshair there
        if (count FIREATP_selectedPos > 0) then {
            private _pos = FIREATP_selectedPos;
            
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
        
        // Draw distance line from vehicle to target
        if (count FIREATP_targets == 0) then {
            private _vehiclePos = getPosASL FIREATP_shootingVehicle;
            private _targetPos = AGLToASL FIREATP_currentPos;
            if (!isNil "_vehiclePos" && !isNil "_targetPos") then {
                drawLine3D [
                    ASLToAGL _vehiclePos,
                    ASLToAGL _targetPos,
                    [0.8,0.8,1,0.5]
                ];
            };
        };
    };
}];

// Set up time handler
FIREATP_timeHandler = addMissionEventHandler ["EachFrame", {
    if (FIREATP_active) then {
        setAccTime FIREATP_timeScale;
    };
}];

[] call fnc_createFireAtPositionUI;

// Add key handler
private _display = findDisplay 312;
FIREATP_keyHandler = _display displayAddEventHandler ["KeyDown", {
    params ["_displayOrControl", "_key", "_shift", "_ctrl", "_alt"];
    
    if (FIREATP_active) then {
        // Space key - Mark target
        if (_key == 57) then {
            systemChat "Space pressed - Marking target position";
            
            if (count FIREATP_targets == 0) then {
                private _pos = FIREATP_currentPos;
                FIREATP_selectedPos = _pos;  // Store the selected position
                
                [_pos] call fnc_createTargetMarker;
            };
            true
        };
        
        // Enter key - Confirm shot (not used for this ability)
        if (_key == 28) then {
            if (count FIREATP_targets > 0 && FIREATP_selectedAmmo != "") then {
                private _confirmBtn = uiNamespace getVariable ["FIREATP_confirmBtn", controlNull];
                if (!isNull _confirmBtn) then {
                    _confirmBtn ctrlShow false;
                };
                [] call fnc_executeFireAtPosition;
            } else {
                if (FIREATP_selectedAmmo == "") then {
                    systemChat "Please select an ammunition type";
                } else {
                    systemChat "Please select a target position";
                };
            };
            true
        };
        
        // Backspace key - Cancel
        if (_key == 14) then {
            [] call fnc_resetFireAtPositionState;
            systemChat "Fire at Position cancelled";
            true
        };
    };
    false
}];

systemChat "Fire at Position activated - SPACE to mark target | BACKSPACE to cancel | Click FIRE button to execute";