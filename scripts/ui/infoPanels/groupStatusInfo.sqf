// scripts\ui\infoPanels\groupStatusInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlShow false;
};

private _group = group _unit;
if (isNull _group) exitWith {
    _ctrl ctrlSetText "Group Status: N/A";
    _ctrl ctrlSetTextColor [0.7, 0.7, 0.7, 1];
    _ctrl ctrlShow true;
};

// Count unit status
private _totalUnits = count (units _group);
private _healthy = 0;
private _wounded = 0;
private _critical = 0;
private _dead = 0;

{
    private _damage = damage _x;
    switch (true) do {
        case (!alive _x): { _dead = _dead + 1; };
        case (_damage > 0.75): { _critical = _critical + 1; };
        case (_damage > 0.25): { _wounded = _wounded + 1; };
        default { _healthy = _healthy + 1; };
    };
} forEach (units _group);

// Get group's combat mode
private _combatMode = behaviour (leader _group);
private _formation = formation _group;

// Format combat mode for display
private _combatModeStr = switch (_combatMode) do {
    case "CARELESS": { "Careless" };
    case "SAFE": { "Safe" };
    case "AWARE": { "Aware" };
    case "COMBAT": { "Combat" };
    case "STEALTH": { "Stealth" };
    default { "Unknown" };
};

// Format formation for display
private _formationStr = switch (_formation) do {
    case "COLUMN": { "Column" };
    case "STAG COLUMN": { "Staggered Column" };
    case "WEDGE": { "Wedge" };
    case "ECH LEFT": { "Echelon Left" };
    case "ECH RIGHT": { "Echelon Right" };
    case "VEE": { "Vee" };
    case "LINE": { "Line" };
    case "FILE": { "File" };
    case "DIAMOND": { "Diamond" };
    default { "Unknown" };
};

// Set text based on collected information
_ctrl ctrlSetText format ["Group: %1 OK, %2 Wounded, %3 Critical | %4 - %5", 
    _healthy, _wounded, _critical, _combatModeStr, _formationStr];

// Set color based on overall status
private _healthyRatio = _healthy / _totalUnits;
private _color = switch (true) do {
    case (_dead > 0): { [0.8, 0.2, 0.2, 1] };
    case (_critical > 0): { [0.8, 0.4, 0.2, 1] };
    case (_wounded > 0): { [0.8, 0.8, 0.2, 1] };
    default { [0.2, 0.8, 0.2, 1] };
};

_ctrl ctrlSetTextColor _color;
_ctrl ctrlShow true;