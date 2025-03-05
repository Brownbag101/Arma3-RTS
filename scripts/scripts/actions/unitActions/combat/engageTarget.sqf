// scripts/actions/unitActions/combat/engageTarget.sqf
params ["_unit", "_selections"];

// This is an individual unit action - only affect this unit, not its group
systemChat format ["%1 engaging target", name _unit];
_unit enableAI "TARGET";
_unit enableAI "AUTOTARGET";
_unit setCombatMode "YELLOW";

// Add option to select target
[] spawn {
    hint "Click on map to select engagement target";
    onMapSingleClick {
        private _unit = curatorSelected select 0 select 0;
        if (!isNull _unit) then {
            _unit doWatch _pos;
            hint format ["%1 watching position", name _unit];
        };
        onMapSingleClick {};
    };
};