// Air Operations UI
// Handles UI creation and interaction for air mission planning

// Open the Air Operations UI
fnc_openAirOperationsUI = {
    if (dialog) then {closeDialog 0};
    createDialog "RscDisplayEmpty";
    
    private _display = findDisplay -1;
    
    if (isNull _display) exitWith {
        diag_log "AIR_OPS UI: Failed to create display";
        systemChat "Error: Could not create Air Operations interface";
        false
    };
    
    // Set UI open flag
    AIR_OP_uiOpen = true;
    
    // ===== CREATE BACKGROUND PANELS =====
    // Create background - use high control ID for z-order
    private _background = _display ctrlCreate ["RscText", 9000];
    _background ctrlSetPosition [0.1 * safezoneW + safezoneX, 0.05 * safezoneH + safezoneY, 0.8 * safezoneW, 0.75 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.8];
    _background ctrlCommit 0;
    
    // Create title row background
    private _titleRow = _display ctrlCreate ["RscText", 9001];
    _titleRow ctrlSetPosition [0.1 * safezoneW + safezoneX, 0.05 * safezoneH + safezoneY, 0.8 * safezoneW, 0.05 * safezoneH];
    _titleRow ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _titleRow ctrlCommit 0;

    // Create main title
    private _title = _display ctrlCreate ["RscText", 9002];
    _title ctrlSetPosition [0.11 * safezoneW + safezoneX, 0.05 * safezoneH + safezoneY, 0.2 * safezoneW, 0.05 * safezoneH];
    _title ctrlSetText "Air Operations Command";
    _title ctrlCommit 0;

    // Create operation name label
    private _opNameLabel = _display ctrlCreate ["RscText", 9003];
    _opNameLabel ctrlSetPosition [0.32 * safezoneW + safezoneX, 0.05 * safezoneH + safezoneY, 0.15 * safezoneW, 0.05 * safezoneH];
    _opNameLabel ctrlSetText "Operation Name:";
    _opNameLabel ctrlCommit 0;

    // Create operation name input field
    private _opNameInput = _display ctrlCreate ["RscEdit", 9004];
    _opNameInput ctrlSetPosition [0.48 * safezoneW + safezoneX, 0.055 * safezoneH + safezoneY, 0.18 * safezoneW, 0.04 * safezoneH];
    _opNameInput ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.8];
    _opNameInput ctrlSetText AIR_OP_operationName;
    _opNameInput ctrlCommit 0;
    
    // ===== ADD TARGET TYPE SELECTOR =====
    // Create target type selector
    private _targetTypeLabel = _display ctrlCreate ["RscText", 9005];
    _targetTypeLabel ctrlSetPosition [0.12 * safezoneW + safezoneX, 0.115 * safezoneH + safezoneY, 0.1 * safezoneW, 0.03 * safezoneH];
    _targetTypeLabel ctrlSetText "Target Type:";
    _targetTypeLabel ctrlSetTextColor [1, 1, 1, 1];
    _targetTypeLabel ctrlCommit 0;
    
    // Create location button
    private _locationBtn = _display ctrlCreate ["RscButton", 9006];
    _locationBtn ctrlSetPosition [0.22 * safezoneW + safezoneX, 0.115 * safezoneH + safezoneY, 0.15 * safezoneW, 0.03 * safezoneH];
    _locationBtn ctrlSetText "LOCATIONS";
    _locationBtn ctrlSetTextColor [1, 1, 1, 1];
    _locationBtn ctrlSetBackgroundColor (if (AIR_OP_selectedTargetType == "LOCATION") then {[0.3, 0.3, 0.7, 1]} else {[0.2, 0.2, 0.2, 1]});
    _locationBtn ctrlSetEventHandler ["ButtonClick", "
        AIR_OP_selectedTargetType = 'LOCATION'; 
        [] call fnc_updateTargetTypeButtons; 
        [] call fnc_updateAirOpsUI;
        [true] call AIR_OP_fnc_toggleLocationMarkers;
        [false] call AIR_OP_fnc_toggleHVTMarkers;
        systemChat 'Switched to Locations view';
    "];
    _locationBtn ctrlCommit 0;
    
    // Create HVT button
    private _hvtBtn = _display ctrlCreate ["RscButton", 9007];
    _hvtBtn ctrlSetPosition [0.38 * safezoneW + safezoneX, 0.115 * safezoneH + safezoneY, 0.22 * safezoneW, 0.03 * safezoneH];
    _hvtBtn ctrlSetText "HIGH-VALUE TARGETS";
    _hvtBtn ctrlSetTextColor [1, 1, 1, 1];
    _hvtBtn ctrlSetBackgroundColor (if (AIR_OP_selectedTargetType == "HVT") then {[0.3, 0.3, 0.7, 1]} else {[0.2, 0.2, 0.2, 1]});
    _hvtBtn ctrlSetEventHandler ["ButtonClick", "
        AIR_OP_selectedTargetType = 'HVT'; 
        [] call fnc_updateTargetTypeButtons; 
        [] call fnc_updateAirOpsUI;
        [false] call AIR_OP_fnc_toggleLocationMarkers;
        [] call AIR_OP_fnc_forceRefreshHVTMarkers;
        [true] call AIR_OP_fnc_toggleHVTMarkers;
        systemChat 'Switched to High-Value Targets view';
    "];
    _hvtBtn ctrlCommit 0;
    
    // Store buttons in uiNamespace for updating
    uiNamespace setVariable ["AIROPS_locationBtn", _locationBtn];
    uiNamespace setVariable ["AIROPS_hvtBtn", _hvtBtn];
    
    // Create aircraft selection combo
    private _aircraftLabel = _display ctrlCreate ["RscText", 9008];
    _aircraftLabel ctrlSetPosition [0.67 * safezoneW + safezoneX, 0.05 * safezoneH + safezoneY, 0.12 * safezoneW, 0.04 * safezoneH];
    _aircraftLabel ctrlSetText "Aircraft:";
    _aircraftLabel ctrlCommit 0;
    
    private _aircraftCombo = _display ctrlCreate ["RscCombo", 9009];
    _aircraftCombo ctrlSetPosition [0.67 * safezoneW + safezoneX, 0.055 * safezoneH + safezoneY, 0.22 * safezoneW, 0.04 * safezoneH];
    _aircraftCombo ctrlCommit 0;
    
    // Add available aircraft
    [] call fnc_populateAircraftCombo;
    
    // ===== CREATE MAP CONTROL =====
    // Create map control - SMALLER map to allow more room for info panels
    private _map = _display ctrlCreate ["RscMapControl", 9010];
    _map ctrlSetPosition [0.12 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.4 * safezoneW, 0.57 * safezoneH]; // Reduced width from 0.5 to 0.4
    _map ctrlSetBackgroundColor [0.969, 0.957, 0.949, 1.0];
    _map ctrlCommit 0;
    
    // ===== CREATE INFO PANELS - IMPROVED LAYOUT =====
    // Create aircraft info panel - NOW ON LEFT SIDE
    private _infoPanel = _display ctrlCreate ["RscText", 9100];
    _infoPanel ctrlSetPosition [0.53 * safezoneW + safezoneX, 0.15 * safezoneH + safezoneY, 0.35 * safezoneW, 0.2 * safezoneH]; // Wider panel
    _infoPanel ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _infoPanel ctrlCommit 0;

    // Create aircraft info text
    private _infoText = _display ctrlCreate ["RscStructuredText", 9101];
    _infoText ctrlSetPosition [0.54 * safezoneW + safezoneX, 0.16 * safezoneH + safezoneY, 0.33 * safezoneW, 0.18 * safezoneH]; // Wider text area
    _infoText ctrlSetStructuredText parseText "Select an aircraft to view details.";
    _infoText ctrlCommit 0;

    // Create target info panel
    private _targetPanel = _display ctrlCreate ["RscText", 9110];
    _targetPanel ctrlSetPosition [0.53 * safezoneW + safezoneX, 0.36 * safezoneH + safezoneY, 0.35 * safezoneW, 0.2 * safezoneH]; // Wider panel
    _targetPanel ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _targetPanel ctrlCommit 0;

    // Create target info text
    private _targetText = _display ctrlCreate ["RscStructuredText", 9111];
    _targetText ctrlSetPosition [0.54 * safezoneW + safezoneX, 0.37 * safezoneH + safezoneY, 0.33 * safezoneW, 0.18 * safezoneH]; // Wider text area
    _targetText ctrlSetStructuredText parseText "Select a target on the map.";
    _targetText ctrlCommit 0;

    // ===== CREATE MISSION PANEL =====
    // Create mission panel - IMPROVED VISIBILITY
    private _missionPanel = _display ctrlCreate ["RscText", 9200];
    _missionPanel ctrlSetPosition [0.53 * safezoneW + safezoneX, 0.57 * safezoneH + safezoneY, 0.35 * safezoneW, 0.15 * safezoneH]; // Wider panel
    _missionPanel ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _missionPanel ctrlCommit 0;

    // Create mission panel title
    private _missionTitle = _display ctrlCreate ["RscText", 9201];
    _missionTitle ctrlSetPosition [0.53 * safezoneW + safezoneX, 0.57 * safezoneH + safezoneY, 0.35 * safezoneW, 0.04 * safezoneH]; // Wider title
    _missionTitle ctrlSetText "Available Missions";
    _missionTitle ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _missionTitle ctrlCommit 0;

    // ===== CREATE MISSION BUTTONS =====
    // Create mission buttons placeholder - IMPROVED LAYOUT
    private _buttonHeight = 0.04 * safezoneH;
    private _buttonMargin = 0.01 * safezoneH;
    private _buttonY = 0.62 * safezoneH + safezoneY;

    for "_i" from 0 to 4 do {
        private _button = _display ctrlCreate ["RscButton", 9300 + _i];
        _button ctrlSetPosition [
            0.54 * safezoneW + safezoneX,
            _buttonY + (_i * (_buttonHeight + _buttonMargin)),
            0.33 * safezoneW, // Wider buttons
            _buttonHeight
        ];
        _button ctrlSetText "";
        _button ctrlEnable false;
        _button ctrlShow false;
        _button ctrlCommit 0;
    };
    
    // ===== CREATE AIRCRAFT CONTROL PANEL =====
    // Create control panel
    private _controlPanel = _display ctrlCreate ["RscText", 9400];
    _controlPanel ctrlSetPosition [0.12 * safezoneW + safezoneX, 0.73 * safezoneH + safezoneY, 0.76 * safezoneW, 0.06 * safezoneH];
    _controlPanel ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _controlPanel ctrlCommit 0;
    
    // Create control panel title
    private _controlTitle = _display ctrlCreate ["RscText", 9401];
    _controlTitle ctrlSetPosition [0.12 * safezoneW + safezoneX, 0.73 * safezoneH + safezoneY, 0.15 * safezoneW, 0.03 * safezoneH];
    _controlTitle ctrlSetText "Aircraft Control";
    _controlTitle ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
    _controlTitle ctrlCommit 0;
    
    // Create RTB button
    private _rtbButton = _display ctrlCreate ["RscButton", 9402];
    _rtbButton ctrlSetPosition [0.28 * safezoneW + safezoneX, 0.735 * safezoneH + safezoneY, 0.12 * safezoneW, 0.04 * safezoneH];
    _rtbButton ctrlSetText "Return To Base";
    _rtbButton ctrlSetBackgroundColor [0.5, 0.1, 0.1, 1];
    _rtbButton ctrlSetEventHandler ["ButtonClick", "[] call AIR_OP_fnc_returnToBase"];
    _rtbButton ctrlCommit 0;
    
    // Create altitude button
    private _altButton = _display ctrlCreate ["RscButton", 9403];
    _altButton ctrlSetPosition [0.41 * safezoneW + safezoneX, 0.735 * safezoneH + safezoneY, 0.12 * safezoneW, 0.04 * safezoneH];
    _altButton ctrlSetText "Set Altitude";
    _altButton ctrlSetBackgroundColor [0.1, 0.3, 0.6, 1];
    _altButton ctrlSetEventHandler ["ButtonClick", "[] call AIR_OP_fnc_setAltitude"];
    _altButton ctrlCommit 0;
    
    // Create speed button
    private _speedButton = _display ctrlCreate ["RscButton", 9404];
    _speedButton ctrlSetPosition [0.54 * safezoneW + safezoneX, 0.735 * safezoneH + safezoneY, 0.12 * safezoneW, 0.04 * safezoneH];
    _speedButton ctrlSetText "Set Speed";
    _speedButton ctrlSetBackgroundColor [0.1, 0.5, 0.3, 1];
    _speedButton ctrlSetEventHandler ["ButtonClick", "[] call AIR_OP_fnc_setSpeed"];
    _speedButton ctrlCommit 0;
    
    // Create combat mode button
    private _combatButton = _display ctrlCreate ["RscButton", 9405];
    _combatButton ctrlSetPosition [0.67 * safezoneW + safezoneX, 0.735 * safezoneH + safezoneY, 0.12 * safezoneW, 0.04 * safezoneH];
    _combatButton ctrlSetText "Combat Mode";
    _combatButton ctrlSetBackgroundColor [0.6, 0.3, 0.1, 1];
    _combatButton ctrlSetEventHandler ["ButtonClick", "[] call AIR_OP_fnc_setCombatMode"];
    _combatButton ctrlCommit 0;
    
    // Create confirm mission button
    private _confirmButton = _display ctrlCreate ["RscButton", 9500];
    _confirmButton ctrlSetPosition [0.72 * safezoneW + safezoneX, 0.64 * safezoneH + safezoneY, 0.15 * safezoneW, 0.05 * safezoneH];
    _confirmButton ctrlSetText "Confirm Mission";
    _confirmButton ctrlSetBackgroundColor [0.2, 0.6, 0.2, 1];
    _confirmButton ctrlEnable false;
    _confirmButton ctrlSetEventHandler ["ButtonClick", "[] call fnc_confirmAirMission"];
    _confirmButton ctrlCommit 0;

    private _cancelButton = _display ctrlCreate ["RscButton", 9501];
    _cancelButton ctrlSetPosition [0.54 * safezoneW + safezoneX, 0.64 * safezoneH + safezoneY, 0.07 * safezoneW, 0.05 * safezoneH];
    _cancelButton ctrlSetText "Cancel";
    _cancelButton ctrlSetBackgroundColor [0.6, 0.2, 0.2, 1];
    _cancelButton ctrlSetEventHandler ["ButtonClick", "closeDialog 0"];
    _cancelButton ctrlCommit 0;
    
    // ===== MAP INTERACTION =====
    // Add map click handler - RENAMED FUNCTIONS to avoid conflicts
    _map ctrlAddEventHandler ["MouseButtonClick", {
        params ["_control", "_button", "_xPos", "_yPos", "_shift", "_ctrl", "_alt"];
        
        if (_button == 0) then { // Left click
            private _worldPos = _control ctrlMapScreenToWorld [_xPos, _yPos];
            
            // Different handling based on target type
            if (AIR_OP_selectedTargetType == "LOCATION") then {
                // Find closest location
                private _closestIndex = -1;
                private _closestDist = 1000000;
                
                {
                    private _locationPos = _x select 3;
                    private _dist = _worldPos distance _locationPos;
                    
                    if (_dist < _closestDist && _dist < 300) then {
                        _closestDist = _dist;
                        _closestIndex = _forEachIndex;
                    };
                } forEach MISSION_LOCATIONS;
                
                if (_closestIndex != -1) then {
                    [_closestIndex] call AIR_OP_fnc_selectLocation;
                };
            } else {
                // Find closest HVT
                private _closestIndex = -1;
                private _closestDist = 1000000;
                
                {
                    private _hvtPos = _x select 3;
                    private _dist = _worldPos distance _hvtPos;
                    
                    if (_dist < _closestDist && _dist < 300) then {
                        _closestDist = _dist;
                        _closestIndex = _forEachIndex;
                    };
                } forEach HVT_TARGETS;
                
                if (_closestIndex != -1) then {
                    [_closestIndex] call AIR_OP_fnc_selectHVT;
                };
            };
        };
    }];
    
    // Set initial marker visibility based on the selected target type
    if (AIR_OP_selectedTargetType == "LOCATION") then {
        [true] call AIR_OP_fnc_toggleLocationMarkers;
        [false] call AIR_OP_fnc_toggleHVTMarkers;
    } else {
        [false] call AIR_OP_fnc_toggleLocationMarkers;
        [true] call AIR_OP_fnc_toggleHVTMarkers;
    };
    
    // ===== DIALOG CLOSURE =====
    // Add handler for dialog closure
    _display displayAddEventHandler ["Unload", {
        AIR_OP_uiOpen = false;
        
        // Save operation name before closing
        private _opNameInput = findDisplay -1 displayCtrl 9004;
        if (!isNull _opNameInput) then {
            AIR_OP_operationName = ctrlText _opNameInput;
        };
    }];
    
    // Start UI update loop
    [] spawn {
        while {AIR_OP_uiOpen && !isNull findDisplay -1} do {
            call fnc_updateAirOpsUI;
            sleep 0.5;
        };
    };
};

// Function to populate the aircraft combo box
fnc_populateAircraftCombo = {
    private _display = findDisplay -1;
    private _aircraftCombo = _display displayCtrl 9009;
    
    if (isNull _aircraftCombo) exitWith {
        diag_log "AIR_OPS UI: Aircraft combo not found";
    };
    
    // Clear combo box
    lbClear _aircraftCombo;
    
    // Get deployed aircraft
    private _deployedAircraft = [] call AIR_OP_fnc_getDeployedAircraft;
    
    // Exit if no aircraft available
    if (count _deployedAircraft == 0) exitWith {
        private _index = _aircraftCombo lbAdd "No aircraft deployed";
        _aircraftCombo lbSetData [_index, "none"];
        _aircraftCombo lbSetCurSel 0;
    };
    
    // Add each aircraft with its type and status
    {
        private _aircraft = _x;
        private _aircraftDetails = [_aircraft] call AIR_OP_fnc_getAircraftDetails;
        
        _aircraftDetails params ["_type", "_displayName", "_specialization", "_fuel", "_damage", "_weaponsData", "_crew", "_currentMission"];
        
        // Format display text based on specialization and current mission
        private _displayText = format ["%1 (%2)", _displayName, _specialization];
        
        if (_currentMission != "") then {
            _displayText = _displayText + format [" - %1", toUpper _currentMission];
        };
        
        // Add to combo
        private _index = _aircraftCombo lbAdd _displayText;
        
        // Store aircraft as variable name for retrieval
        private _varName = format ["AIR_OP_AIRCRAFT_%1", _forEachIndex];
        missionNamespace setVariable [_varName, _aircraft];
        _aircraftCombo lbSetData [_index, _varName];
        
        // Set color based on status
        if (_currentMission != "") then {
            _aircraftCombo lbSetColor [_index, [0.8, 0.8, 0.0, 1]]; // Yellow for active mission
        } else {
            if (_fuel < 0.3 || _damage > 0.3) then {
                _aircraftCombo lbSetColor [_index, [1, 0.5, 0.5, 1]]; // Red for low fuel or damage
            } else {
                _aircraftCombo lbSetColor [_index, [0.7, 1, 0.7, 1]]; // Green for ready
            };
        };
    } forEach _deployedAircraft;
    
    // Add handler for selection change
    _aircraftCombo ctrlRemoveAllEventHandlers "LBSelChanged";
    _aircraftCombo ctrlAddEventHandler ["LBSelChanged", {
        params ["_control", "_selectedIndex"];
        
        private _aircraftVar = _control lbData _selectedIndex;
        private _aircraft = missionNamespace getVariable [_aircraftVar, objNull];
        
        AIR_OP_selectedAircraft = _aircraft;
        [] call fnc_updateAircraftInfo;
        [] call fnc_updateAvailableMissions;
    }];
    
    // Select first item by default
    if (lbSize _aircraftCombo > 0) then {
        _aircraftCombo lbSetCurSel 0;
    };
};

// Function to update aircraft info panel
fnc_updateAircraftInfo = {
    private _display = findDisplay -1;
    private _infoText = _display displayCtrl 9101;
    
    if (isNull _infoText) exitWith {};
    
    // If no aircraft selected, show default message
    if (isNull AIR_OP_selectedAircraft) exitWith {
        _infoText ctrlSetStructuredText parseText "Select an aircraft to view details.";
    };
    
    // Get aircraft details
    private _details = [AIR_OP_selectedAircraft] call AIR_OP_fnc_getAircraftDetails;
    
    _details params ["_type", "_displayName", "_specialization", "_fuel", "_damage", "_weaponsData", "_crew", "_currentMission"];
    
    // Calculate fuel and damage color/text
    private _fuelPercent = round(_fuel * 100);
    private _fuelColor = switch (true) do {
        case (_fuelPercent < 20): {"#ff4444"};
        case (_fuelPercent < 50): {"#ffaa44"};
        default {"#88ff88"};
    };
    
    private _damagePercent = round(_damage * 100);
    private _damageColor = switch (true) do {
        case (_damagePercent > 50): {"#ff4444"};
        case (_damagePercent > 25): {"#ffaa44"};
        default {"#88ff88"};
    };
    
    // Format weapons info
    private _weaponsText = "";
    {
        _x params ["_weapon", "_ammo", "_maxAmmo"];
        
        // Get weapon display name
        private _weaponName = getText (configFile >> "CfgWeapons" >> _weapon >> "displayName");
        if (_weaponName == "") then {
            // Try to extract name from class
            _weaponName = (_weapon splitString "_") select ((count (_weapon splitString "_")) - 1);
            _weaponName = [_weaponName, 0, 1] call BIS_fnc_toUpper + ([_weaponName, 1] call BIS_fnc_trimString);
        };
        
        // Calculate ammo percentage and color
        private _ammoPercent = round((_ammo / _maxAmmo) * 100);
        private _ammoColor = switch (true) do {
            case (_ammoPercent < 20): {"#ff4444"};
            case (_ammoPercent < 50): {"#ffaa44"};
            default {"#88ff88"};
        };
        
        _weaponsText = _weaponsText + format ["<t size='0.8'><t color='#aaaaff'>%1:</t> <t color='%2'>%3%%</t></t><br/>", 
            _weaponName, _ammoColor, _ammoPercent];
    } forEach _weaponsData;
    
    if (_weaponsText == "") then {
        _weaponsText = "<t size='0.8'>(No weapons)</t>";
    };
    
    // Format crew info
    private _crewText = "";
    {
        _x params ["_name", "_role"];
        _crewText = _crewText + format ["<t size='0.8'><t color='#aaaaff'>%1:</t> %2</t><br/>", _role, _name];
    } forEach _crew;
    
    if (_crewText == "") then {
        _crewText = "<t size='0.8'>(No crew)</t>";
    };
    
    // Build full info text
    private _text = format [
        "<t size='1.2' align='center'>%1</t><br/>" +
        "<t align='center' size='0.9'>%2</t><br/><br/>" +
        "<t><t color='#aaaaff'>Fuel:</t> <t color='%3'>%4%%</t> | <t color='#aaaaff'>Damage:</t> <t color='%5'>%6%%</t></t><br/><br/>" +
        "<t size='0.9'><t color='#aaaaff'>Weapons:</t></t><br/>%7<br/>" +
        "<t size='0.9'><t color='#aaaaff'>Crew:</t></t><br/>%8",
        _displayName,
        _specialization,
        _fuelColor, _fuelPercent,
        _damageColor, _damagePercent,
        _weaponsText,
        _crewText
    ];
    
    _infoText ctrlSetStructuredText parseText _text;
};

// Function to update target info panel
fnc_updateTargetInfo = {
    private _display = findDisplay -1;
    private _targetText = _display displayCtrl 9111;
    
    if (isNull _targetText) exitWith {};
    
    // If no target selected, show default message
    if (AIR_OP_selectedTarget == -1) exitWith {
        _targetText ctrlSetStructuredText parseText "Select a target on the map.";
    };
    
    // Get target info based on type
    private _targetName = "Unknown";
    private _targetType = "Unknown";
    private _targetIntel = 0;
    private _targetPos = [0,0,0];
    private _targetDescription = "No information available.";
    
    if (AIR_OP_selectedTargetType == "LOCATION") then {
        if (AIR_OP_selectedTarget >= 0 && AIR_OP_selectedTarget < count MISSION_LOCATIONS) then {
            private _locationData = MISSION_LOCATIONS select AIR_OP_selectedTarget;
            _targetName = _locationData select 1;
            _targetType = _locationData select 2;
            _targetPos = _locationData select 3;
            _targetIntel = _locationData select 4;
            
            // Get briefing based on intel level
            _targetDescription = [AIR_OP_selectedTarget] call fnc_getLocationBriefing;
        };
    } else {
        // HVT target
        if (AIR_OP_selectedTarget >= 0 && AIR_OP_selectedTarget < count HVT_TARGETS) then {
            private _hvtData = HVT_TARGETS select AIR_OP_selectedTarget;
            _targetName = _hvtData select 1;
            _targetType = _hvtData select 2;
            _targetPos = _hvtData select 3;
            _targetIntel = _hvtData select 4;
            
            // Get briefing based on intel level
            _targetDescription = [AIR_OP_selectedTarget] call fnc_getHVTBriefing;
        };
    };
    
    // Calculate intel color
    private _intelColor = switch (true) do {
        case (_targetIntel >= 75): {"#88ff88"};
        case (_targetIntel >= 25): {"#ffaa44"};
        default {"#ff4444"};
    };
    
    // Build target info text
    private _text = format [
        "<t size='1.2' align='center'>%1</t><br/>" +
        "<t align='center' size='0.9'>%2</t><br/><br/>" +
        "<t><t color='#aaaaff'>Intel:</t> <t color='%3'>%4%%</t></t><br/><br/>" +
        "<t size='0.8'>%5</t>",
        _targetName,
        _targetType,
        _intelColor, round _targetIntel,
        _targetDescription
    ];
    
    _targetText ctrlSetStructuredText parseText _text;
};

// Function to update available missions based on aircraft and target
fnc_updateAvailableMissions = {
    private _display = findDisplay -1;
    
    if (isNull AIR_OP_selectedAircraft || AIR_OP_selectedTarget == -1) then {
        // Hide all mission buttons
        for "_i" from 0 to 4 do {
            private _button = _display displayCtrl (9300 + _i);
            _button ctrlShow false;
            _button ctrlEnable false;
        };
        
        // Disable confirm button
        private _confirmButton = _display displayCtrl 9500;
        _confirmButton ctrlEnable false;
        
        // Reset selected mission
        AIR_OP_selectedMission = "";
    } else {
        // Get available missions for this aircraft
        private _availableMissions = [AIR_OP_selectedAircraft] call AIR_OP_fnc_getAvailableMissions;
        
        // Get target intel
        private _targetIntel = 0;
        
        if (AIR_OP_selectedTargetType == "LOCATION") then {
            if (AIR_OP_selectedTarget >= 0 && AIR_OP_selectedTarget < count MISSION_LOCATIONS) then {
                _targetIntel = (MISSION_LOCATIONS select AIR_OP_selectedTarget) select 4;
            };
        } else {
            if (AIR_OP_selectedTarget >= 0 && AIR_OP_selectedTarget < count HVT_TARGETS) then {
                _targetIntel = (HVT_TARGETS select AIR_OP_selectedTarget) select 4;
            };
        };
        
        // Check if aircraft already has a mission
        private _currentMission = "";
        {
            if ((_x select 1) == AIR_OP_selectedAircraft) exitWith {
                _currentMission = _x select 2;
            };
        } forEach AIR_OP_activeMissions;
        
        // Hide all buttons first
        for "_i" from 0 to 4 do {
            private _button = _display displayCtrl (9300 + _i);
            _button ctrlShow false;
            _button ctrlEnable false;
        };
        
        // Show and enable available mission buttons
        private _buttonCount = 0;
        
        {
            _x params ["_missionType", "_missionName", "_missionDesc", "_requiredIntel"];
            
            // Check if intel is sufficient
            private _intelOK = _targetIntel >= _requiredIntel;
            
            // Only add if we have enough buttons and intel is sufficient
            if (_buttonCount < 5 && _intelOK) then {
                private _button = _display displayCtrl (9300 + _buttonCount);
                
                // Show the button
                _button ctrlShow true;
                _button ctrlSetText _missionName;
                _button setVariable ["missionType", _missionType];
                
                // Enable if not already on mission
                _button ctrlEnable (_currentMission == "");
                
                // Update button color if selected
                if (AIR_OP_selectedMission == _missionType) then {
                    _button ctrlSetBackgroundColor [0.3, 0.3, 0.7, 1];
                } else {
                    _button ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
                };
                
                // Add tooltip
                _button ctrlSetTooltip _missionDesc;
                
                // Add click handler
                _button ctrlRemoveAllEventHandlers "ButtonClick";
                _button ctrlSetEventHandler ["ButtonClick", format ["['%1'] call fnc_selectMission", _missionType]];
                
                _buttonCount = _buttonCount + 1;
            };
        } forEach _availableMissions;
        
        // If no missions are available, show a placeholder
        if (_buttonCount == 0) then {
            private _button = _display displayCtrl 9300;
            _button ctrlShow true;
            
            if (_currentMission != "") then {
                _button ctrlSetText format ["ON MISSION: %1", toUpper _currentMission];
                _button ctrlSetTooltip "Aircraft is already on a mission. Cancel current mission to assign a new one.";
                
                // Add cancel mission button
                private _cancelMissionBtn = _display displayCtrl 9301;
                _cancelMissionBtn ctrlShow true;
                _cancelMissionBtn ctrlEnable true;
                _cancelMissionBtn ctrlSetText "CANCEL MISSION";
                _cancelMissionBtn ctrlSetBackgroundColor [0.7, 0.2, 0.2, 1];
                _cancelMissionBtn ctrlSetEventHandler ["ButtonClick", "
                    if (!isNull AIR_OP_selectedAircraft) then {
                        [AIR_OP_selectedAircraft] call AIR_OP_fnc_cancelMission;
                        [] call fnc_populateAircraftCombo;
                        [] call fnc_updateAircraftInfo;
                        [] call fnc_updateAvailableMissions;
                    };
                "];
            } else {
                _button ctrlSetText "NO MISSIONS AVAILABLE";
                _button ctrlSetTooltip "Aircraft cannot perform missions at this target, or intel level is insufficient.";
            };
            
            _button ctrlEnable false;
        };
        
        // Update confirm button
        private _confirmButton = _display displayCtrl 9500;
        _confirmButton ctrlEnable (AIR_OP_selectedMission != "" && _currentMission == "");
    };
};

// Function to select a mission
fnc_selectMission = {
    params ["_missionType"];
    
    private _display = findDisplay -1;
    
    // Update selected mission
    AIR_OP_selectedMission = _missionType;
    
    // Update mission buttons
    for "_i" from 0 to 4 do {
        private _button = _display displayCtrl (9300 + _i);
        
        // Only update visible buttons
        if (ctrlShown _button) then {
            private _btnMissionType = _button getVariable ["missionType", ""];
            
            if (_btnMissionType == _missionType) then {
                _button ctrlSetBackgroundColor [0.3, 0.3, 0.7, 1];
            } else {
                _button ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
            };
        };
    };
    
    // Update confirm button
    private _confirmButton = _display displayCtrl 9500;
    _confirmButton ctrlEnable (AIR_OP_selectedMission != "");
};

// Function to select a location on the map - RENAMED to avoid conflicts
AIR_OP_fnc_selectLocation = {
    params ["_locationIndex"];
    
    private _display = findDisplay -1;
    
    // Safety check for valid location index
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log "AIR_OPS UI: Invalid location index";
    };
    
    // Update selected location
    AIR_OP_selectedTarget = _locationIndex;
    AIR_OP_selectedTargetType = "LOCATION";
    
    // Update target info
    [] call fnc_updateTargetInfo;
    
    // Update available missions
    [] call fnc_updateAvailableMissions;
};

// Function to select an HVT on the map - RENAMED to avoid conflicts
AIR_OP_fnc_selectHVT = {
    params ["_hvtIndex"];
    
    private _display = findDisplay -1;
    
    // Safety check for valid HVT index
    if (_hvtIndex < 0 || _hvtIndex >= count HVT_TARGETS) exitWith {
        diag_log "AIR_OPS UI: Invalid HVT index";
    };
    
    // Update selected target
    AIR_OP_selectedTarget = _hvtIndex;
    AIR_OP_selectedTargetType = "HVT";
    
    // Update target info
    [] call fnc_updateTargetInfo;
    
    // Update available missions
    [] call fnc_updateAvailableMissions;
};

// Function to update target type buttons
fnc_updateTargetTypeButtons = {
    private _locationBtn = uiNamespace getVariable ["AIROPS_locationBtn", controlNull];
    private _hvtBtn = uiNamespace getVariable ["AIROPS_hvtBtn", controlNull];
    
    if (!isNull _locationBtn && !isNull _hvtBtn) then {
        _locationBtn ctrlSetBackgroundColor (if (AIR_OP_selectedTargetType == "LOCATION") then {[0.3, 0.3, 0.7, 1]} else {[0.2, 0.2, 0.2, 1]});
        _hvtBtn ctrlSetBackgroundColor (if (AIR_OP_selectedTargetType == "HVT") then {[0.3, 0.3, 0.7, 1]} else {[0.2, 0.2, 0.2, 1]});
    };
};

// Function to confirm and create air mission
fnc_confirmAirMission = {
    private _display = findDisplay -1;
    
    // Get operation name
    private _opNameInput = _display displayCtrl 9004;
    AIR_OP_operationName = ctrlText _opNameInput;
    
    // Validate selections
    if (isNull AIR_OP_selectedAircraft) exitWith {
        hint "No aircraft selected for mission.";
    };
    
    if (AIR_OP_selectedTarget == -1) exitWith {
        hint "No target selected for mission.";
    };
    
    if (AIR_OP_selectedMission == "") exitWith {
        hint "No mission type selected.";
    };
    
    // Create the mission
    private _missionID = [AIR_OP_selectedAircraft, AIR_OP_selectedMission, AIR_OP_selectedTarget, AIR_OP_selectedTargetType] call AIR_OP_fnc_createMission;
    
    if (_missionID != "") then {
        // Mission created successfully, refresh UI
        [] call fnc_populateAircraftCombo;
        [] call fnc_updateAircraftInfo;
        [] call fnc_updateAvailableMissions;
        
        // Provide feedback
        private _missionName = "";
        {
            if (_x select 0 == AIR_OP_selectedMission) exitWith {
                _missionName = _x select 1;
            };
        } forEach AIR_OP_MISSION_TYPES;
        
        // Get target name
        private _targetName = "Unknown";
        
        if (AIR_OP_selectedTargetType == "LOCATION") then {
            if (AIR_OP_selectedTarget >= 0 && AIR_OP_selectedTarget < count MISSION_LOCATIONS) then {
                _targetName = (MISSION_LOCATIONS select AIR_OP_selectedTarget) select 1;
            };
        } else {
            if (AIR_OP_selectedTarget >= 0 && AIR_OP_selectedTarget < count HVT_TARGETS) then {
                _targetName = (HVT_TARGETS select AIR_OP_selectedTarget) select 1;
            };
        };
        
        // Success message
        hint parseText format [
            "<t size='1.2' align='center' color='#88ff88'>%1 Mission Assigned</t><br/><br/>" +
            "<t align='center'>Target: %2</t><br/><br/>" +
            "<t size='0.8' align='center'>Aircraft is en route to target area.</t>",
            _missionName,
            _targetName
        ];
        
        // Reset selections
        AIR_OP_selectedMission = "";
        
        // Don't close dialog to allow assigning more missions
    } else {
        hint "Error creating mission. Please try again.";
    };
};

// Main UI update function
fnc_updateAirOpsUI = {
    // Update aircraft info if an aircraft is selected
    if (!isNull AIR_OP_selectedAircraft) then {
        [] call fnc_updateAircraftInfo;
    };
    
    // Update target info if a target is selected
    if (AIR_OP_selectedTarget != -1) then {
        [] call fnc_updateTargetInfo;
    };
    
    // Update available missions based on current selections
    [] call fnc_updateAvailableMissions;
};

// Function to toggle location markers - RENAMED for Air Ops system
AIR_OP_fnc_toggleLocationMarkers = {
    params [["_show", true]];
    
    // Store current alpha values to restore later
    if (isNil "AIR_OP_storedMarkerAlphas") then {
        AIR_OP_storedMarkerAlphas = [];
        
        {
            private _markerName = format ["task_location_%1", _forEachIndex];
            if (markerType _markerName != "") then {
                AIR_OP_storedMarkerAlphas pushBack [_markerName, markerAlpha _markerName];
            };
        } forEach MISSION_LOCATIONS;
    };
    
    // Set all location markers to desired alpha
    {
        _x params ["_markerName", "_originalAlpha"];
        if (markerType _markerName != "") then {
            _markerName setMarkerAlphaLocal (if (_show) then {_originalAlpha} else {0});
        };
    } forEach AIR_OP_storedMarkerAlphas;
};

// Function to toggle HVT markers - RENAMED for Air Ops system
AIR_OP_fnc_toggleHVTMarkers = {
    params [["_show", true]];
    
    // Store current alpha values to restore later
    if (isNil "AIR_OP_storedHVTAlphas") then {
        AIR_OP_storedHVTAlphas = [];
        
        {
            if (_forEachIndex < count HVT_markers) then {
                private _markerName = HVT_markers select _forEachIndex;
                if (markerType _markerName != "") then {
                    AIR_OP_storedHVTAlphas pushBack [_markerName, markerAlpha _markerName];
                };
            };
        } forEach HVT_TARGETS;
    };
    
    // Set all HVT markers to desired alpha
    {
        _x params ["_markerName", "_originalAlpha"];
        if (markerType _markerName != "") then {
            _markerName setMarkerAlphaLocal (if (_show) then {_originalAlpha} else {0});
        };
    } forEach AIR_OP_storedHVTAlphas;
};

// Function to refresh HVT markers - RENAMED for Air Ops system
AIR_OP_fnc_forceRefreshHVTMarkers = {
    {
        if (_forEachIndex < count HVT_TARGETS) then {
            [_forEachIndex] call fnc_forceSingleHVTRefresh;
        };
    } forEach HVT_TARGETS;
    
    true
};