// Updated Recruitment System Script

// Configuration
MISSION_recruitmentConfig = [
    ["manpowerCost", 1],    // Manpower cost per unit
    ["fuelCost", 10],       // Base fuel cost per unit
    ["cooldownTime", 30],  // Cooldown time in seconds
    ["maxRecruits", 10],    // Maximum number of recruits per batch
    ["planeType", "LIB_C47_RAF"],  // Type of plane to use
    ["unitType", "JMSSA_gb_rifle_rifle"]  // Type of unit to spawn
];

// Global variables
if (isNil "MISSION_availableManpower") then { MISSION_availableManpower = 100 };  // Starting manpower
if (isNil "MISSION_availableFuel") then { MISSION_availableFuel = 1000 };         // Starting fuel
MISSION_recruitmentCooldown = false;

// Function to calculate recruitment cost
fnc_calculateRecruitmentCost = {
    params ["_numUnits"];
    private _baseCost = MISSION_recruitmentConfig select 1 select 1;
    private _totalCost = 0;
    for "_i" from 1 to _numUnits do {
        _totalCost = _totalCost + (_baseCost * (1 + (_i - 1) * 0.1));
    };
    round _totalCost
};

// Function to show the recruitment selection dialog
fnc_showRecruitmentDialog = {
    if (!dialog) then {
        createDialog "RscDisplayEmpty";
    };
    
    private _display = findDisplay -1;
    
    // Create background
    private _background = _display ctrlCreate ["RscText", -1];
    _background ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.3 * safezoneH + safezoneY, 0.4 * safezoneW, 0.4 * safezoneH];
    _background ctrlSetBackgroundColor [0, 0, 0, 0.7];
    _background ctrlCommit 0;
    
    // Create title
    private _title = _display ctrlCreate ["RscText", -1];
    _title ctrlSetPosition [0.3 * safezoneW + safezoneX, 0.3 * safezoneH + safezoneY, 0.4 * safezoneW, 0.04 * safezoneH];
    _title ctrlSetText "Recruit Units";
    _title ctrlSetBackgroundColor [0.1, 0.1, 0.1, 1];
    _title ctrlCommit 0;
    
    // Create resources text
    private _resourcesText = _display ctrlCreate ["RscText", -1];
    _resourcesText ctrlSetPosition [0.31 * safezoneW + safezoneX, 0.35 * safezoneH + safezoneY, 0.38 * safezoneW, 0.04 * safezoneH];
    _resourcesText ctrlSetText format ["Manpower: %1 | Fuel: %2", MISSION_availableManpower, MISSION_availableFuel];
    _resourcesText ctrlCommit 0;
    
    // Create slider for unit selection
    private _slider = _display ctrlCreate ["RscSlider", 1901];
    _slider ctrlSetPosition [0.31 * safezoneW + safezoneX, 0.4 * safezoneH + safezoneY, 0.38 * safezoneW, 0.04 * safezoneH];
    _slider sliderSetRange [1, 10];
    _slider sliderSetPosition 1;
    _slider ctrlCommit 0;
    
    // Create text to show selected number of units
    private _unitCountText = _display ctrlCreate ["RscText", 1902];
    _unitCountText ctrlSetPosition [0.31 * safezoneW + safezoneX, 0.45 * safezoneH + safezoneY, 0.38 * safezoneW, 0.04 * safezoneH];
    _unitCountText ctrlSetText "Units to recruit: 1";
    _unitCountText ctrlCommit 0;
    
    // Add event handler to update text when slider moves
    _slider ctrlAddEventHandler ["SliderPosChanged", {
        params ["_control", "_newValue"];
        private _display = ctrlParent _control;
        private _unitCountText = _display displayCtrl 1902;
        _unitCountText ctrlSetText format ["Units to recruit: %1", round _newValue];
    }];
    
    // Create confirm button
    private _confirmButton = _display ctrlCreate ["RscButton", 1903];
    _confirmButton ctrlSetPosition [0.35 * safezoneW + safezoneX, 0.6 * safezoneH + safezoneY, 0.3 * safezoneW, 0.06 * safezoneH];
    _confirmButton ctrlSetText "Confirm Recruitment";
    _confirmButton ctrlSetEventHandler ["ButtonClick", "
        private _numUnits = round (sliderPosition 1901);
        [str _numUnits] call fnc_initiateRecruitment;
        closeDialog 0;
    "];
    
    // Create cancel button
    private _cancelButton = _display ctrlCreate ["RscButton", 1601];
    _cancelButton ctrlSetPosition [0.35 * safezoneW + safezoneX, 0.67 * safezoneH + safezoneY, 0.3 * safezoneW, 0.04 * safezoneH];
    _cancelButton ctrlSetText "Cancel";
    _cancelButton ctrlSetEventHandler ["ButtonClick", "closeDialog 0;"];
    _cancelButton ctrlCommit 0;
};

// Main recruitment function
fnc_initiateRecruitment = {
    params ["_numUnits"];
    
    // Ensure _numUnits is a number
    _numUnits = parseNumber _numUnits;
    
    if (_numUnits <= 0) exitWith {
        hint "Invalid number of units selected.";
    };
    
    if (MISSION_recruitmentCooldown) exitWith {
        hint "Recruitment is on cooldown. Please wait.";
    };
    
    private _manpowerCost = _numUnits * (MISSION_recruitmentConfig select 0 select 1);
    private _fuelCost = [_numUnits] call fnc_calculateRecruitmentCost;
    
    if (MISSION_availableManpower < _manpowerCost) exitWith {
        hint format ["Not enough manpower. Required: %1, Available: %2", _manpowerCost, MISSION_availableManpower];
    };
    
    if (MISSION_availableFuel < _fuelCost) exitWith {
        hint format ["Not enough fuel. Required: %1, Available: %2", _fuelCost, MISSION_availableFuel];
    };
    
    // Deduct resources
    MISSION_availableManpower = MISSION_availableManpower - _manpowerCost;
    MISSION_availableFuel = MISSION_availableFuel - _fuelCost;
    
    // Initiate spawning process
    [_numUnits] spawn fnc_spawnRecruits;
    
    // Start cooldown timer
    [] spawn fnc_recruitmentCooldown;
    
    hint format ["Recruiting %1 units. Manpower cost: %2, Fuel cost: %3", _numUnits, _manpowerCost, _fuelCost];
};

// Function to spawn recruits and manage plane movement
fnc_spawnRecruits = {
    params ["_numUnits"];
    
    private _planeType = (MISSION_recruitmentConfig select 4) select 1;
    private _unitType = (MISSION_recruitmentConfig select 5) select 1;
    
    diag_log format ["Spawning plane of type: %1", _planeType];
    diag_log format ["Spawning %1 units of type: %2", _numUnits, _unitType];
    
    // Spawn plane at marker 1
    private _spawnPos = getMarkerPos "recruit_spawn";
    private _plane = createVehicle [_planeType, _spawnPos, [], 0, "FLY"];
    _plane flyInHeight 300;
    
    // Create crew for the plane
    createVehicleCrew _plane;
    
    // Move plane to marker 2 (landing zone)
    private _landPos = getMarkerPos "recruit_land";
    _plane move _landPos;
    
    // Wait for the plane to reach the landing zone
    waitUntil {_plane distance _landPos < 200};
    
    // Prepare for landing
    _plane land "LAND";
    _plane flyInHeight 0;
    
    // Wait for the plane to touch down
    waitUntil {isTouchingGround _plane || {(getPos _plane) select 2 < 1}};
    
    // Ensure the plane comes to a complete stop
    //_plane setVelocity [0, 0, 0];
    
    // Additional wait to ensure the plane is stable
    sleep 120;
    
    diag_log "Plane has landed";
	
	// Ensure the plane comes to a complete stop
    _plane setVelocity [0, 0, 0];
    
    // Spawn and unload troops
    private _group = createGroup independent;
    for "_i" from 1 to _numUnits do {
        private _unit = _group createUnit [_unitType, getPos _plane, [], 0, "NONE"];
        _unit moveInCargo _plane;
    };
    
    // Unload troops
    {
        unassignVehicle _x;
        _x action ["Eject", _plane];
        sleep 0.5; // Small delay between each unit exiting
    } forEach units _group;
    
    // Wait for all units to exit the plane
    waitUntil {{vehicle _x != _plane} count units _group == count units _group};
    
    diag_log "All units have exited the plane";
    
    // Move troops to marker 3
    private _assemblyPos = getMarkerPos "recruit_assembly";
    _group move _assemblyPos;
    
    // Make units editable by Zeus
    {
        _x addCuratorEditableObjects [units _group, true];
    } forEach allCurators;
    
    // Wait a moment before taking off
    sleep 10;

    // Take off and move plane to marker 4 for despawn
    _plane flyInHeight 100;
    private _despawnPos = getMarkerPos "recruit_despawn";
    _plane doMove _despawnPos;

    // Wait for the plane to reach the despawn point
    waitUntil {
        sleep 1;
        (_plane distance _despawnPos < 200) || !(alive _plane)
    };

    // Check if the plane is still alive before deleting
    if (alive _plane) then {
        // Delete the plane's crew
        {
            deleteVehicle _x;
        } forEach (crew _plane);

        // Delete the plane
        deleteVehicle _plane;

        diag_log "Plane and crew have been deleted";
    } else {
        diag_log "Plane was destroyed before reaching despawn point";
    };

    diag_log "Recruitment process completed";
};

// Function to handle recruitment cooldown
fnc_recruitmentCooldown = {
    MISSION_recruitmentCooldown = true;
    private _cooldownTime = (MISSION_recruitmentConfig select 2) select 1;
    
    diag_log format ["Starting cooldown for %1 seconds", _cooldownTime];
    
    sleep _cooldownTime;
    
    MISSION_recruitmentCooldown = false;
    hint "Recruitment is now available again.";
    diag_log "Cooldown ended, recruitment available";
};

// Function to add fuel
fnc_addFuel = {
    params ["_amount"];
    MISSION_availableFuel = MISSION_availableFuel + _amount;
    hint format ["Added %1 fuel. Total fuel: %2", _amount, MISSION_availableFuel];
    diag_log format ["Added %1 fuel. New total: %2", _amount, MISSION_availableFuel];
};

// Function to add manpower
fnc_addManpower = {
    params ["_amount"];
    MISSION_availableManpower = MISSION_availableManpower + _amount;
    hint format ["Added %1 manpower. Total manpower: %2", _amount, MISSION_availableManpower];
    diag_log format ["Added %1 manpower. New total: %2", _amount, MISSION_availableManpower];
};

// Function to handle the recruitment order
fnc_recruitOrder = {
    [] call fnc_showRecruitmentDialog;
};
