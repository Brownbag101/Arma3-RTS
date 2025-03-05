// scripts/ui/infoPanels/nameInfo.sqf
// Simplest possible version
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlSetText "Name: No selection";
    _ctrl ctrlSetTextColor [0.7, 0.7, 0.7, 1];
    _ctrl ctrlShow true;
};

// Just show the unit name
_ctrl ctrlSetText format ["Name: %1", name _unit];
_ctrl ctrlSetTextColor [1, 1, 1, 1];
_ctrl ctrlShow true;