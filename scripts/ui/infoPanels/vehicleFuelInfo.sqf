// scripts/ui/infoPanels/vehicleFuelInfo.sqf
params ["_ctrl", "_vehicle"];

if (isNull _vehicle || !(_vehicle isKindOf "LandVehicle" || _vehicle isKindOf "Air" || _vehicle isKindOf "Ship")) exitWith {
    _ctrl ctrlShow false;
};

private _fuel = fuel _vehicle;
private _color = switch (true) do {
    case (_fuel >= 0.75): {[0.2, 0.8, 0.2, 1]};
    case (_fuel >= 0.25): {[0.8, 0.8, 0.2, 1]};
    default {[0.8, 0.2, 0.2, 1]};
};

_ctrl ctrlSetText format ["Fuel: %1%2", floor(_fuel * 100), "%"];
_ctrl ctrlSetTextColor _color;
_ctrl ctrlShow true;