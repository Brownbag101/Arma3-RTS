// scripts/ui/infoPanels/vehicleCargoInfo.sqf
params ["_ctrl", "_vehicle"];

// Remove debug messages for production
if (isNull _vehicle) exitWith {
    _ctrl ctrlShow false;
};

if !(_vehicle isKindOf "Car" || _vehicle isKindOf "Tank" || _vehicle isKindOf "Air") exitWith {
    _ctrl ctrlShow false;
};

// Check if cargo globals are available
if (isNil "MISSION_cargoVehicles" || isNil "MISSION_cargoCapacity") exitWith {
    _ctrl ctrlSetText "Cargo: System unavailable";
    _ctrl ctrlSetTextColor [0.5, 0.5, 0.5, 1];
    _ctrl ctrlShow true;
};

// Check if this vehicle can carry cargo
private _vehType = typeOf _vehicle;
private _canCarryCargo = _vehType in MISSION_cargoVehicles;

if (!_canCarryCargo) exitWith {
    _ctrl ctrlSetText "Cargo: Not available";
    _ctrl ctrlSetTextColor [0.5, 0.5, 0.5, 1];
    _ctrl ctrlShow true;
};

// Get current cargo and capacity
private _currentCargo = _vehicle getVariable ["cargo_items", []];
private _maxCapacity = 0;

{
    _x params ["_type", "_capacity"];
    if (_type == _vehType) exitWith {
        _maxCapacity = _capacity;
    };
} forEach MISSION_cargoCapacity;

// Set appropriate color based on cargo capacity
private _cargoPercentage = if (_maxCapacity > 0) then {(count _currentCargo) / _maxCapacity} else {0};
private _color = switch (true) do {
    case (_cargoPercentage >= 0.8): {[0.8, 0.2, 0.2, 1]}; // Red when almost full
    case (_cargoPercentage >= 0.5): {[0.8, 0.8, 0.2, 1]}; // Yellow when half full
    default {[0.2, 0.8, 0.2, 1]}; // Green when mostly empty
};

_ctrl ctrlSetText format ["Cargo: %1/%2", count _currentCargo, _maxCapacity];
_ctrl ctrlSetTextColor _color;
_ctrl ctrlShow true;