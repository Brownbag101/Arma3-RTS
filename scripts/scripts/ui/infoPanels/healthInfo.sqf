// scripts/ui/infoPanels/healthInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlShow false;
};

private _damage = 1 - damage _unit;
private _color = switch (true) do {
    case (_damage >= 0.75): {[0.2, 0.8, 0.2, 1]};
    case (_damage >= 0.25): {[0.8, 0.8, 0.2, 1]};
    default {[0.8, 0.2, 0.2, 1]};
};
_ctrl ctrlSetText format ["Health: %1%2", floor(_damage * 100), "%"];
_ctrl ctrlSetTextColor _color;
_ctrl ctrlShow true;