// scripts/actions/squadActions/squadEngageTarget.sqf
params ["_unit", "_selections"];

// Apply to all selected units
{
    _x enableAI "TARGET";
    _x enableAI "AUTOTARGET";
    _x setCombatMode "YELLOW";
} forEach _selections;

// Also set group combat mode if they're in the same group
private _groups = [];
{
    private _group = group _x;
    if (!isNull _group && !(_group in _groups)) then {
        _groups pushBack _group;
    };
} forEach _selections;

{
    _x setCombatMode "YELLOW";
    systemChat format ["%1 set to Engage", groupId _x];
} forEach _groups;

// Add option to select group target
[] spawn {
    hint "Click on map to select engagement target for squad";
    onMapSingleClick {
        private _selections = curatorSelected select 0;
        
        {
            _x doWatch _pos;
        } forEach _selections;
        
        hint format ["Squad now watching position"];
        onMapSingleClick {};
    };
};