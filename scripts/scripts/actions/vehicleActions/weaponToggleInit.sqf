// scripts/actions/vehicleActions/weaponToggleInit.sqf
// Initialize variables for all vehicles to support weapon toggle system

// Wait until mission starts
waitUntil {time > 0};

// Initialize weapon tracking for all vehicles
{
    if (_x isKindOf "Car" || _x isKindOf "Tank" || _x isKindOf "Air") then {
        // Get available weapons
        private _weapons = _x weaponsTurret [0];
        
        // Initialize variables
        _x setVariable ["RTS_availableWeapons", _weapons, true];
        _x setVariable ["RTS_selectedWeaponIndex", 0, true];
    };
} forEach vehicles;

// Add event handler for newly created vehicles
addMissionEventHandler ["EntityCreated", {
    params ["_entity"];
    
    if (_entity isKindOf "Car" || _entity isKindOf "Tank" || _entity isKindOf "Air") then {
        // Get available weapons
        private _weapons = _entity weaponsTurret [0];
        
        // Initialize variables
        _entity setVariable ["RTS_availableWeapons", _weapons, true];
        _entity setVariable ["RTS_selectedWeaponIndex", 0, true];
    };
}];

systemChat "Weapon toggle system initialized";