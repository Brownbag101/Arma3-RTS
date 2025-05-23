// scripts/specialAbilities/abilityManager.sqf - UPDATED WITH SMG BURST ABILITY

// Initialize array to store ability icons
RTSUI_abilityIcons = [];

// Database of all possible abilities
RTSUI_abilityDatabase = [
    [
        "scout",                                                  // Ability ID
        "\A3\UI_F\Data\IGUI\Cfg\SimpleTasks\types\scout_ca.paa", // Icon path
        "Scouting",                                              // Display name
        "Reveals enemy units within 500m",                       // Tooltip
        "scripts\specialAbilities\abilities\scouting.sqf"        // Script path
    ],
    [
        "aimedshot",
        "\A3\ui_f\data\IGUI\Cfg\SimpleTasks\types\target_ca.paa",
        "Precision Shot",
        "Enter precision targeting mode for a calculated shot",
        "scripts\specialAbilities\abilities\aimedShot.sqf"
    ],
    [
        "capture",
        "\A3\ui_f\data\IGUI\Cfg\SimpleTasks\types\meet_ca.paa",
        "Capture Enemy",
        "Force surrender of outnumbered enemy units",
        "scripts\specialAbilities\abilities\capture.sqf"
    ],
    [
        "timebomb",
        "\A3\ui_f\data\IGUI\Cfg\SimpleTasks\types\destroy_ca.paa",
        "Plant Time Bomb",
        "Place timed explosive device (requires TNT)",
        "scripts\specialAbilities\abilities\timeBomb.sqf"
    ],
    [
        "smgburst",
        "\A3\ui_f\data\IGUI\Cfg\WeaponIcons\mg_ca.paa",
        "SMG Burst",
        "Empty your SMG at a target in slow motion",
        "scripts\specialAbilities\abilities\smgBurst.sqf"
    ],
	[
		"medic",
		"\A3\ui_f\data\IGUI\Cfg\Actions\heal_ca.paa",
		"Combat Medic",
		"Heal friendly units to 80% health",
		"scripts\specialAbilities\abilities\medic.sqf"
	],
	[
		"engineer",
		"\A3\ui_f\data\IGUI\Cfg\Actions\repair_ca.paa",
		"Field Engineer",
		"Repair vehicles and structures to 100%",
		"scripts\specialAbilities\abilities\engineer.sqf"
	]
];

// Get unit's unlocked abilities
fnc_getUnitAbilities = {
    params ["_unit"];
    private _abilities = _unit getVariable ["RTSUI_unlockedAbilities", []];
    if (_abilities isEqualTo []) then {
        _unit setVariable ["RTSUI_unlockedAbilities", [], true];
    };
    _abilities
};

// Function to unlock a new ability for a unit
fnc_unlockAbility = {
    params ["_unit", "_abilityId"];
    
    systemChat "Starting ability unlock...";
    
    // Debug: Check if ability exists in database
    private _abilityExists = _abilityId in (RTSUI_abilityDatabase apply {_x select 0});
    systemChat format ["Ability %1 exists in database: %2", _abilityId, _abilityExists];
    
    private _abilities = [_unit] call fnc_getUnitAbilities;
    systemChat format ["Current abilities before: %1", _abilities];
    
    // Check if unit already has this ability
    if (_abilityId in _abilities) exitWith {
        systemChat format ["%1 already has %2", name _unit, _abilityId];
    };
    
    // Add ability
    _abilities pushBack _abilityId;
    _unit setVariable ["RTSUI_unlockedAbilities", _abilities, true];
    
    systemChat format ["Updated abilities: %1", _unit getVariable ["RTSUI_unlockedAbilities", []]];
    
    // Update UI if this unit is selected
    if (_unit == RTSUI_selectedUnit) then {
        private _display = findDisplay 312;
        if (!isNull _display) then {
            systemChat "Updating ability icons...";
            [_display] call fnc_createAbilityIcons;
        };
    };
    
    systemChat format ["%1 learned %2", name _unit, _abilityId];
};

// Create the ability icons for a unit
fnc_createAbilityIcons = {
    params ["_display"];
    
    // Ensure RTSUI_abilityIcons is initialized
    if (isNil "RTSUI_abilityIcons") then { 
        RTSUI_abilityIcons = []; 
    };
    
    // Clear existing icons
    {
        ctrlDelete _x;
    } forEach RTSUI_abilityIcons;
    RTSUI_abilityIcons = [];
    
    // Exit and clear if no unit selected
    if (isNull RTSUI_selectedUnit) exitWith {
        systemChat "No unit selected, clearing ability icons";
    };
    
    // Check if required functions exist
    if (isNil "fnc_getUnitAbilities") exitWith {
        systemChat "Ability system functions not loaded yet";
    };
    
    // Get unit's abilities
    private _abilities = [RTSUI_selectedUnit] call fnc_getUnitAbilities;
    
    if (_abilities isEqualTo []) exitWith {
        systemChat "Unit has no abilities";
    };
    
    systemChat format ["Creating icons for abilities: %1", _abilities];
    
    // Layout configuration
    private _iconSize = 0.04 * safezoneH;
    private _spacing = 0.005 * safezoneW;
    private _iconsPerRow = 4;
    private _startX = safezoneX + safezoneW - 0.29;
    private _startY = safezoneY + safezoneH - 0.26;
    
    {
        private _abilityId = _x;
        private _abilityIndex = RTSUI_abilityDatabase findIf {(_x select 0) == _abilityId};
        
        if (_abilityIndex != -1) then {
            private _abilityData = RTSUI_abilityDatabase select _abilityIndex;
            _abilityData params ["_id", "_iconPath", "_name", "_tooltip", "_script"];
            
            private _row = floor (_forEachIndex / _iconsPerRow);
            private _col = _forEachIndex % _iconsPerRow;
            
            private _ctrl = _display ctrlCreate ["RscPictureKeepAspect", -1];
            _ctrl ctrlSetPosition [
                _startX + (_col * (_iconSize + _spacing)),
                _startY + (_row * (_iconSize + _spacing)),
                _iconSize,
                _iconSize
            ];
            _ctrl ctrlSetText _iconPath;
            _ctrl ctrlSetTooltip format ["%1: %2", _name, _tooltip];
            
            // Create invisible button overlay for better click handling
            private _button = _display ctrlCreate ["RscButton", -1];
            _button ctrlSetPosition [
                _startX + (_col * (_iconSize + _spacing)),
                _startY + (_row * (_iconSize + _spacing)),
                _iconSize,
                _iconSize
            ];
            _button ctrlSetText "";
            _button ctrlSetBackgroundColor [0, 0, 0, 0];
            _button ctrlSetTooltip format ["%1: %2", _name, _tooltip];
            
            // Add click handler to the button
            _button ctrlAddEventHandler ["ButtonClick", {
                params ["_ctrl"];
                private _ability = _ctrl getVariable "abilityData";
                _ability params ["_id", "_iconPath", "_name", "_tooltip", "_script"];
                
                if (!isNull RTSUI_selectedUnit) then {
                    systemChat format ["Starting %1 ability execution...", _name];
                    
                    // Check for active abilities that need to be cancelled first
                    if ((!isNil "AIMEDSHOT_active" && {AIMEDSHOT_active}) || 
                        (!isNil "TIMEBOMB_active" && {TIMEBOMB_active}) ||
                        (!isNil "SMGBURST_active" && {SMGBURST_active})) then {
                        
                        // Simulate backspace to cancel active ability
                        call fnc_simulateBackspaceKey;
                        sleep 0.5; // Small delay to ensure cancellation completes
                    };
                    
                    // Execute the ability script
                    private _result = [RTSUI_selectedUnit] execVM _script;
                    
                    // Debug output
                    if (isNil "_result") then {
                        systemChat "Error: Script execution failed!";
                    } else {
                        systemChat format ["Script %1 executed", _script];
                    };
                };
            }];
            
            _button setVariable ["abilityData", _abilityData];
            _button ctrlCommit 0;
            
            _ctrl ctrlCommit 0;
            RTSUI_abilityIcons pushBack _ctrl;
            RTSUI_abilityIcons pushBack _button;
        };
    } forEach _abilities;
};

// Helper function to get ability info by ID
fnc_getAbilityInfo = {
    params ["_abilityId"];
    
    private _abilityInfo = [];
    {
        if (_x select 0 == _abilityId) exitWith {
            _abilityInfo = _x;
        };
    } forEach RTSUI_abilityDatabase;
    
    _abilityInfo
};

// Check if unit has a specific ability
fnc_hasAbility = {
    params ["_unit", "_abilityId"];
    
    private _abilities = [_unit] call fnc_getUnitAbilities;
    _abilityId in _abilities
};

// Helper function to check ability cooldown
fnc_getAbilityCooldown = {
    params ["_unit", "_abilityId"];
    
    private _cooldownVar = format ["ABILITY_%1_cooldown", _abilityId];
    private _cooldownTime = _unit getVariable [_cooldownVar, 0];
    private _remainingTime = _cooldownTime - time;
    
    if (_remainingTime <= 0) then {
        [0, "Ready"]
    } else {
        [_remainingTime, format ["%1m %2s", floor(_remainingTime / 60), floor(_remainingTime % 60)]]
    }
};