// scripts/ui/infoPanels/combatStatusInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlShow false;
};

// Get group to determine combat mode and speed
private _group = group _unit;
if (isNull _group) exitWith {
    _ctrl ctrlShow false;
};

// Get combat mode
private _combatMode = combatMode _group;
private _combatText = switch (_combatMode) do {
    case "BLUE": { "Holding Fire" };
    case "GREEN": { "Hold Fire, Engage at Will" };
    case "WHITE": { "Hold Fire, Defend Only" };
    case "YELLOW": { "Fire at Will" };
    case "RED": { "Fire at Will, Engage at Will" };
    default { "Unknown" };
};

// Get movement speed
private _speed = speedMode _group;
private _speedText = switch (_speed) do {
    case "LIMITED": { "Slow" };
    case "NORMAL": { "Normal" };
    case "FULL": { "Fast" };
    default { "Unknown" };
};

// Set combined text
_ctrl ctrlSetText format ["Combat: %1 | Speed: %2", _combatText, _speedText];

// Set color based on combat mode
private _color = switch (_combatMode) do {
    case "BLUE": { [0.4, 0.4, 0.8, 1] };   // Blue
    case "GREEN": { [0.4, 0.8, 0.4, 1] };  // Green
    case "WHITE": { [0.8, 0.8, 0.8, 1] };  // White
    case "YELLOW": { [0.8, 0.8, 0.2, 1] }; // Yellow
    case "RED": { [0.8, 0.2, 0.2, 1] };    // Red
    default { [0.7, 0.7, 0.7, 1] };        // Gray
};

_ctrl ctrlSetTextColor _color;
_ctrl ctrlShow true;