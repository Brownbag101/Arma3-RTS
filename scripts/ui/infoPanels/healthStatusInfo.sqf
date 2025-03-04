// scripts/ui/infoPanels/healthStatusInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlShow false;
};

// Get health information
private _health = 1 - damage _unit;
private _healthColor = switch (true) do {
    case (_health >= 0.75): {[0.2, 0.8, 0.2, 1]};  // Green
    case (_health >= 0.25): {[0.8, 0.8, 0.2, 1]};  // Yellow
    default {[0.8, 0.2, 0.2, 1]};  // Red
};

// Initialize status text
private _healthText = format ["Health: %1%%", floor(_health * 100)];

// Get ammo information
private _ammoText = "";
private _currentWeapon = currentWeapon _unit;
if (_currentWeapon != "") then {
    private _ammoCount = _unit ammo _currentWeapon;
    
    // Determine magazine size for infantry
    private _maxAmmo = 30; // Default magazine size
    if (_unit isKindOf "CAManBase") then {
        private _magazines = magazines _unit;
        {
            private _magazineType = _x;
            private _weaponMags = getArray (configFile >> "CfgWeapons" >> _currentWeapon >> "magazines");
            
            if (_magazineType in _weaponMags) then {
                _maxAmmo = getNumber (configFile >> "CfgMagazines" >> _magazineType >> "count");
            };
        } forEach _magazines;
    };
    
    _ammoText = format [" | Ammo: %1/%2", _ammoCount, _maxAmmo];
};

// Get fatigue information if it's a person
private _fatigueText = "";
if (_unit isKindOf "CAManBase") then {
    private _fatigue = getFatigue _unit;
    private _staminaText = switch (true) do {
        case (_fatigue < 0.3): { "Rested" };
        case (_fatigue < 0.7): { "Tired" };
        default { "Exhausted" };
    };
    _fatigueText = format [" | %1", _staminaText];
};

// Set combined text
_ctrl ctrlSetText format ["%1%2%3", _healthText, _ammoText, _fatigueText];
_ctrl ctrlSetTextColor _healthColor;
_ctrl ctrlShow true;