// scripts/ui/infoPanels/stanceInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit || !(_unit isKindOf "CAManBase")) exitWith {
    _ctrl ctrlShow false;
};

private _stance = stance _unit;
private _stanceText = switch (_stance) do {
    case "STAND": { "Standing" };
    case "CROUCH": { "Crouching" };
    case "PRONE": { "Prone" };
    case "UNDEFINED": { "Undefined" };
    default { "Unknown" };
};

_ctrl ctrlSetText format ["Stance: %1", _stanceText];
_ctrl ctrlSetTextColor [0.8, 0.8, 0.8, 1];
_ctrl ctrlShow true;