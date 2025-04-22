// scripts/actions/squadActions/squadHoldFire.sqf
params ["_unit", "_selections"];

// Apply to all selected units
{
    _x disableAI "TARGET";
    _x disableAI "AUTOTARGET";
    _x setCombatMode "BLUE";
	_x setBehaviour "CARELESS";
	_x setSpeedMode "NORMAL";
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
    _x setCombatMode "BLUE";
    systemChat format ["%1 set to Hold Fire", groupId _x];
} forEach _groups;