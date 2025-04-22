// Capture Ability
// Makes nearby outnumbered enemy units surrender and become prisoners

params ["_unit"];

// === GAMEPLAY VARIABLES - ADJUST THESE VALUES TO CHANGE BEHAVIOR ===
private _captureRange = 50;       // Range to check for enemy units (meters)
private _cooldownTime = 600;      // Cooldown time in seconds (10 minutes)
private _captureRatio = 1.5;      // Our units must outnumber enemies by this ratio
private _maxCaptures = 5;         // Maximum number of units that can be captured at once



systemChat format ["%1 is using Capture ability!", name _unit];

// Find nearby enemy units
private _nearEnemies = _unit nearEntities ["CAManBase", _captureRange];
_nearEnemies = _nearEnemies select {
    side _x != side _unit && 
    side _x != civilian && 
    !captive _x && 
    alive _x
};

// Count friendly units in the same area
private _nearFriendlies = _unit nearEntities ["CAManBase", _captureRange];
_nearFriendlies = _nearFriendlies select {side _x == side _unit && alive _x};
private _friendlyCount = count _nearFriendlies;
private _enemyCount = count _nearEnemies;

// Check if we have enough units to force surrender
if (_enemyCount == 0) exitWith {
    systemChat "No enemy units found within capture range.";
    hint "No enemy units found within capture range.";
};

if (_friendlyCount < (_enemyCount * _captureRatio)) exitWith {
    systemChat "Not enough friendly units to force enemy surrender.";
    hint parseText format [
        "<t size='1.5' color='#ff6666'>Capture Failed</t><br/><br/>Need <t color='#ff9900'>%1</t> friendly units to capture <t color='#ff9900'>%2</t> enemies.<br/>Currently have <t color='#ff9900'>%3</t> friendly units.",
        ceil(_enemyCount * _captureRatio), _enemyCount, _friendlyCount
    ];
};

// Limit number of captures to avoid performance issues
if (_enemyCount > _maxCaptures) then {
    _nearEnemies = _nearEnemies select [0, _maxCaptures];
    _enemyCount = _maxCaptures;
    systemChat format ["Limiting capture to %1 units.", _maxCaptures];
};

// Success - begin capture process
private _captureGroup = group _unit;
private _capturedCount = 0;

// Process each enemy for capture
{
    private _enemy = _x;
    
    // Random chance of capture based on various factors
    private _captureChance = 0.85; // Base 85% capture rate
    
    // Reduce chance if enemy is in good condition
    if (damage _enemy < 0.2) then { _captureChance = _captureChance - 0.15; };
    
    // Increase chance if enemy is damaged
    if (damage _enemy > 0.5) then { _captureChance = _captureChance + 0.25; };
    
    // Higher chance if we heavily outnumber them
    if (_friendlyCount > (_enemyCount * 2)) then { _captureChance = _captureChance + 0.2; };
    
    // Proceed with capture if chance is successful
    if (random 1 < _captureChance) then {
        // Make enemy surrender
        _enemy setCaptive true;
        _enemy setUnitPos "UP";
        
        // Remove enemy's weapons
        removeAllWeapons _enemy;
        
        // Make them join our group temporarily
        [_enemy] joinSilent _captureGroup;
        
        // Mark them as a prisoner
        _enemy setVariable ["isPrisoner", true, true];
        
        // Visual identification for prisoners
        if (!isNull _enemy) then {
            [_enemy, "ctsShowPose"] remoteExec ["playActionNow"];
            
            // Add a marker on the unit
            private _marker = createMarker [format ["prisoner_%1", name _enemy], getPos _enemy];
            _marker setMarkerType "mil_circle";
            _marker setMarkerColor "ColorYellow";
            _marker setMarkerText "POW";
            _marker setMarkerSize [0.5, 0.5];
            
            // Attach marker to unit
            [_marker, _enemy] spawn {
                params ["_marker", "_unit"];
                while {alive _unit && _unit getVariable ["isPrisoner", false]} do {
                    _marker setMarkerPos getPos _unit;
                    sleep 1;
                };
                deleteMarker _marker;
            };
        };
        
        _capturedCount = _capturedCount + 1;
    };
} forEach _nearEnemies;

// Set cooldown for the ability
_unit setVariable ["ABILITY_capture_cooldown", time + _cooldownTime, true];

// Provide feedback
if (_capturedCount > 0) then {
    systemChat format ["Successfully captured %1 enemy units!", _capturedCount];
    hint parseText format [
        "<t size='1.5' color='#66ff66'>Capture Successful</t><br/><br/>Captured <t color='#ffcc00'>%1</t> enemy units.<br/><br/>Escort them to your base for processing.",
        _capturedCount
    ];
    
    // Add a marker to indicate successful ability use
    private _marker = createMarker [format ["capture_%1_%2", name _unit, round time], getPos _unit];
    _marker setMarkerType "mil_circle";
    _marker setMarkerColor "ColorGreen";
    _marker setMarkerText "Capture";
    _marker setMarkerSize [1, 1];
    
    // Auto-delete marker after a while
    [_marker] spawn {
        params ["_marker"];
        sleep 60;
        deleteMarker _marker;
    };
} else {
    systemChat "Failed to capture any enemy units.";
    hint "Failed to capture any enemy units.";
    
    // Reduce cooldown on failure
    _unit setVariable ["ABILITY_capture_cooldown", time + (_cooldownTime * 0.3), true];
};