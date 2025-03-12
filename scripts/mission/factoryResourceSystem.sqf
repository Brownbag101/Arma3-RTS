// Simplified Factory Recapture System
// This version focuses on robust recapture mechanics

// =====================================================================
// FACTORY PRODUCTION CONFIGURATION - EDIT THESE VALUES AS NEEDED
// =====================================================================

// Format: [locationType, [[resourceType, incomeBonus], [resourceType, incomeBonus], ...]]
FACTORY_RESOURCE_BONUSES = [
    ["factory", [
        ["iron", 15],      // Factories provide +15 iron per minute
        ["steel", 10],     // +10 steel per minute
        ["rubber", 5]      // +5 rubber per minute
    ]],
    ["port", [
        ["oil", 10],       // Ports provide +10 oil per minute
        ["rubber", 8],     // +8 rubber per minute 
        ["wood", 5]        // +5 wood per minute
    ]],
    ["airfield", [
        ["aluminum", 15],  // Airfields provide +15 aluminum per minute
        ["fuel", 10],      // +10 fuel per minute
        ["oil", 5]         // +5 oil per minute
    ]],
    ["hq", [
        ["training", 5],   // HQs provide +5 training points per minute
        ["manpower", 3],   // +3 manpower per minute
        ["intelligence", 2] // +2 intelligence per minute (if implemented)
    ]]
];

// Track captured locations and their provided bonuses
FACTORY_CAPTURED_BONUSES = [];

// Track locations that need monitoring for enemy recapture
FACTORY_MONITOR_LOCATIONS = [];

// Function to apply resource income bonus when location is captured
fnc_applyLocationResourceBonus = {
    params ["_locationIndex"];
    
    // Get location data
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        diag_log format ["Invalid location index: %1", _locationIndex];
        false
    };
    
    // Check if already providing bonus
    private _existingIndex = FACTORY_CAPTURED_BONUSES findIf {(_x select 0) == _locationIndex};
    if (_existingIndex != -1) exitWith {
        diag_log format ["Location %1 is already providing resource bonuses", _locationIndex];
        false
    };
    
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    private _locationType = _locationData select 2; // Type (factory, port, etc.)
    private _locationName = _locationData select 1; // Name for feedback
    
    diag_log format ["FACTORY SYSTEM: Applying resource bonuses for %1 (%2)", _locationName, _locationType];
    
    // Add to monitored locations for recapture check
    if !(_locationIndex in FACTORY_MONITOR_LOCATIONS) then {
        FACTORY_MONITOR_LOCATIONS pushBack _locationIndex;
        diag_log format ["Added location %1 to recapture monitoring", _locationIndex];
    };
    
    // Find resource bonuses for this location type
    private _typeIndex = FACTORY_RESOURCE_BONUSES findIf {(_x select 0) == _locationType};
    if (_typeIndex == -1) exitWith {
        diag_log format ["No resource bonuses defined for location type: %1", _locationType];
        false
    };
    
    // Get bonuses and apply them
    private _bonuses = (FACTORY_RESOURCE_BONUSES select _typeIndex) select 1;
    private _appliedBonuses = [];
    private _bonusText = "";
    
    {
        _x params ["_resourceType", "_bonusAmount"];
        
        // Apply bonus using economy system
        if (!isNil "RTS_fnc_modifyResourceIncome") then {
            diag_log format ["FACTORY SYSTEM: Applying resource bonus for %1: +%2 %3/min", _locationName, _bonusAmount, _resourceType];
            [_resourceType, _bonusAmount] call RTS_fnc_modifyResourceIncome;
            _appliedBonuses pushBack [_resourceType, _bonusAmount];
            
            // Add to bonus text
            if (_bonusText != "") then { _bonusText = _bonusText + ", "; };
            _bonusText = _bonusText + format ["+%1 %2/min", _bonusAmount, _resourceType];
        } else {
            diag_log "WARNING: RTS_fnc_modifyResourceIncome is not defined, cannot apply resource bonus";
        };
    } forEach _bonuses;
    
    // Store applied bonuses for later removal if location is lost
    if (count _appliedBonuses > 0) then {
        FACTORY_CAPTURED_BONUSES pushBack [_locationIndex, _appliedBonuses];
        
        // Show notification
        systemChat format ["Production increased at %1: %2", _locationName, _bonusText];
        hint format ["Production increased at %1\n\n%2", _locationName, _bonusText];
        
        true
    } else {
        diag_log format ["No bonuses applied for location %1", _locationName];
        false
    };
};

// Function to remove resource income bonus when location is lost
fnc_removeLocationResourceBonus = {
    params ["_locationIndex"];
    
    // Find bonuses for this location
    private _bonusIndex = FACTORY_CAPTURED_BONUSES findIf {(_x select 0) == _locationIndex};
    if (_bonusIndex == -1) exitWith {
        diag_log format ["No active bonuses found for location %1", _locationIndex];
        false
    };
    
    // Get location name for feedback
    private _locationName = "Unknown Location";
    if (_locationIndex >= 0 && _locationIndex < count MISSION_LOCATIONS) then {
        _locationName = (MISSION_LOCATIONS select _locationIndex) select 1;
    };
    
    diag_log format ["FACTORY SYSTEM: Removing resource bonuses for %1", _locationName];
    
    // Get applied bonuses
    private _bonusData = FACTORY_CAPTURED_BONUSES select _bonusIndex;
    private _appliedBonuses = _bonusData select 1;
    private _lossText = "";
    
    // Remove each bonus
    {
        _x params ["_resourceType", "_bonusAmount"];
        
        // Remove bonus using economy system (apply negative of the original bonus)
        if (!isNil "RTS_fnc_modifyResourceIncome") then {
            diag_log format ["FACTORY SYSTEM: Removing resource bonus for %1: -%2 %3/min", _locationName, _bonusAmount, _resourceType];
            [_resourceType, -_bonusAmount] call RTS_fnc_modifyResourceIncome;
            
            // Add to loss text
            if (_lossText != "") then { _lossText = _lossText + ", "; };
            _lossText = _lossText + format ["-%1 %2/min", _bonusAmount, _resourceType];
        } else {
            diag_log "WARNING: RTS_fnc_modifyResourceIncome is not defined, cannot remove resource bonus";
        };
    } forEach _appliedBonuses;
    
    // Remove from tracking array
    FACTORY_CAPTURED_BONUSES deleteAt _bonusIndex;
    
    // Remove from monitored locations
    private _monitorIndex = FACTORY_MONITOR_LOCATIONS find _locationIndex;
    if (_monitorIndex != -1) then {
        FACTORY_MONITOR_LOCATIONS deleteAt _monitorIndex;
        diag_log format ["Removed location %1 from recapture monitoring", _locationIndex];
    };
    
    // Show notification
    systemChat format ["Production lost at %1: %2", _locationName, _lossText];
    hint format ["Production lost at %1\n\n%2", _locationName, _lossText];
    
    true
};

// Function to prepare a location for recapture
fnc_prepareLocationForRecapture = {
    params ["_locationIndex"];
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        systemChat "Invalid location index for recapture preparation";
        false
    };
    
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    private _locationName = _locationData select 1;
    private _pos = _locationData select 3;
    
    // Reset any existing triggers or markers that might interfere
    // This is critical for allowing recapture to work again
    
    // 1. Delete any existing capture triggers in the area
    private _existingTriggers = _pos nearObjects ["EmptyDetector", 300];
    {
        if (_x getVariable ["captureTaskTrigger", false]) then {
            deleteVehicle _x;
            diag_log format ["Deleted existing capture trigger at location %1", _locationName];
        };
    } forEach _existingTriggers;
    
    // 2. Clean up any debug markers that might be present
    if (!isNil "CAPTURE_DEBUG_MARKER") then {
        deleteMarker "capture_debug";
        CAPTURE_DEBUG_MARKER = nil;
        diag_log "Deleted capture debug marker";
    };
    
    // 3. Force proper intel to ensure location is recognized as captured by enemy
    [_locationIndex, 100] call fnc_modifyLocationIntel; // Ensure full intel
    
    // 4. Ensure the location is properly marked as enemy-controlled
    (MISSION_LOCATIONS select _locationIndex) set [7, false];
    [_locationIndex] call fnc_updateLocationMarker;
    
    systemChat format ["Location %1 is now ready for recapture operations", _locationName];
    diag_log format ["Location %1 prepared for recapture", _locationName];
    
    true
};

// Hook into the existing task system by overriding the capture location function
// Store the original function first
if (isNil "original_fnc_setCapturedLocation") then {
    original_fnc_setCapturedLocation = fnc_setCapturedLocation;
};

// Create new version that calls the original and adds our factory resource logic
fnc_setCapturedLocation = {
    params ["_locationIndex", "_isCaptured"];
    
    // Get previous capture status
    private _wasCaptured = false;
    if (_locationIndex >= 0 && _locationIndex < count MISSION_LOCATIONS) then {
        _wasCaptured = (MISSION_LOCATIONS select _locationIndex) select 7;
    };
    
    // Call original function
    private _result = [_locationIndex, _isCaptured] call original_fnc_setCapturedLocation;
    
    // Handle resource bonuses
    if (_isCaptured && !_wasCaptured) then {
        diag_log format ["FACTORY SYSTEM: Location %1 captured, applying resource bonuses", _locationIndex];
        [_locationIndex] call fnc_applyLocationResourceBonus;
    };
    
    if (!_isCaptured && _wasCaptured) then {
        diag_log format ["FACTORY SYSTEM: Location %1 lost, removing resource bonuses", _locationIndex];
        [_locationIndex] call fnc_removeLocationResourceBonus;
    };
    
    _result
};

// Also hook into the destroyed location function
if (isNil "original_fnc_setDestroyedLocation") then {
    original_fnc_setDestroyedLocation = fnc_setDestroyedLocation;
};

// Create new version that calls the original and adds our factory resource logic
fnc_setDestroyedLocation = {
    params ["_locationIndex"];
    
    // Get current capture status before destruction
    private _wasCaptured = false;
    if (_locationIndex >= 0 && _locationIndex < count MISSION_LOCATIONS) then {
        _wasCaptured = (MISSION_LOCATIONS select _locationIndex) select 7;
    };
    
    // If this was a captured location providing resource bonuses, remove them
    if (_wasCaptured) then {
        diag_log format ["FACTORY SYSTEM: Captured location %1 destroyed, removing resource bonuses", _locationIndex];
        [_locationIndex] call fnc_removeLocationResourceBonus;
    };
    
    // Call original function
    [_locationIndex] call original_fnc_setDestroyedLocation
};

// Function to check if a location needs to be recaptured by enemy
fnc_checkLocationRecapture = {
    params ["_locationIndex"];
    
    // Make sure the location is valid and is still captured
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {false};
    private _locationData = MISSION_LOCATIONS select _locationIndex;
    
    // Check if the location is still captured by player
    if (!(_locationData select 7)) exitWith {false};
    
    private _pos = _locationData select 3;
    private _locationName = _locationData select 1;
    
    // Check for presence of friendly and enemy units
    private _playerSide = side player;
    private _friendlyUnits = _pos nearEntities [["Man", "Car", "Tank"], 200] select {side _x == _playerSide};
    private _enemyUnits = _pos nearEntities [["Man", "Car", "Tank"], 200] select {side _x != _playerSide && side _x != civilian};
    
    // If no friendly units and at least one enemy unit, the location should be recaptured
    if (count _friendlyUnits == 0 && count _enemyUnits > 0) then {
        diag_log format ["RECAPTURE: Location %1 has %2 enemy units and no friendly units - will be recaptured", _locationName, count _enemyUnits];
        
        // Get enemy side for feedback
        private _enemySide = side (_enemyUnits select 0);
        
        // Force location to be uncaptured
        [_locationIndex, false] call fnc_setCapturedLocation;
        
        // Additional notification
        systemChat format ["ALERT: %1 has been captured by %2 forces!", _locationName, _enemySide];
        hint format ["Location Lost\n\n%1 has been captured by %2 forces!", _locationName, _enemySide];
        
        true
    } else {
        diag_log format ["Location %1 check: %2 friendly units, %3 enemy units", _locationName, count _friendlyUnits, count _enemyUnits];
        false
    };
};

// Enhanced recapture test function - replaces the existing RTS_testRecapture
RTS_testRecapture = {
    params [["_locationIndex", 1]];
    
    // First force the location to be uncaptured
    [_locationIndex, false] call fnc_setCapturedLocation;
    
    // Then properly prepare it for recapture
    [_locationIndex] call fnc_prepareLocationForRecapture;
    
    // Get location name for feedback
    private _locationName = "Unknown";
    if (_locationIndex >= 0 && _locationIndex < count MISSION_LOCATIONS) then {
        _locationName = (MISSION_LOCATIONS select _locationIndex) select 1;
    };
    
    systemChat format ["Location %1 has been captured by enemy forces and is ready for recapture operations", _locationName];
};

// Main monitoring loop for recapture checks
[] spawn {
    sleep 5; // Initial delay to ensure everything is initialized
    
    while {true} do {
        // Check each monitored location for possible recapture
        if (count FACTORY_MONITOR_LOCATIONS > 0) then {
            {
                [_x] call fnc_checkLocationRecapture;
                sleep 0.5; // Short delay between each location check to spread out processing
            } forEach FACTORY_MONITOR_LOCATIONS;
        };
        
        sleep 15; // Check every 15 seconds
    };
};

// Initialize monitoring for any already captured locations
[] spawn {
    sleep 2; // Wait a bit for everything to initialize
    
    {
        private _locationIndex = _forEachIndex;
        private _isCaptured = _x select 7;
        
        if (_isCaptured) then {
            diag_log format ["FACTORY SYSTEM: Adding already captured location %1 to monitoring", _locationIndex];
            
            // Add to monitored locations
            if !(_locationIndex in FACTORY_MONITOR_LOCATIONS) then {
                FACTORY_MONITOR_LOCATIONS pushBack _locationIndex;
            };
            
            // Also apply resource bonuses if not already applied
            private _bonusIndex = FACTORY_CAPTURED_BONUSES findIf {(_x select 0) == _locationIndex};
            if (_bonusIndex == -1) then {
                [_locationIndex] call fnc_applyLocationResourceBonus;
            };
        };
    } forEach MISSION_LOCATIONS;
};

// Simple function to force recapture of a location (for testing)
fnc_forceRecapture = {
    params ["_locationIndex"];
    
    if (_locationIndex < 0 || _locationIndex >= count MISSION_LOCATIONS) exitWith {
        systemChat "Invalid location index for recapture";
    };
    
    private _locationName = (MISSION_LOCATIONS select _locationIndex) select 1;
    systemChat format ["Forcing recapture of %1", _locationName];
    
    // Force the location to be uncaptured
    [_locationIndex, false] call fnc_setCapturedLocation;
    
    systemChat format ["Recapture complete: %1 is now enemy-controlled", _locationName];
};

// Print confirmation message
diag_log "FACTORY SYSTEM: Simplified Factory Resource System initialized";
systemChat "Factory Resource System initialized with simplified recapture system.";