// scripts/ui/infoPanels/fatigueInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit || !(_unit isKindOf "CAManBase")) exitWith {
    _ctrl ctrlShow false;
};

private _fatigue = getFatigue _unit;
private _color = switch (true) do {
    case (_fatigue < 0.3): {[0.2, 0.8, 0.2, 1]};
    case (_fatigue < 0.7): {[0.8, 0.8, 0.2, 1]};
    default {[0.8, 0.2, 0.2, 1]};
};

_ctrl ctrlSetText format ["Fatigue: %1%2", floor(_fatigue * 100), "%"];
_ctrl ctrlSetTextColor _color;
_ctrl ctrlShow true;