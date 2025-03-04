// scripts/ui/infoPanels/nameRankInfo.sqf
params ["_ctrl", "_unit"];

if (isNull _unit) exitWith {
    _ctrl ctrlSetText "Name: No selection";
    _ctrl ctrlSetTextColor [0.7, 0.7, 0.7, 1];
    _ctrl ctrlShow true;
};

// Combine name and rank information
private _rankDisplay = switch (rank _unit) do {
    case "PRIVATE": { "Pvt." };
    case "CORPORAL": { "Cpl." };
    case "SERGEANT": { "Sgt." };
    case "LIEUTENANT": { "Lt." };
    case "CAPTAIN": { "Capt." };
    case "MAJOR": { "Maj." };
    case "COLONEL": { "Col." };
    default { rank _unit };
};

_ctrl ctrlSetText format ["%1 %2", _rankDisplay, name _unit];
_ctrl ctrlSetTextColor [1, 1, 1, 1];
_ctrl ctrlShow true;