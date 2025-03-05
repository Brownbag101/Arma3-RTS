// scripts/ui/infoPanels/vehicleStatusInfo.sqf
params ["_ctrl", "_vehicle"];

if (isNull _vehicle) exitWith {
    _ctrl ctrlShow false;
};

// Get health information
private _health = 1 - damage _vehicle;
private _healthColor = switch (true) do {
    case (_health >= 0.75): {[0.2, 0.8, 0.2, 1]};  // Green
    case (_health >= 0.25): {[0.8, 0.8, 0.2, 1]};  // Yellow
    default {[0.8, 0.2, 0.2, 1]};  // Red
};

// Get fuel information
private _fuel = fuel _vehicle;
private _fuelText = format [" | Fuel: %1%%", floor(_fuel * 100)];

// Get combat mode
private _combatMode = "UNKNOWN";
if (count (crew _vehicle) > 0) then {
    _combatMode = combatMode (group (driver _vehicle));
};

private _combatText = switch (_combatMode) do {
    case "BLUE": { "Holding Fire" };
    case "GREEN": { "Hold Fire, Engage at Will" };
    case "WHITE": { "Hold Fire, Defend Only" };
    case "YELLOW": { "Fire at Will" };
    case "RED": { "Fire at Will, Engage at Will" };
    default { "Unknown" };
};
private _combatStatus = format [" | %1", _combatText];

// Set combined text
_ctrl ctrlSetText format ["Health: %1%%%2%3", floor(_health * 100), _fuelText, _combatStatus];
_ctrl ctrlSetTextColor _healthColor;
_ctrl ctrlShow true;