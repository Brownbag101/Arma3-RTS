// scripts/ui/infoPanels/rankInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlShow false;
};

_ctrl ctrlSetText format ["Rank: %1", rank _unit];
_ctrl ctrlSetTextColor [0.8, 0.8, 0.8, 1];
_ctrl ctrlShow true;