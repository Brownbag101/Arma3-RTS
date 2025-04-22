// scripts/economy/economySystem.sqf
// Economy system for RTS game - manages resources and income

// Initialize global variables if not already defined
if (isNil "RTS_resources") then {
    // Main resource storage
    RTS_resources = [
        ["wood", 500],       // Starting with 500 wood
        ["iron", 300],       // Starting with 300 iron
        ["oil", 200],        // Starting with 200 oil
        ["rubber", 100],     // Starting with 100 rubber
        ["aluminum", 150],   // Starting with 150 aluminum
        ["training", 100],   // Starting with 100 training points
        ["manpower", 100],   // Starting with 100 manpower
        ["fuel", 1000],      // Starting with 1000 fuel
        ["research", 1000]   // Starting with 1000 research points - ADDED!
    ];
    
    // Resource income rates (per minute)
    RTS_resourceIncome = [
        ["wood", 10],        // 10 wood per minute
        ["iron", 5],         // 5 iron per minute
        ["oil", 3],          // 3 oil per minute
        ["rubber", 2],       // 2 rubber per minute
        ["aluminum", 2],     // 2 aluminum per minute
        ["training", 1],     // 1 training point per minute
        ["manpower", 2],     // 2 manpower per minute
        ["fuel", 5],         // 5 fuel per minute
        ["research", 2]      // 2 research points per minute - ADDED!
    ];
    
    // Last time resources were updated
    RTS_lastResourceUpdate = time;
};

// Resource icons and tooltips
RTS_resourceIcons = [
    ["wood", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\cargothrow_ca.paa", "Wood: Used for basic construction"],
    ["iron", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\cargomag_ca.paa", "Iron: Used for vehicles and weapons"],
    ["oil", "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\clear_ca.paa", "Oil: Used for fuel and advanced components"],
    ["rubber", "\a3\ui_f\data\gui\rsc\rscdisplayconfigure\preview_ca.paa", "Rubber: Used for vehicles and equipment"],
    ["aluminum", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\cargoput_ca.paa", "Aluminum: Used for aircraft and advanced equipment"],
    ["training", "\a3\ui_f\data\gui\rsc\rscdisplaymultiplayersetup\flag_blue_co.paa", "Training Points: Used to upgrade units"],
    ["manpower", "\a3\ui_f\data\gui\rsc\rscdisplayarsenal\face_ca.paa", "Manpower: Used to recruit new units"],
    ["fuel", "\a3\ui_f\data\gui\rsc\rscdisplayarcademap\fuel_ca.paa", "Fuel: Used for vehicle operations and transportation"]
];

// Function to get current amount of a specific resource
RTS_fnc_getResource = {
    params ["_resourceType"];
    
    private _amount = 0;
    {
        _x params ["_type", "_value"];
        if (_type == _resourceType) exitWith {
            _amount = _value;
        };
    } forEach RTS_resources;
    
    _amount
};

// Function to get current income rate of a specific resource
RTS_fnc_getResourceIncome = {
    params ["_resourceType"];
    
    private _rate = 0;
    {
        _x params ["_type", "_value"];
        if (_type == _resourceType) exitWith {
            _rate = _value;
        };
    } forEach RTS_resourceIncome;
    
    _rate
};

// Function to add or remove resources
// Can be called from triggers, scripts, etc.
RTS_fnc_modifyResource = {
    params ["_resourceType", "_amount"];
    
    private _index = -1;
    {
        _x params ["_type", "_value"];
        if (_type == _resourceType) exitWith {
            _index = _forEachIndex;
        };
    } forEach RTS_resources;
    
    if (_index != -1) then {
        private _currentAmount = (RTS_resources select _index) select 1;
        private _newAmount = _currentAmount + _amount;
        
        // Ensure resources don't go below zero
        if (_newAmount < 0) then {
            _newAmount = 0;
        };
        
        // Update the resource value
        RTS_resources set [_index, [_resourceType, _newAmount]];
        
        // Update the UI
        [] call RTS_fnc_updateResourceUI;
        
        // Debug message
        //if (_amount > 0) then {
        //    systemChat format ["Added %1 %2. New total: %3", _amount, _resourceType, _newAmount];
        //} else {
        //    systemChat format ["Removed %1 %2. New total: %3", abs _amount, _resourceType, _newAmount];
        //};
        
        true
    } else {
        systemChat format ["Resource type '%1' not found!", _resourceType];
        false
    };
};

// Function to modify resource income rates
RTS_fnc_modifyResourceIncome = {
    params ["_resourceType", "_amount"];
    
    private _index = -1;
    {
        _x params ["_type", "_value"];
        if (_type == _resourceType) exitWith {
            _index = _forEachIndex;
        };
    } forEach RTS_resourceIncome;
    
    if (_index != -1) then {
        private _currentRate = (RTS_resourceIncome select _index) select 1;
        private _newRate = _currentRate + _amount;
        
        // Ensure income doesn't go below zero
        if (_newRate < 0) then {
            _newRate = 0;
        };
        
        // Update the income rate
        RTS_resourceIncome set [_index, [_resourceType, _newRate]];
        
        // Update the UI
        [] call RTS_fnc_updateResourceUI;
        
        // Debug message
        if (_amount > 0) then {
            systemChat format ["Increased %1 income by %2/min. New rate: %3/min", _resourceType, _amount, _newRate];
        } else {
            systemChat format ["Decreased %1 income by %2/min. New rate: %3/min", _resourceType, abs _amount, _newRate];
        };
        
        true
    } else {
        systemChat format ["Resource type '%1' not found!", _resourceType];
        false
    };
};

// Function to update resources based on income rates
RTS_fnc_updateResources = {
    private _currentTime = time;
    private _deltaTime = _currentTime - RTS_lastResourceUpdate;
    private _deltaMinutes = _deltaTime / 60;
    
    // Update each resource based on its income rate
    {
        _x params ["_type", "_rate"];
        private _income = _rate * _deltaMinutes;
        
        if (_income > 0) then {
            [_type, _income] call RTS_fnc_modifyResource;
        };
    } forEach RTS_resourceIncome;
    
    // Update the last update time
    RTS_lastResourceUpdate = _currentTime;
};

// Main loop for resource income
[] spawn {
    while {true} do {
        // Update resources every 5 seconds
        [] call RTS_fnc_updateResources;
        
        sleep 5;
    };
};