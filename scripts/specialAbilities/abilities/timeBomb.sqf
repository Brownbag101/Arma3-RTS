// Time Bomb Ability
// Allows placing timed explosives with customizable timers
// Based on the aimedShot.sqf implementation

// Initialize global variables
if (isNil "TIMEBOMB_active") then { TIMEBOMB_active = false; };
if (isNil "TIMEBOMB_markerCount") then { TIMEBOMB_markerCount = 0; };
if (isNil "TIMEBOMB_bombUnit") then { TIMEBOMB_bombUnit = objNull; };
if (isNil "TIMEBOMB_timeScale") then { TIMEBOMB_timeScale = 0.1; }; // Slow-mo factor
if (isNil "TIMEBOMB_keyHandler") then { TIMEBOMB_keyHandler = -1; };
if (isNil "TIMEBOMB_timeHandler") then { TIMEBOMB_timeHandler = -1; };
if (isNil "TIMEBOMB_drawHandler") then { TIMEBOMB_drawHandler = -1; };
if (isNil "TIMEBOMB_currentPos") then { TIMEBOMB_currentPos = [0,0,0]; };
if (isNil "TIMEBOMB_selectedPos") then { TIMEBOMB_selectedPos = []; };
if (isNil "TIMEBOMB_selectedTimer") then { TIMEBOMB_selectedTimer = 60; }; // Default 1 minute
if (isNil "TIMEBOMB_controls") then { TIMEBOMB_controls = []; };

// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE BEHAVIOR ===
TIMEBOMB_cooldownTime = 600;      // Cooldown time in seconds (10 minutes) 
TIMEBOMB_placementTime = 20;      // Time in seconds to place the bomb
TIMEBOMB_maxDistance = 100;       // Maximum distance from unit to place bomb
TIMEBOMB_requiredItem = "fow_e_tnt_twohalfpound_mag"; // Required explosive item

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
    
    // Clear markers
    if (!isNil "TIMEBOMB_selectedMarker") then {
        if (markerType TIMEBOMB_selectedMarker != "") then {
            deleteMarker TIMEBOMB_selectedMarker;
        };
        TIMEBOMB_selectedMarker = nil;
    };
    
    systemChat "Time bomb state reset complete";
};

// Create UI function - simplified
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
    
    // Create timer selection buttons - MOVED UP to be just below info text
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
    private _startY = safezoneY + (safezoneH * 0.2); // Moved up directly below info text
    
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
        safezoneY + (safezoneH * 0.26), // Positioned below timer buttons
        safezoneW * 0.1,
        safezoneH * 0.04
    ];
    _confirmBtn ctrlSetText "PLACE BOMB";
    _confirmBtn ctrlSetBackgroundColor [0.7, 0.2, 0.2, 0.8];
    _confirmBtn ctrlShow false;
    _confirmBtn ctrlAddEventHandler ["ButtonClick", {
        systemChat "Place bomb button clicked!";
        if (count TIMEBOMB_selectedPos > 0) then {
            [] spawn fnc_executeTimeBomb; // Using spawn to ensure it runs properly
        };
    }];
    _confirmBtn ctrlCommit 0;
    TIMEBOMB_controls pushBack _confirmBtn;
    
    // Store references
    TIMEBOMB_confirmBtn = _confirmBtn;
    TIMEBOMB_timerButtons = _timerButtons;
};

// Format timer display
fnc_formatTimerDisplay = {
    params ["_seconds"];
    
    if (_seconds < 60) then {
        format ["%1 seconds", _seconds]
    } else {
        if (_seconds < 3600) then {
            format ["%1 minutes", _seconds / 60]
        } else {
            format ["%1 hours", (_seconds / 3600) toFixed 1]
        }
    }
};

// Create a progress bar
fnc_createProgressBar = {
    params ["_title", "_duration"];
    
    private _display = findDisplay 46;
    private _progressBarWidth = 0.3;
    private _progressBarHeight = 0.05;
    
    // Background
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [
        safezoneX + (safezoneW - _progressBarWidth) / 2,
        safezoneY + safezoneH * 0.4,
        _progressBarWidth,
        _progressBarHeight
    ];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.5];
    _background ctrlCommit 0;
    
    // Progress Text
    private _progressText = _display ctrlCreate ["RscStructuredText", -1];
    _progressText ctrlSetPosition [
        safezoneX + (safezoneW - _progressBarWidth) / 2,
        safezoneY + safezoneH * 0.4,
        _progressBarWidth,
        _progressBarHeight / 2
    ];
    _progressText ctrlSetStructuredText parseText format ["<t align='center'>%1</t>", _title];
    _progressText ctrlCommit 0;
    
    // Progress Bar
    private _progressBar = _display ctrlCreate ["RscProgress", -1];
    _progressBar ctrlSetPosition [
        safezoneX + (safezoneW - _progressBarWidth) / 2,
        safezoneY + safezoneH * 0.4 + _progressBarHeight / 2,
        _progressBarWidth,
        _progressBarHeight / 2
    ];
    _progressBar ctrlSetBackgroundColor [0.2, 0.2, 0.2, 0.8];
    _progressBar progressSetPosition 0;
    _progressBar ctrlCommit 0;
    
    [_background, _progressText, _progressBar, _duration]
};

// Update progress bar
fnc_updateProgressBar = {
    params ["_controls", "_progress"];
    
    _controls params ["_background", "_progressText", "_progressBar", "_duration"];
    
    _progressBar progressSetPosition _progress;
    _progressBar ctrlSetTextColor [1 - _progress, _progress, 0, 1];
    
    private _remainingTime = ceil(_duration * (1 - _progress));
    _progressText ctrlSetStructuredText parseText format ["<t align='center'>Placing Explosive: %1s</t>", _remainingTime];
};

// Destroy progress bar
fnc_destroyProgressBar = {
    params ["_controls"];
    
    _controls params ["_background", "_progressText", "_progressBar"];
    
    ctrlDelete _background;
    ctrlDelete _progressText;
    ctrlDelete _progressBar;
};

// Create a target marker
fnc_createTargetMarker = {
    params ["_pos"];
    
    private _markerName = format ["timebomb_target_%1", TIMEBOMB_markerCount];
    
    // Delete previous marker if it exists
    if (markerType _markerName != "") then {
        deleteMarker _markerName;
    };
    
    private _marker = createMarker [_markerName, _pos];
    _marker setMarkerType "mil_destroy";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerSize [0.7, 0.7];
    _marker setMarkerText "BOMB";
    
    TIMEBOMB_markerCount = TIMEBOMB_markerCount + 1;
    TIMEBOMB_selectedMarker = _markerName;
    
    systemChat format["Marker created: %1 at position %2", _markerName, _pos];
    
    _markerName
};

// Place the time bomb
fnc_executeTimeBomb = {
    if (count TIMEBOMB_selectedPos == 0) exitWith {
        systemChat "No position selected for bomb placement";
    };
    
    private _unit = TIMEBOMB_bombUnit;
    private _targetPos = TIMEBOMB_selectedPos;
    private _timerDuration = TIMEBOMB_selectedTimer;
    
    systemChat format["Executing time bomb placement at %1 with timer %2", _targetPos, _timerDuration];
    
    // First, reset the UI and state
    [] call fnc_resetTimeBombState;
    
    // Direct bomb placement - skipping unit movement for testing
    // Create physical bomb object
    private _bomb = createVehicle ["fow_e_tnt_halfpound_mag", _targetPos, [], 0, "CAN_COLLIDE"];
    _bomb setPosATL [_targetPos select 0, _targetPos select 1, (_targetPos select 2) + 0.05];
    
    // Create marker for bomb
    private _marker = createMarker [format ["timebomb_active_%1", round time], _targetPos];
    _marker setMarkerType "mil_warning";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerText format ["BOMB: %1", [_timerDuration] call fnc_formatTimerDisplay];
    
    // Provide feedback
    systemChat format ["Explosive placed with %1 timer", [_timerDuration] call fnc_formatTimerDisplay];
    hint parseText format [
        "<t size='1.2' color='#66ff66'>Explosive Placed</t><br/><br/>Timer set for <t color='#ffcc66'>%1</t><br/><br/>Get clear of the area!",
        [_timerDuration] call fnc_formatTimerDisplay
    ];
    
    // Start timer for explosion
    [_bomb, _marker, _timerDuration] spawn {
        params ["_bomb", "_marker", "_timerDuration"];
        
        systemChat format["Starting bomb timer for %1 seconds", _timerDuration];
        
        // Store start time
        private _startTime = time;
        private _endTime = _startTime + _timerDuration;
        
        // Update marker periodically
        while {time < _endTime && !isNull _bomb} do {
            private _timeLeft = _endTime - time;
            _marker setMarkerText format ["BOMB: %1", [ceil _timeLeft] call fnc_formatTimerDisplay];
            
            // Debug output
            if (round(_timeLeft) mod 5 == 0) then {
                systemChat format["Bomb timer: %1 seconds remaining", round(_timeLeft)];
            };
            
            sleep 1;
        };
        
        // Time's up - explode if bomb still exists
        if (!isNull _bomb) then {
            // Create explosion
            private _bombPos = getPos _bomb;
            
            systemChat "BOOM! Bomb detonating!";
            
            // Delete the bomb object first
            deleteVehicle _bomb;
            
            // Create explosion
            "Bo_GBU12_LGB" createVehicle _bombPos;
            
            // Optional secondary explosions for dramatic effect
            [_bombPos] spawn {
                params ["_pos"];
                sleep 0.3;
                "HelicopterExploBig" createVehicle _pos;
                sleep 0.5;
                "HelicopterExploSmall" createVehicle [(_pos select 0) + 3, (_pos select 1) + 3, _pos select 2];
            };
            
            // Delete marker
            deleteMarker _marker;
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
        drawIcon3D [
            "",
            [1,1,1,1],
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
            TIMEBOMB_selectedPos = _pos;
            TIMEBOMB_currentPos = _pos;
            
            // Create new marker
            [_pos] call fnc_createTargetMarker;
            
            // Show confirm button
            if (!isNil "TIMEBOMB_confirmBtn") then {
                TIMEBOMB_confirmBtn ctrlShow true;
            };
            
            true
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
                
                systemChat format ["Timer set to %1", [TIMEBOMB_selectedTimer] call fnc_formatTimerDisplay];
            };
            true
        };
        
        // Remove Enter key handler - only use button now
        
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