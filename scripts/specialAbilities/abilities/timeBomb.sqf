// Time Bomb Ability - DIRECT APPROACH
// Using simplified explosive creation method with UI

// Initialize global variables
if (isNil "TIMEBOMB_active") then { TIMEBOMB_active = false; };
if (isNil "TIMEBOMB_bombUnit") then { TIMEBOMB_bombUnit = objNull; };
if (isNil "TIMEBOMB_timeScale") then { TIMEBOMB_timeScale = 0.1; }; // Slow-mo factor
if (isNil "TIMEBOMB_keyHandler") then { TIMEBOMB_keyHandler = -1; };
if (isNil "TIMEBOMB_timeHandler") then { TIMEBOMB_timeHandler = -1; };
if (isNil "TIMEBOMB_drawHandler") then { TIMEBOMB_drawHandler = -1; };
if (isNil "TIMEBOMB_currentPos") then { TIMEBOMB_currentPos = [0,0,0]; };
if (isNil "TIMEBOMB_selectedPos") then { TIMEBOMB_selectedPos = []; };
if (isNil "TIMEBOMB_selectedTimer") then { TIMEBOMB_selectedTimer = 60; }; // Default 1 minute
if (isNil "TIMEBOMB_controls") then { TIMEBOMB_controls = []; };
if (isNil "TIMEBOMB_markerCount") then { TIMEBOMB_markerCount = 0; };
if (isNil "TIMEBOMB_targets") then { TIMEBOMB_targets = []; };

// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE BEHAVIOR ===
TIMEBOMB_placementTime = 5;            // Time in seconds to place the bomb
TIMEBOMB_maxDistance = 100;            // Maximum distance from unit to place bomb
TIMEBOMB_bombType = "DemoCharge_Remote_Ammo";  // Type of bomb to create

// Function to reset time bomb state
fnc_resetTimeBombState = {
    systemChat "Resetting time bomb state...";
    
    TIMEBOMB_active = false;
    TIMEBOMB_selectedPos = [];
    
    // Remove handlers
    if (TIMEBOMB_keyHandler != -1) then {
        (findDisplay 312) displayRemoveEventHandler ["KeyDown", TIMEBOMB_keyHandler];
        TIMEBOMB_keyHandler = -1;
    };
    
    if (TIMEBOMB_timeHandler != -1) then {
        removeMissionEventHandler ["EachFrame", TIMEBOMB_timeHandler];
        TIMEBOMB_timeHandler = -1;
    };
    
    if (TIMEBOMB_drawHandler != -1) then {
        removeMissionEventHandler ["Draw3D", TIMEBOMB_drawHandler];
        TIMEBOMB_drawHandler = -1;
    };
    
    // Reset time
    setAccTime 1;
    
    // Clean up UI
    {
        ctrlDelete _x;
    } forEach TIMEBOMB_controls;
    TIMEBOMB_controls = [];
    
    
    systemChat "Time bomb state reset complete";
};

// Format timer display
fnc_formatTimerDisplay = {
    params ["_seconds"];
    
    if (_seconds < 60) then {
        format ["%1 seconds", _seconds]
    } else {
        if (_seconds < 3600) then {
            format ["%1 minutes", floor(_seconds / 60)]
        } else {
            format ["%1 hours", floor(_seconds / 3600)]
        }
    }
};

// Create UI function
fnc_createTimeBombUI = {
    private _display = findDisplay 312;
    
    // Create overlay
    private _overlay = _display ctrlCreate ["RscText", -1];
    _overlay ctrlSetPosition [safezoneX, safezoneY, safezoneW, safezoneH];
    _overlay ctrlSetBackgroundColor [0, 0.1, 0.2, 0.3];
    _overlay ctrlCommit 0;
    TIMEBOMB_controls pushBack _overlay;
    
    // Create info text
    private _infoText = _display ctrlCreate ["RscStructuredText", -1];
    _infoText ctrlSetPosition [safezoneX + (safezoneW * 0.3), safezoneY + (safezoneH * 0.1), safezoneW * 0.4, safezoneH * 0.1];
    _infoText ctrlSetStructuredText parseText "<t align='center' size='1.2'>TIME BOMB PLACEMENT ACTIVE<br/>SPACE to mark position | 1-4 to set timer | BACKSPACE to cancel</t>";
    _infoText ctrlCommit 0;
    TIMEBOMB_controls pushBack _infoText;
    
    // Create target info display with background
    private _targetInfoBG = _display ctrlCreate ["RscText", -1];
    _targetInfoBG ctrlSetPosition [safezoneX + (safezoneW * 0.4), safezoneY + (safezoneH * 0.2), safezoneW * 0.2, safezoneH * 0.15];
    _targetInfoBG ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _targetInfoBG ctrlCommit 0;
    TIMEBOMB_controls pushBack _targetInfoBG;
    
    private _targetInfo = _display ctrlCreate ["RscStructuredText", -1];
    _targetInfo ctrlSetPosition [safezoneX + (safezoneW * 0.4), safezoneY + (safezoneH * 0.2), safezoneW * 0.2, safezoneH * 0.15];
    _targetInfo ctrlSetBackgroundColor [0, 0, 0, 0];
    _targetInfo ctrlSetStructuredText parseText "";
    _targetInfo ctrlCommit 0;
    TIMEBOMB_controls pushBack _targetInfo;
    
    // Store for future updates
    uiNamespace setVariable ["TIMEBOMB_targetInfo", _targetInfo];
    
    // Create timer selection buttons
    private _timerOptions = [
        [30, "30 Seconds"], 
        [60, "1 Minute"], 
        [300, "5 Minutes"], 
        [1800, "30 Minutes"]
    ];
    
    private _buttonWidth = safezoneW * 0.1;
    private _buttonHeight = safezoneH * 0.04;
    private _buttonSpacing = safezoneW * 0.01;
    private _startX = safezoneX + (safezoneW * 0.5) - (_buttonWidth * 2 + _buttonSpacing * 1.5);
    private _startY = safezoneY + (safezoneH * 0.35); // Positioned below target info
    
    private _timerButtons = [];
    
    // Create timer option buttons
    {
        _x params ["_time", "_label"];
        private _index = _forEachIndex;
        
        private _btn = _display ctrlCreate ["RscButton", -1];
        _btn ctrlSetPosition [
            _startX + (_index * (_buttonWidth + _buttonSpacing)),
            _startY,
            _buttonWidth,
            _buttonHeight
        ];
        _btn ctrlSetText _label;
        
        // Highlight default timer button
        if (_time == TIMEBOMB_selectedTimer) then {
            _btn ctrlSetBackgroundColor [0.3, 0.6, 0.3, 0.8];
        } else {
            _btn ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.8];
        };
        
        _btn ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _selectedTime = _ctrl getVariable "timerValue";
            
            TIMEBOMB_selectedTimer = _selectedTime;
            
            // Update button colors
            {
                private _btnColor = if ((_x getVariable ["timerValue", 0]) == _selectedTime) then {
                    [0.3, 0.6, 0.3, 0.8] // Selected
                } else {
                    [0.1, 0.1, 0.1, 0.8] // Not selected
                };
                _x ctrlSetBackgroundColor _btnColor;
            } forEach TIMEBOMB_timerButtons;
            
            // Update target info if it exists
            private _targetInfo = uiNamespace getVariable ["TIMEBOMB_targetInfo", controlNull];
            if (!isNull _targetInfo && count TIMEBOMB_selectedPos > 0) then {
                private _unit = TIMEBOMB_bombUnit;
                private _pos = TIMEBOMB_selectedPos;
                private _distance = _pos distance _unit;
                
                private _text = format [
                    "<t size='1.1'>Target: Bomb Position</t><br/>" +
                    "<t color='#ADD8E6'>Distance: %1m</t><br/>" +
                    "<t color='#90EE90'>Timer: %2</t>",
                    round _distance,
                    [TIMEBOMB_selectedTimer] call fnc_formatTimerDisplay
                ];
                
                _targetInfo ctrlSetStructuredText parseText _text;
            };
            
            systemChat format ["Timer set to %1", [_selectedTime] call fnc_formatTimerDisplay];
        }];
        
        _btn setVariable ["timerValue", _time];
        _btn ctrlCommit 0;
        TIMEBOMB_controls pushBack _btn;
        _timerButtons pushBack _btn;
        
    } forEach _timerOptions;
    
    // Create confirm button (initially hidden)
    private _confirmBtn = _display ctrlCreate ["RscButton", -1];
    _confirmBtn ctrlSetPosition [
        safezoneX + (safezoneW * 0.45),
        safezoneY + (safezoneH * 0.41), // Positioned below timer buttons
        safezoneW * 0.1,
        safezoneH * 0.04
    ];
    _confirmBtn ctrlSetText "PLACE BOMB";
    _confirmBtn ctrlSetBackgroundColor [0.7, 0.2, 0.2, 0.8];
    _confirmBtn ctrlShow false;
    _confirmBtn ctrlAddEventHandler ["ButtonClick", {
        systemChat "Place bomb button clicked!";
        if (count TIMEBOMB_selectedPos > 0) then {
            [] call fnc_executeTimeBomb;
        };
    }];
    _confirmBtn ctrlCommit 0;
    TIMEBOMB_controls pushBack _confirmBtn;
    
    // Store references
    TIMEBOMB_confirmBtn = _confirmBtn;
    TIMEBOMB_timerButtons = _timerButtons;
};

// Execute the time bomb placement and explosion - DIRECT APPROACH
fnc_executeTimeBomb = {
    if (count TIMEBOMB_selectedPos == 0) exitWith {
        systemChat "No position selected for bomb placement";
    };
    
    private _unit = TIMEBOMB_bombUnit;
    private _targetPos = TIMEBOMB_selectedPos;
    private _fuseTime = TIMEBOMB_selectedTimer;
    
    systemChat format["Executing time bomb placement at %1 with timer %2s", _targetPos, _fuseTime];
    
    // First, reset the UI
    [] call fnc_resetTimeBombState;
    
    // Make unit move to position to place bomb
    _unit doMove _targetPos;
    
    // Start the bomb placement process
    [_unit, _targetPos, _fuseTime] spawn {
        params ["_unit", "_targetPos", "_fuseTime"];
        
        systemChat "Unit is moving to bomb position...";
        
        // Wait until unit is close enough
        waitUntil {
            sleep 0.5;
            (_unit distance _targetPos < 3) || !(alive _unit)
        };
        
        // Exit if unit died
        if (!alive _unit) exitWith {
            systemChat "Unit died before reaching bomb position";
        };
        
        systemChat "Unit has reached bomb position, placing explosive...";
        
        // Unit stops and plays animation
        _unit disableAI "MOVE";
        _unit playMoveNow "AinvPknlMstpSnonWnonDnon_medic4"; // Placement animation
        
        // Wait for animation
        sleep TIMEBOMB_placementTime;
        
        // Re-enable unit's movement
        _unit enableAI "MOVE";
        
        // DIRECT APPROACH: Create the bomb and set timer
        private _bomb = createVehicle [TIMEBOMB_bombType, _targetPos, [], 0, "CAN_COLLIDE"];
        _bomb setPosATL [_targetPos select 0, _targetPos select 1, (_targetPos select 2) + 0.05];
        
        // Make unit move away from bomb
        private _moveDir = random 360;
        private _moveDistance = 50;
        private _movePos = _unit getPos [_moveDistance, _moveDir];
        _unit doMove _movePos;
        
        // Provide feedback
        systemChat format ["Explosive placed with %1 timer", [_fuseTime] call fnc_formatTimerDisplay];
        hint parseText format [
            "<t size='1.2' color='#66ff66'>Explosive Placed</t><br/><br/>Timer set for <t color='#ffcc66'>%1</t><br/><br/>Get clear of the area!",
            [_fuseTime] call fnc_formatTimerDisplay
        ];
        
        // Make bomb visible to Zeus
        private _zeus = getAssignedCuratorLogic player;
        if (!isNull _zeus) then {
            _zeus addCuratorEditableObjects [[_bomb], true];
            systemChat "Added bomb to Zeus";
        };
        
        // SIMPLE TIMER: Wait and then detonate
        systemChat format["Starting bomb timer for %1 seconds", _fuseTime];
        
        [_bomb, _fuseTime] spawn {
            params ["_bomb", "_fuseTime"];
            
            // Show periodic countdown
            private _lastAnnounce = _fuseTime;
            for [{private _i = _fuseTime}, {_i > 0}, {_i = _i - 1}] do {
                // Announce time at certain intervals
                if (_i == 60 || _i == 30 || _i == 20 || _i == 10 || _i <= 5) then {
                    systemChat format["Bomb detonates in %1 seconds", _i];
                };
                sleep 1;
            }; 
            
            // BOOM!
            if (!isNull _bomb) then {
                systemChat "BOOM! Bomb detonating!";
                _bomb setDamage 1; // This triggers the explosion
            };
			
			// Delete the helper object
			private _helper = missionNamespace getVariable ["TIMEBOMB_iconHelper", objNull];
			if (!isNull _helper) then {
				deleteVehicle _helper;
				missionNamespace setVariable ["TIMEBOMB_iconHelper", objNull];
			};
        };
        
        [_bomb, _fuseTime] spawn {
            params ["_bomb", "_fuseTime"];
            
            // Show periodic countdown
            private _lastAnnounce = _fuseTime;
            for [{private _i = _fuseTime}, {_i > 0}, {_i = _i - 1}] do {
                // Announce time at certain intervals
                if (_i == 60 || _i == 30 || _i == 20 || _i == 10 || _i <= 5) then {
                    systemChat format["Bomb detonates in %1 seconds", _i];
                };
                sleep 1;
            }; 
            
            // BOOM!
            if (!isNull _bomb) then {
                // Remove the Zeus icon before explosion
                [TIMEBOMB_iconHelper] call BIS_fnc_removeCuratorIcon;
                
                systemChat "BOOM! Bomb detonating!";
                _bomb setDamage 1; // This triggers the explosion
            };
        };
    };
};

// Main ability activation
params ["_unit"];

systemChat format ["%1 is activating Time Bomb ability!", name _unit];
[] call fnc_resetTimeBombState;

TIMEBOMB_active = true;
TIMEBOMB_bombUnit = _unit;

// Set up Draw3D handler for crosshair visualization
TIMEBOMB_drawHandler = addMissionEventHandler ["Draw3D", {
    if (TIMEBOMB_active) then {
        TIMEBOMB_currentPos = screenToWorld getMousePosition;
        
        // If we have a selected position, draw a marker there
        if (count TIMEBOMB_selectedPos > 0) then {
            private _pos = TIMEBOMB_selectedPos;
            
            // Draw main targeting reticle
            drawIcon3D [
                "\a3\ui_f\data\IGUI\Cfg\Targeting\targetingM_ca.paa",
                [1,0,0,1],    // Red
                ASLToAGL (AGLToASL _pos),
                2,
                2,
                45,
                "",
                2,
                0.05,
                "PuristaMedium"
            ];
            
            // Draw explosion radius indicator
            drawIcon3D [
                "\a3\ui_f\data\IGUI\Cfg\HintMission\checkpoint_ca.paa",
                [1,0.5,0,0.8],    // Orange
                ASLToAGL (AGLToASL _pos vectorAdd [0,0,0.5]),
                8,  // Size represents explosion radius
                8,
                0,
                "",
                2,
                0.05,
                "PuristaMedium"
            ];
        } else {
            // Draw cursor position when no target is selected
            private _color = [1,1,1,0.7];
            private _cursorPos = AGLToASL TIMEBOMB_currentPos;
            
            // Draw cursor crosshair
            drawIcon3D [
                "\a3\ui_f\data\IGUI\Cfg\Cursors\tactical_ca.paa",
                _color,
                ASLToAGL _cursorPos,
                1,
                1,
                0,
                "",
                2,
                0.05,
                "PuristaMedium"
            ];
        };
        
        // Draw cursor position and distance indicator
        private _unitPos = getPosASL TIMEBOMB_bombUnit;
        private _targetPos = AGLToASL TIMEBOMB_currentPos;
        drawLine3D [
            ASLToAGL _unitPos,
            ASLToAGL _targetPos,
            [1,0.5,0,0.5]  // Orange
        ];
        
        // Draw distance text
        private _distance = (_unitPos distance _targetPos);
        private _color = if (_distance <= TIMEBOMB_maxDistance) then {
            [0,1,0,1] // Green if in range
        } else {
            [1,0,0,1] // Red if out of range
        };
        
        drawIcon3D [
            "",
            _color,
            ASLToAGL (_unitPos vectorAdd (_targetPos vectorDiff _unitPos vectorMultiply 0.5)),
            0,
            0,
            0,
            format ["%1m", round _distance],
            2,
            0.05,
            "PuristaMedium"
        ];
    };
}];

// Set up time handler for slow motion
TIMEBOMB_timeHandler = addMissionEventHandler ["EachFrame", {
    if (TIMEBOMB_active) then {
        setAccTime TIMEBOMB_timeScale;
    };
}];

// Create UI
call fnc_createTimeBombUI;

// Add key handler
private _display = findDisplay 312;
TIMEBOMB_keyHandler = _display displayAddEventHandler ["KeyDown", {
    params ["_displayOrControl", "_key", "_shift", "_ctrl", "_alt"];
    
    if (TIMEBOMB_active) then {
        // Space key - Mark position
        if (_key == 57) then {
            systemChat "Space pressed - Marking bomb position";
            
            // Get current mouse position
            private _pos = screenToWorld getMousePosition;
            private _unit = TIMEBOMB_bombUnit;
            private _distance = _pos distance _unit;
            
            // Check if position is within range
            if (_distance > TIMEBOMB_maxDistance) then {
                systemChat format ["Position too far! Maximum range is %1m", TIMEBOMB_maxDistance];
                hint parseText format [
                    "<t size='1.2' color='#ff6666'>Position Too Far</t><br/><br/>Maximum range is %1m<br/>Current distance: %2m",
                    TIMEBOMB_maxDistance, round _distance
                ];
                true
            } else {
                TIMEBOMB_selectedPos = _pos;
                TIMEBOMB_currentPos = _pos;
                
                // Create a helper object for the Zeus icon (will be deleted later)
                private _helperLogic = "Logic" createVehicleLocal _pos;
                _helperLogic setPosATL _pos;
                
                // Store the helper object for later access
                missionNamespace setVariable ["TIMEBOMB_iconHelper", _helperLogic];
                
                // Add icon to curator
                private _zeus = getAssignedCuratorLogic player;
                if (!isNull _zeus) then {
                    _zeus addCuratorEditableObjects [[_helperLogic], true];
                    systemChat "Added helper object to Zeus";
                };
                
                systemChat format["Position marked at %1, distance %2m", _pos, round _distance];
                
                // Update target info if it exists
                private _targetInfo = uiNamespace getVariable ["TIMEBOMB_targetInfo", controlNull];
                if (!isNull _targetInfo) then {
                    private _text = format [
                        "<t size='1.1'>Target: Bomb Position</t><br/>" +
                        "<t color='#ADD8E6'>Distance: %1m</t><br/>" +
                        "<t color='#90EE90'>Timer: %2</t>",
                        round _distance,
                        [TIMEBOMB_selectedTimer] call fnc_formatTimerDisplay
                    ];
                    
                    _targetInfo ctrlSetStructuredText parseText _text;
                };
                
                // Show confirm button
                if (!isNil "TIMEBOMB_confirmBtn") then {
                    TIMEBOMB_confirmBtn ctrlShow true;
                };
                
                systemChat format["Position marked at %1, distance %2m", _pos, round _distance];
                true
            }
        };
        
        // Number keys 1-4 for timer selection
        if (_key >= 2 && _key <= 5) then { // 1-4 keys
            private _timerIndex = _key - 2; // Convert to 0-3 index
            private _timerOptions = [30, 60, 300, 1800]; // 30s, 1m, 5m, 30m
            
            if (_timerIndex >= 0 && _timerIndex < count _timerOptions) then {
                TIMEBOMB_selectedTimer = _timerOptions select _timerIndex;
                
                // Update button highlighting
                if (!isNil "TIMEBOMB_timerButtons") then {
                    {
                        private _btnTime = _x getVariable ["timerValue", 0];
                        private _btnColor = if (_btnTime == TIMEBOMB_selectedTimer) then {
                            [0.3, 0.6, 0.3, 0.8] // Selected
                        } else {
                            [0.1, 0.1, 0.1, 0.8] // Not selected
                        };
                        _x ctrlSetBackgroundColor _btnColor;
                    } forEach TIMEBOMB_timerButtons;
                };
                
                // Update target info if it exists
                private _targetInfo = uiNamespace getVariable ["TIMEBOMB_targetInfo", controlNull];
                if (!isNull _targetInfo && count TIMEBOMB_selectedPos > 0) then {
                    private _unit = TIMEBOMB_bombUnit;
                    private _pos = TIMEBOMB_selectedPos;
                    private _distance = _pos distance _unit;
                    
                    private _text = format [
                        "<t size='1.1'>Target: Bomb Position</t><br/>" +
                        "<t color='#ADD8E6'>Distance: %1m</t><br/>" +
                        "<t color='#90EE90'>Timer: %2</t>",
                        round _distance,
                        [TIMEBOMB_selectedTimer] call fnc_formatTimerDisplay
                    ];
                    
                    _targetInfo ctrlSetStructuredText parseText _text;
                };
                
                systemChat format ["Timer set to %1", [TIMEBOMB_selectedTimer] call fnc_formatTimerDisplay];
                true
            };
        };
        
        // Enter key - Confirm (alternative to button)
        if (_key == 28) then {
            if (count TIMEBOMB_selectedPos > 0) then {
                systemChat "Enter pressed - Confirming bomb placement";
                [] call fnc_executeTimeBomb;
                true
            };
        };
        
        // Backspace key - Cancel
        if (_key == 14) then {
            [] call fnc_resetTimeBombState;
            systemChat "Time Bomb placement cancelled";
            true
        };
    };
    false
}];

systemChat "Time Bomb ability activated - SPACE to mark position | 1-4 to set timer | BACKSPACE to cancel";